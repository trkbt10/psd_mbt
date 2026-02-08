import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  page.on("console", (msg) => {
    if (msg.type() === "error" || msg.type() === "warn") {
      console.log(`[browser ${msg.type()}] ${msg.text()}`);
    }
  });
  await page.goto("/test-render-16bit.html");
  await page.waitForFunction(() => window.__testReady, null, { timeout: 15_000 });
  await page.waitForTimeout(100);
});

test("16bit: header reports depth 16", async ({ page }) => {
  const ir = await page.evaluate(() => window.__ir as Record<string, unknown>);
  const header = ir.header as Record<string, unknown>;
  expect(header.depth).toBe(16);
});

test("16bit: layer tree has groups and layers", async ({ page }) => {
  const ir = await page.evaluate(() => window.__ir as Record<string, unknown>);
  const tree = ir.layerTree as Record<string, unknown>;
  expect(tree).not.toBeNull();
  expect(tree.type).toBe("root");

  const children = tree.children as Record<string, unknown>[];
  expect(children.length).toBe(2);

  const group = children[0];
  expect(group.type).toBe("group");

  const groupChildren = group.children as Record<string, unknown>[];
  expect(groupChildren.length).toBe(2);
});

test("16bit: all leaf layers loaded without errors", async ({ page }) => {
  const errors = await page.evaluate(() => window.__layerErrors);
  expect(errors).toEqual([]);

  const infos = await page.evaluate(() =>
    window.__infos.map((i) => ({
      layerIndex: i.layerIndex,
      w: i.rect.right - i.rect.left,
      h: i.rect.bottom - i.rect.top,
    }))
  );

  expect(infos.length).toBe(3);
  for (const info of infos) {
    expect(info.w).toBeGreaterThan(0);
    expect(info.h).toBeGreaterThan(0);
  }
});

test("16bit: canvas has non-black pixels after render", async ({ page }) => {
  // Re-render and read pixels in the same evaluate to avoid buffer clearing
  const stats = await page.evaluate(() => {
    window.__renderer.render();
    const pixels = window.__readPixels();
    let nonBlack = 0;
    let total = pixels.length / 4;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i] > 0 || pixels[i + 1] > 0 || pixels[i + 2] > 0) {
        nonBlack++;
      }
    }
    return { nonBlack, total };
  });

  console.log("Pixel stats:", stats);
  // Should have many non-black pixels (background is grey + layers)
  expect(stats.nonBlack).toBeGreaterThan(100);
});

test("16bit: FBO composite pixel-matches Section 5 composite (raw pixels)", async ({ page }) => {
  // Skip if composite didn't load
  const compositeError = await page.evaluate(() => window.__compositeError);
  test.skip(compositeError !== null, `composite unavailable: ${compositeError}`);

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
    `16bit FBO vs composite: compared ${compared}/${pixelCount}, ` +
      `${diffCount} differ (${diffPct.toFixed(1)}%), max diff=${maxDiff}`,
  );

  expect(compared).toBeGreaterThan(pixelCount * 0.1);
  expect(diffPct).toBeLessThan(1);
  expect(maxDiff).toBeLessThanOrEqual(5);
});

test("16bit: per-layer recomposite produces non-black output", async ({ page }) => {
  // Read pixels in the same evaluate to avoid preserveDrawingBuffer clearing
  const stats = await page.evaluate(() => {
    window.__recomposite();
    const pixels = window.__readPixels();
    let nonBlack = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      if (pixels[i] > 0 || pixels[i + 1] > 0 || pixels[i + 2] > 0) {
        nonBlack++;
      }
    }
    return { nonBlack, total: pixels.length / 4 };
  });

  console.log("Recomposite pixel stats:", stats);
  expect(stats.nonBlack).toBeGreaterThan(100);
});
