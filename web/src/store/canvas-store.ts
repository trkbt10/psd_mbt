import { create } from "zustand";

interface CanvasState {
  zoom: number;
  panX: number;
  panY: number;
  renderMode: "composite" | "layers";
  selectedLayerIndex: number | null;
  hoveredLayerIndex: number | null;
  layerOffsets: Map<number, { dx: number; dy: number }>;
  setZoom: (zoom: number) => void;
  setPan: (x: number, y: number) => void;
  adjustPan: (dx: number, dy: number) => void;
  setRenderMode: (mode: "composite" | "layers") => void;
  setSelectedLayer: (index: number | null) => void;
  setHoveredLayer: (index: number | null) => void;
  setLayerOffset: (layerIndex: number, dx: number, dy: number) => void;
  fitToView: (
    docW: number,
    docH: number,
    canvasW: number,
    canvasH: number,
  ) => void;
  zoomAtPoint: (
    factor: number,
    clientX: number,
    clientY: number,
    canvasRect: DOMRect,
  ) => void;
  reset: () => void;
}

export const useCanvasStore = create<CanvasState>((set, get) => ({
  zoom: 1,
  panX: 0,
  panY: 0,
  renderMode: "composite",
  selectedLayerIndex: null,
  hoveredLayerIndex: null,
  layerOffsets: new Map(),

  setZoom: (zoom) => set({ zoom: Math.max(0.01, Math.min(100, zoom)) }),

  setPan: (panX, panY) => set({ panX, panY }),

  adjustPan: (dx, dy) => {
    const { panX, panY } = get();
    set({ panX: panX + dx, panY: panY + dy });
  },

  setRenderMode: (renderMode) => set({ renderMode }),

  setSelectedLayer: (selectedLayerIndex) => set({ selectedLayerIndex }),

  setHoveredLayer: (hoveredLayerIndex) => set({ hoveredLayerIndex }),

  setLayerOffset: (layerIndex, dx, dy) => {
    const offsets = new Map(get().layerOffsets);
    if (dx === 0 && dy === 0) {
      offsets.delete(layerIndex);
    } else {
      offsets.set(layerIndex, { dx, dy });
    }
    set({ layerOffsets: offsets });
  },

  fitToView: (docW, docH, canvasW, canvasH) => {
    if (docW === 0 || docH === 0 || canvasW === 0 || canvasH === 0) return;
    const scaleX = canvasW / docW;
    const scaleY = canvasH / docH;
    const zoom = Math.min(scaleX, scaleY) * 0.9;
    set({ zoom, panX: 0, panY: 0 });
  },

  zoomAtPoint: (factor, clientX, clientY, canvasRect) => {
    const { zoom, panX, panY } = get();
    const newZoom = Math.max(0.01, Math.min(100, zoom * factor));

    const cx = clientX - canvasRect.left - canvasRect.width / 2;
    const cy = clientY - canvasRect.top - canvasRect.height / 2;

    const scale = 1 - newZoom / zoom;
    const newPanX = panX + (cx - panX) * scale;
    const newPanY = panY + (cy - panY) * scale;

    set({ zoom: newZoom, panX: newPanX, panY: newPanY });
  },

  reset: () =>
    set({
      zoom: 1,
      panX: 0,
      panY: 0,
      renderMode: "composite",
      selectedLayerIndex: null,
      hoveredLayerIndex: null,
      layerOffsets: new Map(),
    }),
}));
