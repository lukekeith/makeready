// Comments panel — ONE chat per variant, not a stack of separate threads.
//
// The scrolling log is every comment on this state in the order it happened; the composer
// is pinned at the bottom and always usable. A comment is a turn in that conversation, so
// each entry shows its opening message plus a one-line trace of the replies, truncated —
// the full thread opens in ThreadModal on click (07 §3.5, D5/D14).
//
// Two kinds of turn share the log:
//   • PINNED   — dropped on the render, carries x/y and often an element target. Selecting
//                it highlights its pin, which is why clicking still calls `jump`.
//   • UNANCHORED — typed into the composer below, x/y NULL. About the state as a whole;
//                never drawn on the render.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import ThreadModal from '../../components/viewer/ThreadModal.jsx';

const fmt = (iso) => {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return iso; }
};
const fmtShort = (iso) => {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
  catch { return iso; }
};

/** First paragraph, collapsed to one flowing line — enough to recognise a message by. */
function preview(text = '') {
  return text.trim().split(/\n\s*\n/)[0].replace(/\s+/g, ' ');
}

export default function CommentsTab({ commentApi, activeVersionId, currentVersionId, onSelectVersion }) {
  const [openId, setOpenId] = useState(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const logRef = useRef(null);

  const comments = useMemo(
    () => [...(commentApi.comments ?? [])].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1)),
    [commentApi.comments],
  );
  const unresolved = comments.filter((c) => !c.resolved).length;

  // A chat reads from the bottom: land on the newest turn, and follow new ones in.
  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [comments.length]);

  // Keep the modal's copy live — a reply or resolve re-fetches the array, and a stale
  // object would leave the modal showing the thread as it was before the reply landed.
  const openComment = openId ? comments.find((c) => c.id === openId) ?? null : null;
  useEffect(() => { if (openId && !openComment) setOpenId(null); }, [openId, openComment]);

  const jump = (c) => {
    if (c.versionId && c.versionId !== activeVersionId && onSelectVersion) {
      onSelectVersion(c.versionId === currentVersionId ? null : c.versionId);
    }
    commentApi.setSelectedCommentId(c.id);
  };

  const openThread = (c) => { jump(c); setOpenId(c.id); };

  const send = async () => {
    const text = draft.trim();
    if (!text || sending || !commentApi.postMessage) return;
    setSending(true);
    try { await commentApi.postMessage(text); setDraft(''); }
    finally { setSending(false); }
  };

  const renderTurn = (c) => {
    const [first, ...rest] = c.messages ?? [];
    const last = rest[rest.length - 1];
    const selected = c.id === commentApi.selectedCommentId;
    const otherVersion = c.versionId && c.versionId !== activeVersionId;
    return (
      <div
        key={c.id}
        className={`cmp-turn${selected ? ' cmp-turn--selected' : ''}${c.resolved ? ' cmp-turn--resolved' : ''}`}
        role="button"
        tabIndex={0}
        onClick={() => openThread(c)}
        onKeyDown={(e) => {
          if (e.target !== e.currentTarget) return;
          if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openThread(c); }
        }}
      >
        <div className="cmp-turn__head">
          {c.resolved && <span className="cmp-turn__done" title="Resolved">✓</span>}
          {c.targetLabel
            ? <span className="cmp-target-chip" title={c.targetSelector}>◎ {c.targetLabel}</span>
            : c.x != null && <span className="cmp-turn__scope">◉ pinned</span>}
          <span className="cmp-turn__time">{fmtShort(c.createdAt)}</span>
          {otherVersion && (
            <span className="cmp-cb-citem__version" title="Made on a different version — opening it shows that render">
              {c.versionId === currentVersionId ? 'current version' : `version of ${fmt(c.version?.capturedAt)}`}
            </span>
          )}
        </div>

        {first && <div className="cmp-turn__msg">{preview(first.text)}</div>}

        {/* The replies collapse to one line: who answered last, and the opening of what
            they said. Reading a 1,500-character Claude reply is what the modal is for. */}
        {last && (
          <div className="cmp-turn__reply">
            <span className={`cmp-msg__src cmp-msg__src--${last.source}`}>{last.source === 'claude' ? 'Claude' : 'You'}</span>
            <span className="cmp-turn__replytext">{preview(last.text)}</span>
          </div>
        )}
        {rest.length > 1 && <div className="cmp-turn__more">{rest.length} replies</div>}
      </div>
    );
  };

  return (
    <div className="cmp-cb-comments">
      <div className="cmp-comments__head">
        <span className="cmp-comments__title">Comments</span>
        {unresolved > 0 && <span className="cmp-comments__open">{unresolved} open</span>}
      </div>
      {commentApi.commentMode && <div className="cmp-comments__hint">Click the render to drop a pin · Esc to exit</div>}

      <div className="cmp-chatlog" ref={logRef}>
        {comments.length === 0 && (
          <div className="cmp-comments__empty">
            No comments yet.{commentApi.canComment
              ? <> Type below to leave one on this state, or press <kbd>c</kbd> to pin one on the render.</>
              : null}
          </div>
        )}
        {comments.map(renderTurn)}
      </div>

      {commentApi.canComment && commentApi.postMessage && (
        <div className="cmp-chatcomposer">
          <textarea
            className="cmp-chatcomposer__input"
            placeholder="Message this state…"
            value={draft}
            rows={1}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
            }}
          />
          <button className="btn btn--primary cmp-chatcomposer__send" onClick={send} disabled={sending || !draft.trim()}>
            {sending ? '…' : 'Send'}
          </button>
        </div>
      )}

      <ThreadModal
        comment={openComment}
        canEdit={commentApi.canComment}
        onReply={commentApi.onReply}
        onResolve={commentApi.onResolve}
        onDelete={commentApi.onDelete}
        onClose={() => setOpenId(null)}
      />
    </div>
  );
}
