// UI 2.0 Layout tab — the geometry derivation behind the panel.
//
// A 2.0 render is a simulator screenshot: there is no DOM to inspect and no CSS
// to read back. What there IS is the element map the capture harness writes
// beside the PNG (UI2Element.swift → CaptureRunner) — every part the view named
// with `.ui2Element`, and the rect it occupied during the SwiftUI layout pass,
// as fractions of the render. Multiplied by the render's own size (in POINTS,
// straight off `GeometryProxy`) those fractions come back as exact point
// values: C-029's root measures 357 × 326, which is the footprint its §2 states.
//
// This module turns that flat list into the tree the panel shows, and derives
// what can be derived honestly from rects alone:
//
//   • nesting        — from containment, tie-broken by the harness's own order
//   • INSET          — each edge's distance from the parent's edge
//   • stack + gap    — when children line up on one axis
//   • alignment      — when they share a cross-axis edge or centre
//
// What it deliberately does NOT derive:
//
//   • padding vs margin. A gap between two rects does not say which side owns
//     it. The panel says INSET and means it.
//   • border width. A rect carries no stroke.
//   • anything "close to" a token. A value either equals a token or it does
//     not; a near-miss is the drift this whole lane exists to reveal, so 15.7
//     stays 15.7 rather than becoming "≈ space-page-margin".
//
// Pure: `{ size, elements }` in, a tree out. Tested in capture/test/ui2-layout.test.mjs.

/** Point values are compared, not just displayed, so they round once here and
 *  everything downstream trusts the result. 0.1pt is finer than the harness's
 *  own precision at any device scale. */
// Geometry is derived from UNROUNDED point values and rounded only for display:
// rounding first pushed a flush edge out by up to 0.05 on each side, which was
// enough to drop C-029's `Caption row` out of the stack that contains it.
// 0.1pt is a third of a device pixel at 3× — finer than the harness can measure,
// coarser than the float noise a flush edge accumulates.
const EPS = 0.1;
const round1 = (n) => Math.round(n * 10) / 10;
const near = (a, b) => Math.abs(a - b) <= EPS;

/** value → every token name that equals it. `space-page-margin` and
 *  `space-card-padding` are both 16, and hiding one of them would be a lie
 *  about which token a 16 in the render came from. */
function tokenIndex(tokens) {
  const index = new Map();
  for (const t of tokens ?? []) {
    const v = round1(Number(t.value));
    if (!Number.isFinite(v)) continue;
    if (!index.has(v)) index.set(v, []);
    index.get(v).push(t.name);
  }
  return index;
}

/** Contains, with a tolerance — a child laid out flush to its parent's edge
 *  differs by float noise, not by geometry. */
const contains = (outer, inner) => (
  inner.x >= outer.x - EPS
  && inner.y >= outer.y - EPS
  && inner.x + inner.w <= outer.x + outer.w + EPS
  && inner.y + inner.h <= outer.y + outer.h + EPS
);

const sameRect = (a, b) => (
  near(a.x, b.x) && near(a.y, b.y) && near(a.w, b.w) && near(a.h, b.h)
);

/**
 * The parent of `i` is the smallest part that STRICTLY contains it and was
 * emitted after it.
 *
 * Two halves, both load-bearing:
 *
 * "emitted after" — `transformAnchorPreference` appends a view's own anchor to
 * whatever its subtree already produced, so an ancestor always follows every one
 * of its descendants. Without it, a part could be nested under something it
 * merely overlaps.
 *
 * "strictly" — a part with a rect IDENTICAL to another's is treated as its
 * SIBLING, never its child. Rects alone cannot tell the two cases apart: C-040's
 * `Leading` slot has its single `GlyphButton`'s rect exactly (a real
 * parent/child), while C-029's `Base ring` and seven `Arc` parts all have the
 * ring box exactly (seven siblings in a ZStack). Reading equal rects as nesting
 * turned the second case into an eight-deep ladder of one-child nodes. Reading
 * them as siblings costs one level of depth in the first case and is never
 * wrong — the panel shows both parts at their true, identical box, which is what
 * the geometry actually says.
 */
function parentIndex(rects, i) {
  let best = -1;
  for (let j = i + 1; j < rects.length; j += 1) {
    if (!contains(rects[j], rects[i]) || sameRect(rects[j], rects[i])) continue;
    if (best === -1 || rects[j].w * rects[j].h < rects[best].w * rects[best].h) best = j;
  }
  return best;
}

/** Which axis the children are stacked on, if any: they must be disjoint and
 *  ordered along it, and overlap on the other. */
function stackAxis(children) {
  if (children.length < 2) return null;
  const test = (start, size, crossStart, crossSize) => {
    const sorted = [...children].sort((a, b) => a.pt[start] - b.pt[start]);
    for (let i = 1; i < sorted.length; i += 1) {
      const prev = sorted[i - 1].pt;
      const cur = sorted[i].pt;
      if (cur[start] < prev[start] + prev[size] - EPS) return null;          // overlap along the axis
      if (cur[crossStart] + cur[crossSize] <= prev[crossStart] + EPS) return null;  // …and none across it
      if (prev[crossStart] + prev[crossSize] <= cur[crossStart] + EPS) return null;
    }
    return sorted;
  };
  const vertical = test('y', 'h', 'x', 'w');
  if (vertical) return { axis: 'vertical', sorted: vertical, start: 'y', size: 'h' };
  const horizontal = test('x', 'w', 'y', 'h');
  if (horizontal) return { axis: 'horizontal', sorted: horizontal, start: 'x', size: 'w' };
  return null;
}

function stackOf(children, tokens) {
  const axis = stackAxis(children);
  if (!axis) return null;
  const gaps = [];
  for (let i = 1; i < axis.sorted.length; i += 1) {
    const prev = axis.sorted[i - 1].pt;
    gaps.push(round1(axis.sorted[i].pt[axis.start] - (prev[axis.start] + prev[axis.size])));
  }
  const uniform = gaps.every((g) => near(g, gaps[0]));
  const gap = uniform ? gaps[0] : null;
  return {
    axis: axis.axis,
    gap,
    gaps,
    gapTokens: gap === null ? [] : (tokens.get(gap) ?? []),
    order: axis.sorted,
  };
}

/** Cross-axis alignment, most specific first: everything filling the parent is
 *  `stretch` even though it also shares both edges. */
function alignOf(parent, children, axis) {
  if (!axis || children.length < 2) return null;
  const [start, size] = axis === 'vertical' ? ['x', 'w'] : ['y', 'h'];
  const p = parent.pt;
  const all = (fn) => children.every((c) => fn(c.pt));
  if (all((b) => near(b[start], p[start]) && near(b[size], p[size]))) return 'stretch';
  const first = children[0].pt;
  if (all((b) => near(b[start] + b[size] / 2, first[start] + first[size] / 2))) return 'center';
  if (all((b) => near(b[start], first[start]))) return 'leading';
  if (all((b) => near(b[start] + b[size], first[start] + first[size]))) return 'trailing';
  return null;
}

const RUN = /^(.*\S)\s+(\d+)$/;

/**
 * Fold a run of numbered siblings into one node.
 *
 * C-030 names 88 bars and C-029 seven arcs; listed one per line they bury
 * everything else in the panel. A run needs three or more consecutive integers
 * under one prefix — a pair is not a run, and two parts that merely share a
 * prefix ("Hour label 12 AM", "Hour label 3 AM") are individually meaningful
 * and stay listed.
 *
 * Members keep their own boxes; the group reports the first member's box plus
 * the range the run spans, because C-030's bars share a width and differ in
 * height and only saying "3 × 3–100" is true of all 88.
 */
function collapseRuns(children) {
  const out = [];
  let i = 0;
  while (i < children.length) {
    const m = RUN.exec(children[i].name);
    if (!m) { out.push(children[i]); i += 1; continue; }
    const prefix = m[1];
    let end = i + 1;
    let expect = Number(m[2]) + 1;
    while (end < children.length) {
      const next = RUN.exec(children[end].name);
      if (!next || next[1] !== prefix || Number(next[2]) !== expect) break;
      end += 1;
      expect += 1;
    }
    const run = children.slice(i, end);
    if (run.length < 3) { out.push(children[i]); i += 1; continue; }
    const span = (key) => [
      round1(Math.min(...run.map((c) => c.pt[key]))),
      round1(Math.max(...run.map((c) => c.pt[key]))),
    ];
    out.push({
      key: `run:${prefix}:${run[0].key}`,
      name: `${prefix} ×${run.length}`,
      repeat: run.length,
      members: run,
      rect: run[0].rect,
      pt: run[0].pt,
      box: run[0].box,
      range: { w: span('w'), h: span('h') },
      inset: null,
      insetTokens: null,
      stack: null,
      align: null,
      // The members stay reachable, so a run can be opened to reach one bar or
      // one MetaPair's own parts. The panel starts every run closed.
      children: run,
    });
    i = end;
  }
  return out;
}

/**
 * Build the panel's tree from one element map.
 *
 * @param {{size:{w:number,h:number}, elements:Array<{name:string,x:number,y:number,w:number,h:number}>}|null} map
 * @param {{tokens?: Array<{name:string,value:number}>}} [opts] spacing tokens, for naming exact matches
 * @returns {{size:{w:number,h:number}|null, root:object|null, nodes:object[]}}
 *   `nodes` is every REAL part, flat, one per input element — collapsed run
 *   nodes are synthetic and appear only inside `root`'s children.
 */
export function buildLayoutTree(map, opts = {}) {
  const size = map?.size ?? null;
  const raw = Array.isArray(map?.elements) ? map.elements : [];
  if (!size || !raw.length) return { size, root: null, nodes: [] };

  const tokens = tokenIndex(opts.tokens);
  const nodes = raw.map((e, i) => ({
    key: `${i}:${e.name}`,
    name: e.name,
    rect: { x: e.x, y: e.y, w: e.w, h: e.h },          // fractions — what the highlight overlay wants
    pt: {                                               // points, unrounded — what every rule below reads
      x: e.x * size.w, y: e.y * size.h, w: e.w * size.w, h: e.h * size.h,
    },
    box: {                                              // points, rounded — what the panel shows
      x: round1(e.x * size.w),
      y: round1(e.y * size.h),
      w: round1(e.w * size.w),
      h: round1(e.h * size.h),
    },
    repeat: null,
    members: null,
    range: null,
    inset: null,
    insetTokens: null,
    stack: null,
    align: null,
    children: [],
  }));

  // Nesting. A part with no containing successor is a root; the harness emits
  // the component's own root last, so in practice there is exactly one.
  // Containment is decided on the POINT boxes, not the fractions: EPS is a
  // point tolerance, and 0.05 of a fraction would swallow whole parts.
  const boxes = nodes.map((n) => n.pt);
  const roots = [];
  const parentOf = new Map();
  for (let i = 0; i < nodes.length; i += 1) {
    const p = parentIndex(boxes, i);
    if (p === -1) roots.push(nodes[i]);
    else {
      nodes[p].children.push(nodes[i]);
      // Recorded here rather than looked up later: the loop below REPLACES a
      // node's `children` with its collapsed form, so a member of a run is no
      // longer reachable from its parent's child list by the time that member
      // needs to know who its parent is.
      parentOf.set(nodes[i], nodes[p]);
    }
  }
  const root = roots[0] ?? null;

  // The root's own inset is measured against the whole render frame, which
  // makes it the ViewRegistry call site's padding — the one number in the panel
  // that describes the harness rather than the component.
  const frame = { pt: { x: 0, y: 0, w: size.w, h: size.h } };

  for (const node of nodes) {
    const parent = parentOf.get(node) ?? (node === root ? frame : null);
    if (parent) {
      node.inset = {
        top: round1(node.pt.y - parent.pt.y),
        right: round1((parent.pt.x + parent.pt.w) - (node.pt.x + node.pt.w)),
        bottom: round1((parent.pt.y + parent.pt.h) - (node.pt.y + node.pt.h)),
        left: round1(node.pt.x - parent.pt.x),
      };
      node.insetTokens = Object.fromEntries(
        Object.entries(node.inset).map(([k, v]) => [k, tokens.get(v) ?? []]),
      );
    }
    node.stack = stackOf(node.children, tokens);
    node.align = alignOf(node, node.children, node.stack?.axis ?? null);
    // Display order follows the stack, so a column reads top-to-bottom rather
    // than in the harness's depth-first emission order.
    if (node.stack) node.children = [...node.stack.order];
    node.children = collapseRuns(node.children);
  }

  return { size: { w: round1(size.w), h: round1(size.h) }, root, nodes };
}

/** Flatten the rendered tree — run nodes included — in display order. */
export function flattenTree(root, depth = 0, out = []) {
  if (!root) return out;
  out.push({ node: root, depth });
  for (const child of root.children ?? []) flattenTree(child, depth + 1, out);
  return out;
}
