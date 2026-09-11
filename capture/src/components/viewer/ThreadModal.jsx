// One comment thread, opened from the comments panel, read as a chat.
//
// The panel transcript truncates every message so the column stays skimmable; this is
// where the full text lives. Same shape as the panel — scrolling log above, one composer
// pinned at the bottom — so opening a thread does not change how replying works, only how
// much you can see.
import React, { useEffect, useRef, useState } from 'react';
import ConfirmDialog from '../ConfirmDialog.jsx';

function formatTime(iso) {
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
    });
  } catch { return iso; }
}

export default function ThreadModal({ comment, canEdit, onReply, onResolve, onDelete, onClose }) {
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  // Never window.confirm — see components/ConfirmDialog.jsx.
  const [confirmDelete, setConfirmDelete] = useState(false);
  const logRef = useRef(null);
  const inputRef = useRef(null);

  // Esc closes — but not while the delete confirmation owns the screen, or Esc would
  // dismiss both at once and leave the user unsure which they cancelled.
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape' && !confirmDelete) onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose, confirmDelete]);

  // Open at the newest message and stay there as replies land — a chat log reads from the
  // bottom, and the newest reply is the reason the thread was opened.
  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [comment?.messages?.length]);

  useEffect(() => { if (canEdit) inputRef.current?.focus({ preventScroll: true }); }, [canEdit]);

  if (!comment) return null;

  const submit = async () => {
    if (!reply.trim() || busy) return;
    setBusy(true);
    try { await onReply(comment.id, reply.trim()); setReply(''); } finally { setBusy(false); }
  };

  return (
    <div className="cmp-threadmodal" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="cmp-threadmodal__panel" role="dialog" aria-modal="true" aria-label="Comment thread">
        <div className="cmp-threadmodal__head">
          <div className="cmp-threadmodal__title">
            {comment.targetLabel
              ? <span className="cmp-target-chip" title={comment.targetSelector}>◎ {comment.targetLabel}</span>
              : <span className="cmp-threadmodal__scope">{comment.x == null ? 'On this state' : 'Pinned'}</span>}
            <span className="cmp-threadmodal__vp">{comment.variantName}</span>
          </div>
          <div className="cmp-threadmodal__actions">
            {canEdit && (
              <>
                <button
                  className={`btn btn--mini cmp-resolve${comment.resolved ? ' cmp-resolve--done' : ''}`}
                  onClick={() => onResolve(comment)}
                  title={comment.resolved ? 'Reopen' : 'Mark resolved'}
                >{comment.resolved ? 'Resolved' : 'Resolve'}</button>
                <button className="cmp-thread__del" title="Delete comment" aria-label="Delete comment"
                  onClick={() => setConfirmDelete(true)}>
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <polyline points="3 6 5 6 21 6" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /><path d="M10 11v6M14 11v6" /><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                  </svg>
                </button>
              </>
            )}
            <button className="cmp-pop__close" onClick={onClose} title="Close" aria-label="Close">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
                <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
              </svg>
            </button>
          </div>
        </div>

        <div className="cmp-threadmodal__log" ref={logRef}>
          {(comment.messages ?? []).map((m) => (
            <div className={`cmp-chatmsg cmp-chatmsg--${m.source}`} key={m.id}>
              <div className="cmp-chatmsg__meta">
                <span className={`cmp-msg__src cmp-msg__src--${m.source}`}>{m.source === 'claude' ? 'Claude' : 'You'}</span>
                <span className="cmp-msg__time">{formatTime(m.createdAt)}</span>
              </div>
              <div className="cmp-chatmsg__text">{m.text}</div>
            </div>
          ))}
        </div>

        {canEdit && (
          <div className="cmp-chatcomposer">
            <textarea
              ref={inputRef}
              className="cmp-chatcomposer__input"
              placeholder="Reply…"
              value={reply}
              rows={1}
              onChange={(e) => setReply(e.target.value)}
              // Enter sends, Shift+Enter is a newline — the chat convention. Cmd/Ctrl+Enter
              // also sends, so the habit from the old thread box still works.
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); submit(); }
              }}
            />
            <button className="btn btn--primary cmp-chatcomposer__send" onClick={submit} disabled={busy || !reply.trim()}>
              {busy ? '…' : 'Send'}
            </button>
          </div>
        )}
      </div>

      <ConfirmDialog
        open={confirmDelete}
        title="Delete this comment?"
        confirmLabel="Delete comment"
        destructive
        onConfirm={() => { setConfirmDelete(false); onDelete(comment.id); onClose(); }}
        onCancel={() => setConfirmDelete(false)}
      >
        The comment and every reply on it are removed permanently. This cannot be undone.
      </ConfirmDialog>
    </div>
  );
}
