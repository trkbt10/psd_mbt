import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  page.on("console", (msg) => {
    if (msg.type() === "error" || msg.type() === "warn") {
      console.log(`[browser ${msg.type()}] ${msg.text()}`);
    }
  });
  await page.goto("/test-render-hidden-group.html");
  await page.waitForFunction(() => window.__testReady, null, { timeout: 15_000 });
  await page.waitForTimeout(100);
});

test("hidden-group: group is marked hidden in tree", async ({ page }) => {
  const ir = await page.evaluate(() => window.__ir as Record<string, unknown>);
  const tree = ir.layerTree as Record<string, unknown>;
  const children = tree.children as Record<string, unknown>[];

  // First child should be the hidden group
  const group = children[0];
  expect(group.type).toBe("group");
  expect(group.name).toBe("HiddenGroup");
  expect(group.visible).toBe(false);

  // Second child should be the Blue flat layer
  const blue = children[1];
  expect(blue.type).toBe("layer");
  expect(blue.name).toBe("Blue");
  expect(blue.visible).toBe(true);
});

test("hidden-group: children of hidden group are extracted as invisible", async ({ page }) => {
  const infos = await page.evaluate(() =>
    window.__infos.map((i) => ({
      layerIndex: i.layerIndex,
      visible: i.visible,
    }))
  );

  // Red (layerIndex=2) is inside the hidden group → should be invisible
  const red = infos.find((i) => i.layerIndex === 2);
  expect(red).toBeDefined();
  expect(red!.visible).toBe(false);

  // Blue (layerIndex=0) is flat → should be visible
  const blue = infos.find((i) => i.layerIndex === 0);
  expect(blue).toBeDefined();
  expect(blue!.visible).toBe(true);
});

test("hidden-group: FBO composite pixel-matches Section 5 composite (raw pixels)", async ({ page }) => {
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
    `hidden-group FBO vs composite: compared ${compared}/${pixelCount}, ` +
      `${diffCount} differ (${diffPct.toFixed(1)}%), max diff=${maxDiff}`,
  );

  expect(compared).toBeGreaterThan(pixelCount * 0.05);
  expect(diffPct).toBeLessThan(1);
  expect(maxDiff).toBeLessThanOrEqual(5);
});

test("hidden-group: recomposite excludes hidden group children", async ({ page }) => {
  const stats = await page.evaluate(() => {
    window.__recomposite();
    const pixels = window.__readPixels();
    let hasBlue = false;
    let hasRed = false;
    for (let i = 0; i < pixels.length; i += 4) {
      const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      // Blue layer: r=0, g=0, b=255
      if (b > 200 && r < 50 && g < 50) hasBlue = true;
      // Red layer: r=255, g=0, b=0
      if (r > 200 && g < 50 && b < 50) hasRed = true;
    }
    return { hasBlue, hasRed };
  });

  // Blue should be visible (flat layer)
  expect(stats.hasBlue).toBe(true);
  // Red should NOT be visible (inside hidden group)
  expect(stats.hasRed).toBe(false);
});

test("hidden-group: toggling hidden layer visible includes it in FBO", async ({ page }) => {
  // Initially Red (layerIndex=2) is invisible. Toggle it visible.
  await page.evaluate(() => window.__toggleLayerVisibility(2, true));
  await page.waitForTimeout(100);

  // Now both Red and Blue should appear in the FBO canvas pixels
  const stats = await page.evaluate(() => {
    const pixels = window.__readPixels();
    let hasBlue = false;
    let hasRed = false;
    for (let i = 0; i < pixels.length; i += 4) {
      const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      if (b > 200 && r < 50 && g < 50) hasBlue = true;
      if (r > 200 && g < 50 && b < 50) hasRed = true;
    }
    return { hasBlue, hasRed };
  });

  expect(stats.hasBlue).toBe(true);
  expect(stats.hasRed).toBe(true);

  // Toggle Red back to hidden
  await page.evaluate(() => window.__toggleLayerVisibility(2, false));
  await page.waitForTimeout(100);

  const afterHide = await page.evaluate(() => {
    const pixels = window.__readPixels();
    let hasRed = false;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i] > 200 && pixels[i + 1] < 50 && pixels[i + 2] < 50) hasRed = true;
    }
    return { hasRed };
  });

  // Red should be hidden again
  expect(afterHide.hasRed).toBe(false);
});
