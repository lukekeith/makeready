// The `@` typeahead popup for the note composer (suite 07 §5.4, R9).
//
// Presentational: the composer owns the query, the caret and the commit; this
// renders the filtered list and reports which row was chosen. Keyboard handling
// lives in the composer too, because the textarea keeps focus the whole time —
// a popup that stole focus would break typing mid-token.
import React from 'react';

export default function MentionTypeahead({ items, activeIndex, onCommit, anchor }) {
  if (!items.length) {
    return (
      <div className="cmp-ui2n__ta" style={anchor}>
        <div className="cmp-ui2n__ta-empty">No component or screen matches</div>
      </div>
    );
  }
  return (
    <div className="cmp-ui2n__ta" style={anchor} role="listbox">
      {items.map((item, i) => (
        <button
          key={`${item.kind}:${item.id}`}
          type="button"
          role="option"
          aria-selected={i === activeIndex}
          className={`cmp-ui2n__ta-row${i === activeIndex ? ' is-active' : ''}`}
          // The textarea must not lose focus: a blur here would close the popup
          // before the click could land.
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => onCommit(item)}
        >
          <span className="cmp-ui2n__ta-id">{item.id}</span>
          <span className="cmp-ui2n__ta-name">{item.name}</span>
          {item.hasNotes && <span className="cmp-ui2n__ta-dot" title="has notes" />}
        </button>
      ))}
    </div>
  );
}
