/**
 * Component-browser filesystem index (docs/features/component-browser/03 §1, 07 §1).
 *
 * Source of truth for the browser's tree + scope resolution:
 *   - the REAL filesystem under iphone/MakeReady/Components/ (folders + *.swift)
 *   - joined per request against the compare fixtures/adapters and the
 *     ViewRegistry's `component.*` cases.
 *
 * Join rule (suite D3/CR1): a component file <Name>.swift matches the comparison
 * whose id is `<Name>` OR `kebab-case(<Name>)`; the registry check accepts
 * `component.<Name>` or `component.<kebab>`. Comparisons with no Components/**
 * Swift file stay /compare-only and never appear here.
 *
 * Cache policy (D17/CR13): ONLY the fs walk and the ViewRegistry parse are
 * cached (fs.watch recursive + file mtime respectively); fixture/adapter fields
 * re-derive on every call — loadComparisons() reads disk per request.
 */
import fs from 'node:fs/promises';
import { watch } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadComparisons, getVariants, resolveAdapter } from '../runners/compare/lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const makereadyRoot = path.resolve(__dirname, '../..');
export const componentsRoot = path.resolve(makereadyRoot, 'iphone/MakeReady/Components');
export const viewRegistryPath = path.resolve(makereadyRoot, 'iphone/MakeReadyCaptureTests/ViewRegistry.swift');

export const kebab = (name) =>
  name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/_/g, '-').toLowerCase();

// ── The fs walk (cached for the default root; fs.watch invalidates) ──

async function walk(dir, rel) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const folders = [];
  const components = [];
  for (const e of entries) {
    if (e.name.startsWith('.')) continue;
    if (e.isDirectory()) {
      const childRel = rel ? `${rel}/${e.name}` : e.name;
      folders.push({ type: 'folder', name: e.name, path: childRel, children: await walk(path.join(dir, e.name), childRel) });
    } else if (e.isFile() && e.name.endsWith('.swift')) {
      const name = e.name.slice(0, -'.swift'.length);
      components.push({ type: 'component', name, path: rel ? `${rel}/${name}` : name, file: path.join(dir, e.name) });
    }
  }
  folders.sort((a, b) => a.name.localeCompare(b.name));
  components.sort((a, b) => a.name.localeCompare(b.name));
  return [...folders, ...components];
}

let treeCache = null;
let watching = false;
function watchComponents() {
  if (watching) return;
  watching = true;
  try {
    watch(componentsRoot, { recursive: true }, () => { treeCache = null; });
  } catch { /* watch is a cache-freshness nicety; a failed watch just means per-request walks */ }
}

export async function scanComponentsTree(root = componentsRoot) {
  const cacheable = root === componentsRoot;
  if (cacheable && treeCache) return treeCache;
  const tree = await walk(root, '');
  const byPath = new Map();
  const byName = new Map();
  const visit = (nodes) => {
    for (const n of nodes) {
      byPath.set(n.path, n);
      if (n.type === 'component') {
        if (!byName.has(n.name)) byName.set(n.name, []);
        byName.get(n.name).push(n);
      } else visit(n.children);
    }
  };
  visit(tree);
  const scan = { tree, byPath, byName };
  if (cacheable) { treeCache = scan; watchComponents(); }
  return scan;
}

// ── ViewRegistry parse (mtime-cached) ──

let registryCache = null; // { mtimeMs, cases: Set<string> }
export async function registryCases(file = viewRegistryPath) {
  const { mtimeMs } = await fs.stat(file);
  if (registryCache && registryCache.file === file && registryCache.mtimeMs === mtimeMs) {
    return registryCache.cases;
  }
  const src = await fs.readFile(file, 'utf-8');
  const cases = new Set();
  for (const m of src.matchAll(/case\s+"component\.([^"]+)"/g)) cases.add(m[1]);
  registryCache = { file, mtimeMs, cases };
  return cases;
}

// ── The per-request join ──

function defaultAdapterCheck(spec) {
  try {
    const a = resolveAdapter(spec.adapter ?? spec.id);
    return typeof a?.toIphone === 'function';
  } catch {
    return false;
  }
}

/**
 * Builds the joined index. Every option is injectable for tests; the defaults
 * hit the real repo.
 * Returns { tree, byPath, byName, components } where components is the flat
 * array of annotated component nodes.
 */
export async function buildIndex({ root, registryFile, comparisons, adapterCheck = defaultAdapterCheck } = {}) {
  const scan = await scanComponentsTree(root);
  const cases = await registryCases(registryFile);
  const specs = comparisons ?? (await loadComparisons());
  const byId = new Map(specs.filter((s) => !s.error).map((s) => [s.id, s]));

  const components = [];
  const annotate = (node) => {
    if (node.type === 'folder') return { ...node, children: node.children.map(annotate) };
    const spec = byId.get(node.name) ?? byId.get(kebab(node.name)) ?? null;
    const collision = (scan.byName.get(node.name)?.length ?? 0) > 1;
    const wired = {
      fixture: !!spec,
      adapter: spec ? adapterCheck(spec) : false,
      registry: cases.has(node.name) || cases.has(kebab(node.name)),
    };
    const out = {
      ...node,
      collision,
      comparisonId: spec?.id ?? null,
      fixtureFile: spec?._file ? `capture/fixtures/compare/${spec._file}` : null,
      wired,
      isWired: wired.fixture && wired.adapter && wired.registry,
      variantCount: spec ? getVariants(spec).length : 0,
      viewports: spec?.viewports ?? ['pro-max'],
    };
    components.push(out);
    return out;
  };
  const tree = scan.tree.map(annotate);
  const byPath = new Map(components.map((c) => [c.path, c]));
  for (const [p, n] of scan.byPath) if (n.type === 'folder') byPath.set(p, n);
  const byName = new Map();
  for (const c of components) {
    if (!byName.has(c.name)) byName.set(c.name, []);
    byName.get(c.name).push(c);
  }
  return { tree, byPath, byName, components };
}

// ── Scope resolution (suite D6 grammar, incl. G3 bare unique name) ──

export class ScopeError extends Error {
  constructor(code, message, paths = []) {
    super(message);
    this.code = code; // 'not-found' | 'ambiguous' | 'collision'
    this.paths = paths;
  }
}

/**
 * Resolves a scope string against a built index → array of component nodes.
 *   A/B/Name  exact component
 *   A/B/** or bare folder path  every component under the folder (recursive)
 *   **  every component
 *   bare Name  the unique component with that basename (ambiguous → error)
 * A collided node anywhere in the result errors the whole resolution (CR21).
 */
export function resolveScope(index, rawScope) {
  const scope = String(rawScope ?? '').trim().replace(/\/+$/, '');
  if (!scope) throw new ScopeError('not-found', 'Empty scope');

  let matched;
  if (scope === '**') {
    matched = index.components;
  } else if (scope.endsWith('/**')) {
    const prefix = scope.slice(0, -3);
    const folder = index.byPath.get(prefix);
    if (!folder || folder.type !== 'folder') throw new ScopeError('not-found', `Unknown folder "${prefix}"`);
    matched = index.components.filter((c) => c.path.startsWith(`${prefix}/`));
  } else {
    const node = index.byPath.get(scope);
    if (node?.type === 'component') {
      matched = [node];
    } else if (node?.type === 'folder') {
      matched = index.components.filter((c) => c.path.startsWith(`${scope}/`));
    } else if (!scope.includes('/')) {
      const named = index.byName.get(scope) ?? [];
      if (named.length === 1) matched = named;
      else if (named.length > 1) {
        throw new ScopeError('ambiguous', `"${scope}" matches ${named.length} components`, named.map((n) => n.path));
      } else throw new ScopeError('not-found', `Unknown scope "${scope}"`);
    } else {
      throw new ScopeError('not-found', `Unknown scope "${scope}"`);
    }
  }

  const collided = matched.filter((c) => c.collision);
  if (collided.length) {
    throw new ScopeError('collision', 'Scope includes basename-collided components — rename to disambiguate', collided.map((c) => c.path));
  }
  return matched;
}
