// Generic file-tree view (component-browser D12) — implements the design of
// ~/www/fai-cd's TreeView primitive in this app's React 18 + cmp-* CSS idiom:
// flat DOM (one <li role="treeitem"> per VISIBLE row in a single <ul role="tree">),
// roving tabindex with the WAI-ARIA tree keyboard pattern, and — in select mode —
// a chevron/row click split so selecting a folder row doesn't collapse it.
// Fully controlled data + selection; expansion state is internal (a set of
// COLLAPSED ids, so newly-appearing nodes default open at shallow depths).
import React, { useEffect, useMemo, useRef, useState } from 'react';

function collectDefaultCollapsed(nodes, maxDepth, depth = 0, out = new Set()) {
  for (const n of nodes) {
    if (n.children) {
      if (depth >= maxDepth) out.add(n.id);
      collectDefaultCollapsed(n.children, maxDepth, depth + 1, out);
    }
  }
  return out;
}

export default function TreeView({
  nodes,
  selectedId = null,
  onSelect,
  defaultExpandedDepth = 1,
  indent = 16,
  renderLabel, // (node) => ReactNode — the host draws badges/actions
  'aria-label': ariaLabel,
}) {
  const [collapsed, setCollapsed] = useState(() => collectDefaultCollapsed(nodes, defaultExpandedDepth));
  const [focusId, setFocusId] = useState(null);
  const listRef = useRef(null);

  // Flatten to the visible rows (depth-first, skipping collapsed subtrees).
  const rows = useMemo(() => {
    const out = [];
    const visit = (list, depth, parentId) => {
      for (const n of list) {
        out.push({ node: n, depth, parentId });
        if (n.children && !collapsed.has(n.id)) visit(n.children, depth + 1, n.id);
      }
    };
    visit(nodes, 0, null);
    return out;
  }, [nodes, collapsed]);

  const idx = (id) => rows.findIndex((r) => r.node.id === id);
  const focusRow = (i) => {
    const row = rows[Math.max(0, Math.min(rows.length - 1, i))];
    if (!row) return;
    setFocusId(row.node.id);
    listRef.current?.querySelector(`[data-tree-id="${CSS.escape(row.node.id)}"]`)?.focus();
  };

  const toggle = (id) => setCollapsed((prev) => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });

  const onKeyDown = (e, row) => {
    const i = idx(row.node.id);
    const isFolder = !!row.node.children;
    const isOpen = isFolder && !collapsed.has(row.node.id);
    switch (e.key) {
      case 'ArrowDown': e.preventDefault(); focusRow(i + 1); break;
      case 'ArrowUp': e.preventDefault(); focusRow(i - 1); break;
      case 'ArrowRight':
        e.preventDefault();
        if (isFolder && !isOpen) toggle(row.node.id);
        else if (isFolder) focusRow(i + 1);
        break;
      case 'ArrowLeft':
        e.preventDefault();
        if (isFolder && isOpen) toggle(row.node.id);
        else if (row.parentId) focusRow(idx(row.parentId));
        break;
      case 'Enter':
        e.preventDefault();
        if (!isFolder && onSelect) onSelect(row.node);
        else if (isFolder) toggle(row.node.id);
        break;
      case ' ':
        e.preventDefault();
        if (isFolder) toggle(row.node.id);
        else if (onSelect) onSelect(row.node);
        break;
      default: break;
    }
  };

  // Keep focus valid when the visible set shrinks (e.g. the filter prunes it).
  useEffect(() => {
    if (focusId && !rows.some((r) => r.node.id === focusId)) setFocusId(null);
  }, [rows, focusId]);

  const tabbableId = focusId ?? selectedId ?? rows[0]?.node.id;

  return (
    <ul className="cmp-tree" role="tree" aria-label={ariaLabel} ref={listRef}>
      {rows.map((row) => {
        const { node, depth } = row;
        const isFolder = !!node.children;
        const isOpen = isFolder && !collapsed.has(node.id);
        const selected = node.id === selectedId;
        return (
          <li
            key={node.id}
            role="treeitem"
            aria-level={depth + 1}
            aria-expanded={isFolder ? isOpen : undefined}
            aria-selected={onSelect ? selected : undefined}
            data-tree-id={node.id}
            tabIndex={node.id === tabbableId ? 0 : -1}
            className={`cmp-tree__row${selected ? ' cmp-tree__row--selected' : ''}${node.muted ? ' cmp-tree__row--muted' : ''}`}
            style={{ paddingLeft: 8 + depth * indent }}
            onKeyDown={(e) => onKeyDown(e, row)}
            onFocus={() => setFocusId(node.id)}
            onClick={() => {
              if (isFolder) { toggle(node.id); return; }
              onSelect?.(node);
            }}
          >
            {isFolder ? (
              <button
                type="button"
                className={`cmp-tree__chev${isOpen ? ' cmp-tree__chev--open' : ''}`}
                aria-hidden="true"
                tabIndex={-1}
                onClick={(e) => { e.stopPropagation(); toggle(node.id); }}
              >
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
              </button>
            ) : (
              <span className="cmp-tree__chev cmp-tree__chev--leaf" aria-hidden="true" />
            )}
            {renderLabel ? renderLabel(node, { isFolder, isOpen }) : <span className="cmp-tree__label">{node.label ?? node.id}</span>}
          </li>
        );
      })}
    </ul>
  );
}
