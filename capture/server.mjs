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
import { createServer } from 'node:http';
import { Server as SocketIOServer } from 'socket.io';
import { spawn, execSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { watch } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  loadComparisons,
  loadComparison,
  saveComparisonShared,
  projectComparison,
  getVariants,
  getVariant,
  compareRoot,
  COMPARE_VIEWPORTS,
  setAdapterResolver,
} from './runners/compare/lib.mjs';
import { buildInventory, queryInventory } from './runners/compare/inventory.mjs';
import {
  syncComparison,
  getComparison,
  setVersionRating,
  latestScreenshots,
  latestVersion,
  getVersion,
  getVariantLatest,
  versionShots,
  listVersions,
  listComments,
  listCommentsForVersion,
  listCommentsForVariant,
  addComment,
  replyComment,
  setResolved,
  deleteComment,
  summarize,
  capturedVariantNames,
} from './db/index.mjs';

const shotUrlFromPath = (rel) => (rel ? `/screenshots/compare/${rel}` : null);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const makereadyRoot = path.resolve(__dirname, '..');

const PORT = Number(process.env.PORT ?? process.env.CAPTURE_UI_PORT ?? 5951);
const isProduction = process.env.NODE_ENV === 'production' || process.env.RAILWAY === 'true';

// ── Realtime (socket.io) ──
// Set once the HTTP server is up (see bottom of file). The Compare UI listens for
// these so it live-refreshes when ANY capture writes a new screenshot — including
// captures triggered outside the UI (CLI, curl, an agent). Emitting from the
// server process (which spawns every capture job) means we don't need the child
// runner processes to know about sockets.
let io = null;

// A compare shot landed: `✓ <platform>: _shots/<id>/<viewport>/<platform>/<file>.png`
// (printed by runners/compare/capture.mjs storeShot). Parsing the job's stdout
// here catches single + batch + iPhone + client captures uniformly.
const SHOT_LINE_RE = /✓\s+\w+:\s+_shots\/([^/\s]+)\/([^/\s]+)\/(iphone|client)\//;
function emitShotFromLine(line) {
  if (!io) return;
  const m = SHOT_LINE_RE.exec(line);
  if (m) io.emit('compare:shot', { id: m[1], viewport: m[2], platform: m[3] });
}

// ── Adapter hot-reload (no server restart needed for a new web twin) ──
// A new comparison adapter is normally only seen at boot (the registry is
// imported once). Watching the adapters folder lets us re-read it live: re-import
// adapters/index.mjs with a cache-busting query (picks up newly-added adapter
// files + new registry entries) and swap lib.mjs's resolver to the fresh one.
// projectComparison stays synchronous; the web pane's `webLive` URL then resolves
// on the next fetch. We emit `compare:adapters` so the UI refetches immediately.
// NOTE: this picks up ADDED adapters (the build-a-twin case); editing an
// already-loaded adapter file is still served from the module cache until restart.
const adaptersDir = path.join(__dirname, 'runners', 'compare', 'adapters');
async function reloadAdapters(reason = 'change') {
  try {
    const mod = await import(`./runners/compare/adapters/index.mjs?t=${Date.now()}`);
    setAdapterResolver(mod.getAdapter);
    console.log(`adapters reloaded (${reason})`);
    io?.emit('compare:adapters', { reason });
  } catch (err) {
    console.warn(`adapter reload failed: ${err.message}`);
  }
}
function watchAdapters() {
  let timer = null;
  try {
    watch(adaptersDir, (_event, filename) => {
      if (filename && !filename.endsWith('.mjs')) return; // ignore editor temp files
      clearTimeout(timer);
      timer = setTimeout(() => reloadAdapters(filename || 'change'), 300);
    });
    console.log(`watching adapters for hot-reload: ${adaptersDir}`);
  } catch (err) {
    console.warn(`could not watch adapters dir: ${err.message}`);
  }
}

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

/**
 * Per-component completion for the compare nav. Counts two platform "cells" per
 * variant: the iPhone cell is done when that variant has a captured iPhone shot;
 * the web cell is done when the variant has a Vue twin (it builds/renders).
 * Overall pct = done cells / (2 × variants).
 */
async function completionFor(spec) {
  const variants = getVariants(spec);
  const total = variants.length;
  if (total === 0) return { pct: 0, iphoneCaptured: 0, webBuilt: 0, total: 0 };
  const iphoneNames = await capturedVariantNames(spec.id, 'iphone');
  const iphoneCaptured = variants.filter((v) => iphoneNames.has(v.name)).length;
  // "Built on web" = the adapter produces a client projection for the variant
  // (a Vue twin / page exists). Broader than webLiveFor, which only recognizes
  // the component-capture island and so misses page comparisons like group-home.
  const webBuilt = variants.filter((v) => {
    try { return !!projectComparison(spec, v.shared).client; } catch { return false; }
  }).length;
  const pct = Math.round(((iphoneCaptured + webBuilt) / (2 * total)) * 100);
  return { pct, iphoneCaptured, webBuilt, total };
}

// "Render sites" — how many times a SwiftUI component is actually used in the
// iOS app. Counts constructor-style usages (`Struct(`) across the app source,
// excluding the component's own definition file (its declaration + #Preview).
// Cached per struct for the server's lifetime (source changes need a restart).
const renderSiteCache = new Map();
function renderSiteCount(struct) {
  if (!struct) return null;
  if (renderSiteCache.has(struct)) return renderSiteCache.get(struct);
  let count = null;
  try {
    const appDir = path.join(makereadyRoot, 'iphone', 'MakeReady');
    // -F fixed string ("Struct(") so it matches init calls but not the type
    // declaration (`struct Struct {`) or sibling types (`StructData(`).
    const out = execSync(`grep -rnF --include=*.swift -- ${JSON.stringify(`${struct}(`)} ${JSON.stringify(appDir)} || true`,
      { encoding: 'utf-8', maxBuffer: 8 * 1024 * 1024 });
    const lines = out.split('\n').filter(Boolean).filter((l) => !l.includes(`/${struct}.swift:`));
    count = lines.length;
  } catch {
    count = null;
  }
  renderSiteCache.set(struct, count);
  return count;
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
    const completion = await completionFor(c);
    // Representative thumbnail = the latest iPhone shot at the first viewport.
    const firstVp = c.viewports?.[0];
    const latestShots = firstVp ? await latestScreenshots(c.id, firstVp) : {};
    const thumbnail = shotUrlFromPath(latestShots.iphone?.path);
    const renderSites = c.type === 'component' ? renderSiteCount(c.id) : null;
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
      completion,
      thumbnail,
      variantCount: completion.total,
      renderSites,
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

// Cross-platform inventory: every component/page with per-platform existence,
// per-variant schema + capture/match status. Filterable for the common asks.
app.get('/api/compare/inventory', async (req, res) => {
  const truthy = (v) => v === '1' || v === 'true';
  try {
    const inv = await buildInventory({ detail: truthy(req.query.detail) });
    const components = queryInventory(inv, {
      missingOnClient: truthy(req.query.missingOnClient),
      hasClientComments: truthy(req.query.hasClientComments),
      mismatched: truthy(req.query.mismatched),
      type: req.query.type || undefined,
      sort: req.query.sort || undefined,
      limit: req.query.limit ? parseInt(req.query.limit, 10) : undefined,
    });
    res.json({ count: components.length, components });
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
      variantCount: getVariants(spec).length,
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

// Base URL where the client (Laravel) serves the live component-capture route.
const CAPTURE_CLIENT_URL = process.env.CAPTURE_CLIENT_URL || 'http://localhost:8001';

/** Live-iframe descriptor for the web side, or null when there's no Vue twin. */
function webLiveFor(spec, shared) {
  let client = null;
  try { client = projectComparison(spec, shared).client; } catch { /* no adapter / no twin */ }
  const data = client?.data;
  if (!data?.component) return null;
  const props = encodeURIComponent(JSON.stringify(data.componentProps ?? {}));
  // A page/layout twin renders full-bleed (it follows the device frame), so the
  // live harness drops its 16px component gutter. Component twins keep the gutter
  // (it mirrors the iPhone sizeThatFits snapshot's 16px margins).
  const bleed = spec?.type === 'page' ? '&bleed=1' : '';
  return {
    component: data.component,
    url: `${CAPTURE_CLIENT_URL}/_capture/live?component=${data.component}&props=${props}${bleed}`,
  };
}

// Left-nav model: a comparison's variants with per-platform render status + the
// two header counts (how many variants render on iPhone vs web).
app.get('/api/compare/comparison/:id/variants', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const spec = await loadComparison(req.params.id);
    if (!spec || spec.error) return res.status(404).json({ error: 'Comparison not found' });
    const viewport = (req.query.viewport && COMPARE_VIEWPORTS[req.query.viewport]) ? req.query.viewport : spec.viewports[0];
    await syncComparison(spec);
    // Badge/count = whether the variant EXISTS on each platform (computed live
    // from the fixtures/adapters), not whether it's been captured. iPhone exists
    // when the comparison has an iphone view; web exists when there's a Vue twin.
    let projected = {};
    try { projected = projectComparison(spec); } catch { /* no adapter */ }
    const iphoneExists = !!projected.iphone;
    const variants = [];
    for (const v of getVariants(spec)) {
      const web = !!webLiveFor(spec, v.shared);
      variants.push({ name: v.name, iphone: iphoneExists, web });
    }
    res.json({
      id: spec.id,
      title: spec.title,
      type: spec.type,
      viewport,
      variants,
      counts: {
        iphone: variants.filter((v) => v.iphone).length,
        web: variants.filter((v) => v.web).length,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Parses the ComponentCapture island's registry → a Map of registry-key →
// client-relative Vue path, so we can point at the exact twin file to reuse.
// The registry key is what an adapter passes as `data.component`; it may alias a
// differently-named class (e.g. `SlideButton: CardSlideButton`), so we resolve
// key → class → import path. Memoized for the server's lifetime.
let captureRegistryPromise = null;
function loadCaptureComponentRegistry() {
  if (captureRegistryPromise) return captureRegistryPromise;
  captureRegistryPromise = (async () => {
    const rel = 'resources/js/components/domain/component-capture/component-capture.vue';
    const file = path.join(makereadyRoot, 'client', rel);
    const map = new Map();
    let src;
    try { src = await fs.readFile(file, 'utf-8'); } catch { return map; }
    const dir = path.posix.dirname(rel);
    const classToPath = new Map();
    const importRe = /import\s+([A-Z][A-Za-z0-9_]*)\s+from\s+['"]([^'"]+\.vue)['"]/g;
    for (const m of src.matchAll(importRe)) {
      classToPath.set(m[1], path.posix.normalize(path.posix.join(dir, m[2])));
    }
    // Scan only the registry object literal (skip the import block above it).
    const regAt = src.indexOf('const registry');
    const block = regAt >= 0 ? src.slice(regAt) : src;
    const entryRe = /^\s*([A-Z][A-Za-z0-9_]*)\s*(?::\s*([A-Z][A-Za-z0-9_]*))?\s*,/gm;
    for (const m of block.matchAll(entryRe)) {
      const key = m[1];
      const vue = classToPath.get(m[2] ?? m[1]);
      if (vue) map.set(key, vue);
    }
    return map;
  })();
  return captureRegistryPromise;
}

// Catalog of every comparison that ALREADY has a web (Vue) twin built, so a
// page/layout build prompt can tell the model to REUSE existing components
// instead of rebuilding them. Only `component`-type comparisons are listed (the
// reusable leaves); the composing page/layout itself is excluded.
async function existingComponentTwins(excludeId) {
  const specs = await loadComparisons();
  const reg = await loadCaptureComponentRegistry();
  const out = [];
  for (const s of specs) {
    if (s.error || s.id === excludeId || s.type !== 'component') continue;
    let proj;
    try { proj = projectComparison(s); } catch { continue; }
    if (!proj.client) continue; // no web twin yet → nothing to reuse
    const struct = (proj.iphone?.view ?? '').replace(/^component\./, '');
    const regKey = proj.client?.data?.component ?? struct;
    // Prefer a clean PascalCase name for the SwiftUI-struct column; a few legacy
    // comparisons use a kebab id as their iphone view, so fall back to regKey.
    const name = /^[A-Z][A-Za-z0-9]*$/.test(struct) ? struct : (regKey || struct);
    out.push({ struct: name, regKey, title: s.title, group: s.group ?? '', vue: reg.get(regKey) ?? null });
  }
  out.sort((a, b) => a.group.localeCompare(b.group) || a.struct.localeCompare(b.struct));
  return out;
}

// Build prompt: everything Claude needs to create the web (Vue) twin of an
// iPhone-only component — its iPhone source, every variant's data/schema, the
// adapter contract, and the exact files to create. Copied into the Claude CLI.
app.get('/api/compare/comparison/:id/build-prompt', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const spec = await loadComparison(req.params.id);
    if (!spec || spec.error) return res.status(404).json({ error: 'Comparison not found' });
    let projected = {};
    try { projected = projectComparison(spec); } catch { /* iphone-only */ }
    const iphoneView = projected.iphone?.view ?? `component.${spec.id}`;
    const struct = iphoneView.replace(/^component\./, '');
    const kebab = struct.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/_/g, '-').toLowerCase();
    const variants = getVariants(spec);

    const variantBlocks = variants.map((v) =>
      `### ${v.name}\n\`\`\`json\n${JSON.stringify(v.shared ?? {}, null, 2)}\n\`\`\``,
    ).join('\n\n');

    // A page/layout is a COMPOSITION of child components. List the ones that
    // already have a web twin so the model reuses them instead of recreating
    // buttons/cards/rows that already exist. Never blocks prompt generation.
    const composes = spec.type === 'page' || spec.type === 'layout';
    let reuseSection = '';
    let twinCount = 0;
    if (composes) {
      try {
        const twins = await existingComponentTwins(spec.id);
        twinCount = twins.length;
        if (twins.length) {
          const rows = twins.map((t) =>
            `| ${t.group} | ${t.struct} | ${t.vue ? `client/${t.vue}` : `registered as \`${t.regKey}\` in the ComponentCapture island`} |`,
          ).join('\n');
          reuseSection = `

## Existing components — REUSE these, do NOT recreate
This comparison is a ${spec.type}: a COMPOSITION of child components, not a leaf. The ${twins.length} component(s) below ALREADY have a web (Vue) twin. As you read the iPhone source for this ${spec.type} and see one of these used, import and reuse its existing Vue twin — never rebuild a button, card, row, chart, or menu that already exists. Build only the parts with no twin yet, and surface a genuinely missing twin rather than inlining a one-off copy of it.

| Group | iPhone component | Web twin (Vue) |
|---|---|---|
${rows}`;
        }
      } catch { /* catalog is best-effort — never block the prompt */ }
    }

    // The build steps differ fundamentally between a leaf component (a single
    // Vue card rendered through the ComponentCapture island) and a composing
    // page/layout (a Blade page that lays out the screen and mounts islands,
    // reusing the existing card twins). Branch the source/stack/steps on type.
    const sourceBullet = composes
      ? `- iPhone ${spec.type}: the SwiftUI view registered as \`${iphoneView}\` — find its page file under \`iphone/MakeReady/Pages/**\` (e.g. \`iphone/MakeReady/Pages/Manage/Group/GroupHomePage.swift\`). Read it AND every child component it composes; the child components are your reuse map (see the table below).`
      : `- iPhone component: SwiftUI \`${struct}\` — find it under \`iphone/MakeReady/Components/**/${struct}.swift\` (card data models live in \`iphone/MakeReady/Components/Card/CardData.swift\`). This is the design reference.`;

    const stackBullet = composes
      ? `- Web stack: Laravel + Vue 3 islands + SCSS design tokens. A ${spec.type} twin is a Blade page that reproduces the screen layout and mounts Vue islands (\`data-vue="…Island" data-props="…"\`) — it is NOT a ComponentCapture entry. Copy the pattern from the existing page twin: the Blade view \`client/resources/views/pages/group-home.blade.php\` + its adapter \`capture/runners/compare/adapters/group-home.mjs\`. Reuse the card \`.vue\` twins from the table below for the composed pieces.`
      : `- Web stack: Laravel + Vue 3 islands + SCSS design tokens. Copy the pattern from existing twins: \`client/resources/js/components/card/card-study/card-study.vue\` and \`client/resources/js/components/card/card-group/card-group.vue\` (+ their \`.scss\` under \`client/resources/css/components/card/\`).`;

    const steps = composes
      ? `1. Read the iPhone SwiftUI ${spec.type} (\`${iphoneView}\`) + its data model to understand the layout, sizing, typography, colors, and section order. Cross-check the captured iPhone screenshot in the compare tool. List every child component it composes and match each against the "Existing components" table above — those are reuse, not rebuild; only the remainder is new work.
2. Build the web twin as a Blade page \`client/resources/views/pages/${spec.id}.blade.php\` that reproduces the iPhone layout. For each composed piece, REUSE its existing Vue twin from the table (import the card \`.vue\` into a page-level island, or mount an existing island) — never re-implement a component that already has a twin. Only create a new Vue component for a piece with no twin, and register any new page-level island in \`client/resources/js/app.js\`. Use existing design-system tokens (never hardcode a value that has a token).
3. Wire the adapter \`capture/runners/compare/adapters/${spec.id}.mjs\` (model: \`group-home.mjs\`). If \`adapters/index.mjs\` still maps \`${spec.id}\` to the iPhone-only stub (\`iphoneCard('${iphoneView}')\`), replace that line with an import of this adapter; otherwise extend the existing one.
   - \`toIphone(shared)\` → the AppState \`auth\`/\`state\` shape the iPhone page reads (see group-home.mjs) — unchanged from today.
   - \`toClient(shared)\` → \`{ platform:'client', view:'${iphoneView}', data:{ /* the Laravel view variables your Blade page expects */ } }\`. NO \`components.component-capture\`, NO \`clip:'.capture-wrap'\`, NO \`componentProps\` — a page renders full-bleed through its own Blade route.
4. Rebuild the client so the page + islands land in the bundle the compare pane renders: \`cd client && npm run build\`. (The compare web pane serves the BUILT client bundle, not HMR. The capture server hot-reloads your new adapter automatically — do NOT restart it.)
5. Capture the web side and verify against the iPhone reference: POST \`{"id":"${spec.id}","viewport":"pro-max","platform":"client","variant":"*"}\` to \`http://localhost:5951/api/compare/capture\`, then read the resulting PNGs under \`capture/fixtures/compare/_shots/${spec.id}/pro-max/client/\` and the iPhone references under \`.../iphone/\`. Refine and re-capture until they match. Surface genuine parity gaps instead of faking them.`
      : `1. Read the iPhone SwiftUI \`${struct}\` + its data model to understand layout, sizing, typography, colors, and what each variant changes. Cross-check the captured iPhone screenshots in the compare tool.
2. Create the Vue component at \`client/resources/js/components/card/${kebab}/${kebab}.vue\` (+ a BEM \`.scss\` under \`client/resources/css/components/card/${kebab}.scss\`), fully data-driven via props, using existing design-system tokens (never hardcode a value that has a token). It must render every variant above from props.
3. Register it in the ComponentCapture island: \`client/resources/js/components/domain/component-capture/component-capture.vue\` — import the component and add it to the \`registry\` map under the name \`${struct}\`.
4. Replace the iPhone-only adapter for \`${spec.id}\`: create \`capture/runners/compare/adapters/${spec.id}.mjs\` exporting \`{ toClient, toIphone }\`, and in \`capture/runners/compare/adapters/index.mjs\` swap the \`${spec.id}: iphoneCard('${iphoneView}')\` line to import this adapter. Pattern (see card-study.mjs / GroupCard.mjs):
   - \`toIphone(shared)\` → \`{ platform:'iphone', view:'${iphoneView}', state:{ component: shared } }\` (unchanged from today).
   - \`toClient(shared)\` → \`{ platform:'client', view:'components.component-capture', clip:'.capture-wrap', data:{ component:'${struct}', componentProps: { /* map shared → your Vue props */ } } }\`. Map any semantic icons to inline SVG for web.
5. Rebuild the client so the new component lands in the bundle the compare pane renders: \`cd client && npm run build\`. (The compare web pane serves the BUILT client bundle, not HMR. The capture server hot-reloads your new adapter automatically — do NOT restart it.)
6. Capture the web side and verify against the iPhone reference: POST \`{"id":"${spec.id}","viewport":"pro-max","platform":"client","variant":"*"}\` to \`http://localhost:5951/api/compare/capture\`, then read the resulting PNGs under \`capture/fixtures/compare/_shots/${spec.id}/pro-max/client/\` and the iPhone references under \`.../iphone/\`. Refine the Vue/SCSS and re-capture until they match. Surface genuine parity gaps instead of faking them.`;

    const prompt = `Build the WEB (Vue) version of the "${spec.title}" ${composes ? spec.type : 'component'} so it matches the iPhone version, for the MakeReady compare tool. The iPhone ${composes ? spec.type : 'component'} already exists; the web twin does NOT yet. Build it to match the iPhone for ALL ${variants.length} variant(s) below.

## Context
- Comparison id: \`${spec.id}\` (type: ${spec.type}, group: ${spec.group})
${sourceBullet}
- See the captured iPhone render for each variant in the compare tool: http://localhost:5950/compare/${spec.id}/<variant>
${stackBullet}

## Variants to support (name → the data that variant renders)
${variantBlocks}${reuseSection}

## Steps
${steps}

The variant data above is the source of truth — render each variant identically to the iPhone, adjusting only where the web platform genuinely requires it.`;

    res.json({ prompt, struct, variantCount: variants.length, reusableTwins: twinCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Variant-locked view (replaces version-locked): the latest iPhone shot + live
// web render + comments + rating for one variant. Works even with no capture yet.
app.get('/api/compare/comparison/:id/variant/:variant', async (req, res) => {
  if (!safeId(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  try {
    const spec = await loadComparison(req.params.id);
    if (!spec || spec.error) return res.status(404).json({ error: 'Comparison not found' });
    const variant = getVariant(spec, req.params.variant);
    const viewport = (req.query.viewport && COMPARE_VIEWPORTS[req.query.viewport]) ? req.query.viewport : spec.viewports[0];
    await syncComparison(spec);
    const ver = await getVariantLatest(spec.id, variant.name, viewport);
    const iphoneShot = ver?.screenshots?.find((s) => s.platform === 'iphone') ?? null;
    const comments = await listCommentsForVariant(spec.id, variant.name, viewport);
    res.json({
      id: spec.id,
      variantName: variant.name,
      viewport,
      versionId: ver?.id ?? null,
      sharedData: variant.shared,
      rating: ver?.rating ?? null,
      capturedAt: ver?.capturedAt ?? null,
      gitSha: ver?.gitSha ?? null,
      shots: {
        iphone: { url: shotUrlFromPath(iphoneShot?.path), screenshotId: iphoneShot?.id ?? null },
      },
      webLive: webLiveFor(spec, variant.shared),
      comments,
      viewports: spec.viewports,
      viewportDimensions: COMPARE_VIEWPORTS,
      canCapture: !isProduction,
    });
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
    const spec = await loadComparison(req.params.id);
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
      // Live web render (iframe) — replaces the captured client PNG.
      webLive: spec && !spec.error ? webLiveFor(spec, v.sharedData) : null,
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
    // Push a realtime event the moment a screenshot is written, so the Compare UI
    // updates as each shot lands (not just when the whole job finishes).
    emitShotFromLine(line);
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
    // Coarse "a capture job finished" signal — a backstop refresh in case a shot
    // line was missed, and lets the UI clear any out-of-band busy state.
    io?.emit('compare:done', { runId, code });
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

  // Compare batch capture: every variant of every given comparison id in ONE
  // xcodebuild run (iPhone-only). Body: { ids: [...], viewport? }. Used by the
  // nav's per-category "Capture all".
  app.post('/api/compare/capture-batch', (req, res) => {
    const { ids, viewport = 'pro-max' } = req.body ?? {};
    if (!Array.isArray(ids) || ids.length === 0) return res.status(400).json({ error: 'ids[] is required' });
    if (!ids.every((x) => safeId(x))) return res.status(400).json({ error: 'Invalid id in ids[]' });
    if (!safeId(viewport) || !COMPARE_VIEWPORTS[viewport]) return res.status(400).json({ error: 'Unknown viewport' });
    const args = [path.resolve(__dirname, 'runners/compare/capture-batch.mjs'), viewport, ...ids];
    const runId = spawnJob('node', args, { cwd: __dirname, env: process.env });
    res.json({ runId });
  });
} else {
  app.post('/api/compare/capture', (_req, res) => {
    res.status(400).json({ error: 'Capture is not available in production. Run captures locally.' });
  });
  app.post('/api/compare/capture-batch', (_req, res) => {
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

const httpServer = createServer(app);

// socket.io shares the HTTP server. In dev the Vite dev server (5950) proxies the
// /socket.io upgrade to here (5951); in production the UI is same-origin. CORS is
// permissive because this is a localhost-only dev tool.
io = new SocketIOServer(httpServer, { cors: { origin: true, credentials: true } });
io.on('connection', (socket) => {
  console.log(`socket connected: ${socket.id} (${io.engine.clientsCount} client(s))`);
  socket.on('disconnect', () => console.log(`socket disconnected: ${socket.id}`));
});

httpServer.listen(PORT, () => {
  console.log(`Capture UI backend listening on http://localhost:${PORT} (${isProduction ? 'production' : 'development'})`);
  console.log(`Platforms: ${platforms.map((p) => `${p.title} (${p.captureRoot})`).join(', ')}`);
  // Dev only: hot-reload adapters so a freshly-built Vue twin appears without a
  // restart. Production never edits adapters and disables capture.
  if (!isProduction) watchAdapters();
});
