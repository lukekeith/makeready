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
import os from 'node:os';
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

test('E-1 / X-1: a well-formed map attaches to the right variant; a screen without one gets null', async () => {
  await dropMap(HOME);
  try {
    await writeMap(HOME, MAP);
    const v = await variantOf('home-dashboard', 'default');
    assert.equal(v.elements.elements.length, 2);
    assert.equal(v.elements.elements[0].ref, 'C-023');
    assert.equal(v.elements.node, '3622:5487');

    // A different screen, no map of its own: null, not the neighbour's.
    const other = await variantOf('groups-home', 'default');
    assert.equal(other.elements, null);
  } finally {
    await dropMap(HOME);
  }
});

test('E-2: a map whose aspect ratio diverges from the PNG by more than 1% is discarded', async () => {
  await dropMap(HOME);
  try {
    // The original spec example: 440×2126 against a frame that is really 440×2730.
    // 28% out — exactly the mistake the guard exists to catch.
    await writeMap(HOME, { ...MAP, size: { w: 440, h: 2126 } });
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);

    // Just inside tolerance still attaches: a 0.5% difference is export rounding.
    await writeMap(HOME, { ...MAP, size: { w: 440, h: 2744 } });
    assert.ok((await variantOf('home-dashboard', 'default')).elements);
  } finally {
    await dropMap(HOME);
  }
});

test('E-3: an element without `ref` makes the map malformed, not partially usable', async () => {
  await dropMap(HOME);
  try {
    await writeMap(HOME, {
      ...MAP,
      elements: [MAP.elements[0], { name: 'unlabelled', x: 0, y: 0, w: 1, h: 1 }],
    });
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);

    await writeMap(HOME, { ...MAP, elements: [] });
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  } finally {
    await dropMap(HOME);
  }
});

test('E-4: a ref the registry no longer knows still attaches — the ROUTE resolves it to null', async () => {
  await dropMap(HOME);
  try {
    await writeMap(HOME, {
      ...MAP,
      elements: [{ ref: 'C-899', name: 'Retired', instance: '1:9', x: 0, y: 0, w: 0.5, h: 0.5 }],
    });
    const v = await variantOf('home-dashboard', 'default');
    // Dropping it here would lose the rect AND the stored name, which is the only
    // thing left to label it with; resolution is the route's job (03 §2.4).
    assert.equal(v.elements.elements.length, 1);
    assert.equal(v.elements.elements[0].ref, 'C-899');
    assert.equal(v.elements.elements[0].name, 'Retired');
  } finally {
    await dropMap(HOME);
  }
});

test('E-5: writing a map invalidates the index cache (a stale index would serve old boxes)', async () => {
  await dropMap(HOME);
  try {
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
    await writeMap(HOME, MAP);
    // Same call, no restart, no explicit invalidation: dirStamp(screenAssetsDir)
    // already stamps every file in the directory, .elements.json included, so this
    // is a REGRESSION test of existing behaviour rather than of new code (09 §G-6).
    assert.ok((await variantOf('home-dashboard', 'default')).elements);
  } finally {
    await dropMap(HOME);
  }
});

test('E-6: a composite export — a section of six frames — parses and passes the guard', async () => {
  const png = await pngSize(COMPOSITE);
  assert.equal(png.width, 1176);
  assert.equal(png.height, 3286);

  await dropMap(COMPOSITE);
  try {
    // `size` is the exported SECTION's point space, rects are fractions of the
    // whole sheet, and the guard arithmetic is unchanged (09 §G-5).
    await writeMap(COMPOSITE, {
      screen: 'shared-edit-field',
      snapshot: 'edit-field-group-fields.png',
      node: '3875:8253',
      size: { w: 588, h: 1643 },
      generatedBy: 'test@2026-09-10',
      elements: [{ ref: 'C-042', name: 'EditableFieldRow', instance: '2:1', x: 0.1, y: 0.2, w: 0.3, h: 0.05 }],
    });
    const v = await variantOf('shared-edit-field', 'edit-field-group-fields');
    assert.ok(v, 'the composite snapshot is a state of shared-edit-field');
    assert.ok(v.elements, 'a composite map is not discarded by the aspect guard');
    assert.equal(v.elements.node, '3875:8253');
  } finally {
    await dropMap(COMPOSITE);
  }
});

test('a map that is not JSON at all is null rather than an exception', async () => {
  await dropMap(HOME);
  try {
    await fs.writeFile(mapPath(HOME), 'not json {', 'utf-8');
    assert.equal((await variantOf('home-dashboard', 'default')).elements, null);
  } finally {
    await dropMap(HOME);
  }
});
