// The Delete dialog — compose `/ui2-component-delete <C-###> "<reason>"`.
//
// Like Merge, this is an `action` Prompt entry rather than a copyable string, for two reasons
// that are specific to delete:
//
//   1. The command REQUIRES a reason. It is written verbatim into the registry row and is the
//      only thing a future reader has to explain why the row is struck. A one-click copy would
//      hand over `/ui2-component-delete C-054` and the reason would be improvised later, or
//      not at all.
//   2. Delete has no keeper. Merge moves a design somewhere; this ends one. The dialog is
//      where that distinction gets stated before the command is copied.
//
// It deliberately does NOT try to decide whether the row is deletable — the command's own §1
// gate does that against the whole repo, which the browser cannot see. What it can do is show
// the consumers it already knows about, so an obviously-live row is caught here rather than
// three phases into a run.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import CopyCode from '../../components/CopyCode.jsx';

const dotKind = (row) => (row.specced ? (row.hasSnapshot ? 'specced' : 'contract') : (row.hasSnapshot ? 'artwork' : 'registry'));

/** Quote only when needed, and never produce a broken shell token. */
function quote(reason) {
  const r = reason.trim().replace(/"/g, "'");
  if (!r) return '';
  return /\s/.test(r) ? ` "${r}"` : ` ${r}`;
}

export default function Ui2DeleteDialog({ open, detail, onClose }) {
  const [reason, setReason] = useState('');
  const panelRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => { if (open) setReason(''); }, [open, detail?.id]);
  useEffect(() => { if (open) inputRef.current?.focus(); }, [open]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); onClose?.(); } };
    document.addEventListener('keydown', onKey, true);
    return () => document.removeEventListener('keydown', onKey, true);
  }, [open, onClose]);

  // What the browser already knows renders this row. Not authoritative — the command greps the
  // repo — but enough to stop an obviously-consumed row before a run starts.
  const consumers = useMemo(() => {
    const c = detail?.registry?.consumedBy ?? detail?.consumedBy ?? '';
    const t = String(c).trim();
    return t && !/^\*?\(?none/i.test(t) ? t : '';
  }, [detail]);

  if (!open) return null;

  const ready = Boolean(detail?.id && reason.trim());
  const command = ready
    ? `/ui2-component-delete ${detail.id}${quote(reason)}`
    : '/ui2-component-delete — give a reason';

  return (
    <div
      className="cmp-merge cmp-del"
      onMouseDown={(e) => { if (!panelRef.current?.contains(e.target)) onClose?.(); }}
    >
      <div className="cmp-merge__panel cmp-del__panel" ref={panelRef} role="dialog" aria-modal="true" aria-label="Delete component">
        <div className="cmp-merge__role cmp-merge__role--duplicate cmp-del__head">
          <span className="cmp-merge__role-title">Delete</span>
          <span className="cmp-merge__role-desc">
            Retires this row from the registry. Its ID, contract, notes, snapshots and capture
            history are all kept — nothing absorbs its design, so the command refuses while
            anything still renders it.
          </span>
        </div>

        <div className="cmp-del__body">
          {detail ? (
            <div className="cmp-ui2__row cmp-ui2__row--active cmp-merge__current-row" title={detail.name}>
              <span className="cmp-ui2__id">{detail.id}</span>
              <span className="cmp-ui2__name">{detail.name}</span>
              <span className={`cmp-ui2__dot cmp-ui2__dot--${dotKind({ specced: detail.specced, hasSnapshot: detail.hasSnapshot })}`} />
            </div>
          ) : <div className="cmp-cb-col__empty">no component</div>}

          {detail && (
            <div className="cmp-merge__current-meta">
              {detail.stateCount ?? 0} designed state(s)
              {detail.hasSnapshot ? ' · frozen snapshot' : ' · no snapshot'}
              {detail.built ? ' · built — fixture, view and registry case are removed' : ' · not built'}
            </div>
          )}

          {consumers && (
            <div className="cmp-del__warn">
              <strong>Consumed by:</strong> {consumers}
              <div className="cmp-del__warn-note">
                Delete refuses while a row is rendered. If another row should take this design
                over, that is <code>/ui2-component-merge</code>, not this.
              </div>
            </div>
          )}

          <label className="cmp-del__label" htmlFor="cmp-del-reason">
            Reason <span className="cmp-del__req">— written verbatim into the registry row</span>
          </label>
          <input
            id="cmp-del-reason"
            ref={inputRef}
            className="cmp-del__input"
            type="text"
            value={reason}
            placeholder="e.g. orphaned by the study-program-home re-spec"
            onChange={(e) => setReason(e.target.value)}
          />
        </div>

        <div className="cmp-merge__foot">
          <CopyCode value={command} className={`cmp-merge__cmd${ready ? '' : ' cmp-merge__cmd--disabled'}`}>
            {command}
          </CopyCode>
        </div>
      </div>
    </div>
  );
}
