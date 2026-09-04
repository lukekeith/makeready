// Data tab — recursive key/value editor over the variant's `shared`, writing
// back to the fixture FILE on save (07 §3.5, D8/D9, 03 §2.4).
import React, { useMemo, useState } from 'react';
import FieldRow from './FieldRow.jsx';

export default function DataEditor({ shared, canEdit, onSave }) {
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
        <span className="cmp-data__hint">Fixture data for this variant — saved to the fixture file.</span>
        {canEdit && (
          <div className="cmp-cb-data__actions">
          {savedAt && <span className="cmp-data__saved">saved ✓</span>}
            <button className="btn btn--mini" onClick={() => save()} disabled={busy || !dirty}>{busy ? 'Saving…' : 'Save'}</button>
            <button className="btn btn--primary btn--mini" onClick={() => save({ recapture: true })} disabled={busy || !dirty}>Save & Recapture</button>
          </div>
        )}
      </div>
      {error && <div className="error-banner">{error}</div>}
      <div className="cmp-cb-data__fields">
        {entries.length === 0 && <div className="cmp-cb-col__empty">This variant has no data.</div>}
        {entries.map(([k, v]) => (
          <FieldRow key={k} k={k} value={v} onChange={(nv) => setDraft((d) => ({ ...d, [k]: nv }))} />
        ))}
      </div>
    </div>
  );
}
