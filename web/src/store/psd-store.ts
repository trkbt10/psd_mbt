import { create } from "zustand";
import type { PsdIR, LayerTreeNode } from "../wasm/types";
import type { LayerPixelData, LayerRenderInfo } from "../webgl/types";
import { parsePsd, rebuildPsd, getCompositeRgba, getLayerRgba } from "../wasm/bridge";

/** Find a node by layerIndex in the tree */
function findNodeByLayerIndex(root: LayerTreeNode, target: number): LayerTreeNode | null {
  if ((root.type === "layer" || root.type === "group") && root.layerIndex === target) {
    return root;
  }
  if (root.type === "group" || root.type === "root") {
    for (const child of root.children) {
      const found = findNodeByLayerIndex(child, target);
      if (found) return found;
    }
  }
  return null;
}

/** Collect all descendant layer indexes (both leaves and sub-groups) */
function collectDescendantIndexes(node: LayerTreeNode): number[] {
  const result: number[] = [];
  function walk(n: LayerTreeNode) {
    if (n.type === "layer") {
      result.push(n.layerIndex);
    } else if (n.type === "group") {
      result.push(n.layerIndex);
      for (const child of n.children) walk(child);
    }
  }
  if (node.type === "group") {
    for (const child of node.children) walk(child);
  }
  return result;
}

/** Get effective visibility: override if present, otherwise original tree value */
function getEffectiveVisibility(
  root: LayerTreeNode,
  layerIndex: number,
  overrides: Map<number, boolean>,
): boolean {
  if (overrides.has(layerIndex)) return overrides.get(layerIndex)!;
  const node = findNodeByLayerIndex(root, layerIndex);
  if (!node) return true;
  if (node.type === "layer" || node.type === "group") return node.visible;
  return true;
}

/** Extract flat list of LayerRenderInfo from the IR layer tree.
 *  Propagates parent group visibility: children of a hidden group are hidden. */
function extractLayerInfos(
  node: LayerTreeNode | null,
  overrides?: Map<number, boolean>,
): LayerRenderInfo[] {
  if (!node) return [];
  const result: LayerRenderInfo[] = [];
  function walk(n: LayerTreeNode, parentVisible: boolean) {
    if (n.type === "layer") {
      const ownVisible = overrides?.has(n.layerIndex)
        ? overrides.get(n.layerIndex)!
        : n.visible;
      result.push({
        layerIndex: n.layerIndex,
        blendMode: n.blendMode,
        opacity: n.opacity,
        visible: parentVisible && ownVisible,
        rect: { ...n.rect },
      });
    } else if (n.type === "group") {
      const groupVisible = overrides?.has(n.layerIndex)
        ? overrides.get(n.layerIndex)!
        : n.visible;
      for (const child of n.children) walk(child, parentVisible && groupVisible);
    } else if (n.type === "root") {
      for (const child of n.children) walk(child, parentVisible);
    }
  }
  walk(node, true);
  return result;
}

interface PsdState {
  fileName: string | null;
  fileSize: number;
  ir: PsdIR | null;
  handle: number;
  loading: boolean;
  error: string | null;
  compositeRgba: Uint8Array | null;
  layerPixels: Map<number, LayerPixelData>;
  layerInfos: LayerRenderInfo[];
  layersLoaded: boolean;
  failedLayers: Set<number>;
  visibilityOverrides: Map<number, boolean>;
  loadFile: (file: File) => Promise<void>;
  exportPsd: () => Promise<void>;
  toggleLayerVisibility: (layerIndex: number) => void;
  clear: () => void;
}

export const usePsdStore = create<PsdState>((set, get) => ({
  fileName: null,
  fileSize: 0,
  ir: null,
  handle: -1,
  loading: false,
  error: null,
  compositeRgba: null,
  layerPixels: new Map(),
  layerInfos: [],
  layersLoaded: false,
  failedLayers: new Set(),
  visibilityOverrides: new Map(),

  loadFile: async (file) => {
    set({
      loading: true,
      error: null,
      fileName: file.name,
      fileSize: file.size,
    });
    try {
      const { ir, handle } = await parsePsd(file);
      const infos = extractLayerInfos(ir.layerTree);
      console.log(`[store] parsed: ${infos.length} leaf layers, visible: ${infos.filter(i => i.visible).length}`);
      for (const info of infos) {
        const w = info.rect.right - info.rect.left;
        const h = info.rect.bottom - info.rect.top;
        console.log(`  layer[${info.layerIndex}]: ${w}x${h} visible=${info.visible}`);
      }
      set({ ir, handle, loading: false, layerInfos: infos, visibilityOverrides: new Map() });

      // Fetch composite RGBA FIRST so the user sees something immediately.
      // For 16-bit files, the composite is already decompressed during parse,
      // so this is fast (just planar→RGBA conversion).
      try {
        const rgba = await getCompositeRgba(handle);
        console.log(`[store] composite rgba: ${rgba.byteLength} bytes`);
        set({ compositeRgba: rgba });
      } catch (err) {
        console.warn("[store] Failed to get composite RGBA:", err);
      }

      // Then fetch per-layer pixel data for visible layers only.
      // Invisible layers are skipped to save GPU memory and time.
      const pixels = new Map<number, LayerPixelData>();
      const failed = new Set<number>();
      const visibleInfos = infos.filter(i => i.visible);
      console.log(`[store] loading ${visibleInfos.length}/${infos.length} visible layers`);
      for (const info of visibleInfos) {
        const w = info.rect.right - info.rect.left;
        const h = info.rect.bottom - info.rect.top;
        if (w <= 0 || h <= 0) continue;
        try {
          const data = await getLayerRgba(handle, info.layerIndex, info.rect);
          console.log(`[store] layer[${info.layerIndex}] rgba: ${data.width}x${data.height} (${data.rgba.byteLength} bytes)`);
          pixels.set(info.layerIndex, data);
        } catch (err) {
          console.warn(`[store] layer[${info.layerIndex}] FAILED:`, err);
          failed.add(info.layerIndex);
        }
      }
      console.log(`[store] all layers done: ${pixels.size} ok, ${failed.size} failed`);
      set({ layerPixels: pixels, layersLoaded: true, failedLayers: failed });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },

  exportPsd: async () => {
    const { handle, fileName } = get();
    if (handle < 0) return;
    set({ loading: true });
    try {
      const bytes = await rebuildPsd(handle);
      const blob = new Blob([bytes as unknown as BlobPart], { type: "application/octet-stream" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName ?? "output.psd";
      a.click();
      URL.revokeObjectURL(url);
      set({ loading: false });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },

  toggleLayerVisibility: (layerIndex: number) => {
    const { ir, visibilityOverrides } = get();
    if (!ir?.layerTree) return;

    const overrides = new Map(visibilityOverrides);
    const currentVisible = getEffectiveVisibility(ir.layerTree, layerIndex, overrides);
    const newVisible = !currentVisible;

    overrides.set(layerIndex, newVisible);

    // If it's a group, propagate to all descendants
    const node = findNodeByLayerIndex(ir.layerTree, layerIndex);
    if (node?.type === "group") {
      for (const idx of collectDescendantIndexes(node)) {
        overrides.set(idx, newVisible);
      }
    }

    const infos = extractLayerInfos(ir.layerTree, overrides);
    set({ visibilityOverrides: overrides, layerInfos: infos });

    // Load pixel data for newly-visible layers that don't have any
    if (!newVisible) return;
    const { handle, layerPixels, failedLayers } = get();
    if (handle < 0) return;

    const toLoad = infos.filter(
      (i) =>
        i.visible &&
        !layerPixels.has(i.layerIndex) &&
        !failedLayers.has(i.layerIndex) &&
        i.rect.right - i.rect.left > 0 &&
        i.rect.bottom - i.rect.top > 0,
    );
    if (toLoad.length === 0) return;

    console.log(`[store] loading ${toLoad.length} newly-visible layers`);
    (async () => {
      const pixels = new Map(get().layerPixels);
      const failed = new Set(get().failedLayers);
      for (const info of toLoad) {
        try {
          const data = await getLayerRgba(handle, info.layerIndex, info.rect);
          console.log(`[store] layer[${info.layerIndex}] rgba: ${data.width}x${data.height}`);
          pixels.set(info.layerIndex, data);
        } catch (err) {
          console.warn(`[store] layer[${info.layerIndex}] FAILED:`, err);
          failed.add(info.layerIndex);
        }
      }
      set({ layerPixels: new Map(pixels), failedLayers: new Set(failed) });
    })();
  },

  clear: () =>
    set({
      fileName: null,
      fileSize: 0,
      ir: null,
      handle: -1,
      error: null,
      compositeRgba: null,
      layerPixels: new Map(),
      layerInfos: [],
      layersLoaded: false,
      failedLayers: new Set(),
      visibilityOverrides: new Map(),
    }),
}));
