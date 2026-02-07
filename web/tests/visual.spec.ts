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
