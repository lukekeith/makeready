// The one sidebar search field, shared by every capture UI's nav (platform
// sets, /compare components, the /components tree). Owns the boxed field,
// the clear button and Escape-to-clear; callers own the dropdown they pass as
// children (rendered inside the positioning context).
import React from 'react';

export default function NavSearch({
  value,
  onChange,
  onKeyDown,
  placeholder,
  label,
  inputRef,
  className = '',
  children,
}) {
  const handleKey = (e) => {
    if (e.key === 'Escape') {
      onChange('');
      e.currentTarget.blur();
      return;
    }
    onKeyDown?.(e);
  };

  return (
    <div className={`nav-search${className ? ` ${className}` : ''}`}>
      <div className="nav-search__field">
        <svg
          className="nav-search__icon"
          viewBox="0 0 24 24" width="14" height="14" fill="none"
          stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        <input
          ref={inputRef}
          className="nav-search__input"
          placeholder={placeholder}
          aria-label={label ?? placeholder}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={handleKey}
        />
        {value && (
          <button className="nav-search__clear" onClick={() => onChange('')} title="Clear" aria-label="Clear search">
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true">
              <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
            </svg>
          </button>
        )}
      </div>
      {children}
    </div>
  );
}
