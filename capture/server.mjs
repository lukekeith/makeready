#!/usr/bin/env node
/**
 * Unified Capture UI backend.
 *
 * Serves both the web client and iPhone capture systems from a single
 * Express server. Each platform has its own capture root directory with
 * fixtures, runners, and screenshot output.
 *
 * Modes:
 *   - Local dev: reads fixtures from ./fixtures/{client,iphone}/,
 *     supports triggering captures via POST /api/:platform/capture
 *   - Production (RAILWAY=true or NODE_ENV=production): reads from
 *     the same ./fixtures/ directory, serves built Vite frontend,
 *     capture triggering is disabled
 */
import express from 'express';
import cors from 'cors';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  loadComparisons,
  loadComparison,
  saveComparisonShared,
  projectComparison,
  getVariants,
  compareRoot,
  COMPARE_VIEWPORTS,
} from './runners/compare/lib.mjs';
import {
  syncComparison,
  getComparison,
  setVersionRating,
  latestScreenshots,
  latestVersion,
  getVersion,
  versionShots,
  listVersions,
  listComments,
  listCommentsForVersion,
  addComment,
  replyComment,
  setResolved,
  deleteComment,
  summarize,
} from './db/index.mjs';

const shotUrlFromPath = (rel) => (rel ? `/screenshots/compare/${rel}` : null);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const makereadyRoot = path.resolve(__dirname, '..');

const PORT = Number(process.env.PORT ?? process.env.CAPTURE_UI_PORT ?? 5951);
const isProduction = process.env.NODE_ENV === 'production' || process.env.RAILWAY === 'true';

// ── Platform Configuration ──

const fixturesRoot = path.resolve(__dirname, 'fixtures');
const runnersRoot = path.resolve(__dirname, 'runners');

const sharedPlatforms = [
  {
    id: 'client',
    title: 'Web Client',
    captureRoot: path.resolve(fixturesRoot, 'client'),
    hasBladeComponents: true,
  },
  {
    id: 'iphone',
    title: 'iPhone',
    captureRoot: path.resolve(fixturesRoot, 'iphone'),
    hasBladeComponents: false,
  },
];

const platforms = sharedPlatforms.map((p) => {
  if (isProduction) return p;
  // Dev mode: attach runner config
  if (p.id === 'client') {
    return {
      ...p,
      runner: {
        cmd: 'node',
        args: (scope) => [path.resolve(runnersRoot, 'client/capture.mjs'), ...scope],
        cwd: path.resolve(fixturesRoot, 'client'),
        env: {},
      },
    };
  }
  if (p.id === 'iphone') {
    return {
      ...p,
      runner: {
        cmd: 'bash',
        args: (scope) => [path.resolve(runnersRoot, 'iphone/capture.sh'), ...scope],
        cwd: path.resolve(makereadyRoot, 'iphone'),
        env: { CAPTURE_ROOT: path.resolve(fixturesRoot, 'iphone') },
      },
    };
  }
  return p;
});

function getPlatform(id) {
  return platforms.find((p) => p.id === id);
}

const app = express();
app.use(cors());
app.use(express.json());

// ── Platforms list ──

app.get('/api/platforms', (_req, res) => {
  res.json({ platforms: platforms.map(({ id, title }) => ({ id, title })), canCapture: !isProduction });
});

// ── Device dimensions ──

let clientDeviceDimensions = {};
{
  try {
    const devicesPath = path.resolve(runnersRoot, 'client/devices.mjs');
    const { availablePresets, getViewport } = await import(devicesPath);
    for (const name of availablePresets) {
      try {
        const { viewport } = getViewport(name);
        if (viewport?.width && viewport?.height) {
          clientDeviceDimensions[name] = { width: viewport.width, height: viewport.height };
        }
      } catch {}
    }
  } catch {}
}

// Fallback: devices.mjs should always be available since it's bundled in the repo,
// but if the import fails for some reason, dimensions will just be empty.

const iphoneDeviceDimensions = {
  'iphone-se':         { width: 320, height: 568 },
  'iphone-15-pro':     { width: 393, height: 852 },
  'iphone-16-pro-max': { width: 440, height: 956 },
};

function getDeviceDimensions(platformId) {
  if (platformId === 'client') return clientDeviceDimensions;
  if (platformId === 'iphone') return iphoneDeviceDimensions;
  return {};
}

// ── Manifest ──

async function loadHydratedManifest(platform) {
  const manifestPath = path.join(platform.captureRoot, 'manifest.json');
  const raw = JSON.parse(await fs.readFile(manifestPath, 'utf-8'));
  const sets = [];
  for (const set of raw.sets ?? []) {
    const folderPath = path.join(platform.captureRoot, set.folder);
    let files = [];
    try {
      files = (await fs.readdir(folderPath))
        .filter((f) => f.endsWith('.json'))
        .sort();
    } catch {}
    const screens = [];
    for (const file of files) {
      try {
        const spec = JSON.parse(await fs.readFile(path.join(folderPath, file), 'utf-8'));
        const rawDevices = spec.devices ?? (platform.id === 'client' ? ['iphone-14'] : ['iphone-15-pro']);
        const viewports = (Array.isArray(rawDevices) ? rawDevices : [rawDevices]).map(
          (v) => (typeof v === 'string' ? v : v.name ?? `custom-${v.width}x${v.height}`),
        );
        let output = spec.output ?? `${path.basename(file, '.json')}.png`;
        if (platform.id === 'iphone') {
          output = `capture.${output.replace(/\.png$/, '')}.png`;
        }
        screens.push({
          file,
          screen: path.basename(file, '.json'),
          title: spec.title ?? path.basename(file, '.json'),
          output,
          view: spec.view ?? null,
          step: spec.step ?? null,
          viewports,
        });
      } catch (err) {
        screens.push({ file, screen: path.basename(file, '.json'), error: err.message });
      }
    }
    sets.push({ ...set, screens });
  }
  return { sets, viewportDimensions: getDeviceDimensions(platform.id) };
}

app.get('/api/:platform(client|iphone)/manifest', async (req, res) => {
  const platform = getPlatform(req.params.platform);
  if (!platform) return res.status(404).json({ error: 'Unknown platform' });
  try {
    res.json(await loadHydratedManifest(platform));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Fixture ──

app.get('/api/:platform(client|iphone)/fixture/:folder/:file', async (req, res) => {
  const platform = getPlatform(req.params.platform);
  if (!platform) return res.status(404).json({ error: 'Unknown platform' });
  const { folder, file } = req.params;
  if (!/^[a-z0-9._-]+$/i.test(folder) || !/^[a-z0-9._-]+\.json$/i.test(file)) {
    return res.status(400).json({ error: 'Invalid path.' });
  }
  try {
    const raw = await fs.readFile(path.join(platform.captureRoot, folder, file), 'utf-8');
    res.type('application/json').send(raw);
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
});

// ── Blade Components (client-only, local dev only) ──

if (!isProduction) {
  const clientRoot = path.resolve(makereadyRoot, 'client');

  function sliceStepBranch(content, step) {
    const stepEsc = step.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const openRe = new RegExp(
      String.raw`@(?:if|elseif)\s*\(\s*\$step\s*===\s*['"]` + stepEsc + String.raw`['"]\s*\)`, 'i',
    );
    const open = content.match(openRe);
    if (!open) return null;
    const start = open.index + open[0].length;
    const tokenRe = /@(if|elseif|else|endif)\b/g;
    tokenRe.lastIndex = start;
    let depth = 0;
    let end = content.length;
    for (let m; (m = tokenRe.exec(content)); ) {
      const kind = m[1];
      if (kind === 'if') { depth++; }
      else if (kind === 'endif') { if (depth === 0) { end = m.index; break; } depth--; }
      else if (kind === 'elseif' || kind === 'else') { if (depth === 0) { end = m.index; break; } }
    }
    return content.slice(start, end);
  }

  let vueRegistryPromise = null;
  function loadVueRegistry() {
    if (vueRegistryPromise) return vueRegistryPromise;
    vueRegistryPromise = (async () => {
      const appPath = path.join(clientRoot, 'resources/js/app.js');
      let src;
      try { src = await fs.readFile(appPath, 'utf-8'); } catch { return new Map(); }
      const importRe = /import\s+([A-Z][A-Za-z0-9_]*)\s+from\s+['"]([^'"]+\.vue)['"]/g;
      const imports = new Map();
      for (const m of src.matchAll(importRe)) {
        imports.set(m[1], m[2].replace(/^\.\//, 'resources/js/'));
      }
      return imports;
    })();
    return vueRegistryPromise;
  }

  async function extractVueChildImports(vuePath) {
    let src;
    try { src = await fs.readFile(path.join(clientRoot, vuePath), 'utf-8'); } catch { return []; }
    const importRe = /import\s+([A-Z][A-Za-z0-9_]*)\s+from\s+['"]([^'"]+\.vue)['"]/g;
    const children = [];
    for (const m of src.matchAll(importRe)) {
      children.push({ name: m[1], path: path.posix.normalize(path.posix.join(path.posix.dirname(vuePath), m[2])) });
    }
    return children;
  }

  async function extractBladeComponents(viewPath, step) {
    const full = await fs.readFile(path.join(clientRoot, viewPath), 'utf-8');
    const scoped = step ? sliceStepBranch(full, step) : null;
    const content = scoped ?? full;

    const xMatches = content.match(/<x-[a-z0-9.:-]+/gi) ?? [];
    const bladeNames = new Set();
    for (const raw of xMatches) {
      const name = raw.slice(3);
      if (name.startsWith('slot:') || name.startsWith('slot.')) continue;
      bladeNames.add(name);
    }
    const components = [];
    for (const name of [...bladeNames].sort()) {
      const relPath = `resources/views/components/${name.split('.').join('/')}.blade.php`;
      let exists = false;
      try { await fs.access(path.join(clientRoot, relPath)); exists = true; } catch {}
      components.push({ name, path: relPath, exists, kind: 'blade' });
    }

    const vueMatches = [...content.matchAll(/data-vue=["']([A-Za-z0-9_]+)["']/g)];
    if (vueMatches.length) {
      const registry = await loadVueRegistry();
      const seen = new Set();
      for (const [, ident] of vueMatches) {
        if (seen.has(ident)) continue;
        seen.add(ident);
        const relPath = registry.get(ident);
        components.push({ name: ident, path: relPath ?? null, exists: Boolean(relPath), kind: 'vue-island' });
        if (relPath) {
          const children = await extractVueChildImports(relPath);
          for (const child of children) {
            if (seen.has(child.name)) continue;
            seen.add(child.name);
            let childExists = false;
            try { await fs.access(path.join(clientRoot, child.path)); childExists = true; } catch {}
            components.push({ name: child.name, path: child.path, exists: childExists, kind: 'vue-child', parent: ident });
          }
        }
      }
    }
    return { components, scope: scoped ? 'step' : 'view' };
  }

  app.get('/api/client/blade-components', async (req, res) => {
    const view = String(req.query.view ?? '');
    if (!/^[a-z0-9._-]+$/i.test(view)) return res.status(400).json({ error: 'Invalid view identifier.' });
    const stepRaw = req.query.step ? String(req.query.step) : '';
    const step = stepRaw && /^[a-z0-9._-]+$/i.test(stepRaw) ? stepRaw : '';
    const viewPath = `resources/views/${view.split('.').join('/')}.blade.php`;
    try {
      const { components, scope } = await extractBladeComponents(viewPath, step);
      res.json({ view, viewPath, step: step || null, scope, components });
    } catch (err) {
      res.status(404).json({ error: err.message });
    }
  });
}

// ── Compare (apples-to-apples iPhone vs Web) ──

function safeId(id) {
  return typeof id === 'string' && /^[a-z0-9._-]+$/i.test(id);
}

/** Capture status per viewport, derived from the latest screenshots in the DB. */
async function captureStatusDB(spec) {
  const status = {};
  for (const vp of spec.viewports) {
    const latest = await latestScreenshots(spec.id, vp);
    status[vp] = {
      iphone: { captured: !!latest.iphone, capturedAt: latest.iphone?.createdAt ?? null },
      client: { captured: !!latest.client, capturedAt: latest.client?.createdAt ?? null },
    };
  }
  return status;
}

async function buildCompareManifest() {
  const comparisons = await loadComparisons();
  // Group by type ("page" | "component"), preserving load order within each.
  const byType = new Map();
  for (const c of comparisons) {
    if (c.error) {
      // Surface broken specs under a dedicated bucket so they're visible.
      const bucket = byType.get('error') ?? [];
      bucket.push({ id: c.id, error: c.error });
      byType.set('error', bucket);
      continue;
    }
    await syncComparison(c);
    const status = await captureStatusDB(c);
    const { unresolved } = await summarize(c.id);
    const latest = await latestVersion(c.id);
    const bucket = byType.get(c.type) ?? [];
    bucket.push({
      id: c.id,
      title: c.title,
      type: c.type,
      group: c.group,
      viewports: c.viewports,
      captures: status,
      rating: latest?.rating ?? null,
      unresolvedComments: unresolved,
    });
    byType.set(c.type, bucket);
  }
  const typeOrder = ['page', 'component', 'error'];
  const types = [...byType.keys()].sort((a, b) => {
    const ai = typeOrder.indexOf(a);
    const bi = typeOrder.indexOf(b);
    return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
  });
  return {
    types: types.map((type) => ({ type, comparisons: byType.get(type) })),
    viewports: COMPARE_VIEWPORTS,
    canCapture: !isProduction,
  };
}

app.get('/api/compare/manifest', async (_req, res) => {
  try {
    res.json(await buildCompareManifest());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/compare/comparison/:id', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const spec = await loadComparison(req.params.id);
    if (!spec) return res.status(404).json({ error: 'Comparison not found' });
    if (spec.error) return res.status(422).json({ error: spec.error, id: spec.id });
    let projected = null;
    let projectionError = null;
    try {
      projected = projectComparison(spec);
    } catch (err) {
      projectionError = err.message;
    }
    await syncComparison(spec);
    const latestV = await latestVersion(spec.id);
    const status = {};
    const shots = {};
    for (const vp of spec.viewports) {
      const latest = await latestScreenshots(spec.id, vp);
      shots[vp] = {
        iphone: shotUrlFromPath(latest.iphone?.path),
        client: shotUrlFromPath(latest.client?.path),
        iphoneVersion: latest.iphone ? { id: latest.iphone.versionId, capturedAt: latest.iphone.createdAt, gitSha: latest.iphone.version?.gitSha } : null,
        clientVersion: latest.client ? { id: latest.client.versionId, capturedAt: latest.client.createdAt, gitSha: latest.client.version?.gitSha } : null,
      };
      status[vp] = {
        iphone: { captured: !!latest.iphone, capturedAt: latest.iphone?.createdAt ?? null },
        client: { captured: !!latest.client, capturedAt: latest.client?.createdAt ?? null },
      };
    }
    res.json({
      id: spec.id,
      type: spec.type,
      group: spec.group,
      title: spec.title,
      viewports: spec.viewports,
      shared: spec.shared ?? {},
      rating: latestV?.rating ?? null,
      latestVersionId: latestV?.id ?? null,
      command: `/compare-adjust ${spec.id}`,
      projected,
      projectionError,
      captures: status,
      shots,
      viewportDimensions: COMPARE_VIEWPORTS,
      canCapture: !isProduction,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Comments (read — always available)
app.get('/api/compare/comparison/:id/comments', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    res.json({ comments: await listComments(req.params.id) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Versions of a comparison (newest first) — read, always available.
app.get('/api/compare/comparison/:id/versions', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const spec = await loadComparison(req.params.id);
    const variants = spec && !spec.error ? getVariants(spec).map((v) => v.name) : [];
    res.json({ versions: await listVersions(req.params.id), variants });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Version-locked view: the shots + rating + comments for one specific version.
app.get('/api/compare/comparison/:id/version/:vid', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const v = await getVersion(req.params.vid);
    if (!v || v.comparisonId !== req.params.id) return res.status(404).json({ error: 'Version not found' });
    const shots = await versionShots(v);
    const comments = await listCommentsForVersion(v.id);
    res.json({
      versionId: v.id,
      viewport: v.viewport,
      variantName: v.variantName,
      capturedAt: v.capturedAt,
      rating: v.rating,
      gitSha: v.gitSha,
      gitDirty: v.gitDirty,
      sourceHash: v.sourceHash,
      sharedData: v.sharedData,
      componentName: v.componentName,
      shots: {
        iphone: { url: shotUrlFromPath(shots.iphone?.path), screenshotId: shots.iphone?.id ?? null, fromThisVersion: shots.iphone?.versionId === v.id },
        client: { url: shotUrlFromPath(shots.client?.path), screenshotId: shots.client?.id ?? null, fromThisVersion: shots.client?.versionId === v.id },
      },
      comments,
      viewportDimensions: COMPARE_VIEWPORTS,
      canCapture: !isProduction,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

if (!isProduction) {
  app.put('/api/compare/comparison/:id', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    const shared = req.body?.shared;
    if (typeof shared !== 'object' || shared === null) {
      return res.status(400).json({ error: 'Body must include a "shared" object.' });
    }
    try {
      const updated = await saveComparisonShared(req.params.id, shared);
      let projected = null;
      let projectionError = null;
      try {
        projected = projectComparison(updated);
      } catch (err) {
        projectionError = err.message;
      }
      res.json({ ok: true, shared: updated.shared, projected, projectionError });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Rating: 1..5 or null to clear.
  app.put('/api/compare/comparison/:id/rating', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    const { rating } = req.body ?? {};
    if (rating != null && (typeof rating !== 'number' || rating < 1 || rating > 5)) {
      return res.status(400).json({ error: 'rating must be 1..5 or null' });
    }
    try {
      // Rate a specific version (body.versionId) or the latest one.
      let versionId = req.body?.versionId;
      if (!versionId) versionId = (await latestVersion(req.params.id))?.id;
      if (!versionId) return res.status(400).json({ error: 'No version to rate — capture first.' });
      const saved = await setVersionRating(versionId, rating);
      res.json({ ok: true, rating: saved, versionId });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Comments: place a pin, reply, resolve/unresolve, delete.
  app.post('/api/compare/comparison/:id/comments', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    try {
      const comment = await addComment({ comparisonId: req.params.id, ...(req.body ?? {}) });
      res.json({ ok: true, comment });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  app.post('/api/compare/comparison/:id/comments/:cid/replies', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    try {
      const { text, source } = req.body ?? {};
      const comment = await replyComment(req.params.cid, text, source);
      res.json({ ok: true, comment });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  app.put('/api/compare/comparison/:id/comments/:cid/resolved', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    try {
      await setResolved(req.params.cid, Boolean(req.body?.resolved));
      res.json({ ok: true });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  app.delete('/api/compare/comparison/:id/comments/:cid', async (req, res) => {
    if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
    try {
      await deleteComment(req.params.cid);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
}

// Screenshots from the compare store
app.use('/screenshots/compare', express.static(compareRoot));

// ── Capture Orchestration (local dev only) ──

const jobs = new Map();

/**
 * Spawns a child process, wires its stdout/stderr into an SSE-streamable job,
 * and returns the runId. Shared by per-platform and compare captures.
 */
function spawnJob(cmd, args, opts) {
  const runId = randomUUID();
  const job = { runId, lines: [], subscribers: new Set(), startedAt: Date.now(), exitCode: null, done: false };
  jobs.set(runId, job);

  const child = spawn(cmd, args, opts);
  const pushLine = (line) => {
    if (!line) return;
    job.lines.push(line);
    for (const sub of job.subscribers) sub.write(`data: ${JSON.stringify(line)}\n\n`);
  };
  let stdoutBuf = '';
  child.stdout.on('data', (chunk) => {
    stdoutBuf += chunk.toString();
    const parts = stdoutBuf.split('\n');
    stdoutBuf = parts.pop();
    for (const p of parts) pushLine(p);
  });
  child.stderr.on('data', (chunk) => {
    for (const p of chunk.toString().split('\n')) pushLine(p);
  });
  child.on('close', (code) => {
    if (stdoutBuf) pushLine(stdoutBuf);
    job.exitCode = code;
    job.done = true;
    const payload = JSON.stringify({ code, durationMs: Date.now() - job.startedAt });
    for (const sub of job.subscribers) {
      sub.write(`event: done\ndata: ${payload}\n\n`);
      sub.end();
    }
    job.subscribers.clear();
    setTimeout(() => jobs.delete(runId), 60 * 60 * 1000).unref();
  });
  return runId;
}

if (!isProduction) {
  function buildRunnerArgs({ scope, target }) {
    if (scope === 'all') return [];
    if (scope === 'set') {
      if (!target) throw new Error('scope=set requires target (folder name)');
      return [target];
    }
    if (scope === 'screen') {
      if (!target || !target.includes('/')) throw new Error('scope=screen requires target "folder/screen"');
      return target.split('/', 2);
    }
    throw new Error(`Unknown scope: ${scope}`);
  }

  app.post('/api/:platform(client|iphone)/capture', (req, res) => {
    const platform = getPlatform(req.params.platform);
    if (!platform) return res.status(404).json({ error: 'Unknown platform' });
    if (!platform.runner) return res.status(400).json({ error: 'Capture not available for this platform in production.' });
    let scopeArgs;
    try {
      scopeArgs = buildRunnerArgs(req.body ?? {});
    } catch (err) {
      return res.status(400).json({ error: err.message });
    }
    const { cmd, args: buildArgs, cwd, env: extraEnv } = platform.runner;
    const runId = spawnJob(cmd, buildArgs(scopeArgs), { cwd, env: { ...process.env, ...extraEnv } });
    res.json({ runId });
  });

  // Compare capture: runs the orchestrator for one comparison + viewport.
  // Body: { id, viewport, platform? }  — platform omitted captures both.
  app.post('/api/compare/capture', (req, res) => {
    const { id, viewport, platform, variant } = req.body ?? {};
    if (!safeId(id)) return res.status(400).json({ error: 'Invalid id' });
    if (!safeId(viewport) || !COMPARE_VIEWPORTS[viewport]) {
      return res.status(400).json({ error: 'Unknown viewport' });
    }
    if (platform && platform !== 'iphone' && platform !== 'client') {
      return res.status(400).json({ error: 'platform must be "iphone" or "client"' });
    }
    const args = [path.resolve(__dirname, 'runners/compare/capture.mjs'), id, viewport];
    if (variant) args.push(variant);
    if (platform) args.push(platform);
    const runId = spawnJob('node', args, { cwd: __dirname, env: process.env });
    res.json({ runId });
  });
} else {
  app.post('/api/compare/capture', (_req, res) => {
    res.status(400).json({ error: 'Capture is not available in production. Run captures locally.' });
  });
  // Production: capture endpoints return 404
  app.post('/api/:platform(client|iphone)/capture', (_req, res) => {
    res.status(400).json({ error: 'Capture is not available in production. Run captures locally.' });
  });
}

app.get('/api/capture/stream/:runId', (req, res) => {
  const job = jobs.get(req.params.runId);
  if (!job) return res.status(404).end();
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
  res.flushHeaders?.();
  for (const line of job.lines) res.write(`data: ${JSON.stringify(line)}\n\n`);
  if (job.done) {
    res.write(`event: done\ndata: ${JSON.stringify({ code: job.exitCode, durationMs: Date.now() - job.startedAt })}\n\n`);
    return res.end();
  }
  job.subscribers.add(res);
  req.on('close', () => job.subscribers.delete(res));
});

// ── Static serving ──

// Screenshots from each platform's capture directory
for (const p of platforms) {
  app.use(`/screenshots/${p.id}`, express.static(p.captureRoot));
}

// In production, serve the built Vite frontend
if (isProduction) {
  const distPath = path.join(__dirname, 'dist');
  app.use(express.static(distPath));
  // SPA fallback — serve index.html for all non-API routes
  app.get('*', (_req, res) => {
    res.sendFile(path.join(distPath, 'index.html'));
  });
}

app.listen(PORT, () => {
  console.log(`Capture UI backend listening on http://localhost:${PORT} (${isProduction ? 'production' : 'development'})`);
  console.log(`Platforms: ${platforms.map((p) => `${p.title} (${p.captureRoot})`).join(', ')}`);
});
