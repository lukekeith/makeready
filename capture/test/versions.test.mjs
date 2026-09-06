/**
 * DB-1 / DB-1b / DB-2 / DB-3 (docs/features/component-browser/03-data-and-api.md §1).
 *
 * Runs against the dev `makeready_capture` DB using synthetic rows under a
 * reserved comparison id — created directly through db/index.mjs, deleted in
 * teardown. NO capture runs (suite decision D19).
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  prisma,
  syncComparison,
  createVersion,
  addScreenshot,
  finalizeVariantVersion,
  versionShots,
  listVersions,
  addComment,
  deleteVersion,
} from '../db/index.mjs';

const CID = '__test-component-browser';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function cleanup() {
  // Comparison cascades versions → screenshots and comments → messages.
  await prisma.comparison.deleteMany({ where: { id: CID } });
}

test('component-browser version retention + anchoring', async (t) => {
  await cleanup();
  await syncComparison({ id: CID, type: 'component', group: '__Test', title: 'Test', adapter: CID });

  // v1: both platforms captured.
  const v1 = await createVersion({ comparisonId: CID, viewport: 'pro-max', variantName: 'default' });
  const s1i = await addScreenshot({ versionId: v1.id, platform: 'iphone', path: `_test/${v1.id}-i.png`, device: 'iphone-16-pro-max', width: 440, height: 900 });
  const s1c = await addScreenshot({ versionId: v1.id, platform: 'client', path: `_test/${v1.id}-c.png`, device: 'iphone-17-pro-max', width: 440, height: 900 });
  await finalizeVariantVersion({ newVersionId: v1.id, comparisonId: CID, variantName: 'default', viewport: 'pro-max', capturedPlatforms: ['iphone', 'client'] });

  await sleep(20);

  // v2: iPhone-only recapture — client must be COPY-forwarded, v1 untouched.
  const v2 = await createVersion({ comparisonId: CID, viewport: 'pro-max', variantName: 'default' });
  await addScreenshot({ versionId: v2.id, platform: 'iphone', path: `_test/${v2.id}-i.png`, device: 'iphone-16-pro-max', width: 440, height: 900 });
  await finalizeVariantVersion({ newVersionId: v2.id, comparisonId: CID, variantName: 'default', viewport: 'pro-max', capturedPlatforms: ['iphone'] });

  await t.test('DB-1: both versions retained', async () => {
    const versions = await prisma.version.findMany({ where: { comparisonId: CID } });
    assert.equal(versions.length, 2);
  });

  await t.test('DB-1: old version keeps its own screenshot rows', async () => {
    const v1shots = await prisma.screenshot.findMany({ where: { versionId: v1.id } });
    assert.deepEqual(new Set(v1shots.map((s) => s.platform)), new Set(['iphone', 'client']));
    assert.ok(v1shots.some((s) => s.id === s1c.id), 'v1 client shot row still parented to v1');
  });

  await t.test('DB-1: new version got a client COPY (same path, new row)', async () => {
    const v2shots = await prisma.screenshot.findMany({ where: { versionId: v2.id } });
    const copied = v2shots.find((s) => s.platform === 'client');
    assert.ok(copied, 'client copy exists on v2');
    assert.equal(copied.path, s1c.path);
    assert.notEqual(copied.id, s1c.id);
  });

  await t.test('DB-2: addComment with an OLD version\'s screenshotId anchors to that version', async () => {
    const c = await addComment({
      comparisonId: CID, variantName: 'default', platform: 'iphone', viewport: 'pro-max',
      screenshotId: s1i.id, x: 0.5, y: 0.5, text: 'old-render note',
    });
    assert.equal(c.versionId, v1.id);
    // Without screenshotId it defaults to the LATEST iphone shot (v2).
    const c2 = await addComment({
      comparisonId: CID, variantName: 'default', platform: 'iphone', viewport: 'pro-max',
      x: 0.1, y: 0.1, text: 'current note',
    });
    assert.equal(c2.versionId, v2.id);
  });

  await t.test('DB-1b: versionShots fallback is bounded by capturedAt', async () => {
    // v0: an even older version with NO client shot — its client pairing must not
    // reach forward to shots created after it.
    const v0 = await createVersion({ comparisonId: CID, viewport: 'pro-max', variantName: 'default', capturedAt: new Date(Date.now() - 60_000) });
    await addScreenshot({ versionId: v0.id, platform: 'iphone', path: `_test/${v0.id}-i.png` });
    const shots = await versionShots(await prisma.version.findUnique({ where: { id: v0.id } }));
    assert.equal(shots.client, null, 'no client shot existed at or before v0.capturedAt');
    assert.ok(shots.iphone, 'own iphone shot found');
  });

  await t.test('DB-3: listVersions single-arg shape unchanged; filters + screenshots opt-in', async () => {
    const all = await listVersions(CID);
    assert.ok(all.length >= 3);
    assert.ok(!('screenshots' in all[0]), 'no screenshots field without withScreenshots');
    const filtered = await listVersions(CID, { variantName: 'default', viewport: 'pro-max', withScreenshots: true });
    assert.ok(filtered.length >= 3);
    assert.ok(Array.isArray(filtered[0].screenshots) && filtered[0].screenshots[0].path, 'full screenshot rows included');
    assert.equal(filtered[0].id, all[0].id, 'newest first in both shapes');
  });


  await cleanup();
});

test('DB-7: finalizeVariantVersion copies forward the platforms it is given', async () => {
  // The ui2 lane captures ONLY the iphone side; without an explicit platform
  // list the frozen Figma snapshot would not ride along to the new version,
  // and the newest version would show a built render with no reference.
  const variantName = 'ui2-copyforward';
  const viewport = 'design';
  await syncComparison({ id: CID, type: 'component', group: '__Test', title: 'Test', adapter: CID });

  const v1 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v1.id, platform: 'design', device: 'figma', path: `_test/${CID}-design.png` });

  await sleep(20);

  const v2 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v2.id, platform: 'iphone', device: 'pro-max', path: `_test/${CID}-iphone.png` });
  await finalizeVariantVersion({
    newVersionId: v2.id, comparisonId: CID, variantName, viewport,
    capturedPlatforms: ['iphone'], platforms: ['iphone', 'design'],
  });

  const shots = await prisma.screenshot.findMany({ where: { versionId: v2.id } });
  assert.deepEqual(shots.map((s) => s.platform).sort(), ['design', 'iphone']);

  // The default must not change: without `platforms`, only iphone+client are
  // considered, so `design` is NOT copied forward.
  const v3 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v3.id, platform: 'iphone', device: 'pro-max', path: `_test/${CID}-iphone3.png` });
  await finalizeVariantVersion({
    newVersionId: v3.id, comparisonId: CID, variantName, viewport, capturedPlatforms: ['iphone'],
  });
  const shots3 = await prisma.screenshot.findMany({ where: { versionId: v3.id } });
  assert.deepEqual(shots3.map((s) => s.platform), ['iphone']);
});

test('DB-8: deleteVersion rolls back an orphaned version and its screenshots', async () => {
  // Mirrors the ui2 runner's failure path (and runners/compare/capture.mjs's
  // existing one): a Version is created before the capture step runs, so a
  // failed capture must call deleteVersion rather than leave a phantom,
  // zero-screenshot entry sitting in the timeline forever.
  await syncComparison({ id: CID, type: 'component', group: '__Test', title: 'Test', adapter: CID });

  const before = await prisma.version.count({ where: { comparisonId: CID } });
  const failed = await createVersion({ comparisonId: CID, variantName: 'ui2-delete-on-failure', viewport: 'design' });
  await addScreenshot({ versionId: failed.id, platform: 'iphone', device: 'pro-max', path: `_test/${CID}-orphan.png` });

  await deleteVersion(failed.id);

  const gone = await prisma.version.findUnique({ where: { id: failed.id } });
  assert.equal(gone, null, 'version row removed');
  const shots = await prisma.screenshot.findMany({ where: { versionId: failed.id } });
  assert.deepEqual(shots, [], 'cascade removed its screenshots too');
  const after = await prisma.version.count({ where: { comparisonId: CID } });
  assert.equal(after, before, 'no net change to the comparison\'s version count');
});

test.after(async () => {
  await cleanup();
  await prisma.$disconnect();
});
