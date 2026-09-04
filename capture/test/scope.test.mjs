/**
 * Scope grammar (docs/features/component-browser/01 D6 incl. G3; 03 §2.5; CR21).
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveScope, ScopeError } from '../lib/fs-index.mjs';

// A hand-built index (shape per buildIndex) — no filesystem needed.
const C = (path, extra = {}) => ({ type: 'component', name: path.split('/').pop(), path, collision: false, comparisonId: path.split('/').pop(), ...extra });
const components = [
  C('Card/CardEvent'),
  C('Card/CardMember'),
  C('Card/Sub/CardDeep'),
  C('Chart/TimeChart'),
  C('Chart/CardEvent2', { name: 'CardEvent2' }),
  C('Loading/Spinner', { comparisonId: null }), // unwired
];
const folders = ['Card', 'Card/Sub', 'Chart', 'Loading'].map((p) => ({ type: 'folder', name: p.split('/').pop(), path: p }));
const index = {
  components,
  byPath: new Map([...components, ...folders].map((n) => [n.path, n])),
  byName: components.reduce((m, c) => (m.set(c.name, [...(m.get(c.name) ?? []), c]), m), new Map()),
};
const paths = (r) => r.map((c) => c.path).sort();

test('exact path', () => {
  assert.deepEqual(paths(resolveScope(index, 'Card/CardEvent')), ['Card/CardEvent']);
});
test('folder/** is recursive', () => {
  assert.deepEqual(paths(resolveScope(index, 'Card/**')), ['Card/CardEvent', 'Card/CardMember', 'Card/Sub/CardDeep']);
});
test('bare folder ≡ folder/**', () => {
  assert.deepEqual(paths(resolveScope(index, 'Card')), paths(resolveScope(index, 'Card/**')));
});
test('** is everything', () => {
  assert.equal(resolveScope(index, '**').length, components.length);
});
test('bare unique component name resolves (G3)', () => {
  assert.deepEqual(paths(resolveScope(index, 'TimeChart')), ['Chart/TimeChart']);
});
test('unwired components are included with null comparisonId', () => {
  const r = resolveScope(index, 'Loading/**');
  assert.equal(r.length, 1);
  assert.equal(r[0].comparisonId, null);
});
test('unknown scope → not-found', () => {
  assert.throws(() => resolveScope(index, 'Nope/Nothing'), (e) => e instanceof ScopeError && e.code === 'not-found');
  assert.throws(() => resolveScope(index, 'NoSuchName'), (e) => e.code === 'not-found');
  assert.throws(() => resolveScope(index, 'Nope/**'), (e) => e.code === 'not-found');
});
test('ambiguous bare name → error listing paths', () => {
  const dup = { ...C('Extra/TimeChart'), name: 'TimeChart' };
  const idx2 = { ...index, components: [...components, dup], byName: new Map(index.byName) };
  idx2.byName.set('TimeChart', [index.byPath.get('Chart/TimeChart'), dup]);
  idx2.byPath = new Map(index.byPath); idx2.byPath.set('Extra/TimeChart', dup);
  assert.throws(() => resolveScope(idx2, 'TimeChart'), (e) => e.code === 'ambiguous' && e.paths.length === 2);
});
test('collision inside a scope errors the whole resolution (CR21)', () => {
  const a = { ...C('Card/Clash'), name: 'Clash', collision: true };
  const b = { ...C('Chart/Clash'), name: 'Clash', collision: true };
  const idx2 = {
    components: [...components, a, b],
    byPath: new Map([...index.byPath, [a.path, a], [b.path, b]]),
    byName: new Map([...index.byName, ['Clash', [a, b]]]),
  };
  assert.throws(() => resolveScope(idx2, 'Card/**'), (e) => e.code === 'collision' && e.paths.includes('Card/Clash'));
});
test('trailing slash tolerated', () => {
  assert.deepEqual(paths(resolveScope(index, 'Card/')), paths(resolveScope(index, 'Card')));
});
