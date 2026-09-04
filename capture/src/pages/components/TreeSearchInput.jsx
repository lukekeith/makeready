// Filter field above the component tree (component-browser D11).
import React from 'react';

export default function TreeSearchInput({ value, onChange }) {
  return (
    <div className="cmp-cb-search">
      <svg className="cmp-cb-search__icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
      </svg>
      <input
        className="cmp-cb-search__input"
        placeholder="Filter components…"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Escape') { onChange(''); e.currentTarget.blur(); } }}
        aria-label="Filter components"
      />
      {value && (
        <button className="cmp-cb-search__clear" onClick={() => onChange('')} title="Clear" aria-label="Clear filter">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true">
            <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
          </svg>
        </button>
      )}
    </div>
  );
}
