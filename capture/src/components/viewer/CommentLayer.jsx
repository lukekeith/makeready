// Extracted VERBATIM from pages/compare/CompareDetail.jsx (component-browser
// phase 2.1). The web-iframe hit-test plumbing stays in the HOST (CompareDetail)
// — this layer only renders pins/drafts/threads (suite CR6/D14).
import React, { useEffect, useState } from 'react';
import Thread from './Thread.jsx';

// Pins + draft composer + open thread, living INSIDE the zoom/pan canvas so they
// track the image. `inv` (1/scale) counter-scales pins so they stay constant size.
export default function CommentLayer({
  platform, viewport, comments, numberOf, commentMode, draft, inv,
  onPlace, onSubmitDraft, onCancelDraft, selectedId, onSelect,
  canEdit, onReply, onResolve, onDelete, hoverBox, inspectBox = null,
}) {
  const [draftVal, setDraftVal] = useState('');
  useEffect(() => { setDraftVal(''); }, [draft?.x, draft?.y, draft?.platform]);

  const handleClick = (e) => {
    if (!commentMode) return;
    const rect = e.currentTarget.getBoundingClientRect();
    onPlace(platform, viewport, (e.clientX - rect.left) / rect.width, (e.clientY - rect.top) / rect.height);
  };
  // Resolved comments stay in the right column but drop their preview pins —
  // except while selected from the column, so the thread can still be viewed
  // (and reopened) in place.
  // `x == null` is an UNANCHORED message — typed into the comments panel's chat input
  // rather than dropped on the render, so it has no position to draw a pin at. It still
  // lives in the panel transcript; it just never appears here.
  const here = comments.filter(
    (c) => c.x != null && c.platform === platform && c.viewport === viewport
      && (!c.resolved || c.id === selectedId),
  );
  const showDraft = draft && draft.platform === platform && draft.viewport === viewport;

  const selectedBox = here.find((c) => c.id === selectedId && c.targetMeta?.rect)?.targetMeta?.rect;
  const draftBox = showDraft && draft.target?.rect ? draft.target.rect : null;

  return (
    <div className={`cmp-commentlayer${commentMode ? ' cmp-commentlayer--placing' : ''}`} onClick={handleClick}>
      {/* The Layout tab's box. Unlike `hoverBox` it is NOT gated on comment
          mode — reading a part's geometry is not placing a comment — and it
          sits under the comment boxes so a thread's target still wins. */}
      {inspectBox && (
        <div
          className="cmp-target-box cmp-target-box--inspect"
          style={{ left: `${inspectBox.x * 100}%`, top: `${inspectBox.y * 100}%`, width: `${inspectBox.w * 100}%`, height: `${inspectBox.h * 100}%` }}
          aria-hidden="true"
        />
      )}
      {commentMode && !draft && !selectedId && hoverBox && (
        <div
          className="cmp-target-box cmp-target-box--hover"
          style={{ left: `${hoverBox.x * 100}%`, top: `${hoverBox.y * 100}%`, width: `${hoverBox.w * 100}%`, height: `${hoverBox.h * 100}%` }}
          aria-hidden="true"
        />
      )}
      {(selectedBox || draftBox) && (() => {
        const r = draftBox || selectedBox;
        return <div className="cmp-target-box" style={{ left: `${r.x * 100}%`, top: `${r.y * 100}%`, width: `${r.w * 100}%`, height: `${r.h * 100}%` }} aria-hidden="true" />;
      })()}
      {here.map((c) => {
        const side = c.x > 0.55 ? 'left' : 'right';
        const selected = c.id === selectedId;
        return (
          <div className="cmp-pin" key={c.id} style={{ left: `${c.x * 100}%`, top: `${c.y * 100}%`, transform: `scale(${inv})`, transformOrigin: '0 0' }}>
            <button className={`cmp-pin__dot${c.resolved ? ' cmp-pin__dot--resolved' : ''}${selected ? ' cmp-pin__dot--selected' : ''}`}
              onClick={(e) => { e.stopPropagation(); onSelect(selected ? null : c.id); }}
              onMouseDown={(e) => e.stopPropagation()}
              title={c.messages?.[0]?.text ?? 'Comment'}>
              {c.resolved ? '✓' : numberOf.get(c.id)}
            </button>
            {selected && (
              <div className={`cmp-pop cmp-pop--${side}`} onClick={(e) => e.stopPropagation()} onMouseDown={(e) => e.stopPropagation()}>
                <div className="cmp-pop__head">
                  <span className="cmp-pop__title">Comment {numberOf.get(c.id)}</span>
                  {c.targetLabel && <span className="cmp-target-chip" title={c.targetSelector}>◎ {c.targetLabel}</span>}
                  <button className="cmp-pop__close" onClick={() => onSelect(null)} title="Close" aria-label="Close">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
                      <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
                    </svg>
                  </button>
                </div>
                <Thread comment={c} canEdit={canEdit} autoFocusReply onReply={onReply} onResolve={onResolve} onDelete={onDelete} />
              </div>
            )}
          </div>
        );
      })}
      {showDraft && (
        <div className="cmp-pin" style={{ left: `${draft.x * 100}%`, top: `${draft.y * 100}%`, transform: `scale(${inv})`, transformOrigin: '0 0' }}>
          <span className="cmp-pin__dot cmp-pin__dot--draft">•</span>
          <div className={`cmp-pop cmp-pop--${draft.x > 0.55 ? 'left' : 'right'}`} onClick={(e) => e.stopPropagation()} onMouseDown={(e) => e.stopPropagation()}>
            {draft.target !== undefined && (
              <div className="cmp-target-chip cmp-target-chip--draft" title={draft.target?.selector}>
                {draft.target ? `◎ ${draft.target.label}` : '◎ resolving element…'}
              </div>
            )}
            <textarea className="cmp-thread__input" autoFocus placeholder="Add a comment…" value={draftVal}
              onChange={(e) => setDraftVal(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Escape') onCancelDraft(); if ((e.metaKey || e.ctrlKey) && e.key === 'Enter' && draftVal.trim()) onSubmitDraft(draftVal.trim()); }} />
            <div className="cmp-thread__actions">
              <button className="btn btn--primary btn--mini" disabled={!draftVal.trim()} onClick={() => onSubmitDraft(draftVal.trim())}>Submit</button>
              <button className="btn btn--mini" onClick={onCancelDraft}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

