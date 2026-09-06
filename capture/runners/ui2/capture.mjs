#!/usr/bin/env node
// capture/runners/ui2/capture.mjs
/**
 * Capture the BUILT side of a UI 2.0 component (preview-build.md §5).
 *
 * Mirrors runners/compare/capture.mjs's captureIphone, minus the adapter: a ui2
 * fixture is already iPhone-shaped, because there is no web twin to project to.
 * The Figma snapshot stays the reference; this adds the `iphone` render to the
 * SAME comparison + variant, so the timeline and comments are untouched.
 *
 * Usage: node capture/runners/ui2/capture.mjs <C-###> [stateSlug|*]
 */
import { spawn, execSync } from 'node:child_process';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import path from 'node:path';
import { readUi2Fixture } from '../../lib/ui2-fixture.mjs';
import { makereadyRoot } from '../../lib/fs-index.mjs';
import { createVersion, addScreenshot, finalizeVariantVersion, deleteVersion } from '../../db/index.mjs';

const VIEWPORT = 'design';          // the viewport syncUi2Row registers under
const DEVICE = 'pro-max';
const TMP_WORKFLOW = 'ztmp-ui2';
const captureRoot = path.resolve(makereadyRoot, 'capture');
const iphoneFixtures = path.resolve(captureRoot, 'fixtures/iphone');
const compareRoot = path.resolve(captureRoot, 'fixtures/compare');

function run(cmd, args, opts) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, opts);
    child.stdout?.on('data', (d) => process.stdout.write(d));
    child.stderr?.on('data', (d) => process.stderr.write(d));
    child.on('close', (code) => resolve(code ?? 0));
    child.on('error', () => resolve(1));
  });
}

function gitInfo() {
  try {
    return {
      sha: execSync('git rev-parse HEAD', { cwd: makereadyRoot }).toString().trim(),
      dirty: execSync('git status --porcelain', { cwd: makereadyRoot }).toString().trim().length > 0,
    };
  } catch { return { sha: null, dirty: false }; }
}

function pngSize(buf) {
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) return {};
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

async function captureVariant(fixture, variant, git) {
  const dir = path.join(iphoneFixtures, TMP_WORKFLOW);
  await fs.mkdir(dir, { recursive: true });
  const key = `${fixture.registryId}-${variant.slug}`;
  // The XCTest runner renders `component.*` views in isolation: device width,
  // intrinsic height, no chrome (CaptureRunner.swift testCaptureAll).
  await fs.writeFile(path.join(dir, `${key}.json`), JSON.stringify({
    view: fixture.view,
    output: `${key}.png`,
    devices: [DEVICE],
    title: `${fixture.registryId} ${fixture.component} — ${variant.name}`,
    state: { component: variant.props },
  }, null, 2), 'utf-8');

  const version = await createVersion({
    comparisonId: fixture.id,
    variantName: variant.name,
    viewport: VIEWPORT,
    gitSha: git.sha,
    gitDirty: git.dirty,
    sourceHash: crypto.createHash('sha1').update(JSON.stringify(variant.props)).digest('hex'),
    sharedData: variant.props,
    componentName: `${fixture.registryId} ${fixture.component}`,
    iphoneView: fixture.view,
  });

  try {
    try {
      console.log(`→ ${fixture.registryId} · ${variant.name} — xcodebuild, this takes a few minutes…`);
      const code = await run('bash', [path.resolve(captureRoot, 'runners/iphone/capture.sh'), TMP_WORKFLOW, key], {
        cwd: path.resolve(makereadyRoot, 'iphone'),
        env: { ...process.env, CAPTURE_ROOT: iphoneFixtures },
      });
      if (code !== 0) throw new Error(`iphone runner exited ${code}`);

      const src = path.join(dir, 'screenshots', DEVICE, `capture.${key}.png`);
      const rel = path.join('_shots', fixture.id, VIEWPORT, 'iphone', `${version.id}.png`);
      const dest = path.join(compareRoot, rel);
      await fs.mkdir(path.dirname(dest), { recursive: true });
      await fs.copyFile(src, dest);
      const dims = pngSize(await fs.readFile(dest));
      await addScreenshot({ versionId: version.id, platform: 'iphone', device: DEVICE, path: rel, width: dims.width ?? null, height: dims.height ?? null });
      // Carry the frozen Figma snapshot onto this version so the newest one shows both.
      await finalizeVariantVersion({
        newVersionId: version.id, comparisonId: fixture.id, variantName: variant.name,
        viewport: VIEWPORT, capturedPlatforms: ['iphone'], platforms: ['iphone', 'design'],
      });
      console.log(`✓ ${rel}`);
    } catch (err) {
      // A capture that never produced a screenshot must not leave an orphaned
      // Version row behind — it would sit in the timeline forever with zero
      // shots. Roll it back and let the caller count the failure (mirrors
      // runners/compare/capture.mjs's deleteVersion-on-empty-capture path).
      console.error(`✗ ${fixture.registryId} · ${variant.name}: ${err.message}`);
      await deleteVersion(version.id);
      throw err;
    }
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

const [registryId, which = '*'] = process.argv.slice(2);
if (!registryId) { console.error('usage: capture.mjs <C-###> [stateSlug|*]'); process.exit(1); }
const fixture = await readUi2Fixture(registryId);
if (!fixture) { console.error(`${registryId} is not built — no fixture at capture/fixtures/ui2/`); process.exit(1); }
const targets = which === '*' ? fixture.variants : fixture.variants.filter((v) => v.slug === which);
if (!targets.length) { console.error(`no state matching "${which}"`); process.exit(1); }
const git = gitInfo();
let failures = 0;
for (const variant of targets) {
  try {
    await captureVariant(fixture, variant, git);
  } catch (err) {
    failures++;
    console.error(`✗ state "${variant.name}" failed: ${err.message}`);
  }
}
const succeeded = targets.length - failures;
console.log(`\n${succeeded}/${targets.length} state(s) captured${failures ? `, ${failures} failed` : ''}.`);
if (failures) process.exit(1);
process.exit(0);
