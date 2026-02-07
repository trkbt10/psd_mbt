import type { ViewTransform, LayerBounds } from "./types";

export function computeViewMatrix(
  canvasWidth: number,
  canvasHeight: number,
  view: ViewTransform,
  docWidth: number,
  docHeight: number,
): Float32Array {
  const aspect = canvasWidth / canvasHeight;
  const scaleX = view.zoom * (docWidth / Math.max(docWidth, docHeight * aspect));
  const scaleY = view.zoom * (docHeight / Math.max(docHeight, docWidth / aspect));
  const tx = view.panX * 2 / canvasWidth;
  const ty = -view.panY * 2 / canvasHeight;

  return new Float32Array([
    scaleX, 0, 0,
    0, scaleY, 0,
    tx, ty, 1,
  ]);
}

export function screenToDocument(
  canvasWidth: number,
  canvasHeight: number,
  view: ViewTransform,
  docWidth: number,
  docHeight: number,
  screenX: number,
  screenY: number,
  dpr: number,
): { docX: number; docY: number } {
  const px = screenX * dpr;
  const py = screenY * dpr;

  const ndcX = (px / canvasWidth) * 2 - 1;
  const ndcY = 1 - (py / canvasHeight) * 2;

  const aspect = canvasWidth / canvasHeight;
  const scaleX = view.zoom * (docWidth / Math.max(docWidth, docHeight * aspect));
  const scaleY = view.zoom * (docHeight / Math.max(docHeight, docWidth / aspect));
  const tx = view.panX * 2 / canvasWidth;
  const ty = -view.panY * 2 / canvasHeight;

  const docNdcX = (ndcX - tx) / scaleX;
  const docNdcY = (ndcY - ty) / scaleY;

  const docX = (docNdcX + 1) / 2 * docWidth;
  const docY = (1 - docNdcY) / 2 * docHeight;

  return { docX, docY };
}

export function hitTestLayers(
  overlayLayers: LayerBounds[],
  layerOffsets: Map<number, { dx: number; dy: number }>,
  docX: number,
  docY: number,
): number | null {
  // overlayLayers is in tree order (top-to-bottom visual order).
  // Iterate forward so the topmost (first) layer wins.
  for (let i = 0; i < overlayLayers.length; i++) {
    const layer = overlayLayers[i];
    const offset = layerOffsets.get(layer.layerIndex) ?? { dx: 0, dy: 0 };
    const l = layer.left + offset.dx;
    const t = layer.top + offset.dy;
    const r = layer.right + offset.dx;
    const b = layer.bottom + offset.dy;
    if (docX >= l && docX <= r && docY >= t && docY <= b) {
      return layer.layerIndex;
    }
  }
  return null;
}
