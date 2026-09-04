// Comments tab — this-version pins first, then other versions' (labeled with
// their capture date); resolved render dimmed with a ✓ (07 §3.5, D5/D14).
import React from 'react';
import Thread from '../../components/viewer/Thread.jsx';

const fmt = (iso) => {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return iso; }
};

export default function CommentsTab({ commentApi, activeVersionId, currentVersionId, onSelectVersion }) {
  const comments = [...(commentApi.comments ?? [])].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1));
  const here = comments.filter((c) => c.versionId === activeVersionId);
  const elsewhere = comments.filter((c) => c.versionId !== activeVersionId);
  const unresolved = comments.filter((c) => !c.resolved).length;

  const jump = (c) => {
    if (c.versionId && c.versionId !== activeVersionId && onSelectVersion) {
      onSelectVersion(c.versionId === currentVersionId ? null : c.versionId);
    }
    commentApi.setSelectedCommentId(c.id);
  };

  const renderItem = (c, { labelVersion } = {}) => (
    <div
      key={c.id}
      className={`cmp-citem${c.id === commentApi.selectedCommentId ? ' cmp-citem--selected' : ''}${c.resolved ? ' cmp-citem--resolved' : ''}`}
      role="button"
      tabIndex={0}
      onClick={() => jump(c)}
      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); jump(c); } }}
    >
      <div className="cmp-citem__head">
        <span className="cmp-citem__num">{c.resolved ? '✓' : '•'}</span>
        <span className="cmp-citem__vp">{c.viewport}</span>
        {labelVersion && (
          <span className="cmp-cb-citem__version" title="Made on a different version — click to view that render">
            {c.versionId ? (c.versionId === currentVersionId ? 'current version' : `version of ${fmt(c.version?.capturedAt)}`) : 'unanchored'}
          </span>
        )}
      </div>
      <div className="cmp-citem__thread">
        <Thread comment={c} canEdit={commentApi.canComment} onReply={commentApi.onReply} onResolve={commentApi.onResolve} onDelete={commentApi.onDelete} />
      </div>
    </div>
  );

  return (
    <div className="cmp-cb-comments">
      <div className="cmp-comments__head">
        <span className="cmp-comments__title">Comments</span>
        {unresolved > 0 && <span className="cmp-comments__open">{unresolved} open</span>}
      </div>
      {commentApi.commentMode && <div className="cmp-comments__hint">Click the render to drop a pin · Esc to exit</div>}
      <div className="cmp-comments__list">
        {comments.length === 0 && (
          <div className="cmp-comments__empty">
            No comments yet.{commentApi.canComment ? <> Press <kbd>c</kbd> or hit <strong>Comment</strong>, then click the render.</> : null}
          </div>
        )}
        {here.length > 0 && <div className="cmp-cb-comments__group">This version</div>}
        {here.map((c) => renderItem(c))}
        {elsewhere.length > 0 && <div className="cmp-cb-comments__group">Other versions</div>}
        {elsewhere.map((c) => renderItem(c, { labelVersion: true }))}
      </div>
    </div>
  );
}
