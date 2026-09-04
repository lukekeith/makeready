// Version timeline — newest first; selecting an old version shows that render
// and accepts comments on it (07 §3.3, D4/R8). selectedId null = current.
import React from 'react';

const fmt = (iso) => {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return iso; }
};

export default function VersionTimeline({ versions, selectedId, onSelect, shotsVersion }) {
  if (!versions.length) return null;
  return (
    <div className="cmp-cb-timeline">
      {versions.map((v, i) => {
        const isCurrent = i === 0;
        const selected = selectedId === null ? isCurrent : selectedId === v.versionId;
        return (
          <button
            key={v.versionId}
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
        );
      })}
    </div>
  );
}
