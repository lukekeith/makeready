// Column 1, UI 2.0 era — the registry's sections and their C-### rows.
//
// The 2.0 counterpart of ComponentTree: registry sections stand in for folders
// and rows for Swift files. A row's badges say where it is in the spec pipeline
// — registry row only, contract written, snapshot frozen — which is the 2.0
// analogue of 1.0's wiring badges.
import React, { useMemo, useState } from 'react';
import NavSearch from '../../components/NavSearch.jsx';

const norm = (s) => (s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');

export default function Ui2Tree({ data, selectedId, onSelect, header = null }) {
  const [query, setQuery] = useState('');

  const sections = useMemo(() => {
    const q = norm(query.trim());
    return (data?.sections ?? [])
      .map((s) => ({
        ...s,
        rows: q ? s.rows.filter((r) => norm(r.id).includes(q) || norm(r.name).includes(q)) : s.rows,
      }))
      .filter((s) => s.rows.length > 0);
  }, [data, query]);

  return (
    <div className="cmp-cb-col cmp-cb-col--tree">
      {header}
      <NavSearch
        placeholder="Filter components…"
        label="Filter UI 2.0 components"
        value={query}
        onChange={setQuery}
      />
      <div className="cmp-cb-col__scroll">
        {!data && <div className="cmp-cb-col__empty">loading…</div>}
        {data && sections.length === 0 && <div className="cmp-cb-col__empty">no matching rows</div>}
        {sections.map((section) => (
          <div key={section.name} className="cmp-ui2__section">
            <div className="cmp-cb-col__title">{section.name}</div>
            {section.rows.map((row) => (
              <button
                key={row.id}
                className={`cmp-ui2__row${row.id === selectedId ? ' cmp-ui2__row--active' : ''}${row.specced ? '' : ' cmp-ui2__row--unspecced'}`}
                onClick={() => onSelect(row)}
                title={row.specced
                  ? `${row.stateCount} designed state(s)${row.hasSnapshot ? ' · frozen snapshot' : ''}`
                  : 'registry row only — no contract yet (/ui2-component)'}
              >
                <span className="cmp-ui2__id">{row.id}</span>
                <span className="cmp-ui2__name">{row.name}</span>
                {row.unresolvedComments > 0 && <span className="cmp-open-badge">{row.unresolvedComments}</span>}
                <span className={`cmp-ui2__dot cmp-ui2__dot--${row.specced ? (row.hasSnapshot ? 'specced' : 'contract') : 'registry'}`} />
              </button>
            ))}
          </div>
        ))}
      </div>
      {data && (
        <div className="cmp-ui2__foot">
          {data.counts.specced}/{data.counts.total} specced · {data.counts.withSnapshot} with a frozen snapshot
        </div>
      )}
    </div>
  );
}
