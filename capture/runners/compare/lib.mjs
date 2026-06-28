/**
 * Shared compare helpers — used by both the Express backend (server.mjs) and
 * the capture orchestrator (capture.mjs).
 *
 * Layout on disk:
 *   fixtures/compare/<group>/<id>.json     — a comparison spec (canonical data)
 *   fixtures/compare/_shots/<id>/<vp>/<platform>.png  — captured screenshots
 *
 * A comparison spec looks like:
 *   {
 *     "id": "group-home",          // derived from filename if omitted
 *     "type": "page",              // "page" | "component"
 *     "group": "Group",            // display grouping within its type
 *     "title": "Group Home",
 *     "adapter": "group-home",     // defaults to id
 *     "viewports": ["pro-max","se"],
 *     "shared": { ...canonical data both platforms render... }
 *   }
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COMPARE_VIEWPORTS, DEFAULT_VIEWPORT } from './viewports.mjs';
import { getAdapter } from './adapters/index.mjs';

// Adapter resolution goes through a swappable reference so the long-running
// capture server can hot-reload the registry (a freshly-added Vue twin's adapter)
// without a restart. Defaults to the statically-imported registry; the server
// calls setAdapterResolver() with a cache-busted re-import when adapters change.
// Stays synchronous, so projectComparison() and its callers are unaffected.
let adapterResolver = getAdapter;
export function setAdapterResolver(fn) {
  adapterResolver = typeof fn === 'function' ? fn : getAdapter;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const captureRepoRoot = path.resolve(__dirname, '../..');
export const compareRoot = path.resolve(captureRepoRoot, 'fixtures/compare');
export const shotsRoot = path.resolve(compareRoot, '_shots');

export { COMPARE_VIEWPORTS, DEFAULT_VIEWPORT };

const PLATFORMS = ['iphone', 'client'];

/** Reads and normalizes every comparison spec under fixtures/compare/. */
export async function loadComparisons() {
  const out = [];
  let groupDirs = [];
  try {
    groupDirs = await fs.readdir(compareRoot, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const dirent of groupDirs) {
    if (!dirent.isDirectory()) continue;
    if (dirent.name.startsWith('_') || dirent.name.startsWith('.')) continue;
    const groupPath = path.join(compareRoot, dirent.name);
    let files = [];
    try {
      files = (await fs.readdir(groupPath)).filter((f) => f.endsWith('.json')).sort();
    } catch {
      continue;
    }
    for (const file of files) {
      try {
        const raw = JSON.parse(await fs.readFile(path.join(groupPath, file), 'utf-8'));
        const id = raw.id ?? path.basename(file, '.json');
        out.push({
          ...raw,
          id,
          type: raw.type ?? 'page',
          group: raw.group ?? dirent.name,
          title: raw.title ?? id,
          adapter: raw.adapter ?? id,
          viewports: Array.isArray(raw.viewports) && raw.viewports.length ? raw.viewports : [DEFAULT_VIEWPORT],
          _file: path.join(dirent.name, file),
        });
      } catch (err) {
        out.push({ id: path.basename(file, '.json'), error: err.message, _file: path.join(dirent.name, file) });
      }
    }
  }
  return out;
}

export async function loadComparison(id) {
  const all = await loadComparisons();
  return all.find((c) => c.id === id) ?? null;
}

/** Reads a spec's raw JSON, applies `mutate(raw)`, writes it back. */
async function updateComparisonRaw(id, mutate) {
  const spec = await loadComparison(id);
  if (!spec || spec.error) throw new Error(`Comparison "${id}" not found`);
  const filePath = path.join(compareRoot, spec._file);
  const raw = JSON.parse(await fs.readFile(filePath, 'utf-8'));
  const result = mutate(raw);
  await fs.writeFile(filePath, JSON.stringify(raw, null, 2) + '\n', 'utf-8');
  return result;
}

/** Writes the `shared` block back to a comparison spec (preserving the rest). */
export async function saveComparisonShared(id, shared) {
  await updateComparisonRaw(id, (raw) => { raw.shared = shared; });
  return loadComparison(id);
}

/**
 * Rating: 1 (strongly dislike) … 5 (love it), or null to clear. Captures how
 * acceptable the user finds the current implementation despite any visual
 * discrepancies — surfaced in the manifest so tooling/LLMs can read approval.
 */
export async function setComparisonRating(id, rating) {
  const normalized = rating == null ? null : Math.max(1, Math.min(5, Math.round(Number(rating))));
  await updateComparisonRaw(id, (raw) => { raw.rating = normalized; });
  return normalized;
}


/**
 * A comparison's variants — each is { name, shared } and carries its OWN data
 * (variants often need different data). The `name` matches the iPhone component's
 * variant (e.g. ".lesson"). Falls back to a single "default" variant from `shared`.
 */
export function getVariants(spec) {
  if (Array.isArray(spec.variants) && spec.variants.length) {
    return spec.variants.map((v) => ({ name: v.name ?? 'default', shared: v.shared ?? {} }));
  }
  return [{ name: 'default', shared: spec.shared ?? {} }];
}

export function getVariant(spec, variantName) {
  const variants = getVariants(spec);
  return variants.find((v) => v.name === variantName) ?? variants[0];
}

/** Projects shared data into per-platform fixtures (variant data, or spec.shared).
 *  The web side is optional: iPhone-first comparisons have no Vue twin yet, so a
 *  missing or null-returning `toClient` yields `client: null` rather than throwing
 *  (keeps the comparison navigable + iPhone-capturable on its own). */
export function projectComparison(spec, shared) {
  const adapter = adapterResolver(spec.adapter ?? spec.id);
  const data = shared ?? spec.shared ?? {};
  return {
    iphone: adapter.toIphone(data),
    client: typeof adapter.toClient === 'function' ? (adapter.toClient(data) ?? null) : null,
  };
}

export function shotPath(id, viewport, platform) {
  return path.join(shotsRoot, id, viewport, `${platform}.png`);
}

/** Relative URL (under /screenshots/compare) for a captured screenshot. */
export function shotUrl(id, viewport, platform) {
  return `/screenshots/compare/_shots/${id}/${viewport}/${platform}.png`;
}

/** For each declared viewport, reports which platform screenshots exist. */
export async function captureStatus(spec) {
  const status = {};
  for (const vp of spec.viewports) {
    status[vp] = {};
    for (const platform of PLATFORMS) {
      try {
        const st = await fs.stat(shotPath(spec.id, vp, platform));
        status[vp][platform] = { captured: true, capturedAt: st.mtimeMs };
      } catch {
        status[vp][platform] = { captured: false };
      }
    }
  }
  return status;
}
