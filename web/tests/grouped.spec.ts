import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/test-render-grouped.html");
  await page.waitForFunction(() => window.__testReady, null, { timeout: 15_000 });
  // Wait an extra frame for GL to flush
  await page.waitForTimeout(100);
});

test("grouped: layer tree has correct structure", async ({ page }) => {
  const ir = await page.evaluate(() => window.__ir as Record<string, unknown>);
  const tree = ir.layerTree as Record<string, unknown>;
  expect(tree.type).toBe("root");

  const children = tree.children as Record<string, unknown>[];
  // Should have: Shapes group and Blue layer
  expect(children.length).toBe(2);

  // First child should be the group
  const group = children[0];
  expect(group.type).toBe("group");
  expect(group.name).toBe("Shapes");

  const groupChildren = group.children as Record<string, unknown>[];
  expect(groupChildren.length).toBe(2);
  expect(groupChildren[0].name).toBe("Green");
  expect(groupChildren[1].name).toBe("Red");

  // Second child should be Blue
  expect(children[1].type).toBe("layer");
  expect(children[1].name).toBe("Blue");
});

test("grouped: all leaf layers have pixel data", async ({ page }) => {
  const infos = await page.evaluate(() =>
    window.__infos.map((info) => ({
      layerIndex: info.layerIndex,
      width: info.rect.right - info.rect.left,
      height: info.rect.bottom - info.rect.top,
    }))
  );

  // Should have 3 leaf layers (Red, Green, Blue)
  expect(infos.length).toBe(3);

  // All should have non-zero dimensions
  for (const info of infos) {
    expect(info.width).toBeGreaterThan(0);
    expect(info.height).toBeGreaterThan(0);
  }
});

test("grouped: composite image renders correctly", async ({ page }) => {
  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("grouped-composite.png");
});

test("grouped: per-layer recomposite matches composite", async ({ page }) => {
  await page.evaluate(() => window.__recomposite());
  await page.waitForTimeout(100);

  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("grouped-recomposite.png");
});

test("grouped: FBO composite pixel-matches Section 5 composite (raw pixels)", async ({ page }) => {
  await page.evaluate(() => window.__recomposite());
  await page.waitForTimeout(100);

  const composite = await page.evaluate(() => window.__readRawCompositePixels());
  const fbo = await page.evaluate(() => window.__readRawFboPixels());

  expect(composite.width).toBe(fbo.width);
  expect(composite.height).toBe(fbo.height);
  expect(composite.pixels.length).toBeGreaterThan(0);

  let compared = 0;
  let diffCount = 0;
  let maxDiff = 0;
  const total = composite.pixels.length;
  for (let i = 0; i < total; i += 4) {
    if (fbo.pixels[i + 3] !== 255) continue;
    compared++;
    const d = Math.max(
      Math.abs(composite.pixels[i] - fbo.pixels[i]),
      Math.abs(composite.pixels[i + 1] - fbo.pixels[i + 1]),
      Math.abs(composite.pixels[i + 2] - fbo.pixels[i + 2]),
    );
    if (d > maxDiff) maxDiff = d;
    if (d > 2) diffCount++;
  }

  const pixelCount = total / 4;
  const diffPct = compared > 0 ? (diffCount / compared) * 100 : 0;
  console.log(
    `grouped FBO vs composite: compared ${compared}/${pixelCount}, ` +
      `${diffCount} differ (${diffPct.toFixed(1)}%), max diff=${maxDiff}`,
  );

  expect(compared).toBeGreaterThan(pixelCount * 0.1);
  expect(diffPct).toBeLessThan(1);
  expect(maxDiff).toBeLessThanOrEqual(5);
});

test("grouped: layer inside group can be moved", async ({ page }) => {
  // Move Red layer (index 2, inside Shapes group) by (10, 10)
  const infos = await page.evaluate(() => window.__infos);
  const redInfo = infos.find(
    (i: { layerIndex: number }) => i.layerIndex === 2,
  );
  expect(redInfo).toBeTruthy();

  await page.evaluate(() => window.__moveLayer(2, 10, 10));
  await page.waitForTimeout(100);

  const canvas = page.locator("#canvas");
  await expect(canvas).toHaveScreenshot("grouped-layer-moved.png");
});
