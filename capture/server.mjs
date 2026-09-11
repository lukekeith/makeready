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
import { saveVariantShared } from './runners/compare/lib.mjs';
import { buildIndex, ScopeError, kebab, makereadyRoot as repoRoot } from './lib/fs-index.mjs';
import {
  buildUi2Index, ui2Counts, assetsDir as ui2AssetsDir,
  buildUi2Screens, ui2ScreenCounts, screenAssetsDir as ui2ScreenAssetsDir,
} from './lib/ui2-index.mjs';
import { isBuilt, ui2FixturePath, readUi2Fixture, writeUi2Fixture } from './lib/ui2-fixture.mjs';
import {
  noteKind, readNotes, appendNote, extractMentions, notesRepoPath, targetsWithNotes,
} from './lib/ui2-notes.mjs';
import { parseTokens, tokensPath } from './lib/ui2-tokens.mjs';
import { pngSize } from './lib/png-size.mjs';
import { buildScopePayload } from './lib/comment-payload.mjs';
import {
  syncComparison,
  getComparison,
  setVersionRating,
  latestScreenshots,
  latestVersion,
  getVersion,
  deleteVersion,
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
  createVersion,
  addScreenshot,
  findVersionBySourceHash,
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
    title: 'Web',
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


// ── Components browser (docs/features/component-browser — 03 §2) ──

const repoRel = (absPath) => path.relative(repoRoot, absPath);

function wiringPayload(node) {
  const missing = ['fixture', 'adapter', 'registry'].filter((k) => !node.wired[k]);
  return { missing, addCommand: `/capture-add ${kebab(node.name)}` };
}

// 03 §2.1 — the fs-indexed tree with per-component wiring, counts, thumbnails.
app.get('/api/components/tree', async (_req, res) => {
  try {
    const index = await buildIndex();
    const annotate = async (node) => {
      if (node.type === 'folder') {
        return { type: 'folder', name: node.name, path: node.path, children: await Promise.all(node.children.map(annotate)) };
      }
      let unresolvedComments = 0;
      let thumbnail = null;
      if (node.comparisonId) {
        unresolvedComments = (await summarize(node.comparisonId)).unresolved;
        const latest = await latestScreenshots(node.comparisonId, node.viewports[0]);
        thumbnail = shotUrlFromPath(latest.iphone?.path);
      }
      return {
        type: 'component', name: node.name, path: node.path, file: repoRel(node.file),
        comparisonId: node.comparisonId, wired: node.wired, isWired: node.isWired,
        collision: node.collision, variantCount: node.variantCount,
        unresolvedComments, thumbnail,
      };
    };
    res.json({ root: 'iphone/MakeReady/Components', tree: await Promise.all(index.tree.map(annotate)) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 03 §2.2 — component detail: variants + viewport-scoped version timelines.
app.get('/api/components/detail', async (req, res) => {
  try {
    const p = String(req.query.path ?? '');
    const index = await buildIndex();
    const node = index.byPath.get(p);
    if (!node || node.type !== 'component') return res.status(404).json({ error: 'unknown path' });
    const viewport = (req.query.viewport && COMPARE_VIEWPORTS[req.query.viewport]) ? req.query.viewport : 'pro-max';
    const base = {
      path: node.path, name: node.name, comparisonId: node.comparisonId,
      wired: node.wired, collision: node.collision, file: repoRel(node.file),
      fixtureFile: node.fixtureFile, viewports: node.viewports, viewport,
      commands: { resolve: `/component-resolve ${node.path}` },
      canCapture: !isProduction,
      viewportDimensions: COMPARE_VIEWPORTS,
    };
    if (!node.isWired) {
      return res.json({ ...base, variants: [], wiring: wiringPayload(node) });
    }
    const spec = await loadComparison(node.comparisonId);
    if (!spec || spec.error) return res.status(500).json({ error: spec?.error ?? 'fixture went missing' });
    await syncComparison(spec);
    const variants = [];
    for (const v of getVariants(spec)) {
      const comments = await listCommentsForVariant(spec.id, v.name, viewport);
      const versions = (await listVersions(spec.id, { variantName: v.name, viewport, withScreenshots: true })).map((ver) => {
        const iShot = ver.screenshots.find((sc) => sc.platform === 'iphone') ?? null;
        return {
          versionId: ver.id, capturedAt: ver.capturedAt, viewport: ver.viewport,
          gitSha: ver.gitSha, gitDirty: ver.gitDirty,
          shot: shotUrlFromPath(iShot?.path), screenshotId: iShot?.id ?? null,
          unresolvedComments: comments.filter((c) => c.versionId === ver.id && !c.resolved).length,
        };
      });
      variants.push({
        name: v.name, shared: v.shared,
        unresolvedComments: comments.filter((c) => !c.resolved).length,
        versions,
      });
    }
    res.json({ ...base, variants });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 03 §2.3 — a version-locked render + the variant's comments (this viewport, all versions).
app.get('/api/components/version/:vid', async (req, res) => {
  try {
    const v = await getVersion(req.params.vid);
    if (!v) return res.status(404).json({ error: 'Version not found' });
    const shots = await versionShots(v);
    const comments = await listCommentsForVariant(v.comparisonId, v.variantName, v.viewport);
    const spec = await loadComparison(v.comparisonId);
    res.json({
      versionId: v.id, comparisonId: v.comparisonId, variantName: v.variantName,
      viewport: v.viewport, capturedAt: v.capturedAt, gitSha: v.gitSha,
      shot: shotUrlFromPath(shots.iphone?.path), screenshotId: shots.iphone?.id ?? null,
      sharedData: v.sharedData,
      // Live web twin (loaded as a hidden hit-test iframe by the browser) —
      // powers element-targeted comments; null when there's no Vue twin.
      webLive: spec && !spec.error ? webLiveFor(spec, v.sharedData) : null,
      comments: comments.map((c) => ({ ...c, onThisVersion: c.versionId === v.id })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 03 §2.5 — scope resolution (the MCP resolve_scope tool's HTTP twin; curl gate).
app.get('/api/components/scope', async (req, res) => {
  try {
    res.json(await buildScopePayload(String(req.query.scope ?? '')));
  } catch (err) {
    if (err instanceof ScopeError) {
      return res.status(err.code === 'not-found' ? 404 : 409).json({ error: err.message, code: err.code, paths: err.paths });
    }
    res.status(500).json({ error: err.message });
  }
});

// 03 §2.4 — fixture write (dev-only, like the other mutating routes).
if (!isProduction) {
  app.put('/api/components/fixture', async (req, res) => {
    const { path: p, variant, shared } = req.body ?? {};
    if (typeof shared !== 'object' || shared === null || Array.isArray(shared)) {
      return res.status(400).json({ error: 'Body must include a "shared" object.' });
    }
    try {
      const index = await buildIndex();
      const node = index.byPath.get(String(p ?? ''));
      if (!node || node.type !== 'component') return res.status(404).json({ error: 'unknown path' });
      if (!node.wired.fixture) return res.status(409).json({ error: 'unwired' });
      await saveVariantShared(node.comparisonId, variant ?? 'default', shared);
      res.json({ ok: true, fixtureFile: node.fixtureFile });
    } catch (err) {
      if (err.code === 'unknown-variant') return res.status(404).json({ error: err.message });
      res.status(500).json({ error: err.message });
    }
  });
}

// ── UI 2.0 spec browser (docs/ui2 — the 2.0 era of /components) ──
//
// The 1.0 era browses Swift components that exist; the 2.0 era browses REGISTRY
// ROWS that are specced but not built. A row's "variants" are its designed
// states and its "render" is the frozen Figma snapshot, registered in the same
// Version/Screenshot tables (platform `design`) so the version timeline and
// pinned comments work identically on both sides.

const UI2_VIEWPORT = 'design';
/**
 * A `docs/ui2/**\/assets/x.png` repo path → the URL that serves it.
 *
 * Components and screens keep separate asset dirs, and both register their
 * artwork as platform `design` screenshots — so the mount is chosen by the
 * path's DIRECTORY, never by the caller. Keying on the basename alone would
 * have served a screen's PNG out of the components dir and 404'd.
 */
const ui2AssetUrl = (rel) => {
  if (!rel) return null;
  const mount = path.normalize(rel).includes(path.join('screens', 'assets')) ? 'ui2-screen-assets' : 'ui2-assets';
  return `/${mount}/${path.basename(rel)}`;
};
/** Screenshots carry their own platform, and the design ones live outside the
 *  compare shot store — so URL resolution is per-screenshot, not per-caller. */
const screenshotUrl = (sc) => (!sc ? null : sc.platform === 'design' ? ui2AssetUrl(sc.path) : shotUrlFromPath(sc.path));

// The element map written beside a built (`iphone`) 2.0 render by the XCTest capture
// harness — `{ size, elements: [{ name, x, y, w, h }] }`, rects as fractions of the
// render. It is what the browser hit-tests to give a comment its element context, the
// 2.0 answer to the 1.0 side's hidden web twin. Absent for the Figma snapshot and for
// anything captured before the harness emitted it, which reads as "no highlights".
const ui2ElementMap = async (sc) => {
  if (!sc?.path || sc.platform !== 'iphone') return null;
  try {
    const raw = await fs.readFile(path.join(compareRoot, sc.path.replace(/\.png$/, '.elements.json')), 'utf-8');
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed?.elements) || !parsed.elements.length) return null;
    // The map is collected during the pass that renders the PNG, so the two agree by
    // construction — but the sidecar is a SEPARATE FILE keyed on the screenshot's
    // path, and a screenshot path is copy-forwarded onto later versions
    // (finalizeVariantVersion). A stale or mismatched map would put highlights in the
    // wrong place, which is worse than none: the comment would record the wrong part.
    // Aspect ratio is the one dimensionless check available (the map is in points, the
    // PNG in pixels at the device scale), so a pass here means they describe one view.
    if (sc.width > 0 && sc.height > 0 && parsed.size?.w > 0 && parsed.size?.h > 0) {
      const drift = Math.abs((parsed.size.w / parsed.size.h) - (sc.width / sc.height));
      if (drift / (sc.width / sc.height) > 0.01) return null;
    }
    return parsed;
  } catch { return null; }
};

/**
 * Register the row's current frozen snapshot as a design version per state.
 * Idempotent: keyed on the PNG's sha, so reads are free and only a genuinely
 * refreshed snapshot appends to the timeline. Returns the versions created.
 */
async function syncUi2Row(row) {
  if (!row.snapshot || !row.variants.length) return [];
  await syncComparison({
    id: row.comparisonId,
    type: 'ui2',
    group: row.section,
    title: `${row.id} ${row.name}`,
    adapter: 'ui2-design',
  });
  const abs = path.resolve(repoRoot, row.snapshot.repoPath);
  const { width, height } = await pngSize(abs);
  const created = [];
  for (const v of row.variants) {
    // An `undesigned` state has NO artwork in the frozen snapshot — that is what
    // undesigned means. Registering the shared whole-set PNG under it anyway
    // claimed a design that does not exist (C-024 `align · top` showed the six
    // designed symbols, none of them top-aligned). Skip it: the row's Details
    // and the render pane say the state is undesigned and name the OQ it waits
    // on, which is the truthful thing to show.
    if (v.consumptionState === 'undesigned') continue;
    const existing = await findVersionBySourceHash(row.comparisonId, {
      variantName: v.name, viewport: UI2_VIEWPORT, sourceHash: row.snapshot.sha,
    });
    if (existing) continue;
    const version = await createVersion({
      comparisonId: row.comparisonId,
      variantName: v.name,
      viewport: UI2_VIEWPORT,
      capturedAt: row.snapshot.capturedAt,
      sourceHash: row.snapshot.sha,
      componentName: `${row.id} ${row.name}`,
      width, height,
    });
    await addScreenshot({ versionId: version.id, platform: 'design', device: 'figma', path: row.snapshot.repoPath, width, height });
    created.push(version.id);
  }
  return created;
}

/**
 * The SPACING tokens, as `[{ name, value }]` in points.
 *
 * The Layout tab names a measured value when it EQUALS a token — a 16pt inset
 * is `space-page-margin`. Two tokens can share a value (`space-page-margin` and
 * `space-card-padding` are both 16) and both are shipped: hiding one would
 * assert which of them the render used, which the geometry cannot say.
 *
 * Radius tokens are deliberately NOT included. The panel derives no corner
 * radius — a rect carries none — so every radius a value could match would be a
 * false label on a distance: `radius-bar` is 2 and would have named C-030's 2pt
 * bar gap `radius-bar`, which is a different property entirely.
 *
 * The same `parseTokens` the Swift generator runs on, so the browser and
 * `UI2Preview/Tokens.swift` can never disagree about what tokens.md says.
 */
async function ui2SpacingTokens() {
  try {
    const md = await fs.readFile(tokensPath, 'utf-8');
    const { spacing } = parseTokens(md);
    return spacing
      .map(({ name, value }) => ({ name, value: Number(value) }))
      .filter((t) => Number.isFinite(t.value));
  } catch {
    // tokens.md unreadable → the panel shows bare numbers, which is the same
    // thing it shows for a value no token matches. Never a reason to 500.
    return [];
  }
}

/** Shared row → API shape (the registry half; contract fields added per-caller). */
const ui2RowBase = async (row) => {
  const built = await isBuilt(row.id);
  return {
    id: row.id,
    name: row.name,
    nameNote: row.nameNote,
    status: row.status,
    platform: row.platform,
    section: row.section,
    comparisonId: row.comparisonId,
    specced: !!row.contract,
    built,
    fixtureFile: built ? path.relative(repoRoot, ui2FixturePath(row.id)) : null,
    hasSnapshot: !!row.snapshot,
    stateCount: row.variants.length,
    // For the Layout tab, which names a measured value when it equals a token.
    spacingTokens: await ui2SpacingTokens(),
  };
};

// ── UI 2.0 notes (docs/features/ui2-component-notes/03-data-and-api.md §2) ──
//
// Notes are files under docs/ui2, not DB rows (suite D1): they are normative spec
// content, so they live where every other normative artefact lives — reviewable in
// a PR, diffable, and surviving a capture-DB reset. The parser is
// lib/ui2-notes.mjs, which the two /ui2-component commands run as a CLI, so the
// browser and the skills cannot disagree about what a note says.

/** Every mentionable target: the registry's rows and the README's screens. One
 *  payload, filtered client-side — it is ~98 rows, so a request per keystroke
 *  would be waste (03 §2.3). */
async function ui2MentionIndex() {
  const [index, screens, withNotes] = await Promise.all([
    buildUi2Index(), buildUi2Screens(), targetsWithNotes(),
  ]);
  const items = [];
  for (const section of index.sections) {
    for (const row of section.rows) {
      items.push({
        kind: 'component', id: row.id, name: row.name,
        section: section.name, hasNotes: withNotes.has(row.id.toUpperCase()),
      });
    }
  }
  for (const section of screens.sections) {
    for (const row of section.rows) {
      items.push({
        kind: 'screen', id: row.id, name: row.name ?? row.id,
        section: section.name, hasNotes: withNotes.has(row.id),
      });
    }
  }
  return items;
}

/** A target exists when the registry or the README screen table knows it. Notes
 *  are keyed on the id alone, so an unknown id is a 404 rather than a file the
 *  browser would happily create under a typo. */
async function ui2ResolveTarget(target) {
  const kind = noteKind(target);
  if (!kind) return null;
  if (kind === 'component') {
    const row = (await buildUi2Index()).byId.get(String(target).toUpperCase());
    return row ? { kind, id: row.id, name: row.name } : null;
  }
  const row = (await buildUi2Screens()).byId.get(String(target));
  return row ? { kind, id: row.id, name: row.name ?? row.id } : null;
}

/** Mention tokens → the rows they name. A token that resolves to nothing is left
 *  out of `refs` and stays literal text in the body (03 §1.1) — a note must never
 *  render a broken link for writing about something that has since been renamed. */
function ui2ResolveMentions(body, mentionItems) {
  const byId = new Map(mentionItems.map((m) => [m.id.toUpperCase(), m]));
  const refs = [];
  for (const { token, id } of extractMentions(body)) {
    const hit = byId.get(id.toUpperCase());
    if (hit) refs.push({ token, kind: hit.kind, id: hit.id, name: hit.name });
  }
  return refs;
}

app.get('/api/ui2/notes', async (req, res) => {
  try {
    const target = String(req.query.target ?? '');
    const resolved = await ui2ResolveTarget(target);
    if (!resolved) return res.status(404).json({ error: 'unknown target' });

    const read = await readNotes(resolved.id);
    const mentions = await ui2MentionIndex();
    res.json({
      target: resolved.id,
      kind: resolved.kind,
      file: read.file,
      exists: read.exists,
      // Newest first for display; the FILE is oldest-first, which is what makes
      // an append a pure append and what D3's precedence reads.
      notes: [...read.notes].reverse().map((n) => ({
        ...n, refs: ui2ResolveMentions(n.body, mentions),
      })),
      parseError: read.parseError,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/ui2/mentions', async (_req, res) => {
  try {
    res.json({ items: await ui2MentionIndex() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// The registry tree: sections → rows, with spec/snapshot state + comment badges.
app.get('/api/ui2/tree', async (_req, res) => {
  try {
    const index = await buildUi2Index();
    const sections = [];
    for (const section of index.sections) {
      const rows = [];
      for (const row of section.rows) {
        const unresolvedComments = row.contract ? (await summarize(row.comparisonId)).unresolved : 0;
        rows.push({ ...(await ui2RowBase(row)), unresolvedComments, thumbnail: ui2AssetUrl(row.snapshot?.repoPath) });
      }
      sections.push({ name: section.name, rows });
    }
    const builtCount = sections.reduce((n, s) => n + s.rows.filter((r) => r.built).length, 0);
    res.json({ root: 'docs/ui2/design-system/registry.md', sections, counts: { ...ui2Counts(index), built: builtCount } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// One registry row: the contract, its designed states as variants, each with the
// design-version timeline. Mirrors /api/components/detail's shape so the browser
// columns render either era without branching on the payload.
app.get('/api/ui2/detail', async (req, res) => {
  try {
    const index = await buildUi2Index();
    const row = index.byId.get(String(req.query.id ?? '').toUpperCase());
    if (!row) return res.status(404).json({ error: 'unknown component' });
    await syncUi2Row(row);

    const base = {
      ...(await ui2RowBase(row)),
      era: '2.0',
      registry: {
        figmaRef: row.figmaRef,
        // Null whenever the ref does not determine ONE node — see figmaNodeUrl. The UI
        // shows the raw `figmaRef` instead of guessing a link.
        figmaUrl: row.figmaUrl ?? null,
        variantsProse: row.variantsProse,
        props: row.props,
        definedIn: row.definedIn,
        consumedBy: row.consumedBy,
      },
      contract: row.contract,
      snapshot: row.snapshot ? { ...row.snapshot, url: ui2AssetUrl(row.snapshot.repoPath) } : null,
      viewports: [UI2_VIEWPORT],
      viewport: UI2_VIEWPORT,
      viewportDimensions: {},
      canCapture: !isProduction,
      // Runnable verbatim: `commands.spec` carries the node URL whenever the registry
      // determines one, because the UI puts this string in a click-to-COPY control and a
      // `<figma-url>` placeholder there copies something you then have to hand-edit.
      commands: {
        spec: row.figmaUrl ? `/ui2-component ${row.id} ${row.figmaUrl}` : `/ui2-component ${row.id}`,
      },
      // Per-prop artwork for the value sets §4 declares, as URLs: { prop: { value: url } }.
      // Built here rather than in the index so the `/ui2-assets` route stays known in one
      // place, and built into a NEW object because the index is cached and must not be
      // mutated per-request. The files are keyed on the PROVIDER row (C-021 for a glyph),
      // so every component delegating to it previews the same inventory.
      propAssets: Object.fromEntries(
        (row.contract?.propRows ?? [])
          .filter((p) => p.optionAssets)
          .map((p) => [
            p.key ?? p.name,
            Object.fromEntries(Object.entries(p.optionAssets).map(([value, file]) => [value, `/ui2-assets/${file}`])),
          ]),
      ),
    };
    // The 2.0 analogue of an unwired 1.0 component: the row exists, the contract
    // doesn't. WiringChecklist's counterpart lives in the UI, and `needsSpec`
    // is what turns it on.
    //
    // An unspecced row still falls through to the variant loop whenever it has
    // ARTWORK — since 2026-09-10 a /ui2-screen run captures the component it
    // mints, so the row has a picture long before it has a contract, and the
    // index gives it a single `set` state to hang that picture on. Returning
    // early here (as this did) threw that away and rendered the row blank, which
    // is what made C-052 unviewable. A row with neither contract nor artwork
    // genuinely has nothing to show, and `row.variants` is empty for it anyway.
    const needsSpec = !row.contract;
    if (needsSpec && !row.variants.length) {
      return res.json({ ...base, variants: [], needsSpec: true });
    }

    // The built fixture, if this row has one — the source of the props each
    // state was actually rendered with, and what the Data tab edits. Keyed by
    // variant NAME (the same string the version timeline and comments key on),
    // never by slug.
    const fixture = await readUi2Fixture(row.id);
    const fixtureProps = new Map((fixture?.variants ?? []).map((fv) => [fv.name, fv.props ?? {}]));

    const variants = [];
    for (const v of row.variants) {
      const comments = await listCommentsForVariant(row.comparisonId, v.name, UI2_VIEWPORT);
      // An undesigned state has no artwork and nothing built, so it has nothing
      // to show. syncUi2Row no longer mints a design version for one, but rows
      // synced before that change still have theirs on disk — dropping them here
      // covers both, without deleting anything (and any comment already pinned
      // on such a version still counts in `unresolvedComments`).
      const undesigned = v.consumptionState === 'undesigned';
      const versions = undesigned ? [] : (await listVersions(row.comparisonId, { variantName: v.name, viewport: UI2_VIEWPORT, withScreenshots: true })).map((ver) => {
        const shot = ver.screenshots.find((sc) => sc.platform === 'design') ?? null;
        const iphoneShot = ver.screenshots.find((sc) => sc.platform === 'iphone') ?? null;
        // `shot`/`screenshotId` is the version's REPRESENTATIVE thumbnail, so it
        // prefers the built render and falls back to Figma for a version that
        // has none (the design-only versions syncUi2Row mints from the frozen
        // snapshot). Showing Figma for a version that HAS a render made a
        // captured version indistinguishable from an uncaptured one in the
        // timeline. `shots` still carries both platforms for the pane's toggle.
        const thumb = iphoneShot ?? shot;
        return {
          versionId: ver.id, capturedAt: ver.capturedAt, viewport: ver.viewport,
          gitSha: ver.gitSha, gitDirty: ver.gitDirty,
          shot: screenshotUrl(thumb), screenshotId: thumb?.id ?? null,
          hasBuiltRender: !!iphoneShot,
          // The props THIS render was captured with, recorded by the ui2 runner
          // at capture time (`sharedData`). The fixture on disk is the data the
          // NEXT capture will use and drifts from this one the moment it is
          // edited, so the two are reported separately and never conflated.
          // null on a design-only version: the frozen snapshot is not a capture.
          props: ver.sharedData ?? null,
          shots: {
            design: { url: screenshotUrl(shot), screenshotId: shot?.id ?? null },
            iphone: { url: screenshotUrl(iphoneShot), screenshotId: iphoneShot?.id ?? null },
          },
          unresolvedComments: comments.filter((c) => c.versionId === ver.id && !c.resolved).length,
        };
      });
      variants.push({
        name: v.name,
        slug: v.slug,
        propValues: v.propValues,
        consumption: v.consumption,
        consumptionState: v.consumptionState,
        undesigned,
        cells: v.cells,
        // The fixture props for this state, or null when the state has no
        // fixture entry at all — an `undesigned` row, or one rule 6 skipped.
        // null and {} mean different things to the Data tab, so keep them apart.
        fixtureProps: fixtureProps.has(v.name) ? fixtureProps.get(v.name) : null,
        unresolvedComments: comments.filter((c) => !c.resolved).length,
        versions,
      });
    }
    res.json({ ...base, variants, needsSpec });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── UI 2.0 screens ─────────────────────────────────────────────────────────
//
// The registry's rows are one axis of the 2.0 program; the README's screen table
// is the other. A screen is browsed exactly like a component — same four
// columns, same version timeline, same pinned comments — because it is the same
// kind of artefact: a frozen Figma frame with a normative spec beside it. The
// only structural difference is that a screen's states each have their OWN
// snapshot (invite-home's `unlinked` and `linked` are two frames), where a
// component's states share one whole-set PNG.

/** Register each of a screen's frozen frames as a design version of its state.
 *  Idempotent on the PNG's sha, like syncUi2Row. */
async function syncUi2Screen(row) {
  if (!row.variants.length) return [];
  await syncComparison({
    id: row.comparisonId,
    type: 'ui2-screen',
    group: row.section,
    title: `${row.id} — ${row.name}`,
    adapter: 'ui2-design',
  });
  const created = [];
  for (const v of row.variants) {
    const abs = path.resolve(repoRoot, v.snapshot.repoPath);
    const { width, height } = await pngSize(abs);
    const existing = await findVersionBySourceHash(row.comparisonId, {
      variantName: v.name, viewport: UI2_VIEWPORT, sourceHash: v.snapshot.sha,
    });
    if (existing) continue;
    const version = await createVersion({
      comparisonId: row.comparisonId,
      variantName: v.name,
      viewport: UI2_VIEWPORT,
      capturedAt: v.snapshot.capturedAt,
      sourceHash: v.snapshot.sha,
      componentName: row.id,
      width, height,
    });
    await addScreenshot({ versionId: version.id, platform: 'design', device: 'figma', path: v.snapshot.repoPath, width, height });
    created.push(version.id);
  }
  return created;
}

/** Shared screen row → API shape (the README half). */
const ui2ScreenRowBase = (row) => ({
  id: row.id,
  name: row.name,
  kind: 'screen',
  status: row.status,
  platform: row.platform,
  figma: row.figma,
  section: row.section,
  comparisonId: row.comparisonId,
  specced: !!row.spec,
  specFile: row.spec?.file ?? null,
  hasSnapshot: !!row.snapshot,
  stateCount: row.variants.length,
  componentIds: row.componentIds,
  notes: row.notes,
});

// The screen tree: README sections → screen rows, with spec/snapshot state.
app.get('/api/ui2/screens', async (_req, res) => {
  try {
    const index = await buildUi2Screens();
    const sections = [];
    for (const section of index.sections) {
      const rows = [];
      for (const row of section.rows) {
        const unresolvedComments = row.spec ? (await summarize(row.comparisonId)).unresolved : 0;
        rows.push({ ...ui2ScreenRowBase(row), unresolvedComments, thumbnail: ui2AssetUrl(row.snapshot?.repoPath) });
      }
      sections.push({ name: section.name, rows });
    }
    res.json({ root: 'docs/ui2/README.md', sections, counts: ui2ScreenCounts(index) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// One screen: its spec, its designed content states as variants, each with the
// design-version timeline. Same payload shape as /api/ui2/detail so the browser
// columns render a screen without branching.
app.get('/api/ui2/screen-detail', async (req, res) => {
  try {
    const index = await buildUi2Screens();
    const row = index.byId.get(String(req.query.id ?? ''));
    if (!row) return res.status(404).json({ error: 'unknown screen' });
    await syncUi2Screen(row);

    // Every C-### the spec's §4 enumerates, resolved against the registry so the
    // UI can link each one and show the name it actually carries now (a row
    // renamed after the screen was specced still resolves — ids never change).
    //
    // Resolution happens ONCE PER UNIQUE ref and is shared with the element maps
    // below (suite 09 §X-3). Two reasons: `built` costs an isBuilt() fs check and
    // a screen can render the same chip fourteen times, and the Screen tab's
    // roll-call and the render's hover labels must never disagree about the same
    // component.
    const registry = await buildUi2Index();
    const resolveCache = new Map();
    const resolveRef = async (id) => {
      if (resolveCache.has(id)) return resolveCache.get(id);
      const c = registry.byId.get(id);
      const resolved = c
        ? { name: c.name, specced: !!c.contract, built: await isBuilt(c.id), hasSnapshot: !!c.snapshot }
        : null;
      resolveCache.set(id, resolved);
      return resolved;
    };

    const components = [];
    for (const id of row.componentIds) {
      const r = await resolveRef(id);
      components.push({ id, name: r?.name ?? null, specced: !!r?.specced, built: !!r?.built, hasSnapshot: !!r?.hasSnapshot });
    }

    const base = {
      ...ui2ScreenRowBase(row),
      era: '2.0',
      spec: row.spec,
      components,
      snapshot: row.snapshot ? { ...row.snapshot, url: ui2AssetUrl(row.snapshot.repoPath) } : null,
      viewports: [UI2_VIEWPORT],
      viewport: UI2_VIEWPORT,
      viewportDimensions: {},
      canCapture: !isProduction,
      commands: {
        spec: row.spec?.figmaUrl
          ? `/ui2-screen ${row.id} ${row.spec.figmaUrl}`
          : `/ui2-screen ${row.id}`,
      },
    };
    if (!row.variants.length) return res.json({ ...base, variants: [], needsSpec: true });

    const variants = [];
    for (const v of row.variants) {
      const comments = await listCommentsForVariant(row.comparisonId, v.name, UI2_VIEWPORT);
      const versions = (await listVersions(row.comparisonId, { variantName: v.name, viewport: UI2_VIEWPORT, withScreenshots: true })).map((ver) => {
        const shot = ver.screenshots.find((sc) => sc.platform === 'design') ?? null;
        return {
          versionId: ver.id, capturedAt: ver.capturedAt, viewport: ver.viewport,
          gitSha: ver.gitSha, gitDirty: ver.gitDirty,
          shot: screenshotUrl(shot), screenshotId: shot?.id ?? null,
          hasBuiltRender: false,
          props: null,
          shots: {
            design: { url: screenshotUrl(shot), screenshotId: shot?.id ?? null },
            iphone: { url: null, screenshotId: null },
          },
          unresolvedComments: comments.filter((c) => c.versionId === ver.id && !c.resolved).length,
        };
      });
      // The frame's component instances, each resolved so the browser can label a
      // hover box without a second fetch. `null` when there is no map, it failed
      // to parse, or it failed the aspect guard — the client draws no boxes for
      // all three, and the screen renders exactly as it did before this existed.
      let elements = null;
      if (v.elements) {
        const resolvedEls = [];
        for (const el of v.elements.elements) {
          resolvedEls.push({ ...el, resolved: await resolveRef(el.ref) });
        }
        elements = {
          node: v.elements.node ?? null,
          size: v.elements.size ?? null,
          generatedBy: v.elements.generatedBy ?? null,
          elements: resolvedEls,
        };
      }

      variants.push({
        name: v.name,
        slug: v.slug,
        consumption: '',
        consumptionState: 'unknown',
        undesigned: false,
        cells: [],
        fixtureProps: null,
        snapshotFile: v.snapshot.file,
        elements,
        unresolvedComments: comments.filter((c) => !c.resolved).length,
        versions,
      });
    }
    res.json({ ...base, variants, needsSpec: !row.spec });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// A design version + its variant's comments (the 2.0 twin of
// /api/components/version/:vid; no web twin exists to hit-test against).
app.get('/api/ui2/version/:vid', async (req, res) => {
  try {
    const v = await getVersion(req.params.vid);
    if (!v) return res.status(404).json({ error: 'Version not found' });
    const shots = await versionShots(v);
    const comments = await listCommentsForVariant(v.comparisonId, v.variantName, v.viewport);
    res.json({
      versionId: v.id, comparisonId: v.comparisonId, variantName: v.variantName,
      viewport: v.viewport, capturedAt: v.capturedAt,
      // What THIS render was captured with (see /api/ui2/detail). null when the
      // version is the frozen Figma snapshot rather than a capture.
      props: v.sharedData ?? null,
      // `shot`/`screenshotId` stay the design (Figma) shot for existing readers;
      // `shots` carries both platforms so the client can show whichever the
      // platform toggle has selected instead of always the Figma snapshot.
      shot: screenshotUrl(shots.design), screenshotId: shots.design?.id ?? null,
      shots: {
        design: { url: screenshotUrl(shots.design), screenshotId: shots.design?.id ?? null },
        iphone: { url: screenshotUrl(shots.iphone), screenshotId: shots.iphone?.id ?? null },
      },
      webLive: null,
      // 2.0 has no web twin to hit-test; the built render carries its own geometry.
      elements: await ui2ElementMap(shots.iphone),
      comments: comments.map((c) => ({ ...c, onThisVersion: c.versionId === v.id })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

if (!isProduction) {
  // "Recapture" for a spec: re-read the frozen snapshot from disk and append a
  // design version if /ui2-component refreshed it.
  // Remove one CAPTURE from a state's timeline.
  //
  // Only a version carrying a built (`iphone`) render can go: the design-only
  // versions are syncUi2Row's, minted from the frozen snapshot and re-minted on
  // the next read, so deleting one is a no-op that looks like a bug. Refusing
  // with a reason beats a delete that silently comes back.
  //
  // The PNG on disk is deliberately NOT unlinked. finalizeVariantVersion
  // copy-forwards a screenshot path onto later versions, so one file can back
  // several versions and deleting it would blank a version this request never
  // named. Screenshot ROWS cascade with the version; comments do not — they are
  // `onDelete: SetNull`, so they survive on the variant, detached from the
  // version they were pinned to.
  app.delete('/api/ui2/version/:vid', async (req, res) => {
    try {
      const version = await getVersion(req.params.vid);
      if (!version) return res.status(404).json({ error: 'Version not found' });
      const shots = await versionShots(version);
      if (!shots.iphone) {
        return res.status(409).json({
          error: 'That version is the frozen Figma snapshot, not a capture — it would be re-created on the next read.',
        });
      }
      await deleteVersion(version.id);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // The 2.0 twin of PUT /api/components/fixture: edit the props ONE state was
  // rendered with, in `capture/fixtures/ui2/C-###.json`. Written through
  // writeUi2Fixture so the byte format matches what /ui2-component-build
  // produces and a later programmatic rewrite stays idempotent
  // (preview-build.md §3 rule 7).
  //
  // Props only. The variant NAME is the DB key for versions and comments and
  // the contract's §3 label, and the state list itself comes from the contract
  // — so this route never adds, removes or renames a variant.
  // Append one note. Write-side only, so it sits with the other repo writers
  // inside the non-production block: a deployed capture instance can READ notes
  // but never writes into the repo it was built from (suite 09 §X-1).
  app.post('/api/ui2/notes', async (req, res) => {
    try {
      const { target, body, after } = req.body ?? {};
      const resolved = await ui2ResolveTarget(String(target ?? ''));
      if (!resolved) return res.status(404).json({ error: 'unknown target' });

      const text = String(body ?? '').trim();
      if (!text) return res.status(400).json({ error: 'note body is empty' });
      if (text.length > 8000) return res.status(400).json({ error: 'note body is over 8000 characters' });

      // `after` is the newest note id the client held when it opened the
      // composer. Appending is a read-modify-write of a file the owner may also
      // be editing, so a mismatch means someone else appended in between: refuse
      // rather than write a note whose author never saw what it now follows
      // (suite 09 §G-7). Omitting `after` opts out — the CLI and tests do.
      const current = await readNotes(resolved.id);
      const last = current.notes[current.notes.length - 1]?.id ?? null;
      if (after !== undefined && after !== null && after !== last) {
        return res.status(409).json({ error: 'notes changed on disk', last });
      }

      const note = await appendNote(resolved.id, text, new Date(), resolved.name);
      const mentions = await ui2MentionIndex();
      res.json({
        ok: true,
        file: notesRepoPath(resolved.id),
        note: { ...note, refs: ui2ResolveMentions(note.body, mentions) },
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/ui2/fixture', async (req, res) => {
    const { id, variant, props } = req.body ?? {};
    if (typeof props !== 'object' || props === null || Array.isArray(props)) {
      return res.status(400).json({ error: 'Body must include a "props" object.' });
    }
    try {
      const fixture = await readUi2Fixture(String(id ?? ''));
      if (!fixture) return res.status(404).json({ error: `no fixture for ${id} — build it with /ui2-component-build` });
      const entry = (fixture.variants ?? []).find((v) => v.name === variant);
      if (!entry) return res.status(404).json({ error: `unknown state "${variant}" in ${id}` });
      entry.props = props;
      await writeUi2Fixture(fixture.registryId, fixture);
      res.json({ ok: true, fixtureFile: path.relative(repoRoot, ui2FixturePath(fixture.registryId)) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/ui2/refresh', async (req, res) => {
    try {
      const id = String(req.body?.id ?? '');
      // A screen id is anything that isn't a C-### — the same shape test the
      // browser routes on, so one Refresh button serves both registries.
      if (!/^C-\d{3}$/i.test(id)) {
        const screens = await buildUi2Screens();
        const screen = screens.byId.get(id);
        if (!screen) return res.status(404).json({ error: 'unknown screen' });
        const created = await syncUi2Screen(screen);
        return res.json({ ok: true, created: created.length, sha: screen.snapshot?.sha ?? null });
      }
      const index = await buildUi2Index();
      const row = index.byId.get(id.toUpperCase());
      if (!row) return res.status(404).json({ error: 'unknown component' });
      const created = await syncUi2Row(row);
      res.json({ ok: true, created: created.length, sha: row.snapshot?.sha ?? null });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Capture the BUILT side of a UI 2.0 component (preview-build.md §5): renders
  // the fixture in the iOS simulator and registers the PNG as the `iphone` side
  // of the same comparison, alongside the frozen `design` (Figma) snapshot.
  // Body: { id, variant? } — variant omitted (or "*") captures every state.
  app.post('/api/ui2/capture', (req, res) => {
    const id = String(req.body?.id ?? '').toUpperCase();
    const variant = String(req.body?.variant ?? '*');
    if (!safeId(id)) return res.status(400).json({ error: 'Invalid id' });
    if (variant !== '*' && !safeId(variant)) return res.status(400).json({ error: 'Invalid variant' });
    const args = [path.resolve(__dirname, 'runners/ui2/capture.mjs'), id, variant];
    const runId = spawnJob('node', args, { cwd: __dirname, env: process.env });
    res.json({ runId });
  });
}

// Frozen Figma snapshots (read-only, flat directory).
app.use('/ui2-assets', express.static(ui2AssetsDir));
app.use('/ui2-screen-assets', express.static(ui2ScreenAssetsDir));

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
