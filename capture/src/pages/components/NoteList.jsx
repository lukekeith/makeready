// Note cards: timestamped, newest first, clamped to two lines (suite 07 §5.2, R7).
//
// A note is read as written — plain text, blank lines preserved, markdown NOT
// rendered — so the body goes in a <pre>-like block rather than through a
// formatter. Mentions are the one exception: they are canonical tokens (D10) and
// resolve to the CURRENT display name at read time, so a rename never rots a note.
import React, { useState } from 'react';

/** Split a body into text and resolved mention chips. Unresolved tokens stay
 *  literal — writing about something since renamed must not produce a dead link. */
function renderBody(body, refs) {
  if (!refs?.length) return body;
  const byToken = new Map(refs.map((r) => [r.token, r]));
  const parts = String(body).split(/(@[A-Za-z0-9][A-Za-z0-9-]*)/g);
  return parts.map((part, i) => {
    const ref = byToken.get(part);
    if (!ref) return part;
    return (
      <span key={i} className={`cmp-ui2n__mention cmp-ui2n__mention--${ref.kind}`} data-id={ref.id}>
        {ref.name ?? ref.id}
      </span>
    );
  });
}

function NoteCard({ note, onMention }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <div className="cmp-ui2n__card">
      <div className="cmp-ui2n__when">{new Date(note.at).toLocaleString()}</div>
      <div
        className={`cmp-ui2n__body${expanded ? ' is-expanded' : ''}`}
        onClick={(e) => {
          // A mention chip is a link; the rest of the card is the expander.
          const id = e.target?.dataset?.id;
          if (id) { onMention?.(id); return; }
          setExpanded((v) => !v);
        }}
      >
        {renderBody(note.body, note.refs)}
      </div>
      {/* Expanding toggles the clamp IN PLACE — it never navigates and never opens
          the composer, so reading a long note cannot lose anything. */}
      <button type="button" className="cmp-ui2n__expand" onClick={() => setExpanded((v) => !v)}>
        {expanded ? 'Show less' : 'Show more'}
      </button>
    </div>
  );
}

export default function NoteList({ notes, parseError, onMention, onAdd, canWrite, error, onRetry }) {
  return (
    <div className="cmp-ui2n">
      <div className="cmp-ui2n__head">
        <span className="cmp-ui2n__title">Notes</span>
        {canWrite && (
          <button type="button" className="btn btn--mini" onClick={onAdd}>Add note</button>
        )}
      </div>

      {/* A file that could not be parsed must SAY so. Rendering it as "no notes
          yet" is the one outcome that loses the owner's words silently, which is
          exactly what this store exists to prevent (suite 09 §G-13). */}
      {parseError && (
        <div className="cmp-ui2n__parse-error">
          This note file could not be read — {parseError}
        </div>
      )}

      {error && (
        <div className="cmp-ui2n__error">
          {error}
          <button type="button" className="btn btn--mini" onClick={onRetry}>Retry</button>
        </div>
      )}

      {!error && !parseError && !notes.length && (
        <div className="cmp-cb-col__empty">
          No notes yet. A note says what this component is <em>for</em> — it is read by
          /ui2-component-build and /ui2-component-update, and a newer note always wins.
        </div>
      )}

      {notes.map((n) => <NoteCard key={n.id} note={n} onMention={onMention} />)}
    </div>
  );
}
