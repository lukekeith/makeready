#!/usr/bin/env node
/**
 * Batch iPhone compare capture.
 *
 * The per-variant orchestrator (capture.mjs) runs one `xcodebuild` per call —
 * fine for one shot, far too slow for every variant of every card. This stages
 * EVERY (comparison, variant) iPhone fixture into a single workflow directory,
 * runs the snapshot test ONCE (xcodebuild builds once, then loops fixtures), and
 * records a Version + Screenshot per variant so the Compare UI shows them all.
 *
 * Usage:
 *   node runners/compare/capture-batch.mjs [viewport] [id1 id2 …]
 *     viewport  — compare viewport (default "pro-max")
 *     idN       — limit to these comparison ids (default: all `type: component`)
 *
 * Needs an Xcode build (xcodebuild). iPhone-only — web twins are skipped.
 */
import { spawn, execSync } from 'node:child_process';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  captureRepoRoot,
  compareRoot,
  loadComparisons,
  projectComparison,
  getVariants,
  COMPARE_VIEWPORTS,
} from './lib.mjs';
import { prisma, syncComparison, createVersion, finalizeVariantVersion, addScreenshot } from '../../db/index.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const runnersRoot = path.resolve(__dirname, '..');
const makereadyRoot = path.resolve(captureRepoRoot, '..');
const BATCH_WORKFLOW = 'ztmp-compare-batch';
const iphoneFixturesRoot = path.resolve(captureRepoRoot, 'fixtures/iphone');

function run(cmd, args, opts) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, opts);
    child.stdout?.on('data', (d) => process.stdout.write(d));
    child.stderr?.on('data', (d) => process.stderr.write(d));
    child.on('close', (code) => resolve(code ?? 0));
    child.on('error', (err) => { process.stderr.write(`spawn error: ${err.message}\n`); resolve(1); });
  });
}

function gitInfo() {
  try {
    const sha = execSync('git rev-parse HEAD', { cwd: makereadyRoot }).toString().trim();
    const dirty = execSync('git status --porcelain', { cwd: makereadyRoot }).toString().trim().length > 0;
    return { sha, dirty };
  } catch { return { sha: null, dirty: false }; }
}

function sourceHash(shared, projected) {
  return crypto.createHash('sha1')
    .update(JSON.stringify(shared ?? {}) + ' ' + JSON.stringify(projected ?? {}))
    .digest('hex');
}

function pngSize(buf) {
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) return {};
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

/** A safe, unique fixture/output stem for one (comparison, variant). */
function stem(id, variantName) {
  return `${id}__${variantName}`.replace(/[^A-Za-z0-9._-]/g, '-');
}

async function main() {
  const [, , vpArg, ...idArgs] = process.argv;
  const viewport = vpArg && COMPARE_VIEWPORTS[vpArg] ? vpArg : 'pro-max';
  if (vpArg && !COMPARE_VIEWPORTS[vpArg] && !vpArg.startsWith('-')) {
    // vpArg wasn't a viewport — treat it as an id filter instead.
    idArgs.unshift(vpArg);
  }
  const vp = COMPARE_VIEWPORTS[viewport];
  const onlyIds = new Set(idArgs);

  const specs = (await loadComparisons()).filter(
    (s) => !s.error && s.type === 'component' && (onlyIds.size === 0 || onlyIds.has(s.id)),
  );
  if (!specs.length) { console.error('No component comparisons matched.'); process.exit(1); }

  // ── Stage every variant fixture into one workflow dir ──
  const batchDir = path.join(iphoneFixturesRoot, BATCH_WORKFLOW);
  await fs.rm(batchDir, { recursive: true, force: true });
  await fs.mkdir(batchDir, { recursive: true });

  const jobs = []; // { spec, variant, projected, outStem }
  for (const spec of specs) {
    for (const variant of getVariants(spec)) {
      const projected = projectComparison(spec, variant.shared);
      if (!projected.iphone) continue;
      const outStem = stem(spec.id, variant.name);
      const fixture = { ...projected.iphone, output: `${outStem}.png`, devices: [vp.iphone], title: `${spec.title} · ${variant.name}` };
      await fs.writeFile(path.join(batchDir, `${outStem}.json`), JSON.stringify(fixture, null, 2), 'utf-8');
      jobs.push({ spec, variant, projected, outStem });
    }
  }
  console.log(`Staged ${jobs.length} variant fixture(s) across ${specs.length} comparison(s) → ${BATCH_WORKFLOW}/`);
  console.log(`Building + snapshotting once via xcodebuild (${vp.iphone})…\n`);

  // ── One xcodebuild run captures them all ──
  const code = await run('bash', [path.resolve(runnersRoot, 'iphone/capture.sh'), BATCH_WORKFLOW], {
    cwd: path.resolve(makereadyRoot, 'iphone'),
    env: { ...process.env, CAPTURE_ROOT: iphoneFixturesRoot },
  });
  if (code !== 0) {
    // A non-zero exit usually means one or more fixtures failed to render (e.g. a
    // component with no ViewRegistry case yet). The snapshot test continues past
    // each failure, so shots for the components that DID render are still on disk —
    // record those rather than discarding the whole batch. A true build failure
    // surfaces below as "0 captured".
    console.warn(`\n⚠ xcodebuild exited ${code} — some fixtures may have failed to render; recording the shots that were produced…`);
  }

  // ── Record a Version + Screenshot per variant ──
  const { sha, dirty } = gitInfo();
  const shotsBase = path.join(batchDir, 'screenshots', vp.iphone);
  let ok = 0, missing = 0;
  for (const { spec, variant, projected, outStem } of jobs) {
    const srcPath = path.join(shotsBase, `capture.${outStem}.png`);
    try { await fs.access(srcPath); }
    catch { console.warn(`✗ no shot for ${spec.id} / ${variant.name}`); missing++; continue; }

    await syncComparison(spec);
    // Create the version without deleting the prior one — the existing web (client)
    // shot for this variant must survive this iPhone-only batch. It's carried
    // forward and the stale versions pruned in finalizeVariantVersion below.
    const version = await createVersion({
      comparisonId: spec.id,
      viewport,
      variantName: variant.name,
      gitSha: sha,
      gitDirty: dirty,
      sourceHash: sourceHash(variant.shared, projected),
      sharedData: variant.shared,
      componentName: projected.client?.data?.component ?? null,
      iphoneView: projected.iphone?.view ?? null,
      clientView: projected.client?.view ?? null,
      width: vp.width,
      height: vp.height,
    });

    const rel = path.join('_shots', spec.id, viewport, 'iphone', `${version.id}.png`);
    const dest = path.join(compareRoot, rel);
    await fs.mkdir(path.dirname(dest), { recursive: true });
    await fs.copyFile(srcPath, dest);
    let dims = {};
    try { dims = pngSize(await fs.readFile(dest)); } catch {}
    await addScreenshot({ versionId: version.id, platform: 'iphone', device: vp.iphone, path: rel, width: dims.width ?? null, height: dims.height ?? null });
    // iPhone-only run: carry forward the latest client shot, then prune old versions.
    await finalizeVariantVersion({
      newVersionId: version.id,
      comparisonId: spec.id,
      variantName: variant.name,
      viewport,
      capturedPlatforms: ['iphone'],
    });
    console.log(`✓ ${spec.id} / ${variant.name}`);
    ok++;
  }

  await fs.rm(batchDir, { recursive: true, force: true });
  await prisma.$disconnect();
  console.log(`\nDone. ${ok} captured, ${missing} missing.`);
  // Only treat the run as failed if NOTHING was captured (likely a build failure);
  // partial misses (intentionally-skipped components) are expected.
  if (ok === 0) process.exit(1);
}

main().catch(async (err) => { console.error(err); try { await prisma.$disconnect(); } catch {} process.exit(1); });
