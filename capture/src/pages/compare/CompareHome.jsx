import React, { useContext, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CompareContext } from './CompareContext.js';
import { HeaderContainer } from '../../components/grid/HeaderContainer.jsx';
import { SearchInput } from '../../components/grid/SearchInput.jsx';
import { FilterTags, FilterTag } from '../../components/grid/FilterTags.jsx';
import { CardGrid } from '../../components/grid/CardGrid.jsx';
import { ComponentCard } from '../../components/grid/ComponentCard.jsx';

// Browse all comparisons as a virtual-scrolling grid of component cards, with a
// fixed header carrying a search field (filters by title/id) and filter-tag
// chips (filter by group: Cards, Groups, Pages, …). Each card shows the iPhone
// thumbnail plus title + metadata (type/group, variant count, render sites).
// Minimum cell width: the grid packs as many columns as fit at >= this width,
// then stretches every cell to fill the row (no trailing gap). Matches fai-cd's
// default minCellWidth mode.
const MIN_CELL_WIDTH = 280;
const ROW_HEIGHT = 232;

export default function CompareHome() {
  const { manifest, shotsVersion } = useContext(CompareContext);
  const navigate = useNavigate();

  const [query, setQuery] = useState('');
  const [activeGroup, setActiveGroup] = useState(null);

  const all = useMemo(
    () => manifest?.types?.flatMap((t) => t.comparisons.filter((c) => !c.error)) ?? [],
    [manifest],
  );

  const groups = useMemo(() => {
    const seen = [];
    for (const c of all) if (c.group && !seen.includes(c.group)) seen.push(c.group);
    return seen.sort((a, b) => a.localeCompare(b));
  }, [all]);

  const searched = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return all;
    return all.filter((c) => c.title.toLowerCase().includes(q) || c.id.toLowerCase().includes(q));
  }, [all, query]);

  const visible = useMemo(
    () => (activeGroup ? searched.filter((c) => c.group === activeGroup) : searched),
    [searched, activeGroup],
  );

  const countFor = (group) => (group == null ? searched.length : searched.filter((c) => c.group === group).length);

  const open = (id) => navigate(`/compare/${id}`);

  return (
    <div className="cmp-browse">
      <HeaderContainer
        breadcrumb={
          <div className="cmp-browse__heading">
            <h1 className="cmp-browse__title">Compare</h1>
            <span className="cmp-browse__subtitle">
              {all.length} component{all.length === 1 ? '' : 's'} · iPhone ↔ web parity
            </span>
          </div>
        }
      >
        <SearchInput
          fullWidth
          placeholder="Search components…"
          value={query}
          onValueChange={setQuery}
        />
        <FilterTags aria-label="Filter by group">
          <FilterTag label="All" count={countFor(null)} active={activeGroup == null} onClick={() => setActiveGroup(null)} />
          {groups.map((g) => (
            <FilterTag key={g} label={g} count={countFor(g)} active={activeGroup === g} onClick={() => setActiveGroup(g)} />
          ))}
        </FilterTags>
      </HeaderContainer>

      <div className="cmp-browse__grid">
        <CardGrid
          items={visible}
          minCellWidth={MIN_CELL_WIDTH}
          rowHeight={ROW_HEIGHT}
          getItemKey={(c) => c.id}
          ariaLabel="Components"
          emptyMessage={manifest ? 'No components match' : 'Loading…'}
          renderItem={(c) => (
            <ComponentCard
              title={c.title}
              type={c.type}
              group={c.group}
              thumbnailUrl={c.thumbnail ? `${c.thumbnail}?v=${shotsVersion}` : null}
              variantCount={c.variantCount ?? c.completion?.total ?? 0}
              renderSites={c.renderSites}
              onClick={() => open(c.id)}
            />
          )}
        />
      </div>
    </div>
  );
}
