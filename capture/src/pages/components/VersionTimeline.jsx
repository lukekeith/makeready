// Version timeline — newest first; selecting an old version shows that render
// and accepts comments on it (07 §3.3, D4/R8). selectedId null = current.
//
// `onDelete` is optional: pass it and each DELETABLE version grows a hover
// delete control. A version is deletable when it carries a built render
// (`hasBuiltRender`) — the frozen-snapshot versions are re-minted on the next
// read, so offering to delete one would promise something that doesn't stick.
import React from 'react';

const fmt = (iso) => {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return iso; }
};

export default function VersionTimeline({ versions, selectedId, onSelect, shotsVersion, onDelete = null }) {
  if (!versions.length) return null;
  return (
    <div className="cmp-cb-timeline">
      {versions.map((v, i) => {
        const isCurrent = i === 0;
        const selected = selectedId === null ? isCurrent : selectedId === v.versionId;
        const deletable = !!onDelete && v.hasBuiltRender;
        return (
          // A wrapper, not a parent button: the delete control has to be a
          // SIBLING of the item, since a <button> inside a <button> is invalid
          // HTML and the nested one would not reliably receive its own click.
          <div className="cmp-cb-timeline__slot" key={v.versionId}>
            <button
              className={`cmp-cb-timeline__item${selected ? ' cmp-cb-timeline__item--selected' : ''}`}
              onClick={() => onSelect(isCurrent ? null : v.versionId)}
              title={`${fmt(v.capturedAt)}${v.gitSha ? ` · ${v.gitSha.slice(0, 8)}${v.gitDirty ? '-dirty' : ''}` : ''}`}
            >
              {v.shot
                ? <img className="cmp-cb-timeline__thumb" src={`${v.shot}?v=${shotsVersion}`} alt="" loading="lazy" />
                : <span className="cmp-cb-timeline__thumb cmp-cb-timeline__thumb--empty" />}
              <span className="cmp-cb-timeline__meta">
                {isCurrent && <span className="cmp-cb-timeline__current">current</span>}
                <span className="cmp-cb-timeline__date">{fmt(v.capturedAt)}</span>
                {v.unresolvedComments > 0 && <span className="cmp-open-badge">{v.unresolvedComments}</span>}
              </span>
            </button>
            {deletable && (
              <button
                type="button"
                className="cmp-cb-timeline__del"
                aria-label={`Delete the capture from ${fmt(v.capturedAt)}`}
                title="Delete this capture"
                onClick={() => onDelete(v)}
              >
                <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
                  <path d="M6 6l12 12M18 6L6 18" />
                </svg>
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}
