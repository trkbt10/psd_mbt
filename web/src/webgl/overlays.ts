import type { ViewTransform, LayerBounds } from "./types";

export function renderOverlays(
  gl: WebGL2RenderingContext,
  overlayProgram: WebGLProgram,
  lineVAO: WebGLVertexArrayObject,
  quadVAO: WebGLVertexArrayObject,
  viewMatrix: Float32Array,
  overlayLayers: LayerBounds[],
  layerOffsets: Map<number, { dx: number; dy: number }>,
  docWidth: number,
  docHeight: number,
  selectedLayerIndex: number | null,
  hoveredLayerIndex: number | null,
  view: ViewTransform,
  canvas: HTMLCanvasElement,
): void {
  if (overlayLayers.length === 0 || docWidth === 0) return;

  gl.useProgram(overlayProgram);
  gl.bindVertexArray(lineVAO);

  const uView = gl.getUniformLocation(overlayProgram, "u_viewMatrix");
  const uRect = gl.getUniformLocation(overlayProgram, "u_rect");
  const uDocSize = gl.getUniformLocation(overlayProgram, "u_docSize");
  const uColor = gl.getUniformLocation(overlayProgram, "u_color");

  gl.uniformMatrix3fv(uView, false, viewMatrix);
  gl.uniform2f(uDocSize, docWidth, docHeight);

  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  for (const layer of overlayLayers) {
    const offset = layerOffsets.get(layer.layerIndex) ?? { dx: 0, dy: 0 };
    const l = layer.left + offset.dx;
    const t = layer.top + offset.dy;
    const r = layer.right + offset.dx;
    const b = layer.bottom + offset.dy;

    if (r - l <= 0 || b - t <= 0) continue;

    const isSelected = layer.layerIndex === selectedLayerIndex;
    const isHovered = layer.layerIndex === hoveredLayerIndex;

    if (!isSelected && !isHovered) continue;

    gl.uniform4f(uRect, l, t, r, b);

    if (isSelected) {
      gl.uniform4f(uColor, 0.0, 0.47, 0.84, 1.0);
      gl.drawArrays(gl.LINE_LOOP, 0, 4);
      renderHandles(
        gl, overlayProgram, quadVAO, lineVAO, viewMatrix,
        l, t, r, b, docWidth, docHeight, view, canvas,
      );
    } else if (isHovered) {
      gl.useProgram(overlayProgram);
      gl.bindVertexArray(lineVAO);
      gl.uniformMatrix3fv(uView, false, viewMatrix);
      gl.uniform2f(uDocSize, docWidth, docHeight);
      gl.uniform4f(uRect, l, t, r, b);
      gl.uniform4f(uColor, 0.0, 0.47, 0.84, 0.5);
      gl.drawArrays(gl.LINE_LOOP, 0, 4);
    }
  }
}

function renderHandles(
  gl: WebGL2RenderingContext,
  overlayProgram: WebGLProgram,
  quadVAO: WebGLVertexArrayObject,
  lineVAO: WebGLVertexArrayObject,
  viewMatrix: Float32Array,
  l: number, t: number, r: number, b: number,
  docWidth: number, docHeight: number,
  view: ViewTransform,
  canvas: HTMLCanvasElement,
): void {
  const dpr = window.devicePixelRatio || 1;
  const cw = canvas.width;
  const ch = canvas.height;
  const aspect = cw / ch;
  const scaleX = view.zoom * (docWidth / Math.max(docWidth, docHeight * aspect));
  const handleDocSize = 4 * dpr / (scaleX * cw / (2 * docWidth));

  const corners = [
    [l, t], [r, t], [r, b], [l, b],
    [(l + r) / 2, t], [(l + r) / 2, b],
    [l, (t + b) / 2], [r, (t + b) / 2],
  ];

  gl.useProgram(overlayProgram);
  gl.bindVertexArray(quadVAO);

  const uView = gl.getUniformLocation(overlayProgram, "u_viewMatrix");
  const uRect = gl.getUniformLocation(overlayProgram, "u_rect");
  const uDocSize = gl.getUniformLocation(overlayProgram, "u_docSize");
  const uColor = gl.getUniformLocation(overlayProgram, "u_color");

  gl.uniformMatrix3fv(uView, false, viewMatrix);
  gl.uniform2f(uDocSize, docWidth, docHeight);

  // White fill
  gl.uniform4f(uColor, 1.0, 1.0, 1.0, 1.0);
  const hs = handleDocSize;
  for (const [cx, cy] of corners) {
    gl.uniform4f(uRect, cx - hs, cy - hs, cx + hs, cy + hs);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  // Blue outline
  gl.bindVertexArray(lineVAO);
  gl.uniform4f(uColor, 0.0, 0.47, 0.84, 1.0);
  for (const [cx, cy] of corners) {
    gl.uniform4f(uRect, cx - hs, cy - hs, cx + hs, cy + hs);
    gl.drawArrays(gl.LINE_LOOP, 0, 4);
  }
}
