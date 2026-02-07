import { create } from "zustand";
import type { PsdIR, LayerTreeNode } from "../wasm/types";
import type { LayerPixelData, LayerRenderInfo } from "../webgl/types";
import { parsePsd, rebuildPsd, getCompositeRgba, getLayerRgba } from "../wasm/bridge";

/** Extract flat list of LayerRenderInfo from the IR layer tree */
function extractLayerInfos(node: LayerTreeNode | null): LayerRenderInfo[] {
  if (!node) return [];
  const result: LayerRenderInfo[] = [];
  function walk(n: LayerTreeNode) {
    if (n.type === "layer") {
      result.push({
        layerIndex: n.layerIndex,
        blendMode: n.blendMode,
        opacity: n.opacity,
        visible: n.visible,
        rect: { ...n.rect },
      });
    } else if (n.type === "group" || n.type === "root") {
      for (const child of n.children) walk(child);
    }
  }
  walk(node);
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
  loadFile: (file: File) => Promise<void>;
  exportPsd: () => Promise<void>;
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
      set({ ir, handle, loading: false, layerInfos: infos });

      // Fetch composite RGBA in background for the visualizer
      getCompositeRgba(handle)
        .then((rgba) => set({ compositeRgba: rgba }))
        .catch((err) => console.warn("Failed to get composite RGBA:", err));

      // Fetch all layer pixel data in parallel
      const pixels = new Map<number, LayerPixelData>();
      const promises = infos.map(async (info) => {
        try {
          const data = await getLayerRgba(handle, info.layerIndex, info.rect);
          pixels.set(info.layerIndex, data);
        } catch (err) {
          console.warn(`Failed to get layer ${info.layerIndex} RGBA:`, err);
        }
      });
      await Promise.all(promises);
      set({ layerPixels: pixels, layersLoaded: true });
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
    }),
}));
