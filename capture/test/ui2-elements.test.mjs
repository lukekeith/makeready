// Unit tests for the UI 2.0 SCREEN element map — parsing, the `ref` requirement,
// and the aspect-ratio guard
// (docs/features/ui2-component-notes/08-testing.md §2, tests E-1…E-7, X-1).
//
// The map is a sidecar keyed on a snapshot's filename, so nothing about the file
// itself proves it describes that image. Aspect ratio is the one dimensionless
// check available, and these tests exist because a silently-discarded map and a
// silently-WRONG map look identical from the UI: the first draws no boxes, the
// second draws them on the wrong component.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { pngSize } from '../lib/png-size.mjs';
import { buildUi2Screens, screenAssetsDir } from '../lib/ui2-index.mjs';

/** The real frozen snapshot the suite measured: a 440×2730 Figma frame exported
 *  with its long edge capped at 2048, so the ratio survives but neither number
 *  matches the frame (09 §G-4 — the spec's first worked example got this wrong
 *  and would have been discarded by its own guard). */
const HOME = path.join(screenAssetsDir, 'home-dashboard.png');
/** The composite: a whole SECTION of six frames exported as one PNG (09 §G-5). */
const COMPOSITE = path.join(screenAssetsDir, 'edit-field-group-fields.png');

const MAP = {
  screen: 'home-dashboard',
  snapshot: 'home-dashboard.png',
  node: '3622:5487',
  size: { w: 440, h: 2730 },
  generatedBy: 'test@2026-09-10',
  elements: [
    { ref: 'C-023', name: 'KpiCard', instance: '1:1', x: 0.03, y: 0.12, w: 0.44, h: 0.13 },
    { ref: 'C-019', name: 'TopNav', instance: '1:2', x: 0, y: 0, w: 1, h: 0.02 },
  ],
};

/** buildUi2Screens caches on the assets directory's mtimes, so a test that writes
 *  a map into it is observed by the next call — which is exactly what E-5 asserts.
 *  Every writer here cleans up. */
const mapPath = (png) => png.replace(/\.png$/, '.elements.json');
const writeMap = async (png, body) => fs.writeFile(mapPath(png), `${JSON.stringify(body, null, 2)}\n`, 'utf-8');
const dropMap = async (png) => { try { await fs.unlink(mapPath(png)); } catch { /* none */ } };

/**
 * Run `fn` with a test map in place of whatever is on disk, then put the real one
 * back exactly as it was.
 *
 * These tests write into `docs/ui2/screens/assets/` because that is the only place
 * `buildUi2Screens` looks — and after the phase-3 backfill, REAL maps live there.
 * The first version of this file simply unlinked them in its cleanup, which
 * deleted committed artefacts on every `npm test` run.
 */
async function withMap(png, body, fn) {
  const file = mapPath(png);
  const backup = await fs.readFile(file, 'utf-8').catch(() => null);
  try {
    if (body === null) await dropMap(png); else await writeMap(png, body);
    return await fn();
  } finally {
    if (backup === null) await dropMap(png);
    else await fs.writeFile(file, backup, 'utf-8');
  }
}

const variantOf = async (screenId, label) => {
  const index = await buildUi2Screens();
  return index.byId.get(screenId)?.variants.find((v) => v.name === label) ?? null;
};

test('E-7: pngSize reads a real screen PNG, and the index attaches its dimensions', async () => {
  const size = await pngSize(HOME);
  assert.equal(size.width, 331);
  assert.equal(size.height, 2048);

  const v = await variantOf('home-dashboard', 'default');
  assert.equal(v.snapshot.width, 331);
  assert.equal(v.snapshot.height, 2048);
  assert.equal((await pngSize('/nope/missing.png')).width, undefined); // never throws
});

test('E-1 / X-1: a well-formed map attaches to the right variant; a snapshot without one gets null', async () => {
  // Both conditions are CREATED here rather than assumed of the repo. The first
  // version of this test used groups-home as its "no map" case and went red the
  // moment the backfill gave groups-home a map — a test resting on repo state
  // rather than on the behaviour it names.
  const other = path.join(screenAssetsDir, 'groups-home.png');
  await withMap(HOME, MAP, async () => {
    const v = await variantOf('home-dashboard', 'default');
    assert.equal(v.elements.elements.length, 2);
    assert.equal(v.elements.elements[0].ref, 'C-023');
    assert.equal(v.elements.node, '3622:5487');

    // …and a snapshot with no sidecar beside it gets null, not the neighbour's.
    await withMap(other, null, async () => {
      assert.equal((await variantOf('groups-home', 'default')).elements, null);
    });
  });
});

test('E-2: a map whose aspect ratio diverges from the PNG by more than 1% is discarded', async () => {
  // The original spec example: 440×2126 against a frame that is really 440×2730.
  // 28% out — exactly the mistake the guard exists to catch.
  await withMap(HOME, { ...MAP, size: { w: 440, h: 2126 } }, async () => {
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  });
  // Just inside tolerance still attaches: a 0.5% difference is export rounding.
  await withMap(HOME, { ...MAP, size: { w: 440, h: 2744 } }, async () => {
    assert.ok((await variantOf('home-dashboard', 'default')).elements);
  });
});

test('E-3: an element without `ref` makes the map malformed, not partially usable', async () => {
  await withMap(HOME, { ...MAP, elements: [MAP.elements[0], { name: 'unlabelled', x: 0, y: 0, w: 1, h: 1 }] }, async () => {
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  });
  await withMap(HOME, { ...MAP, elements: [] }, async () => {
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  });
});

test('E-4: a ref the registry no longer knows still attaches — the ROUTE resolves it to null', async () => {
  await withMap(HOME, { ...MAP, elements: [{ ref: 'C-899', name: 'Retired', instance: '1:9', x: 0, y: 0, w: 0.5, h: 0.5 }] }, async () => {
    const v = await variantOf('home-dashboard', 'default');
    // Dropping it here would lose the rect AND the stored name, which is the only
    // thing left to label it with; resolution is the route's job (03 §2.4).
    assert.equal(v.elements.elements.length, 1);
    assert.equal(v.elements.elements[0].ref, 'C-899');
    assert.equal(v.elements.elements[0].name, 'Retired');
  });
});

test('E-5: writing a map invalidates the index cache (a stale index would serve old boxes)', async () => {
  await withMap(HOME, null, async () => {
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
    await writeMap(HOME, MAP);
    // Same call, no restart, no explicit invalidation: dirStamp(screenAssetsDir)
    // already stamps every file in the directory, .elements.json included, so this
    // is a REGRESSION test of existing behaviour rather than of new code (09 §G-6).
    assert.ok((await variantOf('home-dashboard', 'default')).elements);
  });
});

test('E-6: a composite export — a section of six frames — parses and passes the guard', async () => {
  const png = await pngSize(COMPOSITE);
  assert.equal(png.width, 1176);
  assert.equal(png.height, 3286);

  // `size` is the exported SECTION's point space PLUS its export padding, rects are
  // fractions of the whole sheet, and the guard arithmetic is unchanged (09 §G-5).
  await withMap(COMPOSITE, {
    screen: 'shared-edit-field',
    snapshot: 'edit-field-group-fields.png',
    node: '3875:8253',
    size: { w: 588, h: 1643 },
    generatedBy: 'test@2026-09-10',
    elements: [{ ref: 'C-040', name: 'PageHeader', instance: '2:1', x: 0.1, y: 0.2, w: 0.3, h: 0.05 }],
  }, async () => {
    const v = await variantOf('shared-edit-field', 'edit-field-group-fields');
    assert.ok(v, 'the composite snapshot is a state of shared-edit-field');
    assert.ok(v.elements, 'a composite map is not discarded by the aspect guard');
    assert.equal(v.elements.node, '3875:8253');
  });
});

test('a map that is not JSON at all is null rather than an exception', async () => {
  await withMap(HOME, null, async () => {
    await fs.writeFile(mapPath(HOME), 'not json {', 'utf-8');
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  });
});

test('H-2b: the backfilled maps are ordered innermost-first, so ties pick the child', async () => {
  // Lives in THIS file rather than beside the other hit-test tests because the
  // tests above swap `home-dashboard.elements.json` in and out, and node runs test
  // FILES in parallel processes — asserting on the real artifact from another file
  // raced with those swaps.
  const map = JSON.parse(await fs.readFile(mapPath(HOME), 'utf-8'));
  const areas = map.elements.map((e) => e.w * e.h);
  // Smallest first, so the first containing entry the hit test meets is always the
  // innermost — exact ties included (09 §G-19).
  assert.deepEqual(areas, [...areas].sort((a, b) => a - b));
  assert.ok(map.elements.every((e) => e.ref && e.instance), 'every entry carries its ref and its Figma instance');
});
