export interface ViewTransform {
  panX: number;
  panY: number;
  zoom: number;
}

export interface LayerPixelData {
  rgba: Uint8Array;
  width: number;
  height: number;
  offsetX: number;
  offsetY: number;
}

export interface LayerRenderInfo {
  layerIndex: number;
  blendMode: string;
  opacity: number;
  visible: boolean;
  rect: { top: number; left: number; bottom: number; right: number };
}

export interface LayerBounds {
  layerIndex: number;
  name: string;
  left: number;
  top: number;
  right: number;
  bottom: number;
}
