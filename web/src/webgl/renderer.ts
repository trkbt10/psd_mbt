import {
  BLIT_VERTEX,
  BLIT_FRAGMENT,
  COMPOSITE_VERTEX,
  COMPOSITE_FRAGMENT,
  OVERLAY_VERTEX,
  OVERLAY_FRAGMENT,
} from "./shaders";
import { createProgram } from "./gl-utils";
import {
  compositeAllLayers,
  createCompositorState,
  destroyCompositorState,
} from "./compositor";
import type { CompositorState } from "./compositor";
import { renderOverlays } from "./overlays";
import { computeViewMatrix, screenToDocument, hitTestLayers } from "./spatial";
import type { ViewTransform, LayerPixelData, LayerRenderInfo, LayerBounds } from "./types";

export class WebGLRenderer {
  private gl: WebGL2RenderingContext;
  private canvas: HTMLCanvasElement;

  private blitProgram: WebGLProgram;
  private compositeProgram: WebGLProgram;
  private overlayProgram: WebGLProgram;

  private quadVAO: WebGLVertexArrayObject;
  private lineVAO: WebGLVertexArrayObject;

  private view: ViewTransform = { panX: 0, panY: 0, zoom: 1 };
  private docWidth = 0;
  private docHeight = 0;

  private compositeTexture: WebGLTexture | null = null;
  private layerTextures: Map<number, { tex: WebGLTexture; data: LayerPixelData }> =
    new Map();

  private compositorState: CompositorState = createCompositorState();
  private renderMode: "composite" | "layers" = "composite";

  // Overlay state
  private overlayLayers: LayerBounds[] = [];
  private selectedLayerIndex: number | null = null;
  private hoveredLayerIndex: number | null = null;
  private layerOffsets: Map<number, { dx: number; dy: number }> = new Map();

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const gl = canvas.getContext("webgl2", {
      alpha: false,
      premultipliedAlpha: false,
      antialias: false,
      preserveDrawingBuffer: true,
    });
    if (!gl) throw new Error("WebGL2 not supported");
    this.gl = gl;

    this.blitProgram = createProgram(gl, BLIT_VERTEX, BLIT_FRAGMENT);
    this.compositeProgram = createProgram(gl, COMPOSITE_VERTEX, COMPOSITE_FRAGMENT);
    this.overlayProgram = createProgram(gl, OVERLAY_VERTEX, OVERLAY_FRAGMENT);
    this.quadVAO = this.createQuad();
    this.lineVAO = this.createLineQuad();

    gl.disable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  }

  private createQuad(): WebGLVertexArrayObject {
    const gl = this.gl;
    // prettier-ignore
    const verts = new Float32Array([
      // position    texcoord
      -1, -1,        0, 1,
       1, -1,        1, 1,
      -1,  1,        0, 0,
       1,  1,        1, 0,
    ]);

    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    const vbo = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 16, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 16, 8);

    gl.bindVertexArray(null);
    return vao;
  }

  private createLineQuad(): WebGLVertexArrayObject {
    const gl = this.gl;
    // prettier-ignore
    const verts = new Float32Array([
      -1, -1,
       1, -1,
       1,  1,
      -1,  1,
    ]);

    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);

    const vbo = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0);

    gl.bindVertexArray(null);
    return vao;
  }

  // --- Document size ---

  setDocumentSize(width: number, height: number): void {
    this.docWidth = width;
    this.docHeight = height;
  }

  // --- Texture management ---

  setCompositeImage(rgba: Uint8Array, width: number, height: number): void {
    const gl = this.gl;
    this.docWidth = width;
    this.docHeight = height;

    if (this.compositeTexture) gl.deleteTexture(this.compositeTexture);
    this.compositeTexture = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, this.compositeTexture);
    gl.texImage2D(
      gl.TEXTURE_2D, 0, gl.RGBA8,
      width, height, 0,
      gl.RGBA, gl.UNSIGNED_BYTE, rgba
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    this.render();
  }

  setLayerImage(layerIndex: number, pixelData: LayerPixelData): void {
    const gl = this.gl;

    const existing = this.layerTextures.get(layerIndex);
    if (existing) gl.deleteTexture(existing.tex);

    if (pixelData.width === 0 || pixelData.height === 0) {
      this.layerTextures.delete(layerIndex);
      return;
    }

    const tex = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(
      gl.TEXTURE_2D, 0, gl.RGBA8,
      pixelData.width, pixelData.height, 0,
      gl.RGBA, gl.UNSIGNED_BYTE, pixelData.rgba
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    this.layerTextures.set(layerIndex, { tex, data: pixelData });
  }

  // --- Layer info & compositing ---

  private layerInfos: LayerRenderInfo[] = [];

  setRenderMode(mode: "composite" | "layers"): void {
    this.renderMode = mode;
  }

  setLayerInfos(infos: LayerRenderInfo[]): void {
    this.layerInfos = infos;
  }

  recomposite(): void {
    if (this.layerInfos.length === 0 || this.layerTextures.size === 0) {
      console.warn(`[renderer] recomposite skipped: infos=${this.layerInfos.length}, textures=${this.layerTextures.size}`);
      return;
    }
    // layerInfos is in tree order (top-to-bottom visual).
    // Compositing needs bottom-to-top, so reverse.
    const bottomToTop = [...this.layerInfos].reverse();
    const visibleWithTex = bottomToTop.filter(l => l.visible && this.layerTextures.has(l.layerIndex));
    console.log(`[renderer] recomposite: ${bottomToTop.length} layers, ${visibleWithTex.length} visible+textured, doc=${this.docWidth}x${this.docHeight}`);
    compositeAllLayers(
      this.gl, this.compositorState, bottomToTop,
      this.layerTextures, this.layerOffsets,
      this.docWidth, this.docHeight,
      this.blitProgram, this.quadVAO,
    );
    // Don't auto-switch renderMode here; let caller decide.
  }

  // --- Overlay state ---

  setOverlayLayers(layers: LayerBounds[]): void {
    this.overlayLayers = layers;
  }

  setSelectedLayer(index: number | null): void {
    this.selectedLayerIndex = index;
  }

  setHoveredLayer(index: number | null): void {
    this.hoveredLayerIndex = index;
  }

  setLayerOffset(layerIndex: number, dx: number, dy: number): void {
    if (dx === 0 && dy === 0) {
      this.layerOffsets.delete(layerIndex);
    } else {
      this.layerOffsets.set(layerIndex, { dx, dy });
    }
  }

  getLayerOffset(layerIndex: number): { dx: number; dy: number } {
    return this.layerOffsets.get(layerIndex) ?? { dx: 0, dy: 0 };
  }

  hasLayerTexture(layerIndex: number): boolean {
    return this.layerTextures.has(layerIndex);
  }

  // --- Coordinate conversion ---

  screenToDocument(screenX: number, screenY: number): { docX: number; docY: number } {
    const rect = this.canvas.getBoundingClientRect();
    return screenToDocument(
      rect.width, rect.height,
      this.view, this.docWidth, this.docHeight,
      screenX, screenY,
    );
  }

  hitTestLayers(docX: number, docY: number): number | null {
    return hitTestLayers(this.overlayLayers, this.layerOffsets, docX, docY);
  }

  // --- View ---

  setViewTransform(panX: number, panY: number, zoom: number): void {
    this.view = { panX, panY, zoom };
  }

  // --- Main render ---

  render(): void {
    const gl = this.gl;
    const cw = this.canvas.width;
    const ch = this.canvas.height;

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, cw, ch);
    gl.clearColor(0.12, 0.12, 0.12, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    const useFBO = this.renderMode === "layers" && this.compositorState.compositedTexture != null;
    const tex = useFBO ? this.compositorState.compositedTexture : this.compositeTexture;

    if (!tex || this.docWidth === 0 || this.docHeight === 0) return;

    gl.useProgram(this.blitProgram);
    gl.bindVertexArray(this.quadVAO);

    // Use CSS pixel dimensions for view matrix (zoom/pan are in CSS pixel space)
    const rect = this.canvas.getBoundingClientRect();
    const viewMatrix = computeViewMatrix(rect.width, rect.height, this.view, this.docWidth, this.docHeight);

    // FBO composites are Y-flipped relative to uploaded textures
    const modelMatrix = new Float32Array([
      1, 0, 0,
      0, useFBO ? -1 : 1, 0,
      0, 0, 1,
    ]);

    const uView = gl.getUniformLocation(this.blitProgram, "u_viewMatrix");
    const uModel = gl.getUniformLocation(this.blitProgram, "u_modelMatrix");
    const uTex = gl.getUniformLocation(this.blitProgram, "u_texture");
    const uChecker = gl.getUniformLocation(this.blitProgram, "u_useChecker");
    const uOpacity = gl.getUniformLocation(this.blitProgram, "u_opacity");

    gl.uniformMatrix3fv(uView, false, viewMatrix);
    gl.uniformMatrix3fv(uModel, false, modelMatrix);
    gl.uniform1i(uChecker, 1);
    gl.uniform1f(uOpacity, 1.0);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.uniform1i(uTex, 0);

    gl.disable(gl.BLEND);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.enable(gl.BLEND);

    // In composite mode (no FBO), render moved layers as overlays.
    if (!useFBO) {
      this.renderMovedLayers(viewMatrix, uView, uModel, uTex, uChecker);
    }

    // Render bounding box overlays
    renderOverlays(
      gl, this.overlayProgram, this.lineVAO, this.quadVAO,
      viewMatrix, this.overlayLayers, this.layerOffsets,
      this.docWidth, this.docHeight,
      this.selectedLayerIndex, this.hoveredLayerIndex,
      this.view, this.canvas,
    );
  }

  private renderMovedLayers(
    viewMatrix: Float32Array,
    uView: WebGLUniformLocation | null,
    uModel: WebGLUniformLocation | null,
    uTex: WebGLUniformLocation | null,
    uChecker: WebGLUniformLocation | null,
  ): void {
    const gl = this.gl;
    if (this.layerOffsets.size === 0 || this.layerTextures.size === 0) return;
    if (this.docWidth === 0 || this.docHeight === 0) return;

    gl.useProgram(this.blitProgram);
    gl.bindVertexArray(this.quadVAO);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.uniformMatrix3fv(uView, false, viewMatrix);
    gl.uniform1i(uChecker, 0);
    const uOp = gl.getUniformLocation(this.blitProgram, "u_opacity");
    gl.uniform1f(uOp, 1.0);

    for (const [layerIndex, offset] of this.layerOffsets) {
      const entry = this.layerTextures.get(layerIndex);
      if (!entry) continue;

      const { data } = entry;
      if (data.width === 0 || data.height === 0) continue;

      const sx = data.width / this.docWidth;
      const sy = data.height / this.docHeight;
      const cx = (data.offsetX + offset.dx + data.width / 2) / this.docWidth * 2 - 1;
      const cy = 1 - (data.offsetY + offset.dy + data.height / 2) / this.docHeight * 2;

      // prettier-ignore
      gl.uniformMatrix3fv(uModel, false, new Float32Array([
        sx, 0,  0,
        0,  sy, 0,
        cx, cy, 1,
      ]));

      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, entry.tex);
      gl.uniform1i(uTex, 0);

      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
  }

  // --- Lifecycle ---

  resize(): void {
    const dpr = window.devicePixelRatio || 1;
    const rect = this.canvas.getBoundingClientRect();
    const w = Math.round(rect.width * dpr);
    const h = Math.round(rect.height * dpr);
    if (this.canvas.width !== w || this.canvas.height !== h) {
      this.canvas.width = w;
      this.canvas.height = h;
      this.render();
    }
  }

  getDocumentSize(): { width: number; height: number } {
    return { width: this.docWidth, height: this.docHeight };
  }

  destroy(): void {
    const gl = this.gl;
    gl.deleteProgram(this.blitProgram);
    gl.deleteProgram(this.compositeProgram);
    gl.deleteProgram(this.overlayProgram);
    if (this.compositeTexture) gl.deleteTexture(this.compositeTexture);
    for (const [, entry] of this.layerTextures) {
      gl.deleteTexture(entry.tex);
    }
    destroyCompositorState(gl, this.compositorState);
  }
}
