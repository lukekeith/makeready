// Extracted VERBATIM from pages/compare/CompareDetail.jsx (component-browser
// phase 2.1). The web-iframe hit-test plumbing stays in the HOST (CompareDetail)
// — this layer only renders pins/drafts/threads (suite CR6/D14).
import React, { useEffect, useRef, useState } from 'react';
import Thread from './Thread.jsx';

// Pins + draft composer + open thread, living INSIDE the zoom/pan canvas so they
// track the image. `inv` (1/scale) counter-scales pins so they stay constant size.
/** Label height plus its gap, in SCREEN px. The flip rule is "is there room above
 *  the box", which is a PIXEL question — the same box at 40% zoom and at 200% zoom
 *  has the same `y` fraction and very different room above it.
 *
 *  The layer measures itself with a ResizeObserver, whose contentRect is the
 *  LAYOUT box — canvas-local units, before the zoom transform — so the comparison
 *  happens in local units and the constant is converted with `inv`. It used to be
 *  compared raw, which was right only while the label scaled with the canvas; now
 *  that the label is a fixed 24 screen px it occupies `24 * inv` local units. */
const LABEL_CLEARANCE = 24;

export default function CommentLayer({
  platform, viewport, comments, numberOf, commentMode, draft, inv,
  onPlace, onSubmitDraft, onCancelDraft, selectedId, onSelect,
  canEdit, onReply, onResolve, onDelete, hoverBox, inspectBox = null,
  // The component-targeting box on a 2.0 screen (suite 07 §4.5). `{ rect, label,
  // insideFlip }` or null. The host forces it null in comment mode, so this layer
  // never has to know about the two modes.
  componentBox = null,
  // The SELECTED component's boxes — every instance of it on this screen. Unlike
  // `componentBox` these are not pointer-driven: they persist for as long as the
  // selection does, which is what makes a selection readable on the render after
  // the pointer has moved away (and a component used twice visibly used twice).
  componentSelectedBoxes = null,
  // Preview boxes: the component under the pointer in the Screen tab's chip list.
  // Same geometry as a selection, drawn in the hover weight — it is a "where is
  // this?" answer, not a commitment.
  componentPreviewBoxes = null,
}) {
  const [draftVal, setDraftVal] = useState('');
  useEffect(() => { setDraftVal(''); }, [draft?.x, draft?.y, draft?.platform]);

  // The layer is inset:0 over the rendered image, so its own height IS the render's
  // height on screen — which is what decides whether a label fits above its box.
  const layerRef = useRef(null);
  const [layerH, setLayerH] = useState(0);
  useEffect(() => {
    const el = layerRef.current;
    if (!el || typeof ResizeObserver === 'undefined') return undefined;
    const ro = new ResizeObserver(([entry]) => setLayerH(entry.contentRect.height));
    ro.observe(el);
    setLayerH(el.clientHeight);
    return () => ro.disconnect();
  }, []);

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

  /**
   * A target box's inline style: its rect as percentages of the render, plus
   * `--inv` — the same 1/scale the pins counter-scale with.
   *
   * The box's RECT has to live inside the zoomed canvas (it tracks the image),
   * but its stroke and its label must not: a 2px border inside `scale(3)` paints
   * 6 device px, and the label's type grew with it. Everything that should be a
   * CONSTANT number of screen pixels is written `calc(<px> * var(--inv))` in the
   * stylesheet, so local units × the canvas scale come back to exactly that many
   * device pixels at every zoom.
   */
  const boxStyle = (rect) => ({
    left: `${rect.x * 100}%`, top: `${rect.y * 100}%`,
    width: `${rect.w * 100}%`, height: `${rect.h * 100}%`,
    '--inv': inv,
  });

  return (
    <div ref={layerRef} className={`cmp-commentlayer${commentMode ? ' cmp-commentlayer--placing' : ''}`} onClick={handleClick}>
      {/* The Layout tab's box. Unlike `hoverBox` it is NOT gated on comment
          mode — reading a part's geometry is not placing a comment — and it
          sits under the comment boxes so a thread's target still wins. */}
      {inspectBox && (
        <div
          className="cmp-target-box cmp-target-box--inspect"
          style={boxStyle(inspectBox)}
          aria-hidden="true"
        />
      )}
      {/* Component targeting: drawn with the inspect box, UNDER the comment boxes,
          so an open thread's target still wins the eye. Both the box and its label
          are pointer-transparent — the hit test reads the render's own pointer
          events, and a box that ate them would flicker at its own edges. */}
      {/* Persistent selection, drawn UNDER the hover box: hovering another
          component must still read as the thing under the pointer. */}
      {componentSelectedBoxes?.map((b, i) => (
        <div
          key={`${b.rect.x}:${b.rect.y}:${i}`}
          className="cmp-target-box cmp-target-box--component cmp-target-box--selected"
          style={boxStyle(b.rect)}
          aria-hidden="true"
        >
          {/* Only the FIRST instance carries the label: a component used four
              times in a row would otherwise stack four overlapping labels and
              none of them would be readable. */}
          {i === 0 && (
            <span className={`cmp-target-box__label${b.rect.y * layerH < LABEL_CLEARANCE * inv ? ' cmp-target-box__label--inside' : ''}`}>
              {b.label}
            </span>
          )}
        </div>
      ))}
      {/* `tone` lets a caller mark a preview as something other than "this
          component": the screen pane uses it to pick out ONE schema's instances
          in green, against the purple that already means "the component". */}
      {componentPreviewBoxes?.map((b, i) => (
        <div
          key={`preview:${b.rect.x}:${b.rect.y}:${i}`}
          className={`cmp-target-box cmp-target-box--component${b.tone ? ` cmp-target-box--${b.tone}` : ''}`}
          style={boxStyle(b.rect)}
          aria-hidden="true"
        >
          {i === 0 && (
            <span className={`cmp-target-box__label${b.rect.y * layerH < LABEL_CLEARANCE * inv ? ' cmp-target-box__label--inside' : ''}`}>
              {b.label}
            </span>
          )}
        </div>
      ))}
      {componentBox && (
        <div
          className="cmp-target-box cmp-target-box--component"
          style={boxStyle(componentBox.rect)}
          aria-hidden="true"
        >
          <span className={`cmp-target-box__label${componentBox.rect.y * layerH < LABEL_CLEARANCE * inv ? ' cmp-target-box__label--inside' : ''}`}>
            {componentBox.label}
          </span>
        </div>
      )}
      {commentMode && !draft && !selectedId && hoverBox && (
        <div
          className="cmp-target-box cmp-target-box--hover"
          style={boxStyle(hoverBox)}
          aria-hidden="true"
        />
      )}
      {(selectedBox || draftBox) && (() => {
        const r = draftBox || selectedBox;
        return <div className="cmp-target-box" style={boxStyle(r)} aria-hidden="true" />;
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

