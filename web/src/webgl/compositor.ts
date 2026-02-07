import type { FramebufferPair } from "./gl-utils";
import { createFBO } from "./gl-utils";
import type { LayerPixelData, LayerRenderInfo } from "./types";

export interface CompositorState {
  fbo: FramebufferPair | null;
  compositedTexture: WebGLTexture | null;
}

export function createCompositorState(): CompositorState {
  return { fbo: null, compositedTexture: null };
}

export function destroyCompositorState(
  gl: WebGL2RenderingContext,
  state: CompositorState
): void {
  if (state.fbo) {
    gl.deleteFramebuffer(state.fbo.fb);
    gl.deleteTexture(state.fbo.tex);
  }
}

export function compositeAllLayers(
  gl: WebGL2RenderingContext,
  state: CompositorState,
  layers: LayerRenderInfo[],
  layerTextures: Map<number, { tex: WebGLTexture; data: LayerPixelData }>,
  layerOffsets: Map<number, { dx: number; dy: number }>,
  docWidth: number,
  docHeight: number,
  blitProgram: WebGLProgram,
  quadVAO: WebGLVertexArrayObject,
): WebGLTexture | null {
  if (docWidth === 0 || docHeight === 0) return null;

  // Ensure FBO exists at document size
  if (!state.fbo || state.fbo.width !== docWidth || state.fbo.height !== docHeight) {
    if (state.fbo) {
      gl.deleteFramebuffer(state.fbo.fb);
      gl.deleteTexture(state.fbo.tex);
    }
    state.fbo = createFBO(gl, docWidth, docHeight);
  }

  gl.bindFramebuffer(gl.FRAMEBUFFER, state.fbo.fb);
  gl.viewport(0, 0, docWidth, docHeight);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT);

  gl.useProgram(blitProgram);
  gl.bindVertexArray(quadVAO);

  const uView = gl.getUniformLocation(blitProgram, "u_viewMatrix");
  const uModel = gl.getUniformLocation(blitProgram, "u_modelMatrix");
  const uTex = gl.getUniformLocation(blitProgram, "u_texture");
  const uChecker = gl.getUniformLocation(blitProgram, "u_useChecker");
  const uOpacity = gl.getUniformLocation(blitProgram, "u_opacity");

  // Identity view matrix (FBO is in document NDC space)
  // prettier-ignore
  gl.uniformMatrix3fv(uView, false, new Float32Array([
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
  ]));
  gl.uniform1i(uChecker, 0);
  gl.uniform1i(uTex, 0);

  gl.enable(gl.BLEND);
  // Use separate blend for correct alpha accumulation:
  // Color: src.rgb * src.a + dst.rgb * (1 - src.a)
  // Alpha: src.a * 1 + dst.a * (1 - src.a)  [source-over]
  gl.blendFuncSeparate(
    gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA,
    gl.ONE, gl.ONE_MINUS_SRC_ALPHA,
  );

  for (const layer of layers) {
    if (!layer.visible) continue;

    const entry = layerTextures.get(layer.layerIndex);
    if (!entry) continue;

    const { data } = entry;
    if (data.width === 0 || data.height === 0) continue;

    const offset = layerOffsets.get(layer.layerIndex) ?? { dx: 0, dy: 0 };
    const sx = data.width / docWidth;
    const sy = data.height / docHeight;
    const cx = (data.offsetX + offset.dx + data.width / 2) / docWidth * 2 - 1;
    const cy = 1 - (data.offsetY + offset.dy + data.height / 2) / docHeight * 2;

    // prettier-ignore
    gl.uniformMatrix3fv(uModel, false, new Float32Array([
      sx, 0,  0,
      0,  sy, 0,
      cx, cy, 1,
    ]));

    gl.uniform1f(uOpacity, layer.opacity / 255);

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, entry.tex);

    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  state.compositedTexture = state.fbo.tex;
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  // Restore default blend state
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  return state.compositedTexture;
}
