// Column 1 — the filesystem tree of iphone/MakeReady/Components/ with wiring +
// comment badges and per-row command copy (component-browser 07 §3.1, D11/D13).
import React, { useMemo, useState } from 'react';
import TreeView from '../../components/tree/TreeView.jsx';
import TreeSearchInput from './TreeSearchInput.jsx';

// D11: case-insensitive substring after stripping every non-alphanumeric char
// from both query and candidate relative path ("cardev" matches "Card/CardEvent").
const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');

function filterTree(nodes, q) {
  if (!q) return nodes;
  const out = [];
  for (const n of nodes) {
    if (n.type === 'folder') {
      const children = filterTree(n.children, q);
      if (children.length) out.push({ ...n, children });
    } else if (norm(n.path).includes(q)) {
      out.push(n);
    }
  }
  return out;
}

async function copyToClipboard(text) {
  try { await navigator.clipboard.writeText(text); }
  catch {
    const ta = document.createElement('textarea');
    ta.value = text; document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } catch { /* ignore */ }
    document.body.removeChild(ta);
  }
}

export default function ComponentTree({ tree, selectedPath, onSelect }) {
  const [query, setQuery] = useState('');
  const [copiedPath, setCopiedPath] = useState(null);

  const filtered = useMemo(() => filterTree(tree ?? [], norm(query.trim())), [tree, query]);

  // TreeView nodes: id = fs path; folders carry children; leaves carry the payload.
  const toNodes = (list) => list.map((n) => (
    n.type === 'folder'
      ? { id: n.path, label: n.name, children: toNodes(n.children), raw: n }
      : { id: n.path, label: n.name, muted: !n.isWired, raw: n }
  ));
  const nodes = useMemo(() => toNodes(filtered), [filtered]);

  const copyCommand = async (e, raw) => {
    e.stopPropagation();
    const cmd = raw.type === 'folder' ? `/component-resolve ${raw.path}/**` : `/component-resolve ${raw.path}`;
    await copyToClipboard(cmd);
    setCopiedPath(raw.path);
    setTimeout(() => setCopiedPath((p) => (p === raw.path ? null : p)), 1400);
  };

  const renderLabel = (node) => {
    const raw = node.raw;
    const isFolder = raw.type === 'folder';
    return (
      <span className="cmp-tree__labelwrap">
        <span className={`cmp-tree__label${!isFolder && !raw.isWired ? ' cmp-tree__label--unwired' : ''}`}>{node.label}</span>
        {!isFolder && raw.collision && <span className="cmp-tree__badge cmp-tree__badge--error" title="Basename collision — rename to disambiguate">!</span>}
        {!isFolder && !raw.isWired && !raw.collision && <span className="cmp-tree__badge cmp-tree__badge--unwired" title="Not capturable yet — missing fixture/adapter/registry wiring">–</span>}
        {!isFolder && raw.unresolvedComments > 0 && <span className="cmp-open-badge" title={`${raw.unresolvedComments} unresolved comment(s)`}>{raw.unresolvedComments}</span>}
        <button
          type="button"
          className="cmp-tree__copy"
          title={copiedPath === raw.path ? 'Copied!' : (isFolder ? `Copy /component-resolve ${raw.path}/**` : `Copy /component-resolve ${raw.path}`)}
          aria-label="Copy resolve command"
          onClick={(e) => copyCommand(e, raw)}
        >
          {copiedPath === raw.path ? '✓' : (
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <polyline points="4 17 10 11 4 5" /><line x1="12" y1="19" x2="20" y2="19" />
            </svg>
          )}
        </button>
      </span>
    );
  };

  return (
    <div className="cmp-cb-col cmp-cb-col--tree">
      <TreeSearchInput value={query} onChange={setQuery} />
      {!tree && <div className="cmp-cb-col__empty">loading…</div>}
      {tree && nodes.length === 0 && <div className="cmp-cb-col__empty">No components match “{query}”.</div>}
      {nodes.length > 0 && (
        <div className="cmp-cb-col__scroll">
          <TreeView
            nodes={nodes}
            selectedId={selectedPath}
            onSelect={(node) => onSelect(node.raw)}
            defaultExpandedDepth={query ? Infinity : 1}
            aria-label="iPhone components"
          />
        </div>
      )}
    </div>
  );
}
