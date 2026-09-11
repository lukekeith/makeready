// Column 1, UI 2.0 era — the program's two registries side by side.
//
// The 2.0 counterpart of ComponentTree, over BOTH of the program's axes:
// registry.md's C-### rows (components) and the README screen table's rows
// (screens). Sections stand in for folders and rows for Swift files; a row's
// badges say where it is in the spec pipeline — row only, spec written, snapshot
// frozen — which is the 2.0 analogue of 1.0's wiring badges.
//
// The kind filter above the search narrows the list to one axis. It defaults to
// `all` because the interesting question is usually "what is there", and the
// counts stay whole-registry so switching filters never hides how much exists.
import React, { useMemo, useState } from 'react';
import NavSearch from '../../components/NavSearch.jsx';
import { FilterTags, FilterTag } from '../../components/grid/FilterTags.jsx';

const norm = (s) => (s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');

/** Sections filtered to the rows matching `q`, dropping any left empty. */
function search(sections, q) {
  if (!q) return sections ?? [];
  return (sections ?? [])
    .map((s) => ({ ...s, rows: s.rows.filter((r) => norm(r.id).includes(q) || norm(r.name).includes(q)) }))
    .filter((s) => s.rows.length > 0);
}

/** Which dot a row gets: nothing specced, spec written, spec + frozen artwork. */
const dotKind = (row) => (row.specced ? (row.hasSnapshot ? 'specced' : 'contract') : (row.hasSnapshot ? 'artwork' : 'registry'));

function Row({ row, kind, selected, onSelect }) {
  const label = kind === 'screen'
    ? `${row.stateCount} designed state(s)${row.hasSnapshot ? ' · frozen snapshot' : ''}${row.specced ? '' : ' — no spec yet (/ui2-screen)'}`
    : (row.specced
      ? `${row.stateCount} designed state(s)${row.hasSnapshot ? ' · frozen snapshot' : ''}`
      : `registry row only — no contract yet (/ui2-component)${row.hasSnapshot ? ', but its artwork is captured' : ''}`);
  return (
    <button
      className={`cmp-ui2__row${selected ? ' cmp-ui2__row--active' : ''}${row.specced ? '' : ' cmp-ui2__row--unspecced'}`}
      onClick={() => onSelect({ ...row, kind })}
      title={label}
    >
      {kind === 'screen'
        ? <span className="cmp-ui2__name cmp-ui2__name--screen">{row.id}</span>
        : <><span className="cmp-ui2__id">{row.id}</span><span className="cmp-ui2__name">{row.name}</span></>}
      {row.unresolvedComments > 0 && <span className="cmp-open-badge">{row.unresolvedComments}</span>}
      <span className={`cmp-ui2__dot cmp-ui2__dot--${dotKind(row)}`} />
    </button>
  );
}

export default function Ui2Tree({ data, screens, selectedId, onSelect, header = null }) {
  const [query, setQuery] = useState('');
  // `all` by default: the list is the program's inventory, and a filter that
  // starts narrowed hides half of it from someone who just opened the page.
  const [kind, setKind] = useState('all');

  const q = norm(query.trim());
  const componentSections = useMemo(() => search(data?.sections, q), [data, q]);
  const screenSections = useMemo(() => search(screens?.sections, q), [screens, q]);

  const showComponents = kind !== 'screens';
  const showScreens = kind !== 'components';
  const shownComponents = showComponents ? componentSections : [];
  const shownScreens = showScreens ? screenSections : [];
  const empty = !shownComponents.length && !shownScreens.length;
  // Group headings only earn their space when both axes are on screen at once.
  const grouped = showComponents && showScreens;

  const loading = !data || !screens;

  return (
    <div className="cmp-cb-col cmp-cb-col--tree">
      {header}
      <FilterTags className="cmp-ui2__kinds" aria-label="Show components, screens, or both">
        <FilterTag
          label="All"
          count={(data?.counts.total ?? 0) + (screens?.counts.total ?? 0)}
          active={kind === 'all'}
          onClick={() => setKind('all')}
        />
        <FilterTag
          label="Components"
          count={data?.counts.total}
          active={kind === 'components'}
          onClick={() => setKind('components')}
        />
        <FilterTag
          label="Screens"
          count={screens?.counts.total}
          active={kind === 'screens'}
          onClick={() => setKind('screens')}
        />
      </FilterTags>
      <NavSearch
        placeholder={kind === 'screens' ? 'Filter screens…' : kind === 'components' ? 'Filter components…' : 'Filter components & screens…'}
        label="Filter the UI 2.0 registry"
        value={query}
        onChange={setQuery}
      />
      <div className="cmp-cb-col__scroll">
        {loading && <div className="cmp-cb-col__empty">loading…</div>}
        {!loading && empty && <div className="cmp-cb-col__empty">no matching rows</div>}
        {grouped && shownComponents.length > 0 && <div className="cmp-ui2__group">Components</div>}
        {shownComponents.map((section) => (
          <div key={`c:${section.name}`} className="cmp-ui2__section">
            <div className="cmp-cb-col__title">{section.name}</div>
            {section.rows.map((row) => (
              <Row key={row.id} row={row} kind="component" selected={row.id === selectedId} onSelect={onSelect} />
            ))}
          </div>
        ))}
        {grouped && shownScreens.length > 0 && <div className="cmp-ui2__group">Screens</div>}
        {shownScreens.map((section) => (
          <div key={`s:${section.name}`} className="cmp-ui2__section">
            <div className="cmp-cb-col__title">{section.name}</div>
            {section.rows.map((row) => (
              <Row key={row.id} row={row} kind="screen" selected={row.id === selectedId} onSelect={onSelect} />
            ))}
          </div>
        ))}
      </div>
      {!loading && (
        <div className="cmp-ui2__foot">
          {showScreens && !showComponents
            ? `${screens.counts.specced}/${screens.counts.total} screens specced`
            : showComponents && !showScreens
              ? `${data.counts.specced}/${data.counts.total} specced · ${data.counts.withSnapshot} with a frozen snapshot`
              : `${data.counts.specced}/${data.counts.total} components · ${screens.counts.specced}/${screens.counts.total} screens specced`}
        </div>
      )}
    </div>
  );
}
