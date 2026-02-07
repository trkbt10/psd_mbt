import { useRef, useEffect, useCallback, useMemo } from "react";
import { usePsdStore } from "../../store/psd-store";
import { useCanvasStore } from "../../store/canvas-store";
import { useUIStore } from "../../store/ui-store";
import { WebGLRenderer } from "../../webgl/renderer";
import { CanvasControls } from "./CanvasControls";
import type { LayerBounds, LayerPixelData } from "../../webgl/types";
import type { LayerTreeNode } from "../../wasm/types";

/** Flatten the layer tree into a list of LayerBounds for overlay rendering */
function flattenLayers(node: LayerTreeNode | null): LayerBounds[] {
  if (!node) return [];
  const result: LayerBounds[] = [];

  function walk(n: LayerTreeNode) {
    if (n.type === "layer") {
      const w = n.rect.right - n.rect.left;
      const h = n.rect.bottom - n.rect.top;
      if (w > 0 && h > 0) {
        result.push({
          layerIndex: n.layerIndex,
          name: n.name,
          left: n.rect.left,
          top: n.rect.top,
          right: n.rect.right,
          bottom: n.rect.bottom,
        });
      }
    } else if (n.type === "group") {
      for (const child of n.children) walk(child);
    } else if (n.type === "root") {
      for (const child of n.children) walk(child);
    }
  }

  walk(node);
  return result;
}

/** Extract a layer's pixel region from the pre-baked composite RGBA data */
function extractLayerFromComposite(
  compositeRgba: Uint8Array,
  docW: number,
  docH: number,
  bounds: LayerBounds,
): LayerPixelData | null {
  const left = Math.max(0, bounds.left);
  const top = Math.max(0, bounds.top);
  const right = Math.min(docW, bounds.right);
  const bottom = Math.min(docH, bounds.bottom);
  const w = right - left;
  const h = bottom - top;
  if (w <= 0 || h <= 0) return null;
  const rgba = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    const srcOff = ((top + y) * docW + left) * 4;
    rgba.set(compositeRgba.subarray(srcOff, srcOff + w * 4), y * w * 4);
  }
  return { rgba, width: w, height: h, offsetX: left, offsetY: top };
}

type DragMode = "none" | "pan" | "move-layer";

interface DragState {
  mode: DragMode;
  startScreenX: number;
  startScreenY: number;
  startDocX: number;
  startDocY: number;
  // For pan
  startPanX: number;
  startPanY: number;
  // For move-layer
  layerIndex: number;
  startOffsetDx: number;
  startOffsetDy: number;
}

export function PsdCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rendererRef = useRef<WebGLRenderer | null>(null);
  const dragRef = useRef<DragState>({
    mode: "none",
    startScreenX: 0,
    startScreenY: 0,
    startDocX: 0,
    startDocY: 0,
    startPanX: 0,
    startPanY: 0,
    layerIndex: -1,
    startOffsetDx: 0,
    startOffsetDy: 0,
  });
  const spaceHeldRef = useRef(false);

  const compositeRgba = usePsdStore((s) => s.compositeRgba);
  const ir = usePsdStore((s) => s.ir);
  const layerPixels = usePsdStore((s) => s.layerPixels);
  const layerInfos = usePsdStore((s) => s.layerInfos);
  const layersLoaded = usePsdStore((s) => s.layersLoaded);
  const zoom = useCanvasStore((s) => s.zoom);
  const panX = useCanvasStore((s) => s.panX);
  const panY = useCanvasStore((s) => s.panY);
  const selectedLayerIndex = useCanvasStore((s) => s.selectedLayerIndex);
  const hoveredLayerIndex = useCanvasStore((s) => s.hoveredLayerIndex);
  const layerOffsets = useCanvasStore((s) => s.layerOffsets);
  const fitToView = useCanvasStore((s) => s.fitToView);
  const zoomAtPoint = useCanvasStore((s) => s.zoomAtPoint);

  const layerBounds = useMemo(
    () => (ir?.layerTree ? flattenLayers(ir.layerTree) : []),
    [ir],
  );

  // Initialize renderer
  useEffect(() => {
    if (!canvasRef.current) return;
    try {
      const renderer = new WebGLRenderer(canvasRef.current);
      rendererRef.current = renderer;
      renderer.resize();
      return () => {
        renderer.destroy();
        rendererRef.current = null;
      };
    } catch (err) {
      console.error("WebGL init failed:", err);
    }
  }, []);

  // ResizeObserver
  useEffect(() => {
    const container = canvasRef.current?.parentElement;
    if (!container || !rendererRef.current) return;
    const observer = new ResizeObserver(() => {
      rendererRef.current?.resize();
      rendererRef.current?.render();
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  // Load composite image
  useEffect(() => {
    const renderer = rendererRef.current;
    if (!renderer || !compositeRgba || !ir) return;
    renderer.setCompositeImage(compositeRgba, ir.header.width, ir.header.height);
    if (canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      fitToView(ir.header.width, ir.header.height, rect.width, rect.height);
    }
  }, [compositeRgba, ir, fitToView]);

  // Set overlay layers when IR changes
  useEffect(() => {
    rendererRef.current?.setOverlayLayers(layerBounds);
    rendererRef.current?.render();
  }, [layerBounds]);

  // Load per-layer textures from WASM data (proper transparency)
  useEffect(() => {
    const renderer = rendererRef.current;
    if (!renderer || !layersLoaded) return;
    for (const [layerIndex, data] of layerPixels) {
      if (data.width > 0 && data.height > 0) {
        renderer.setLayerImage(layerIndex, data);
      }
    }
    // Set layer infos so recomposite() can be called during drag
    if (layerInfos.length > 0) {
      renderer.setLayerInfos(layerInfos);
    }
  }, [layerPixels, layerInfos, layersLoaded]);

  // Sync overlay state to renderer and re-render
  useEffect(() => {
    const renderer = rendererRef.current;
    if (!renderer) return;
    renderer.setSelectedLayer(selectedLayerIndex);
    renderer.setHoveredLayer(hoveredLayerIndex);
    // Sync layer offsets
    for (const [idx, offset] of layerOffsets) {
      renderer.setLayerOffset(idx, offset.dx, offset.dy);
    }
    renderer.setViewTransform(panX, panY, zoom);
    renderer.render();
  }, [zoom, panX, panY, selectedLayerIndex, hoveredLayerIndex, layerOffsets]);

  // Space key for pan mode
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.code === "Space" && !e.repeat) {
        spaceHeldRef.current = true;
        if (canvasRef.current) canvasRef.current.style.cursor = "grab";
      }
      // Escape deselects
      if (e.code === "Escape") {
        useCanvasStore.setState({ selectedLayerIndex: null });
        useUIStore.getState().select(null);
      }
    };
    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === "Space") {
        spaceHeldRef.current = false;
        if (canvasRef.current) canvasRef.current.style.cursor = "";
      }
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
    };
  }, []);

  // Mouse wheel zoom
  const handleWheel = useCallback(
    (e: React.WheelEvent) => {
      e.preventDefault();
      const factor = e.deltaY > 0 ? 0.9 : 1.1;
      const rect = (e.target as HTMLElement).getBoundingClientRect();
      zoomAtPoint(factor, e.clientX, e.clientY, rect);
    },
    [zoomAtPoint],
  );

  // Mouse down: determine drag mode
  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      const renderer = rendererRef.current;
      if (!renderer) return;

      const rect = canvasRef.current!.getBoundingClientRect();
      const localX = e.clientX - rect.left;
      const localY = e.clientY - rect.top;
      const { docX, docY } = renderer.screenToDocument(localX, localY);

      // Middle button or space held = pan
      if (e.button === 1 || spaceHeldRef.current) {
        e.preventDefault();
        dragRef.current = {
          mode: "pan",
          startScreenX: e.clientX,
          startScreenY: e.clientY,
          startDocX: docX,
          startDocY: docY,
          startPanX: panX,
          startPanY: panY,
          layerIndex: -1,
          startOffsetDx: 0,
          startOffsetDy: 0,
        };
        if (canvasRef.current) canvasRef.current.style.cursor = "grabbing";
        return;
      }

      if (e.button !== 0) return;

      // Left click: hit test
      const hitIndex = renderer.hitTestLayers(docX, docY);

      if (hitIndex !== null) {
        // Select the layer
        useCanvasStore.setState({ selectedLayerIndex: hitIndex });
        // Sync to tree view
        useUIStore.getState().select({ section: "layers", path: [hitIndex] });

        // Ensure layer texture is loaded (extract from composite if needed)
        if (!renderer.hasLayerTexture(hitIndex)) {
          const cRgba = usePsdStore.getState().compositeRgba;
          const cIr = usePsdStore.getState().ir;
          if (cRgba && cIr) {
            const bounds = layerBounds.find((l) => l.layerIndex === hitIndex);
            if (bounds) {
              const data = extractLayerFromComposite(
                cRgba, cIr.header.width, cIr.header.height, bounds,
              );
              if (data) renderer.setLayerImage(hitIndex, data);
            }
          }
        }

        // Start move-layer drag
        const currentOffset = renderer.getLayerOffset(hitIndex);
        dragRef.current = {
          mode: "move-layer",
          startScreenX: e.clientX,
          startScreenY: e.clientY,
          startDocX: docX,
          startDocY: docY,
          startPanX: panX,
          startPanY: panY,
          layerIndex: hitIndex,
          startOffsetDx: currentOffset.dx,
          startOffsetDy: currentOffset.dy,
        };
        if (canvasRef.current) canvasRef.current.style.cursor = "move";
      } else {
        // Click on empty = deselect and start pan
        useCanvasStore.setState({ selectedLayerIndex: null });
        useUIStore.getState().select(null);
        dragRef.current = {
          mode: "pan",
          startScreenX: e.clientX,
          startScreenY: e.clientY,
          startDocX: docX,
          startDocY: docY,
          startPanX: panX,
          startPanY: panY,
          layerIndex: -1,
          startOffsetDx: 0,
          startOffsetDy: 0,
        };
        if (canvasRef.current) canvasRef.current.style.cursor = "grabbing";
      }
    },
    [panX, panY, layerBounds],
  );

  // Mouse move for hover + drag
  const handleMouseMove = useCallback(
    (e: React.MouseEvent) => {
      const renderer = rendererRef.current;
      if (!renderer || !canvasRef.current) return;

      const rect = canvasRef.current.getBoundingClientRect();
      const localX = e.clientX - rect.left;
      const localY = e.clientY - rect.top;
      const { docX, docY } = renderer.screenToDocument(localX, localY);

      // Hover hit test (only when not dragging)
      if (dragRef.current.mode === "none") {
        const hitIndex = renderer.hitTestLayers(docX, docY);
        if (hitIndex !== hoveredLayerIndex) {
          useCanvasStore.setState({ hoveredLayerIndex: hitIndex });
        }
        // Update cursor
        if (spaceHeldRef.current) {
          canvasRef.current.style.cursor = "grab";
        } else if (hitIndex !== null) {
          canvasRef.current.style.cursor = "move";
        } else {
          canvasRef.current.style.cursor = "";
        }
      }
    },
    [hoveredLayerIndex],
  );

  // Global mouse move/up for drag
  useEffect(() => {
    const handleGlobalMouseMove = (e: MouseEvent) => {
      const drag = dragRef.current;
      if (drag.mode === "none") return;

      if (drag.mode === "pan") {
        const dx = e.clientX - drag.startScreenX;
        const dy = e.clientY - drag.startScreenY;
        useCanvasStore.setState({
          panX: drag.startPanX + dx,
          panY: drag.startPanY + dy,
        });
      } else if (drag.mode === "move-layer") {
        const renderer = rendererRef.current;
        if (!renderer || !canvasRef.current) return;

        const rect = canvasRef.current.getBoundingClientRect();
        const localX = e.clientX - rect.left;
        const localY = e.clientY - rect.top;
        const { docX, docY } = renderer.screenToDocument(localX, localY);

        const ddx = docX - drag.startDocX;
        const ddy = docY - drag.startDocY;

        const newDx = drag.startOffsetDx + ddx;
        const newDy = drag.startOffsetDy + ddy;

        renderer.setLayerOffset(drag.layerIndex, newDx, newDy);
        useCanvasStore.getState().setLayerOffset(drag.layerIndex, newDx, newDy);
        renderer.recomposite();
        renderer.render();
      }
    };

    const handleGlobalMouseUp = () => {
      if (dragRef.current.mode !== "none") {
        dragRef.current.mode = "none";
        if (canvasRef.current) {
          canvasRef.current.style.cursor = spaceHeldRef.current ? "grab" : "";
        }
      }
    };

    window.addEventListener("mousemove", handleGlobalMouseMove);
    window.addEventListener("mouseup", handleGlobalMouseUp);
    return () => {
      window.removeEventListener("mousemove", handleGlobalMouseMove);
      window.removeEventListener("mouseup", handleGlobalMouseUp);
    };
  }, []);

  return (
    <div className="canvas-container">
      <canvas
        ref={canvasRef}
        className="psd-canvas"
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onContextMenu={(e) => e.preventDefault()}
      />
      <CanvasControls />
    </div>
  );
}
