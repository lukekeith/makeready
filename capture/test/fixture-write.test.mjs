/**
 * saveVariantShared (docs/features/component-browser/03 §2.4, CR16).
 * Writes go through updateComparisonRaw against a REAL temp fixture file placed
 * under fixtures/compare/ (the loader has a fixed root), removed in teardown.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { compareRoot, saveVariantShared, loadComparison } from '../runners/compare/lib.mjs';

const GROUP = 'ztest-cb'; // note: _-prefixed dirs are skipped by loadComparisons
const dir = path.join(compareRoot, GROUP);
const V_ID = '__TestVariantFixture';
const D_ID = '__TestDefaultFixture';

test.before(async () => {
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, `${V_ID}.json`), JSON.stringify({
    id: V_ID, type: 'component', group: 'Test', title: 'T', adapter: V_ID,
    zKeepMe: { deep: true },
    variants: [
      { name: 'A', shared: { title: 'a', metadata: [{ icon: 'pin', value: 'x' }] } },
      { name: 'B', shared: { title: 'b' } },
    ],
  }, null, 2) + '\n');
  await fs.writeFile(path.join(dir, `${D_ID}.json`), JSON.stringify({
    id: D_ID, type: 'component', group: 'Test', title: 'T', adapter: D_ID,
    shared: { title: 'orig' },
  }, null, 2) + '\n');
});
test.after(async () => { await fs.rm(dir, { recursive: true, force: true }); });

test('variant-targeted write replaces exactly that variant', async () => {
  await saveVariantShared(V_ID, 'B', { title: 'b2', extra: 1 });
  const spec = await loadComparison(V_ID);
  assert.deepEqual(spec.variants[1].shared, { title: 'b2', extra: 1 });
  assert.equal(spec.variants[0].shared.title, 'a', 'sibling variant untouched');
  assert.deepEqual(spec.zKeepMe, { deep: true }, 'unrelated keys preserved');
});

test('implicit default variant writes top-level shared', async () => {
  await saveVariantShared(D_ID, 'default', { title: 'edited' });
  const spec = await loadComparison(D_ID);
  assert.deepEqual(spec.shared, { title: 'edited' });
});

test('unknown variant throws with code (no silent first-variant fallback)', async () => {
  await assert.rejects(() => saveVariantShared(V_ID, 'Nope', {}), (e) => e.code === 'unknown-variant');
  await assert.rejects(() => saveVariantShared(D_ID, 'B', {}), (e) => e.code === 'unknown-variant');
});

test('unknown comparison throws', async () => {
  await assert.rejects(() => saveVariantShared('__no-such-cb', 'default', {}), /not found/);
});

test('formatting: 2-space + trailing newline, key order preserved', async () => {
  const raw = await fs.readFile(path.join(dir, `${V_ID}.json`), 'utf-8');
  assert.ok(raw.endsWith('}\n'));
  assert.ok(raw.includes('  "id"'));
  assert.ok(raw.indexOf('"id"') < raw.indexOf('"zKeepMe"'), 'key order intact');
  assert.ok(raw.indexOf('"zKeepMe"') < raw.indexOf('"variants"'), 'key order intact');
});
