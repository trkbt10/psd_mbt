import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/test-render.html");
  await page.waitForFunction(() => window.__testReady, null, { timeout: 15_000 });
  // Wait an extra frame for GL to flush
  await page.waitForTimeout(100);
});

test("composite image renders correctly", async ({ page }) => {
  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("composite.png");
});

test("per-layer recomposite matches composite", async ({ page }) => {
  // Trigger FBO recomposite from per-layer data
  await page.evaluate(() => window.__recomposite());
  await page.waitForTimeout(100);

  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("recomposite.png");
});

test("layer movement updates composited output", async ({ page }) => {
  // Move the first layer (Red, index 0) by (10, 10)
  await page.evaluate(() => window.__moveLayer(0, 10, 10));
  await page.waitForTimeout(100);

  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("layer-moved.png");
});

test("FBO composite pixel-matches Section 5 composite (raw pixels)", async ({ page }) => {
  // Trigger FBO recomposite so both textures are available
  await page.evaluate(() => window.__recomposite());
  await page.waitForTimeout(100);

  // Read raw pixels directly from textures (bypasses checker shader)
  const composite = await page.evaluate(() => window.__readRawCompositePixels());
  const fbo = await page.evaluate(() => window.__readRawFboPixels());

  expect(composite.width).toBe(fbo.width);
  expect(composite.height).toBe(fbo.height);
  expect(composite.pixels.length).toBeGreaterThan(0);

  // Compare only pixels where FBO has full coverage (alpha=255).
  // Section 5 composite has a white background baked in, so uncovered
  // areas will always differ (white vs transparent). By comparing only
  // fully-covered pixels, we test actual compositing correctness.
  let compared = 0;
  let diffCount = 0;
  let maxDiff = 0;
  const total = composite.pixels.length;
  for (let i = 0; i < total; i += 4) {
    const fboAlpha = fbo.pixels[i + 3];
    if (fboAlpha !== 255) continue; // skip non-fully-covered pixels

    compared++;
    const dr = Math.abs(composite.pixels[i] - fbo.pixels[i]);
    const dg = Math.abs(composite.pixels[i + 1] - fbo.pixels[i + 1]);
    const db = Math.abs(composite.pixels[i + 2] - fbo.pixels[i + 2]);
    const d = Math.max(dr, dg, db);
    if (d > maxDiff) maxDiff = d;
    if (d > 2) diffCount++; // allow ±2 for rounding
  }

  const pixelCount = total / 4;
  const diffPct = compared > 0 ? (diffCount / compared) * 100 : 0;
  console.log(
    `FBO vs composite (raw): compared ${compared}/${pixelCount} fully-covered pixels, ` +
      `${diffCount} differ (${diffPct.toFixed(1)}%), max diff=${maxDiff}`,
  );

  // Must have compared a meaningful number of pixels
  expect(compared).toBeGreaterThan(pixelCount * 0.1);
  // Less than 1% of compared pixels should differ
  expect(diffPct).toBeLessThan(1);
  // No single channel should differ by more than 5
  expect(maxDiff).toBeLessThanOrEqual(5);
});
