// The notepad (suite 07 §5.3, R8): Add note replaces the whole right-panel region
// BELOW the tab strip, so the context is never lost, and a bar pinned to the
// bottom holds exactly Cancel and Save.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import ConfirmDialog from '../../components/ConfirmDialog.jsx';
import MentionTypeahead from './MentionTypeahead.jsx';
import { filterMentions, activeMention, commitToken } from '../../lib/mentions.js';

export default function NoteComposer({ target, mentions, busy, error, onSave, onCancel }) {
  const [text, setText] = useState('');
  const [caret, setCaret] = useState(0);
  const [taIndex, setTaIndex] = useState(0);
  const [dismissed, setDismissed] = useState(false);
  const [confirmDiscard, setConfirmDiscard] = useState(false);
  const ref = useRef(null);

  useEffect(() => { ref.current?.focus(); }, []);

  const active = dismissed ? null : activeMention(text, caret);
  const matches = useMemo(
    () => (active ? filterMentions(mentions, active.query).slice(0, 8) : []),
    [active, mentions],
  );
  useEffect(() => { setTaIndex(0); }, [active?.query]);

  const commit = (item) => {
    const next = commitToken(text, caret, `@${item.id}`);
    setText(next.text);
    setCaret(next.caret);
    setDismissed(false);
    requestAnimationFrame(() => {
      ref.current?.focus();
      ref.current?.setSelectionRange(next.caret, next.caret);
    });
  };

  const onKeyDown = (e) => {
    if (active && matches.length) {
      if (e.key === 'ArrowDown') { e.preventDefault(); setTaIndex((i) => (i + 1) % matches.length); return; }
      if (e.key === 'ArrowUp') { e.preventDefault(); setTaIndex((i) => (i - 1 + matches.length) % matches.length); return; }
      if (e.key === 'Enter' || e.key === 'Tab') { e.preventDefault(); commit(matches[taIndex]); return; }
    }
    // Escape closes an open typeahead; a SECOND Escape is Cancel, so an
    // accidental `@` never costs the note being written.
    if (e.key === 'Escape') {
      e.preventDefault();
      if (active && !dismissed) { setDismissed(true); return; }
      requestCancel();
    }
  };

  const requestCancel = () => {
    // The composer is the one place in this feature where work can be lost, so a
    // non-empty body is confirmed — through ConfirmDialog, never window.confirm.
    if (text.trim()) setConfirmDiscard(true); else onCancel();
  };

  return (
    <div className="cmp-ui2n__pad">
      <div className="cmp-ui2n__pad-head">
        New note on <strong>{target}</strong>
      </div>

      <div className="cmp-ui2n__pad-body">
        <textarea
          ref={ref}
          className="cmp-ui2n__ta-input"
          value={text}
          placeholder="What is this component for? Type @ to reference another component or screen."
          onChange={(e) => { setText(e.target.value); setCaret(e.target.selectionStart); setDismissed(false); }}
          onKeyUp={(e) => setCaret(e.target.selectionStart)}
          onClick={(e) => setCaret(e.target.selectionStart)}
          onKeyDown={onKeyDown}
          disabled={busy}
        />
        {active && !dismissed && (
          <MentionTypeahead items={matches} activeIndex={taIndex} onCommit={commit} />
        )}
      </div>

      {error && <div className="cmp-ui2n__error">{error}</div>}

      <div className="cmp-ui2n__bar">
        <button type="button" className="btn" onClick={requestCancel} disabled={busy}>Cancel</button>
        <button
          type="button"
          className="btn btn--primary"
          onClick={() => onSave(text.trim())}
          disabled={busy || !text.trim()}
        >
          {busy ? 'Saving…' : 'Save'}
        </button>
      </div>

      <ConfirmDialog
        open={confirmDiscard}
        title="Discard this note?"
        confirmLabel="Discard"
        destructive
        onConfirm={() => { setConfirmDiscard(false); onCancel(); }}
        onCancel={() => setConfirmDiscard(false)}
      >
        <div>What you have typed is not saved anywhere yet. Discarding it cannot be undone.</div>
      </ConfirmDialog>
    </div>
  );
}
