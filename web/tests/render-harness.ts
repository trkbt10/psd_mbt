import { WebGLRenderer } from "../src/webgl/renderer";
import { parsePsd, getCompositeRgba, getLayerRgba } from "../src/wasm/bridge";
import type { LayerTreeNode } from "../src/wasm/types";
import type { LayerRenderInfo } from "../src/webgl/types";

declare global {
  interface Window {
    __testReady: Promise<void>;
    __renderer: WebGLRenderer;
    __handle: number;
    __recomposite: () => void;
    __moveLayer: (layerIndex: number, dx: number, dy: number) => void;
    __readPixels: () => Uint8Array;
  }
}

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

async function init() {
  const canvas = document.getElementById("canvas") as HTMLCanvasElement;
  const renderer = new WebGLRenderer(canvas);
  window.__renderer = renderer;

  // Fetch and parse test PSD
  const resp = await fetch("/tests/fixtures/test-layers.psd");
  const buf = await resp.arrayBuffer();
  const file = new File([buf], "test-layers.psd");

  const { ir, handle } = await parsePsd(file);
  window.__handle = handle;

  // Get composite RGBA
  const compositeRgba = await getCompositeRgba(handle);
  renderer.setCompositeImage(compositeRgba, ir.header.width, ir.header.height);

  // Load per-layer data
  const infos = extractLayerInfos(ir.layerTree);
  renderer.setLayerInfos(infos);

  for (const info of infos) {
    const data = await getLayerRgba(handle, info.layerIndex, info.rect);
    if (data.width > 0 && data.height > 0) {
      renderer.setLayerImage(info.layerIndex, data);
    }
  }

  // Set view to fill canvas with document
  renderer.setViewTransform(0, 0, 1);
  renderer.render();

  // Expose test helpers
  window.__recomposite = () => {
    renderer.recomposite();
    renderer.render();
  };

  window.__moveLayer = (layerIndex: number, dx: number, dy: number) => {
    renderer.setLayerOffset(layerIndex, dx, dy);
    renderer.recomposite();
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
}

// Signal readiness
window.__testReady = init();
