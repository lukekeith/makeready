import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation, useParams, useNavigate } from 'react-router-dom';
import { CompareContext } from './CompareContext.js';
import { fetchCompareManifest, fetchVersions } from '../../api.js';

const TYPE_LABELS = { page: 'Pages', component: 'Components', error: 'Broken specs' };

const RATING_FACES = {
  1: { mouth: 'M8 17 Q12 12 16 17', color: '#f87171' },
  2: { mouth: 'M8 16 Q12 13.5 16 16', color: '#fb923c' },
  3: { mouth: 'M8 15 L16 15', color: '#fbbf24' },
  4: { mouth: 'M8 14 Q12 17 16 14', color: '#a3e635' },
  5: { mouth: 'M8 13.5 Q12 18 16 13.5', color: '#4ade80' },
};
function RatingDot({ rating }) {
  const f = RATING_FACES[rating];
  if (!f) return null;
  return (
    <svg className="cmp-nav-face" viewBox="0 0 24 24" fill="none" stroke={f.color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9" />
      <circle cx="9" cy="10" r="0.7" fill={f.color} stroke="none" />
      <circle cx="15" cy="10" r="0.7" fill={f.color} stroke="none" />
      <path d={f.mouth} />
    </svg>
  );
}
const ChevronR = () => (
  <svg className="cmp-nav__chev" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
);

export default function CompareLayout() {
  const [manifest, setManifest] = useState(null);
  const [error, setError] = useState(null);
  const [shotsVersion, setShotsVersion] = useState(() => Date.now());
  const [activeRun, setActiveRun] = useState(null);
  const location = useLocation();
  const { id, version } = useParams();
  const navigate = useNavigate();
  const isDetail = /^\/compare\/.+/.test(location.pathname);

  const reload = useCallback(async () => {
    try { setManifest(await fetchCompareManifest()); setError(null); }
    catch (err) { setError(err.message); }
  }, []);
  useEffect(() => { reload(); }, [reload]);
  const bumpShots = useCallback(() => { setShotsVersion(Date.now()); reload(); }, [reload]);

  const ctx = useMemo(() => ({ manifest, reload, shotsVersion, bumpShots, activeRun, setActiveRun }),
    [manifest, reload, shotsVersion, bumpShots, activeRun]);

  const allComparisons = useMemo(
    () => manifest?.types?.flatMap((t) => t.comparisons.filter((c) => !c.error)) ?? [],
    [manifest],
  );
  const activeTitle = allComparisons.find((c) => c.id === id)?.title ?? id;

  // ── Version list for the selected component ──
  const [versions, setVersions] = useState([]);
  const [variantNames, setVariantNames] = useState([]);
  const [selectedVariant, setSelectedVariant] = useState(null);
  useEffect(() => { setSelectedVariant(null); }, [id]);
  useEffect(() => {
    if (!id) { setVersions([]); setVariantNames([]); return; }
    let cancelled = false;
    fetchVersions(id).then((d) => {
      if (cancelled) return;
      const vs = d.versions ?? [];
      setVersions(vs);
      // Union of the component's declared variants + any captured ones.
      setVariantNames([...new Set([...(d.variants ?? []), ...vs.map((v) => v.variantName)])]);
    }).catch(() => { if (!cancelled) { setVersions([]); setVariantNames([]); } });
    return () => { cancelled = true; };
  }, [id, shotsVersion]);
  // Default the selected variant to the open version's variant (or the first).
  useEffect(() => {
    if (selectedVariant || !variantNames.length) return;
    const cur = versions.find((v) => v.id === version)?.variantName;
    setSelectedVariant(cur ?? variantNames[0]);
  }, [variantNames, versions, version, selectedVariant]);
  const shownVersions = versions.filter((v) => v.variantName === selectedVariant);

  // Clicking a variant selects it AND jumps to its most recent capture (versions
  // are newest-first), so the detail view always lands on the latest version of
  // the variant rather than leaving a stale version open. Uncaptured variants
  // (no versions yet) just get selected so their empty state shows.
  const selectVariant = (name) => {
    setSelectedVariant(name);
    const latest = versions.find((v) => v.variantName === name);
    if (latest && latest.id !== version) navigate(`/compare/${id}/${latest.id}`);
  };

  // ── Typeahead search ──
  const [query, setQuery] = useState('');
  const [highlight, setHighlight] = useState(0);
  const searchRef = useRef(null);
  const matches = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return allComparisons.filter((c) => c.title.toLowerCase().includes(q) || c.id.toLowerCase().includes(q)).slice(0, 8);
  }, [query, allComparisons]);
  useEffect(() => setHighlight(0), [query]);

  const goto = (cid) => { setQuery(''); navigate(`/compare/${cid}`); };
  const onSearchKey = (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setHighlight((h) => Math.min(h + 1, matches.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setHighlight((h) => Math.max(h - 1, 0)); }
    else if (e.key === 'Enter') { if (matches[highlight]) goto(matches[highlight].id); }
    else if (e.key === 'Escape') { setQuery(''); searchRef.current?.blur(); }
  };

  const fmt = (iso) => { try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); } catch { return iso; } };

  return (
    <CompareContext.Provider value={ctx}>
      <div className="layout">
        <header className="layout__header">
          <div className="layout__brand"><span className="layout__brand-dot" /><NavLink to="/">MakeReady Capture</NavLink></div>
          <div className="layout__platform-tabs">
            <NavLink to="/client" className="layout__platform-tab">Web</NavLink>
            <NavLink to="/iphone" className="layout__platform-tab">iPhone</NavLink>
            <NavLink to="/compare" className="layout__platform-tab layout__platform-tab--active">Compare</NavLink>
          </div>
          {activeRun && (
            <div className="layout__capture-group">
              <button className="layout__activity-btn" disabled><span className="layout__activity-spinner" />Capturing {activeRun.id}…</button>
            </div>
          )}
        </header>

        <aside className="layout__sidebar cmp-nav">
          {error && <div className="error-banner">{error}</div>}
          {/* Search stays pinned above the slider — available on both panes */}
          <div className="cmp-search">
            <input
              ref={searchRef}
              className="cmp-search__input"
              placeholder="Search components…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={onSearchKey}
            />
            {matches.length > 0 && (
              <div className="cmp-search__dropdown">
                {matches.map((c, i) => (
                  <button key={c.id} className={`cmp-search__opt${i === highlight ? ' is-active' : ''}`}
                    onMouseEnter={() => setHighlight(i)} onMouseDown={(e) => { e.preventDefault(); goto(c.id); }}>
                    <span>{c.title}</span><span className="cmp-search__type">{c.type}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className={`cmp-nav__slider${id ? ' cmp-nav__slider--versions' : ''}`}>
            {/* Level 1 — components */}
            <div className="cmp-nav__pane">
              {!manifest && !error && <div className="component-list__loading">loading…</div>}
              {manifest?.types?.map((group) => (
                <div key={group.type} className="nav__section">
                  <div className="nav__section-title">{TYPE_LABELS[group.type] ?? group.type}</div>
                  {group.comparisons.map((c) => (
                    <button key={c.id} className={`nav__item cmp-nav__component${c.id === id ? ' nav__item--active' : ''}`} onClick={() => c.error ? null : goto(c.id)}>
                      <span className="cmp-nav__component-title">{c.error ? c.id : c.title}</span>
                      {!c.error && c.rating != null && <RatingDot rating={c.rating} />}
                      {!c.error && c.unresolvedComments > 0 && <span className="cmp-open-badge">{c.unresolvedComments}</span>}
                      {!c.error && <ChevronR />}
                    </button>
                  ))}
                </div>
              ))}
            </div>

            {/* Level 2 — versions of the selected component */}
            <div className="cmp-nav__pane">
              <button className="cmp-nav__back" onClick={() => navigate('/compare')}>
                <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6" /></svg>
                Components
              </button>
              <div className="cmp-nav__versions-title">{activeTitle}<span className="cmp-nav__versions-sub">versions</span></div>
              {variantNames.length > 0 && (
                <div className="cmp-variant-menu">
                  {variantNames.map((name) => (
                    <button key={name} className={`cmp-variant${name === selectedVariant ? ' cmp-variant--active' : ''}`} onClick={() => selectVariant(name)}>{name}</button>
                  ))}
                </div>
              )}
              {shownVersions.map((v) => (
                <NavLink key={v.id} to={`/compare/${id}/${v.id}`}
                  className={({ isActive }) => `cmp-version${isActive ? ' cmp-version--active' : ''}`}>
                  <div className="cmp-version__top">
                    <span className="cmp-version__vp">{v.label ?? v.viewport}</span>
                    {v.rating != null && <RatingDot rating={v.rating} />}
                    {v.unresolvedCount > 0 && <span className="cmp-open-badge">{v.unresolvedCount}</span>}
                  </div>
                  <div className="cmp-version__meta">
                    {fmt(v.capturedAt)} · {v.platforms.join('+') || 'no shots'}{v.gitSha ? ` · ${v.gitSha.slice(0, 7)}${v.gitDirty ? '*' : ''}` : ''}
                  </div>
                </NavLink>
              ))}
              {id && shownVersions.length === 0 && <div className="cmp-comments__empty">No captures of <strong>{selectedVariant}</strong> yet — pick it and hit Capture.</div>}
            </div>
          </div>
        </aside>

        <main className={`layout__main${isDetail ? ' layout__main--bleed' : ''}`}>
          <Outlet />
        </main>
      </div>
    </CompareContext.Provider>
  );
}
