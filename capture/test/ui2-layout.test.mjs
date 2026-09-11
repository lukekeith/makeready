// Unit tests for the UI 2.0 Layout tab's geometry derivation
// (capture/src/lib/ui2-layout.js).
//
// The module is pure — `{ size, elements }` in, a tree out — so it is tested
// against hand-built maps for the rules and against the REAL element maps on
// disk for the shapes those rules have to survive (C-029's equal-rect arcs,
// C-030's 88 bars).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildLayoutTree } from '../src/lib/ui2-layout.js';

const round1 = (n) => Math.round(n * 10) / 10;

const here = path.dirname(fileURLToPath(import.meta.url));

/** Points → the fractional rects the harness actually writes. */
const frac = (size) => (name, x, y, w, h) => ({
  name, x: x / size.w, y: y / size.h, w: w / size.w, h: h / size.h,
});

const SIZE = { w: 400, h: 200 };
const at = frac(SIZE);

const TOKENS = [
  { name: 'space-page-margin', value: 16 },
  { name: 'space-card-padding', value: 16 },
  { name: 'space-element-gap', value: 8 },
  { name: 'space-meta-gap', value: 4 },
  { name: 'space-chip-gap', value: 2 },
];

const byName = (tree) => Object.fromEntries(tree.nodes.map((n) => [n.name, n]));

/** Every node in the rendered tree, collapsed run nodes included — `tree.nodes`
 *  holds only the real parts, one per input element. */
function walk(node, out = []) {
  if (!node) return out;
  out.push(node);
  for (const c of node.children ?? []) walk(c, out);
  return out;
}

// ── Containment ──

test('nests each part under the smallest part that contains it', () => {
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [at('Inner', 20, 20, 40, 40), at('Middle', 10, 10, 100, 100), at('Root', 0, 0, 400, 200)],
  });
  assert.equal(tree.root.name, 'Root');
  assert.deepEqual(tree.root.children.map((c) => c.name), ['Middle']);
  assert.deepEqual(tree.root.children[0].children.map((c) => c.name), ['Inner']);
});

test('treats two parts with the same rect as siblings, never as parent and child', () => {
  // Rects alone cannot separate the two cases: C-040's `Leading` slot holds its
  // single `GlyphButton` at exactly its own rect (real nesting), and C-029's
  // `Base ring` shares the ring box with seven sibling `Arc` parts (no nesting
  // at all). Reading equal rects as nesting turned the second into an eight-deep
  // ladder, so neither is nested and both parts show their true, identical box.
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [at('GlyphButton', 10, 10, 44, 44), at('Leading', 10, 10, 44, 44), at('Root', 0, 0, 400, 200)],
  });
  const n = byName(tree);
  assert.deepEqual(n.Root.children.map((c) => c.name), ['GlyphButton', 'Leading']);
  assert.equal(n.Leading.children.length, 0);
  assert.deepEqual(n.GlyphButton.box, n.Leading.box);
});

test('converts fractions to points and rounds to one decimal', () => {
  const tree = buildLayoutTree({ size: SIZE, elements: [at('Root', 0, 0, 357, 160)] });
  assert.deepEqual(tree.root.box, { x: 0, y: 0, w: 357, h: 160 });
  assert.deepEqual(tree.size, { w: 400, h: 200 });
});

test('measures the root inset against the whole render frame', () => {
  // That inset IS the ViewRegistry call site's padding — the one number in the
  // panel that describes the harness rather than the component.
  const tree = buildLayoutTree({ size: SIZE, elements: [at('Root', 16, 16, 368, 168)] }, { tokens: TOKENS });
  assert.deepEqual(tree.root.inset, { top: 16, right: 16, bottom: 16, left: 16 });
  assert.deepEqual(tree.root.insetTokens.top, ['space-page-margin', 'space-card-padding']);
});

// ── Stacks ──

test('reads a vertical stack: axis, gap, and the token the gap equals', () => {
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [
      at('A', 10, 10, 100, 20), at('B', 10, 34, 100, 20), at('C', 10, 58, 100, 20),
      at('Stack', 10, 10, 100, 68),
    ],
  }, { tokens: TOKENS });
  const stack = byName(tree).Stack.stack;
  assert.equal(stack.axis, 'vertical');
  assert.equal(stack.gap, 4);
  assert.deepEqual(stack.gapTokens, ['space-meta-gap']);
});

test('reads a horizontal stack', () => {
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [at('A', 10, 10, 20, 20), at('B', 38, 10, 20, 20), at('Row', 10, 10, 48, 20)],
  }, { tokens: TOKENS });
  const stack = byName(tree).Row.stack;
  assert.equal(stack.axis, 'horizontal');
  assert.equal(stack.gap, 8);
  assert.deepEqual(stack.gapTokens, ['space-element-gap']);
});

test('reports every gap when the gaps are not uniform, and no single gap', () => {
  // A space-between row has no one gap. Averaging would invent a number the
  // layout does not have.
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [
      at('A', 0, 0, 20, 10), at('B', 40, 0, 20, 10), at('C', 100, 0, 20, 10),
      at('Row', 0, 0, 120, 10),
    ],
  });
  const stack = byName(tree).Row.stack;
  assert.equal(stack.gap, null);
  assert.deepEqual(stack.gaps, [20, 40]);
});

test('leaves stack null for a part with fewer than two children', () => {
  const tree = buildLayoutTree({ size: SIZE, elements: [at('Only', 10, 10, 20, 20), at('Box', 0, 0, 40, 40)] });
  assert.equal(byName(tree).Box.stack, null);
  assert.equal(byName(tree).Only.stack, null);
});

// ── Alignment ──

test('names cross-axis alignment', () => {
  const build = (a, b, parent) => byName(buildLayoutTree({
    size: SIZE, elements: [at('A', ...a), at('B', ...b), at('P', ...parent)],
  })).P.align;
  // vertical stack, children share their leading (x) edge
  assert.equal(build([0, 0, 40, 10], [0, 20, 60, 10], [0, 0, 60, 30]), 'leading');
  // …share their trailing edge
  assert.equal(build([20, 0, 40, 10], [0, 20, 60, 10], [0, 0, 60, 30]), 'trailing');
  // …share a centre
  assert.equal(build([10, 0, 40, 10], [0, 20, 60, 10], [0, 0, 60, 30]), 'center');
  // …each fill the parent's cross axis
  assert.equal(build([0, 0, 60, 10], [0, 20, 60, 10], [0, 0, 60, 30]), 'stretch');
});

// ── Repeated siblings ──

test('collapses a run of numbered siblings and keeps their size range', () => {
  // Bottom-anchored bars of rising height, like C-030's mask.
  const bars = [];
  for (let i = 0; i < 5; i += 1) {
    const h = 10 + i * 10;
    bars.push(at(`Bar ${i + 1}`, i * 5, 50 - h, 3, h));
  }
  const tree = buildLayoutTree({ size: SIZE, elements: [...bars, at('Row', 0, 0, 23, 50)] });
  const [node] = byName(tree).Row.children;
  assert.equal(node.name, 'Bar ×5');
  assert.equal(node.repeat, 5);
  assert.equal(node.members.length, 5);
  assert.deepEqual(node.box, { x: 0, y: 40, w: 3, h: 10 });  // the first member's own box
  assert.deepEqual(node.range, { w: [3, 3], h: [10, 50] });  // …and what the run spans
});

test('leaves two numbered siblings alone — a pair is not a run', () => {
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [at('Tab 1', 0, 0, 10, 10), at('Tab 2', 20, 0, 10, 10), at('Row', 0, 0, 30, 10)],
  });
  assert.deepEqual(byName(tree).Row.children.map((c) => c.name), ['Tab 1', 'Tab 2']);
});

test('does not collapse siblings whose names merely share a prefix', () => {
  const tree = buildLayoutTree({
    size: SIZE,
    elements: [
      at('Hour label 12 AM', 0, 0, 10, 10), at('Hour label 3 AM', 20, 0, 10, 10),
      at('Hour label 6 AM', 40, 0, 10, 10), at('Ring', 0, 0, 50, 10),
    ],
  });
  assert.equal(byName(tree).Ring.children.length, 3);
});

// ── Degenerate input ──

test('returns an empty tree for a missing or empty element map', () => {
  assert.equal(buildLayoutTree(null).root, null);
  assert.equal(buildLayoutTree({ size: SIZE, elements: [] }).root, null);
});

// ── The real maps on disk ──

/** Newest `.elements.json` for a ui2 comparison, or null if never captured. */
function realMap(id) {
  const dir = path.join(here, '..', 'fixtures', 'compare', '_shots', `ui2-${id}`, 'design', 'iphone');
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.elements.json'));
  if (!files.length) return null;
  const newest = files
    .map((f) => ({ f, t: fs.statSync(path.join(dir, f)).mtimeMs }))
    .sort((a, b) => b.t - a.t)[0].f;
  return JSON.parse(fs.readFileSync(path.join(dir, newest), 'utf-8'));
}

test('C-029: the root measures the footprint C-029 §2 states', { skip: !realMap('c-029') && 'not captured' }, () => {
  const tree = buildLayoutTree(realMap('c-029'), { tokens: TOKENS });
  assert.equal(tree.root.name, 'RadialDayClock');
  assert.equal(tree.root.box.w, 357);
  assert.equal(tree.root.box.h, 326);
  // The call site pads 16 and then fills the device width, so the component is
  // centred horizontally in the 440pt render and pinned 16 from the top.
  assert.equal(tree.root.inset.top, 16);
  // Centred, but measured at device pixels — 41.7, not the ideal 41.5. The
  // panel reports what the harness measured, so the tolerance lives here.
  assert.ok(Math.abs(tree.root.inset.left - (440 - 357) / 2) < 0.5, `left inset ${tree.root.inset.left}`);
});

test("C-030: the bar mask's pitch resolves to space-chip-gap", { skip: !realMap('c-030') && 'not captured' }, () => {
  const tree = buildLayoutTree(realMap('c-030'), { tokens: TOKENS });
  const stack = byName(tree)['Bar mask'].stack;
  assert.equal(stack.axis, 'horizontal');
  assert.equal(stack.gap, 2);
  assert.deepEqual(stack.gapTokens, ['space-chip-gap']);
});

test('C-030: the space-between tick row reports every gap, not an average', { skip: !realMap('c-030') && 'not captured' }, () => {
  const stack = byName(buildLayoutTree(realMap("c-030")))["Tick row"].stack;
  assert.equal(stack.gap, null);
  assert.equal(stack.gaps.length, 3);
});

// A part positioned with `.offset` keeps its PRE-OFFSET layout bounds, so the
// harness records where it was laid out, not where it was drawn. C-029 positions
// all eight hour labels and its tick dots that way and they all land on one rect
// at the ring's centre. The panel reports the map faithfully; the fix is in the
// view, not here. Asserted so the day C-029 is rebuilt with layout-based
// positioning, this test fails and says so.
test('C-029: known limitation — offset-positioned parts share one rect', { skip: !realMap('c-029') && 'not captured' }, () => {
  const n = byName(buildLayoutTree(realMap('c-029')));
  assert.deepEqual(n['Hour label 12 AM'].box, n['Hour label 6 PM'].box);
});

test('C-029: the seven identical arcs collapse to one node', { skip: !realMap('c-029') && 'not captured' }, () => {
  const tree = buildLayoutTree(realMap('c-029'));
  assert.ok(walk(tree.root).some((n) => n.name === 'Arc ×7' && n.repeat === 7));
});

test('C-030: the 88 bars collapse to one node', { skip: !realMap('c-030') && 'not captured' }, () => {
  const tree = buildLayoutTree(realMap('c-030'));
  const bars = walk(tree.root).find((n) => n.repeat === 88);
  assert.ok(bars, 'expected a collapsed run of 88');
  assert.equal(bars.name, 'Bar ×88');
  assert.equal(bars.range.h[0], 3);     // §2's dot stub
  assert.equal(bars.range.h[1], 100);   // …and the window max
});

test('every real map resolves to exactly one root', () => {
  for (const id of ['c-026', 'c-029', 'c-030', 'c-034', 'c-040']) {
    const map = realMap(id);
    if (!map) continue;
    const tree = buildLayoutTree(map);
    assert.ok(tree.root, `${id}: no root`);
    assert.equal(tree.nodes.length, map.elements.length, `${id}: lost or invented a part`);
    assert.equal(new Set(tree.nodes.map((n) => n.key)).size, map.elements.length, `${id}: duplicate keys`);
  }
});

test('a collapsed run keeps its members reachable as children', () => {
  // Collapsing is a default view, not a truncation: opening `Bar ×88` has to
  // reach one bar, and opening `MetaPair ×4` has to reach that pair's own Value
  // and Unit.
  const bars = [];
  for (let i = 0; i < 4; i += 1) bars.push(at(`Bar ${i + 1}`, i * 5, 0, 3, 10));
  const tree = buildLayoutTree({ size: SIZE, elements: [...bars, at('Row', 0, 0, 18, 10)] });
  const [run] = byName(tree).Row.children;
  assert.equal(run.repeat, 4);
  assert.deepEqual(run.children.map((c) => c.name), ['Bar 1', 'Bar 2', 'Bar 3', 'Bar 4']);
  assert.equal(run.children, run.members);
});
