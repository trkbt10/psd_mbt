import type { ViewTransform, LayerBounds } from "./types";

/**
 * Compute the view matrix for rendering the document on screen.
 *
 * All parameters use CSS pixel coordinates (not device pixels).
 * zoom = CSS pixels per document pixel (from fitToView).
 * panX/panY = CSS pixel offsets.
 * canvasWidth/canvasHeight = CSS pixel canvas dimensions.
 */
export function computeViewMatrix(
  canvasWidth: number,
  canvasHeight: number,
  view: ViewTransform,
  docWidth: number,
  docHeight: number,
): Float32Array {
  // zoom is "CSS pixels per document pixel".
  // scaleX converts the [-1,1] document quad to the correct NDC size:
  //   document fills (zoom * docWidth) CSS pixels on screen,
  //   the canvas spans canvasWidth CSS pixels = NDC range [-1,1].
  const scaleX = view.zoom * docWidth / canvasWidth;
  const scaleY = view.zoom * docHeight / canvasHeight;
  // panX/panY are CSS pixel offsets. Convert to NDC:
  const tx = view.panX * 2 / canvasWidth;
  const ty = -view.panY * 2 / canvasHeight;

  return new Float32Array([
    scaleX, 0, 0,
    0, scaleY, 0,
    tx, ty, 1,
  ]);
}

/**
 * Convert screen (CSS pixel) coordinates to document coordinates.
 * canvasWidth/canvasHeight are CSS pixel dimensions (same space as zoom/pan).
 */
export function screenToDocument(
  canvasWidth: number,
  canvasHeight: number,
  view: ViewTransform,
  docWidth: number,
  docHeight: number,
  screenX: number,
  screenY: number,
): { docX: number; docY: number } {
  // screenX/screenY are already CSS pixels (relative to canvas element)
  const ndcX = (screenX / canvasWidth) * 2 - 1;
  const ndcY = 1 - (screenY / canvasHeight) * 2;

  const scaleX = view.zoom * docWidth / canvasWidth;
  const scaleY = view.zoom * docHeight / canvasHeight;
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
