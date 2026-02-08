import { test, expect } from "@playwright/test";

/**
 * This test simulates the real-world scenario for large 16-bit PSD files:
 * - Composite RGBA fails (OOM for large files)
 * - Only per-layer data is available
 * - Rendering must work from per-layer compositing only
 */

test.beforeEach(async ({ page }) => {
  page.on("console", (msg) => {
    console.log(`[browser ${msg.type()}] ${msg.text()}`);
  });
  await page.goto("/test-render-16bit.html");
  await page.waitForFunction(() => window.__testReady, null, { timeout: 15_000 });
  await page.waitForTimeout(100);
});

test("no-composite: renders correctly without composite texture", async ({ page }) => {
  // Simulate what happens when getCompositeRgba fails:
  // - Delete the composite texture
  // - Set document size manually (like PsdCanvas does)
  // - Recomposite from per-layer data
  const result = await page.evaluate(() => {
    const renderer = window.__renderer as any;
    const gl = renderer.gl as WebGL2RenderingContext;

    // Delete composite texture (simulate composite load failure)
    if (renderer.compositeTexture) {
      gl.deleteTexture(renderer.compositeTexture);
      renderer.compositeTexture = null;
    }

    // Reset render mode to composite (initial state)
    renderer.renderMode = "composite";

    // Now try to render - this should show nothing (no composite, no FBO)
    renderer.render();
    const pixelsBefore = window.__readPixels();
    let nonBlackBefore = 0;
    for (let i = 0; i < pixelsBefore.length; i += 4) {
      if (pixelsBefore[i] > 10 || pixelsBefore[i + 1] > 10 || pixelsBefore[i + 2] > 10) {
        nonBlackBefore++;
      }
    }

    // Now recomposite from per-layer data and switch to layers mode
    renderer.recomposite();
    renderer.setRenderMode("layers");
    renderer.render();

    const pixelsAfter = window.__readPixels();
    let nonBlackAfter = 0;
    for (let i = 0; i < pixelsAfter.length; i += 4) {
      if (pixelsAfter[i] > 10 || pixelsAfter[i + 1] > 10 || pixelsAfter[i + 2] > 10) {
        nonBlackAfter++;
      }
    }

    return {
      renderMode: renderer.renderMode,
      hasComposite: renderer.compositeTexture != null,
      hasFBO: renderer.compositorState?.compositedTexture != null,
      docW: renderer.docWidth,
      docH: renderer.docHeight,
      texCount: renderer.layerTextures?.size ?? 0,
      infosCount: renderer.layerInfos?.length ?? 0,
      nonBlackBefore,
      nonBlackAfter,
    };
  });

  console.log("No-composite test result:", JSON.stringify(result, null, 2));

  expect(result.hasComposite).toBe(false);
  expect(result.hasFBO).toBe(true);
  expect(result.renderMode).toBe("layers");
  expect(result.nonBlackAfter).toBeGreaterThan(100);
});

test("no-composite: fitToView works without composite", async ({ page }) => {
  // Test that the view transform is correct when composite is missing
  const result = await page.evaluate(() => {
    const renderer = window.__renderer as any;
    const gl = renderer.gl as WebGL2RenderingContext;

    // Delete composite texture
    if (renderer.compositeTexture) {
      gl.deleteTexture(renderer.compositeTexture);
      renderer.compositeTexture = null;
    }
    renderer.renderMode = "composite";

    // Set a view transform (like fitToView would)
    const canvasW = renderer.canvas.width;
    const canvasH = renderer.canvas.height;
    const docW = renderer.docWidth;
    const docH = renderer.docHeight;
    const scale = Math.min(canvasW / docW, canvasH / docH) * 0.9;

    renderer.setViewTransform(0, 0, scale);
    renderer.recomposite();
    renderer.setRenderMode("layers");
    renderer.render();

    const pixels = window.__readPixels();
    let nonBlack = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i] > 10 || pixels[i + 1] > 10 || pixels[i + 2] > 10) {
        nonBlack++;
      }
    }

    return { nonBlack, scale, canvasW, canvasH, docW, docH };
  });

  console.log("fitToView test result:", JSON.stringify(result, null, 2));
  expect(result.nonBlack).toBeGreaterThan(100);
});
