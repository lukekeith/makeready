// Data tab — recursive key/value editor over the variant's `shared`, writing
// back to the fixture FILE on save (07 §3.5, D8/D9, 03 §2.4).
//
// `readOnly` renders the same fields, disabled and with no Save: the 2.0 era
// shows the props a PAST capture was rendered with, and those are a record of
// what happened, not something to edit. `note` says which case the reader is
// looking at.
import React, { useMemo, useState } from 'react';
import FieldRow from './FieldRow.jsx';

export default function DataEditor({ shared, canEdit, onSave, readOnly = false, note = null, hint = null, optionsByKey = null, assetsByKey = null }) {
  const [draft, setDraft] = useState(() => structuredClone(shared ?? {}));
  const [busy, setBusy] = useState(false);
  const [savedAt, setSavedAt] = useState(null);
  const [error, setError] = useState(null);

  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(shared ?? {}), [draft, shared]);
  const entries = Object.entries(draft);

  const save = async ({ recapture = false } = {}) => {
    setBusy(true); setError(null);
    try {
      await onSave(draft, { recapture });
      setSavedAt(Date.now());
      setTimeout(() => setSavedAt(null), 1800);
    } catch (err) { setError(err.message); }
    finally { setBusy(false); }
  };

  return (
    <div className="cmp-cb-data">
      <div className="cmp-cb-data__head">
        <span className="cmp-data__hint">{hint ?? 'Fixture data for this variant — saved to the fixture file.'}</span>
        {canEdit && !readOnly && (
          <div className="cmp-cb-data__actions">
          {savedAt && <span className="cmp-data__saved">saved ✓</span>}
            <button className="btn btn--mini" onClick={() => save()} disabled={busy || !dirty}>{busy ? 'Saving…' : 'Save'}</button>
            <button className="btn btn--primary btn--mini" onClick={() => save({ recapture: true })} disabled={busy || !dirty}>Save & Recapture</button>
          </div>
        )}
      </div>
      {note && <div className="cmp-cb-data__note">{note}</div>}
      {error && <div className="error-banner">{error}</div>}
      <div className="cmp-cb-data__fields">
        {entries.length === 0 && <div className="cmp-cb-col__empty">This variant has no data.</div>}
        {entries.map(([k, v]) => (
          // Options apply to the PROP itself, so they are passed at the top
          // level only — an element inside a `series` array is not the prop.
          <FieldRow
            key={k}
            k={k}
            value={v}
            disabled={readOnly}
            options={optionsByKey?.[k] ?? null}
            assets={assetsByKey?.[k] ?? null}
            onChange={(nv) => setDraft((d) => ({ ...d, [k]: nv }))}
          />
        ))}
      </div>
    </div>
  );
}
