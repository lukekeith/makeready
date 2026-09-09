// A value picker for a prop whose options have ARTWORK — an icon prop.
//
// Not a <select>: a native option list cannot render an image, and the whole
// point of an icon prop is that you pick the picture, not the string. The
// options and their artwork both come from the providing contract (C-021 for a
// glyph), so this control never carries an inventory of its own.
import React, { useEffect, useRef, useState } from 'react';

export default function IconSelect({ value, options, assets, disabled = false, onChange }) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const onDown = (e) => { if (!rootRef.current?.contains(e.target)) setOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); setOpen(false); } };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey, true);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey, true); };
  }, [open]);

  // A value the contract doesn't list is still shown and still selectable, so
  // opening the editor can never silently rewrite the fixture (same rule as the
  // plain enum select).
  const known = options.includes(value);
  const list = known ? options : [value, ...options];

  return (
    <div className="cmp-iconsel" ref={rootRef}>
      {/* Icon, name and chevron are all INSIDE the button — it is one control, and it
          stretches like every other field control (`flex: 1` after the 90px key column)
          so the pickers line up with each other and with the inputs above them. Only this
          button is clickable: FieldRow renders an icon-picker row as a <div>, because a
          <label> would forward a click on the field NAME here too. */}
      <button
        type="button"
        className="cmp-iconsel__trigger"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        {assets?.[value]
          ? <img className="cmp-iconsel__art" src={assets[value]} alt="" />
          : <span className="cmp-iconsel__art cmp-iconsel__art--none" />}
        <span className="cmp-iconsel__label">{value}{known ? '' : ' — not in the contract'}</span>
        <svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </button>
      {open && !disabled && (
        <div className="cmp-iconsel__menu" role="listbox">
          {list.map((o) => (
            <button
              type="button"
              key={o}
              role="option"
              aria-selected={o === value}
              className={`cmp-iconsel__opt${o === value ? ' is-active' : ''}`}
              onClick={() => { onChange(o); setOpen(false); }}
            >
              {assets?.[o]
                ? <img className="cmp-iconsel__art" src={assets[o]} alt="" />
                : <span className="cmp-iconsel__art cmp-iconsel__art--none" />}
              <span className="cmp-iconsel__label">{o}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
