// Column 4, UI 2.0 era — the built render's measured layout.
//
// The 1.0 side could inspect a live Vue twin's computed style. A 2.0 render is
// a simulator screenshot, so its geometry comes from the element map the
// capture harness writes beside the PNG: every part the view named with
// `.ui2Element`, and the rect it occupied during the SwiftUI layout pass.
//
// So this panel reports what was BUILT, in points, not what the contract
// specifies — §2's prose stays in the Contract tab. Where a measured value
// equals a SPACING token it is named; where it does not, the bare number
// stands, because a near-miss is exactly the drift this lane exists to reveal.
// Radius tokens are not offered: nothing here derives a corner radius, so a
// match would only ever be a false label on a distance (see server.mjs).
//
// Derivation lives in src/lib/ui2-layout.js (pure, unit-tested); this file is
// only the rendering of it.
import React, { useEffect, useMemo, useState } from 'react';
import { buildLayoutTree, flattenTree } from '../../lib/ui2-layout.js';

const pt = (n) => `${n}`;
const AXIS_GLYPH = { vertical: '↕', horizontal: '↔' };

/** A measured value plus every token it equals. */
function Value({ n, tokens }) {
  return (
    <span className="cmp-lay__val">
      {pt(n)}
      {tokens?.length ? <span className="cmp-lay__tok">{tokens.join(' · ')}</span> : null}
    </span>
  );
}

function Row({ label, children }) {
  if (children === null || children === undefined) return null;
  return (
    <div className="cmp-lay__row">
      <div className="cmp-lay__row-label">{label}</div>
      <div className="cmp-lay__row-value">{children}</div>
    </div>
  );
}

/**
 * Webflow's spacing diagram, minus the half it cannot honestly draw.
 *
 * Webflow nests margin around padding around the content box because CSS tells
 * it which is which. A rect inside a rect does not: the space between a part
 * and its parent could be the parent's padding, the part's margin, a Spacer, or
 * a frame alignment. So there is one ring and it is labelled INSET.
 */
function InsetDiagram({ node }) {
  const inset = node.inset;
  if (!inset) return null;
  const W = 268;
  const H = 116;
  // The ring's thickness is proportional to the real inset but always thick
  // enough to hold a number, so a 0pt inset still reads as an edge.
  const span = Math.max(node.box.w + inset.left + inset.right, 1);
  const vSpan = Math.max(node.box.h + inset.top + inset.bottom, 1);
  const band = (v, total, max) => Math.min(max, Math.max(22, (v / total) * max * 2.4));
  const l = band(inset.left, span, 56);
  const r = band(inset.right, span, 56);
  const t = band(inset.top, vSpan, 30);
  const b = band(inset.bottom, vSpan, 30);
  return (
    <svg className="cmp-lay__diagram" viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Inset from parent">
      <rect className="cmp-lay__diagram-outer" x="0.5" y="0.5" width={W - 1} height={H - 1} rx="4" />
      <text className="cmp-lay__diagram-tag" x="7" y="11">INSET</text>
      <rect
        className="cmp-lay__diagram-inner"
        x={l} y={t} width={Math.max(W - l - r, 24)} height={Math.max(H - t - b, 20)} rx="3"
      />
      <text className="cmp-lay__diagram-n" x={W / 2} y={t / 2 + 4} textAnchor="middle">{pt(inset.top)}</text>
      <text className="cmp-lay__diagram-n" x={W / 2} y={H - b / 2 + 4} textAnchor="middle">{pt(inset.bottom)}</text>
      <text className="cmp-lay__diagram-n" x={l / 2} y={H / 2 + 4} textAnchor="middle">{pt(inset.left)}</text>
      <text className="cmp-lay__diagram-n" x={W - r / 2} y={H / 2 + 4} textAnchor="middle">{pt(inset.right)}</text>
      <text className="cmp-lay__diagram-size" x={W / 2} y={H / 2 + 4} textAnchor="middle">
        {pt(node.box.w)} × {pt(node.box.h)}
      </text>
    </svg>
  );
}

/** How many parts a node actually holds — a collapsed run counts its members. */
const childCount = (node) => (node.children ?? [])
  .reduce((n, c) => n + (c.repeat ?? 1), 0);

function Detail({ node }) {
  if (!node) return <div className="cmp-lay__hint">Select a part above.</div>;
  const s = node.stack;
  return (
    <div className="cmp-lay__detail">
      <div className="cmp-lay__detail-name">{node.name}</div>
      <InsetDiagram node={node} />
      <Row label="Size">
        {node.range && (node.range.w[0] !== node.range.w[1] || node.range.h[0] !== node.range.h[1])
          ? <>W {node.range.w[0] === node.range.w[1] ? pt(node.box.w) : `${node.range.w[0]}–${node.range.w[1]}`}
            {'   '}H {node.range.h[0] === node.range.h[1] ? pt(node.box.h) : `${node.range.h[0]}–${node.range.h[1]}`}</>
          : <>W {pt(node.box.w)}{'   '}H {pt(node.box.h)}</>}
      </Row>
      <Row label="Position">x {pt(node.box.x)}{'   '}y {pt(node.box.y)}</Row>
      {node.inset && (
        <Row label="Inset">
          <div className="cmp-lay__edges">
            {['top', 'right', 'bottom', 'left'].map((edge) => (
              <div key={edge} className="cmp-lay__edge">
                <span className="cmp-lay__edge-name">{edge}</span>
                <Value n={node.inset[edge]} tokens={node.insetTokens?.[edge]} />
              </div>
            ))}
          </div>
        </Row>
      )}
      {s && (
        <Row label="Stack">
          <div className="cmp-lay__stack">
            <span className="cmp-lay__axis">{AXIS_GLYPH[s.axis]} {s.axis}</span>
            {s.gap === null
              // A space-between row has no one gap. Showing an average would
              // invent a number the layout does not have.
              ? <span className="cmp-lay__gaps">gaps {s.gaps.join(' · ')}</span>
              : <>gap <Value n={s.gap} tokens={s.gapTokens} /></>}
          </div>
        </Row>
      )}
      <Row label="Align">{node.align}</Row>
      {/* Real parts, not tree rows: a collapsed run is one row and 88 parts, and
          "Children 1" for C-030's bar mask was simply wrong. */}
      <Row label="Children">{childCount(node) ? String(childCount(node)) : null}</Row>
      {node.repeat ? <Row label="Repeat">{node.repeat} siblings, collapsed into one row</Row> : null}
    </div>
  );
}

/** Runs start closed — the point of collapsing C-030's 88 bars is not to see
 *  them all again the moment the panel opens. */
const closedRuns = (root) => new Set(
  flattenTree(root).filter(({ node }) => node.repeat).map(({ node }) => node.key),
);

export default function Ui2LayoutTab({ detail, elements, platform, onInspect }) {
  const [selectedKey, setSelectedKey] = useState(null);
  const [hoverKey, setHoverKey] = useState(null);
  const [collapsed, setCollapsed] = useState(() => new Set());

  const tree = useMemo(
    () => buildLayoutTree(elements, { tokens: detail?.spacingTokens ?? [] }),
    [elements, detail?.spacingTokens],
  );
  const rows = useMemo(() => flattenTree(tree.root), [tree]);

  // A different component, state or capture is a different tree; keeping the
  // old selection would point at a part that no longer exists.
  useEffect(() => {
    setSelectedKey(null);
    setHoverKey(null);
    setCollapsed(closedRuns(tree.root));
  }, [tree]);
  // Nothing in this panel should leave a box stuck on the render behind it.
  useEffect(() => () => onInspect?.(null), [onInspect]);

  const visible = useMemo(() => {
    const out = [];
    let hideDeeperThan = Infinity;
    for (const row of rows) {
      if (row.depth > hideDeeperThan) continue;
      hideDeeperThan = Infinity;
      out.push(row);
      if (collapsed.has(row.node.key)) hideDeeperThan = row.depth;
    }
    return out;
  }, [rows, collapsed]);

  const selected = rows.find((r) => r.node.key === selectedKey)?.node ?? null;
  const hovered = rows.find((r) => r.node.key === hoverKey)?.node ?? null;

  // The box follows the SELECTION and is temporarily overridden by hover, the
  // way a design tool behaves: picking a part and then reading its numbers must
  // not lose the highlight the moment the cursor leaves the tree.
  useEffect(() => {
    onInspect?.((hovered ?? selected)?.rect ?? null);
  }, [hovered, selected, onInspect]);

  if (!detail?.built) {
    return (
      <div className="cmp-cb-col__empty">
        This row is specced but not built, so there is no render to measure.
        <div className="cmp-lay__cmd">/ui2-component-build {detail?.id}</div>
      </div>
    );
  }
  if (platform !== 'iphone') {
    return (
      <div className="cmp-cb-col__empty">
        The Figma snapshot is one flat image — only the built render carries geometry.
        Switch the render to <strong>iPhone</strong> to measure it.
      </div>
    );
  }
  if (!tree.root) {
    return (
      <div className="cmp-cb-col__empty">
        This capture predates the element map, or the view names no parts with
        <code> .ui2Element</code>. Re-capture to produce one:
        <div className="cmp-lay__cmd">node capture/runners/ui2/capture.mjs {detail.id} &apos;*&apos;</div>
      </div>
    );
  }

  return (
    <div className="cmp-lay">
      <div className="cmp-lay__frame">
        Render {pt(tree.size.w)} × {pt(tree.size.h)} · measured points
      </div>
      <div className="cmp-lay__tree" onMouseLeave={() => setHoverKey(null)}>
        {visible.map(({ node, depth }) => {
          const hasChildren = node.children.length > 0;
          const isCollapsed = collapsed.has(node.key);
          return (
            <div
              key={node.key}
              className={`cmp-lay__node${node.key === selectedKey ? ' cmp-lay__node--sel' : ''}`}
              style={{ paddingLeft: `${6 + depth * 11}px` }}
              onMouseEnter={() => setHoverKey(node.key)}
              onClick={() => setSelectedKey(node.key)}
            >
              <button
                type="button"
                className={`cmp-lay__twist${hasChildren ? '' : ' cmp-lay__twist--leaf'}`}
                aria-label={isCollapsed ? 'Expand' : 'Collapse'}
                onClick={(e) => {
                  e.stopPropagation();
                  if (!hasChildren) return;
                  setCollapsed((prev) => {
                    const next = new Set(prev);
                    if (next.has(node.key)) next.delete(node.key); else next.add(node.key);
                    return next;
                  });
                }}
              >
                {hasChildren ? (isCollapsed ? '▸' : '▾') : ''}
              </button>
              <span className="cmp-lay__node-name">{node.name}</span>
              <span className="cmp-lay__node-size">{pt(node.box.w)} × {pt(node.box.h)}</span>
            </div>
          );
        })}
      </div>
      <Detail node={selected} />
    </div>
  );
}
