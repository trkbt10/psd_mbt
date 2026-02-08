import { test, expect } from "@playwright/test";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Integration tests that exercise the REAL app flow:
 * DropZone file input → psd-store loadFile → PsdCanvas effects → WebGL renderer
 *
 * These tests simulate what the user does: drop/select a PSD file,
 * wait for it to load, and verify the canvas shows content.
 */

test.beforeEach(async ({ page }) => {
  page.on("console", (msg) => {
    console.log(`[browser ${msg.type()}] ${msg.text()}`);
  });
  await page.goto("/");
  await page.waitForSelector(".app");
});

/** Helper: load a PSD fixture through the DropZone file input */
async function loadFixture(page: import("@playwright/test").Page, fixtureName: string) {
  const fixturePath = path.resolve(__dirname, "fixtures", fixtureName);

  // The DropZone has a hidden <input type="file">
  const fileInput = page.locator('.dropzone input[type="file"]');
  await fileInput.setInputFiles(fixturePath);

  // Wait for the PsdCanvas to appear (React renders it when ir is set)
  await page.waitForSelector(".psd-canvas", { timeout: 15000 });

  // Wait for layers to finish loading (poll the store state)
  await page.waitForFunction(
    () => {
      // Access the store through React's module cache
      const storeEl = document.querySelector(".app");
      if (!storeEl) return false;
      // Check if canvas has been drawn by looking for non-trivial WebGL content
      const canvas = document.querySelector(".psd-canvas") as HTMLCanvasElement;
      if (!canvas) return false;
      return canvas.width > 0 && canvas.height > 0;
    },
    { timeout: 10000 },
  );

  // Give React effects time to process textures and recomposite
  await page.waitForTimeout(2000);
}

/** Helper: read pixel data from the real app canvas */
async function readCanvasPixels(page: import("@playwright/test").Page) {
  return page.evaluate(() => {
    const canvas = document.querySelector(".psd-canvas") as HTMLCanvasElement;
    if (!canvas) return { error: "no canvas" as const };
    const gl = canvas.getContext("webgl2");
    if (!gl) return { error: "no gl" as const };

    const w = canvas.width;
    const h = canvas.height;
    const buf = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, buf);

    let nonBlack = 0;
    let hasRed = false;
    let hasGreen = false;
    let hasBlue = false;
    for (let i = 0; i < buf.length; i += 4) {
      const r = buf[i], g = buf[i + 1], b = buf[i + 2];
      if (r > 10 || g > 10 || b > 10) nonBlack++;
      if (r > 200 && g < 50 && b < 50) hasRed = true;
      if (g > 200 && r < 50 && b < 50) hasGreen = true;
      if (b > 200 && r < 50 && g < 50) hasBlue = true;
    }
    return { nonBlack, total: w * h, canvasW: w, canvasH: h, hasRed, hasGreen, hasBlue };
  });
}

/** Helper: get store state diagnostics */
async function getStoreState(page: import("@playwright/test").Page) {
  return page.evaluate(() => {
    // Access Zustand store internals via the devtools API
    // Zustand stores expose getState() on the hook function
    const stores = (window as any).__ZUSTAND_STORES__;
    if (!stores?.psd) return { error: "no store access" };
    const state = stores.psd.getState();
    return {
      hasIr: state.ir !== null,
      layerInfoCount: state.layerInfos.length,
      pixelCount: state.layerPixels.size,
      layersLoaded: state.layersLoaded,
      failedCount: state.failedLayers.size,
      visibleLayers: state.layerInfos.filter((i: any) => i.visible).length,
    };
  });
}

test("integration: 8-bit grouped PSD renders through real app flow", async ({ page }) => {
  await loadFixture(page, "test-grouped-layers.psd");

  const pixels = await readCanvasPixels(page);
  console.log("Pixel result:", JSON.stringify(pixels));

  expect(pixels).not.toHaveProperty("error");
  const p = pixels as { nonBlack: number; hasRed: boolean; hasGreen: boolean; hasBlue: boolean };
  expect(p.nonBlack).toBeGreaterThan(0);
});

test("integration: 16-bit grouped PSD renders through real app flow", async ({ page }) => {
  await loadFixture(page, "test-16bit-grouped.psd");

  const pixels = await readCanvasPixels(page);
  console.log("16-bit pixel result:", JSON.stringify(pixels));

  expect(pixels).not.toHaveProperty("error");
  const p = pixels as { nonBlack: number };
  expect(p.nonBlack).toBeGreaterThan(0);
});

test("integration: hidden group PSD - children not rendered", async ({ page }) => {
  await loadFixture(page, "test-hidden-group.psd");

  const pixels = await readCanvasPixels(page);
  console.log("Hidden group pixel result:", JSON.stringify(pixels));

  expect(pixels).not.toHaveProperty("error");
  const p = pixels as { hasBlue: boolean; hasRed: boolean };
  // Blue (flat visible layer) should render
  expect(p.hasBlue).toBe(true);
  // Red (inside hidden group) should NOT render
  expect(p.hasRed).toBe(false);
});
