// One field of the recursive key/value fixture editor (D9): scalars get typed
// inputs; plain objects/arrays render as collapsible groups of the same; null
// (or anything that isn't a JSON scalar/object/array) falls back to a raw-JSON
// textarea for that key. Keys are not addable/removable (values only).
import React, { useState } from 'react';

function RawJsonField({ value, onChange }) {
  const [text, setText] = useState(JSON.stringify(value));
  const [bad, setBad] = useState(false);
  return (
    <textarea
      className={`cmp-cb-field__raw${bad ? ' cmp-cb-field__raw--bad' : ''}`}
      value={text}
      spellCheck={false}
      onChange={(e) => {
        setText(e.target.value);
        try { onChange(JSON.parse(e.target.value)); setBad(false); }
        catch { setBad(true); }
      }}
    />
  );
}

export default function FieldRow({ k, value, onChange, depth = 0 }) {
  const [open, setOpen] = useState(depth < 2);
  const t = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;

  if (t === 'object' || t === 'array') {
    const entries = t === 'array' ? value.map((v, i) => [i, v]) : Object.entries(value);
    return (
      <div className="cmp-cb-field cmp-cb-field--group" style={{ '--depth': depth }}>
        <button className="cmp-cb-field__grouphead" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
          <svg className={`cmp-cb-field__chev${open ? ' cmp-cb-field__chev--open' : ''}`} viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
          <span className="cmp-cb-field__key">{k}</span>
          <span className="cmp-cb-field__type">{t === 'array' ? `array[${value.length}]` : 'object'}</span>
        </button>
        {open && (
          <div className="cmp-cb-field__children">
            {entries.map(([ck, cv]) => (
              <FieldRow
                key={ck}
                k={String(ck)}
                value={cv}
                depth={depth + 1}
                onChange={(nv) => {
                  if (t === 'array') { const next = [...value]; next[ck] = nv; onChange(next); }
                  else onChange({ ...value, [ck]: nv });
                }}
              />
            ))}
            {entries.length === 0 && <div className="cmp-cb-field__emptygroup">empty</div>}
          </div>
        )}
      </div>
    );
  }

  return (
    <label className="cmp-cb-field" style={{ '--depth': depth }}>
      <span className="cmp-cb-field__key">{k}</span>
      {t === 'boolean' && (
        <input type="checkbox" checked={value} onChange={(e) => onChange(e.target.checked)} />
      )}
      {t === 'number' && (
        <input
          className="cmp-cb-field__input"
          type="number"
          value={value}
          onChange={(e) => onChange(e.target.value === '' ? 0 : Number(e.target.value))}
        />
      )}
      {t === 'string' && (
        <input className="cmp-cb-field__input" type="text" value={value} onChange={(e) => onChange(e.target.value)} />
      )}
      {t === 'null' && <RawJsonField value={value} onChange={onChange} />}
    </label>
  );
}
