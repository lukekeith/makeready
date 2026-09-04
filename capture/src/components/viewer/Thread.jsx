// Extracted VERBATIM from pages/compare/CompareDetail.jsx (component-browser
// phase 2.1) so /compare and /components share one comment-thread UI.
import React, { useEffect, useRef, useState } from 'react';

function formatTime(iso) {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
  catch { return iso; }
}
function SourceTag({ source }) {
  return <span className={`cmp-msg__src cmp-msg__src--${source}`}>{source === 'claude' ? 'Claude' : 'You'}</span>;
}

export function Thread({ comment, canEdit, autoFocusReply, onReply, onResolve, onDelete }) {
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const replyRef = useRef(null);
  useEffect(() => { if (autoFocusReply && canEdit) replyRef.current?.focus({ preventScroll: true }); }, [autoFocusReply, canEdit]);
  const submit = async () => {
    if (!reply.trim()) return;
    setBusy(true);
    try { await onReply(comment.id, reply.trim()); setReply(''); } finally { setBusy(false); }
  };
  return (
    <>
      <div className="cmp-thread__msgs">
        {(comment.messages ?? []).map((m) => (
          <div className="cmp-msg" key={m.id}>
            <div className="cmp-msg__meta"><SourceTag source={m.source} /><span className="cmp-msg__time">{formatTime(m.createdAt)}</span></div>
            <div className="cmp-msg__text">{m.text}</div>
          </div>
        ))}
      </div>
      {canEdit && (
        <div className="cmp-thread__reply">
          <textarea ref={replyRef} className="cmp-thread__input" placeholder="Reply…" value={reply}
            onChange={(e) => setReply(e.target.value)}
            onKeyDown={(e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') submit(); }} />
          <div className="cmp-thread__actions">
            <button className={`btn btn--mini cmp-resolve${comment.resolved ? ' cmp-resolve--done' : ''}`}
              onClick={() => onResolve(comment)} title={comment.resolved ? 'Reopen' : 'Mark resolved'}>
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3z" />
                <path d="M7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3" />
              </svg>
              {comment.resolved ? 'Resolved' : 'Resolve'}
            </button>
            <button className="btn btn--mini cmp-resolve" onClick={submit} disabled={busy || !reply.trim()}>Reply</button>
            <button className="cmp-thread__del" title="Delete comment" aria-label="Delete comment"
              onClick={() => { if (window.confirm('Delete this comment?')) onDelete(comment.id); }}>
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <polyline points="3 6 5 6 21 6" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /><path d="M10 11v6M14 11v6" /><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
              </svg>
            </button>
          </div>
        </div>
      )}
    </>
  );
}


export default Thread;
