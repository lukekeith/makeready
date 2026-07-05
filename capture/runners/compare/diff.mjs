#!/usr/bin/env node
/**
 * Compare diff — programmatic pixel diff between the latest iPhone and client
 * screenshots of a comparison, per variant.
 *
 * The numbers are ADVISORY, not a gate: fonts rasterize differently per
 * platform (SF Pro vs web font, CoreText vs Skia), so text regions always
 * register some mismatch. Use the mismatch %, the hot-band list, and the
 * highlighted delta PNG to find WHERE the two sides disagree, then judge the
 * region by eye in /compare.
 *
 * Usage:
 *   node runners/compare/diff.mjs <id> [viewport=pro-max] [variant]
 *
 * Output per variant:
 *   - dimensions of both shots (+ height delta — height gaps can be legitimate,
 *     e.g. content-hugging tiles; see the compare-tile-snapshot-collapse memory)
 *   - mismatch % over the overlapping region
 *   - the vertical bands with the most mismatched pixels (in points, @3x)
 *   - a delta PNG at fixtures/compare/_shots/<id>/<viewport>/_diff/<variant>.png
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import { shotsRoot, compareRoot, captureRepoRoot } from './lib.mjs';
import { prisma } from '../../db/index.mjs';

const [, , id, viewport = 'pro-max', onlyVariant] = process.argv;
if (!id) {
  console.error('Usage: node runners/compare/diff.mjs <id> [viewport=pro-max] [variant]');
  process.exit(1);
}

const SCALE = 3; // both platforms capture @3x at compare viewports
const BAND_PX = 120; // 40pt bands

/** Crop a PNG to width×height from the top-left. */
function crop(png, width, height) {
  const out = new PNG({ width, height });
  PNG.bitblt(png, out, 0, 0, width, height, 0, 0);
  return out;
}

async function loadShot(relPath) {
  // Screenshot.path has been stored relative to fixtures/compare/ or capture/
  // depending on runner era — try both.
  let abs = path.resolve(compareRoot, relPath);
  try {
    await fs.access(abs);
  } catch {
    abs = path.resolve(captureRepoRoot, relPath);
  }
  const buf = await fs.readFile(abs);
  return PNG.sync.read(buf);
}

async function main() {
  const versions = await prisma.version.findMany({
    where: { comparisonId: id, viewport },
    orderBy: { capturedAt: 'desc' },
    include: { screenshots: true },
  });
  if (!versions.length) {
    console.error(`No versions found for ${id} @ ${viewport}`);
    process.exit(1);
  }

  const variants = [...new Set(versions.map((v) => v.variantName))].filter(
    (v) => !onlyVariant || v === onlyVariant,
  );
  if (!variants.length) {
    console.error(`No variant "${onlyVariant}" for ${id} @ ${viewport}`);
    process.exit(1);
  }

  let comparedAny = false;
  for (const variant of variants) {
    const inVariant = versions.filter((v) => v.variantName === variant);
    const latest = {};
    for (const platform of ['iphone', 'client']) {
      const version = inVariant.find((v) => v.screenshots.some((s) => s.platform === platform));
      latest[platform] = version?.screenshots.find((s) => s.platform === platform) ?? null;
    }
    if (!latest.iphone || !latest.client) {
      const missing = ['iphone', 'client'].filter((p) => !latest[p]).join(' + ');
      console.log(`\n▸ ${variant}: SKIP — no ${missing} screenshot captured yet`);
      continue;
    }

    const [ref, web] = await Promise.all([loadShot(latest.iphone.path), loadShot(latest.client.path)]);
    const width = Math.min(ref.width, web.width);
    const height = Math.min(ref.height, web.height);
    const a = crop(ref, width, height);
    const b = crop(web, width, height);
    const delta = new PNG({ width, height });
    const mismatched = pixelmatch(a.data, b.data, delta.data, width, height, {
      threshold: 0.15,
      includeAA: false,
    });

    const diffDir = path.resolve(shotsRoot, id, viewport, '_diff');
    await fs.mkdir(diffDir, { recursive: true });
    const diffPath = path.resolve(diffDir, `${variant}.png`);
    await fs.writeFile(diffPath, PNG.sync.write(delta));

    // Mismatch counts per horizontal band → tells you WHERE to look.
    const bands = new Map();
    for (let y = 0; y < height; y++) {
      let rowCount = 0;
      for (let x = 0; x < width; x++) {
        const i = (y * width + x) * 4;
        if (delta.data[i] === 255 && delta.data[i + 1] === 0) rowCount++; // pixelmatch red
      }
      if (rowCount) {
        const band = Math.floor(y / BAND_PX);
        bands.set(band, (bands.get(band) ?? 0) + rowCount);
      }
    }
    const hot = [...bands.entries()].sort((x, y) => y[1] - x[1]).slice(0, 5);

    const pct = ((mismatched / (width * height)) * 100).toFixed(2);
    console.log(`\n▸ ${variant}`);
    console.log(`  iphone ${ref.width}×${ref.height}  client ${web.width}×${web.height}` +
      (ref.height !== web.height ? `  (height Δ ${Math.abs(ref.height - web.height)}px — may be legitimate)` : ''));
    console.log(`  mismatch: ${pct}% of overlapping ${width}×${height} (advisory — text AA always differs)`);
    if (hot.length) {
      console.log('  hottest bands (y in points):');
      for (const [band, count] of hot) {
        const y0 = (band * BAND_PX) / SCALE;
        const y1 = ((band + 1) * BAND_PX) / SCALE;
        console.log(`    y ${y0}–${y1}pt  (${count.toLocaleString()} px)`);
      }
    }
    console.log(`  delta: ${path.relative(process.cwd(), diffPath)}`);
    comparedAny = true;
  }

  if (!comparedAny) {
    console.error('\nNothing compared — capture both platforms first.');
    process.exit(1);
  }
}

main()
  .catch((err) => { console.error(err); process.exit(1); })
  .finally(() => prisma.$disconnect());
