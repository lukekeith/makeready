// The app's confirmation dialog. Native window.confirm/alert/prompt are NOT
// used anywhere in this UI: they can't be styled, they block the whole browser
// (including any capture stream running behind them), and they give a
// destructive action the same neutral "OK" as a harmless one.
//
// Usage — render it alongside the thing it guards and drive it with state:
//
//   const [pending, setPending] = useState(null);
//   <ConfirmDialog
//     open={!!pending}
//     title="Delete this capture?"
//     confirmLabel="Delete capture"
//     destructive
//     onConfirm={() => { doIt(pending); setPending(null); }}
//     onCancel={() => setPending(null)}
//   >
//     …body…
//   </ConfirmDialog>
import React, { useEffect, useRef } from 'react';

export default function ConfirmDialog({
  open,
  title,
  children,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  destructive = false,
  busy = false,
  onConfirm,
  onCancel,
}) {
  const cancelRef = useRef(null);
  const panelRef = useRef(null);

  // Escape cancels. Bound while open only, so it never competes with the
  // page's own Escape handling (comment mode, the recapture menu).
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape') { e.stopPropagation(); onCancel?.(); }
    };
    document.addEventListener('keydown', onKey, true);
    return () => document.removeEventListener('keydown', onKey, true);
  }, [open, onCancel]);

  // Focus lands on CANCEL, not on the destructive button: a stray Enter from
  // whatever the user was doing before the dialog opened must not delete
  // anything.
  useEffect(() => { if (open) cancelRef.current?.focus(); }, [open]);

  if (!open) return null;

  return (
    <div
      className="cmp-confirm"
      // A click on the scrim cancels; a click that started inside the panel
      // must not, hence the target check rather than a bare onClick.
      onMouseDown={(e) => { if (!panelRef.current?.contains(e.target)) onCancel?.(); }}
    >
      <div className="cmp-confirm__panel" ref={panelRef} role="alertdialog" aria-modal="true" aria-label={title}>
        <div className="cmp-confirm__title">{title}</div>
        {children && <div className="cmp-confirm__body">{children}</div>}
        <div className="cmp-confirm__actions">
          <button className="btn" ref={cancelRef} onClick={onCancel} disabled={busy}>{cancelLabel}</button>
          <button
            className={`btn ${destructive ? 'btn--danger' : 'btn--primary'}`}
            onClick={onConfirm}
            disabled={busy}
          >
            {busy ? 'Working…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
