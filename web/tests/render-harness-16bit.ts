import { WebGLRenderer } from "../src/webgl/renderer";
import { parsePsd, getCompositeRgba, getLayerRgba } from "../src/wasm/bridge";
import type { LayerTreeNode } from "../src/wasm/types";
import type { LayerRenderInfo } from "../src/webgl/types";

declare global {
  interface Window {
    __testReady: Promise<void>;
    __renderer: WebGLRenderer;
    __handle: number;
    __ir: unknown;
    __infos: LayerRenderInfo[];
    __layerErrors: string[];
    __compositeError: string | null;
    __recomposite: () => void;
    __moveLayer: (layerIndex: number, dx: number, dy: number) => void;
    __readPixels: () => Uint8Array;
    __readRawCompositePixels: () => { pixels: number[]; width: number; height: number };
    __readRawFboPixels: () => { pixels: number[]; width: number; height: number };
  }
}

function extractLayerInfos(node: LayerTreeNode | null): LayerRenderInfo[] {
  if (!node) return [];
  const result: LayerRenderInfo[] = [];
  function walk(n: LayerTreeNode, parentVisible: boolean) {
    if (n.type === "layer") {
      result.push({
        layerIndex: n.layerIndex,
        blendMode: n.blendMode,
        opacity: n.opacity,
        visible: parentVisible && n.visible,
        rect: { ...n.rect },
      });
    } else if (n.type === "group") {
      for (const child of n.children) walk(child, parentVisible && n.visible);
    } else if (n.type === "root") {
      for (const child of n.children) walk(child, parentVisible);
    }
  }
  walk(node, true);
  return result;
}

async function init() {
  const canvas = document.getElementById("canvas") as HTMLCanvasElement;
  const renderer = new WebGLRenderer(canvas);
  window.__renderer = renderer;
  window.__layerErrors = [];
  window.__compositeError = null;

  // Fetch and parse 16-bit grouped test PSD
  const resp = await fetch("/tests/fixtures/test-16bit-grouped.psd");
  const buf = await resp.arrayBuffer();
  const file = new File([buf], "test-16bit-grouped.psd");

  const { ir, handle } = await parsePsd(file);
  window.__handle = handle;
  window.__ir = ir;

  console.log("Header:", ir.header);
  console.log("Layer tree:", JSON.stringify(ir.layerTree, null, 2));

  // Set document size (may not have composite for 16-bit)
  renderer.setDocumentSize(ir.header.width, ir.header.height);

  // Try to get composite RGBA
  try {
    const compositeRgba = await getCompositeRgba(handle);
    renderer.setCompositeImage(compositeRgba, ir.header.width, ir.header.height);
    console.log("Composite loaded:", compositeRgba.byteLength, "bytes");
  } catch (err) {
    console.warn("Composite failed:", err);
    window.__compositeError = String(err);
  }

  // Load per-layer data
  const infos = extractLayerInfos(ir.layerTree);
  window.__infos = infos;
  renderer.setLayerInfos(infos);

  console.log("Extracted infos:", infos);

  for (const info of infos) {
    try {
      const data = await getLayerRgba(handle, info.layerIndex, info.rect);
      console.log(`Layer ${info.layerIndex}: ${data.width}x${data.height}, rgba ${data.rgba.byteLength} bytes`);
      if (data.width > 0 && data.height > 0) {
        renderer.setLayerImage(info.layerIndex, data);
      } else {
        window.__layerErrors.push(`Layer ${info.layerIndex}: empty data`);
      }
    } catch (err) {
      console.error(`Failed layer ${info.layerIndex}:`, err);
      window.__layerErrors.push(`Layer ${info.layerIndex}: ${err}`);
    }
  }

  // Set view to fill canvas with document
  renderer.setViewTransform(0, 0, 1);
  renderer.render();

  // Expose test helpers
  window.__recomposite = () => {
    renderer.recomposite();
    renderer.setRenderMode("layers");
    renderer.render();
  };

  window.__moveLayer = (layerIndex: number, dx: number, dy: number) => {
    renderer.setLayerOffset(layerIndex, dx, dy);
    renderer.recomposite();
    renderer.setRenderMode("layers");
    renderer.render();
  };

  window.__readPixels = () => {
    const gl = (canvas as any).getContext("webgl2") as WebGL2RenderingContext;
    const w = canvas.width;
    const h = canvas.height;
    const pixels = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    return pixels;
  };

  window.__readRawCompositePixels = () => {
    const r = renderer as any;
    const gl: WebGL2RenderingContext = r.gl;
    const tex = r.compositeTexture;
    const w: number = r.docWidth;
    const h: number = r.docHeight;
    if (!tex || w === 0 || h === 0) return { pixels: [], width: 0, height: 0 };
    const fb = gl.createFramebuffer()!;
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    const buf = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, buf);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.deleteFramebuffer(fb);
    return { pixels: Array.from(buf), width: w, height: h };
  };

  window.__readRawFboPixels = () => {
    const r = renderer as any;
    const gl: WebGL2RenderingContext = r.gl;
    const state = r.compositorState;
    const w: number = r.docWidth;
    const h: number = r.docHeight;
    if (!state?.fbo || w === 0 || h === 0) return { pixels: [], width: 0, height: 0 };
    gl.bindFramebuffer(gl.FRAMEBUFFER, state.fbo.fb);
    const buf = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, buf);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    const flipped = new Uint8Array(w * h * 4);
    const rowBytes = w * 4;
    for (let y = 0; y < h; y++) {
      flipped.set(buf.subarray((h - 1 - y) * rowBytes, (h - y) * rowBytes), y * rowBytes);
    }
    return { pixels: Array.from(flipped), width: w, height: h };
  };
}

// Signal readiness
window.__testReady = init();
