// One field of the recursive key/value fixture editor (D9): scalars get typed
// inputs; plain objects/arrays render as collapsible groups of the same; null
// (or anything that isn't a JSON scalar/object/array) falls back to a raw-JSON
// textarea for that key. Keys are not addable/removable (values only).
import React, { useState } from 'react';
import IconSelect from './IconSelect.jsx';

function RawJsonField({ value, onChange, disabled = false }) {
  const [text, setText] = useState(JSON.stringify(value));
  const [bad, setBad] = useState(false);
  return (
    <textarea
      className={`cmp-cb-field__raw${bad ? ' cmp-cb-field__raw--bad' : ''}`}
      value={text}
      spellCheck={false}
      disabled={disabled}
      onChange={(e) => {
        setText(e.target.value);
        try { onChange(JSON.parse(e.target.value)); setBad(false); }
        catch { setBad(true); }
      }}
    />
  );
}

export default function FieldRow({ k, value, onChange, depth = 0, disabled = false, options = null, assets = null }) {
  const [open, setOpen] = useState(depth < 2);
  const t = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;

  if (t === 'object' || t === 'array') {
    const entries = t === 'array' ? value.map((v, i) => [i, v]) : Object.entries(value);
    return (
      <div className="cmp-cb-field cmp-cb-field--group" style={{ '--depth': depth }}>
        <button className="cmp-cb-field__grouphead" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
          <svg className={`cmp-cb-field__chev${open ? ' cmp-cb-field__chev--open' : ''}`} viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
          <span className="cmp-cb-field__key">{k}</span>
        </button>
        {open && (
          <div className="cmp-cb-field__children">
            {entries.map(([ck, cv]) => (
              <FieldRow
                key={ck}
                k={String(ck)}
                value={cv}
                depth={depth + 1}
                disabled={disabled}
                {...(t === 'array' ? { options, assets } : {})}
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

  // A <label> natively forwards a click anywhere inside it to its control — which is what
  // you want for a checkbox or a text field, and exactly wrong for the icon picker: it made
  // the field NAME (and every other pixel of the row) open the menu. The picker is a custom
  // listbox, not a form control, so its row is a plain <div>.
  const isIconPicker = t === 'string' && options?.length > 0 && !!assets;
  const Row = isIconPicker ? 'div' : 'label';

  return (
    <Row className="cmp-cb-field" style={{ '--depth': depth }}>
      <span className="cmp-cb-field__key">{k}</span>
      {t === 'boolean' && (
        <input type="checkbox" checked={value} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      )}
      {t === 'number' && (
        <input
          className="cmp-cb-field__input"
          type="number"
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value === '' ? 0 : Number(e.target.value))}
        />
      )}
      {/* A prop whose §4 type enumerates its values gets exactly those values
          and no free text — picking an illegal one is how a fixture renders
          wrong with no error (ViewRegistry throws, or the prop decodes to
          nothing). A value the contract does NOT list is still offered, so
          opening the tab can never silently rewrite the fixture; it is labelled
          so the disagreement between fixture and contract is visible. */}
      {t === 'string' && options?.length > 0 && assets && (
        <IconSelect value={value} options={options} assets={assets} disabled={disabled} onChange={onChange} />
      )}
      {t === 'string' && options?.length > 0 && !assets && (
        <select
          className="cmp-cb-field__input cmp-cb-field__select"
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
        >
          {!options.includes(value) && <option value={value}>{value} — not in the contract</option>}
          {options.map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      )}
      {t === 'string' && !(options?.length > 0) && (
        <input className="cmp-cb-field__input" type="text" value={value} disabled={disabled} onChange={(e) => onChange(e.target.value)} />
      )}
      {t === 'null' && <RawJsonField value={value} onChange={onChange} disabled={disabled} />}
    </Row>
  );
}
