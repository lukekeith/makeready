import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation, useParams, useNavigate } from 'react-router-dom';
import { io } from 'socket.io-client';
import { CompareContext } from './CompareContext.js';
import { fetchCompareManifest, fetchVariants, startCompareBatchCapture, subscribeCapture } from '../../api.js';

const TYPE_LABELS = { page: 'Pages', component: 'Components', error: 'Broken specs' };

// Preferred order for the category sections (mirrors the iOS Components/ folders).
// Unknown groups fall to the end, alphabetically.
const CATEGORY_ORDER = [
  'Button', 'Input', 'Navigation', 'Display', 'Cards', 'Card', 'Chart',
  'Calendar', 'Content', 'Feedback', 'Group', 'Domain', 'Layout', 'Loading',
  'Overlays', 'Video',
];
function orderGroups(groups) {
  return [...groups].sort((a, b) => {
    const ai = CATEGORY_ORDER.indexOf(a);
    const bi = CATEGORY_ORDER.indexOf(b);
    return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi) || a.localeCompare(b);
  });
}
const sectionKey = (type, group) => `${type}::${group || 'Other'}`;

// Aggregate completion across a category's components: sum of done platform
// "cells" (iPhone captured + web built) over total cells (2 × variants), as a %.
function aggregateCompletion(items) {
  let done = 0;
  let total = 0;
  for (const c of items) {
    if (c.error || !c.completion) continue;
    done += (c.completion.iphoneCaptured || 0) + (c.completion.webBuilt || 0);
    total += 2 * (c.completion.total || 0);
  }
  return { pct: total ? Math.round((done / total) * 100) : 0, total };
}

// Completion color on a continuous red(0%) → orange(~50%) → green(100%) scale,
// so a category's progress is legible at a glance. Hue 0=red … 120=green.
function pctColor(pct) {
  const clamped = Math.max(0, Math.min(100, pct));
  return `hsl(${Math.round(clamped * 1.2)}, 70%, 55%)`;
}

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
  const { id, variant } = useParams();
  const navigate = useNavigate();
  const isDetail = /^\/compare\/.+/.test(location.pathname);

  const reload = useCallback(async () => {
    try { setManifest(await fetchCompareManifest()); setError(null); }
    catch (err) { setError(err.message); }
  }, []);
  useEffect(() => { reload(); }, [reload]);
  const bumpShots = useCallback(() => { setShotsVersion(Date.now()); reload(); }, [reload]);

  // ── Live updates over socket.io ──
  // The server pushes an event whenever ANY capture writes a screenshot — including
  // captures run outside this UI (CLI, curl, an agent building a new twin). On each
  // event we bumpShots(), which cache-busts screenshot URLs and refetches the
  // manifest + the open variant, so the nav %, variant dots, and the detail view
  // all refresh automatically. Bursts (e.g. a batch capture) are debounced.
  const [liveConnected, setLiveConnected] = useState(false);
  useEffect(() => {
    const socket = io({ path: '/socket.io', transports: ['websocket', 'polling'] });
    let timer = null;
    const refresh = () => { clearTimeout(timer); timer = setTimeout(() => bumpShots(), 300); };
    socket.on('connect', () => {
      setLiveConnected(true);
      // Refresh on (re)connect too: after a server restart — e.g. a new adapter was
      // added for a freshly-built Vue twin — the UI picks up the change immediately.
      refresh();
    });
    socket.on('disconnect', () => setLiveConnected(false));
    socket.on('compare:shot', refresh);
    socket.on('compare:done', refresh);
    // The capture server hot-reloaded its adapter registry (a new web twin) —
    // refetch so the right-hand live web pane appears without a manual reload.
    socket.on('compare:adapters', refresh);
    return () => { clearTimeout(timer); socket.close(); };
  }, [bumpShots]);

  const ctx = useMemo(() => ({ manifest, reload, shotsVersion, bumpShots, activeRun, setActiveRun }),
    [manifest, reload, shotsVersion, bumpShots, activeRun]);

  const allComparisons = useMemo(
    () => manifest?.types?.flatMap((t) => t.comparisons.filter((c) => !c.error)) ?? [],
    [manifest],
  );
  const activeTitle = allComparisons.find((c) => c.id === id)?.title ?? id;

  // ── Group each type's comparisons into category sections (collapsible) ──
  const grouped = useMemo(() => (manifest?.types ?? []).map((t) => {
    const byGroup = new Map();
    for (const c of t.comparisons) {
      const g = c.group || 'Other';
      if (!byGroup.has(g)) byGroup.set(g, []);
      byGroup.get(g).push(c);
    }
    return {
      type: t.type,
      groups: orderGroups([...byGroup.keys()]).map((g) => {
        const items = byGroup.get(g);
        return { group: g, items, completion: aggregateCompletion(items) };
      }),
    };
  }), [manifest]);

  const allSectionKeys = useMemo(
    () => grouped.flatMap((t) => t.groups.map((g) => sectionKey(t.type, g.group))),
    [grouped],
  );

  // Expanded sections (persisted). Default: all collapsed — a clean header list.
  const [expanded, setExpanded] = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem('cmp-nav-expanded') || '[]')); }
    catch { return new Set(); }
  });
  useEffect(() => {
    try { localStorage.setItem('cmp-nav-expanded', JSON.stringify([...expanded])); } catch { /* ignore */ }
  }, [expanded]);
  const toggleSection = (key) => setExpanded((prev) => {
    const next = new Set(prev);
    next.has(key) ? next.delete(key) : next.add(key);
    return next;
  });
  const expandAll = () => setExpanded(new Set(allSectionKeys));
  const collapseAll = () => setExpanded(new Set());

  // Keep the active component's section open so the selection is always visible.
  useEffect(() => {
    const c = id && allComparisons.find((x) => x.id === id);
    if (!c) return;
    const key = sectionKey(c.type, c.group);
    setExpanded((prev) => (prev.has(key) ? prev : new Set(prev).add(key)));
  }, [id, allComparisons]);

  // ── Per-category action menu ("Capture all") ──
  const [menuOpen, setMenuOpen] = useState(null); // section key whose menu is open
  const unsubRef = useRef(null);
  const canCapture = manifest?.canCapture ?? false;
  useEffect(() => {
    if (!menuOpen) return undefined;
    const close = () => setMenuOpen(null);
    document.addEventListener('click', close);
    return () => document.removeEventListener('click', close);
  }, [menuOpen]);
  useEffect(() => () => unsubRef.current?.(), []);

  const captureGroup = async (key, items) => {
    setMenuOpen(null);
    if (activeRun) return; // one run at a time (single xcodebuild)
    const ids = items.filter((c) => !c.error).map((c) => c.id);
    if (!ids.length) return;
    const groupName = key.split('::')[1];
    try {
      const { runId } = await startCompareBatchCapture({ ids, viewport: 'pro-max' });
      setActiveRun({ id: groupName, runId, batch: true });
      unsubRef.current = subscribeCapture(runId, {
        onDone: () => { setActiveRun(null); bumpShots(); },
        onError: () => setActiveRun(null),
      });
    } catch (err) { setError(err.message); }
  };

  // ── Variants for the selected component (the version system is gone) ──
  const [variantInfo, setVariantInfo] = useState({ variants: [], counts: { iphone: 0, web: 0 } });
  useEffect(() => {
    if (!id) { setVariantInfo({ variants: [], counts: { iphone: 0, web: 0 } }); return; }
    let cancelled = false;
    fetchVariants(id)
      .then((d) => { if (!cancelled) setVariantInfo({ variants: d.variants ?? [], counts: d.counts ?? { iphone: 0, web: 0 } }); })
      .catch(() => { if (!cancelled) setVariantInfo({ variants: [], counts: { iphone: 0, web: 0 } }); });
    return () => { cancelled = true; };
  }, [id, shotsVersion]);

  // Land on the first variant when a component is opened without one selected.
  useEffect(() => {
    if (id && !variant && variantInfo.variants.length) {
      navigate(`/compare/${id}/${encodeURIComponent(variantInfo.variants[0].name)}`, { replace: true });
    }
  }, [id, variant, variantInfo, navigate]);

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
          <span
            title={liveConnected ? 'Live — the view auto-updates when captures complete' : 'Live updates offline'}
            style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, letterSpacing: 0.3, textTransform: 'uppercase', color: liveConnected ? '#4ade80' : '#6b7280' }}
          >
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: liveConnected ? '#4ade80' : '#6b7280', boxShadow: liveConnected ? '0 0 6px #4ade80' : 'none' }} />
            Live
          </span>
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
            {/* Level 1 — components grouped into collapsible category sections */}
            <div className="cmp-nav__pane">
              {!manifest && !error && <div className="component-list__loading">loading…</div>}
              {manifest && allSectionKeys.length > 0 && (
                <div className="cmp-nav__toolbar">
                  <button className="cmp-nav__toolbtn" onClick={expandAll}>Expand all</button>
                  <span className="cmp-nav__toolbar-sep" />
                  <button className="cmp-nav__toolbtn" onClick={collapseAll}>Collapse all</button>
                </div>
              )}
              {grouped.map((t) => (
                <div key={t.type} className="nav__section">
                  <div className="nav__section-title">{TYPE_LABELS[t.type] ?? t.type}</div>
                  {t.groups.map(({ group, items, completion }) => {
                    const key = sectionKey(t.type, group);
                    const isOpen = expanded.has(key);
                    const openComments = items.reduce((a, c) => a + (c.error ? 0 : c.unresolvedComments || 0), 0);
                    const isCapturing = activeRun?.batch && activeRun.id === group;
                    return (
                      <div key={key} className={`cmp-nav__group${isOpen ? ' is-open' : ''}`}>
                        <div className="cmp-nav__group-header">
                          <button className="cmp-nav__group-toggle" onClick={() => toggleSection(key)} aria-expanded={isOpen}>
                            <svg className="cmp-nav__group-chev" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
                            <span className="cmp-nav__group-name">{group}</span>
                          </button>
                          {openComments > 0 && <span className="cmp-open-badge cmp-nav__group-badge">{openComments}</span>}
                          {completion.total > 0 && (
                            <span className="cmp-nav__group-pct" style={{ color: pctColor(completion.pct) }} title={`Category completion: ${completion.pct}%`}>{completion.pct}%</span>
                          )}
                          <span className="cmp-nav__group-count">{items.length}</span>
                          <div className="cmp-nav__menu-wrap">
                            <button
                              className="cmp-nav__group-dots"
                              title="Category actions"
                              aria-label={`${group} actions`}
                              onClick={(e) => { e.stopPropagation(); setMenuOpen((m) => (m === key ? null : key)); }}
                            >
                              {isCapturing ? <span className="layout__activity-spinner" /> : (
                                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><circle cx="12" cy="5" r="1.6" /><circle cx="12" cy="12" r="1.6" /><circle cx="12" cy="19" r="1.6" /></svg>
                              )}
                            </button>
                            {menuOpen === key && (
                              <div className="cmp-nav__menu" onClick={(e) => e.stopPropagation()}>
                                <button
                                  className="cmp-nav__menu-item"
                                  disabled={!canCapture || !!activeRun}
                                  title={!canCapture ? 'Capture is not available in production' : (activeRun ? 'A capture is already running' : `Capture all ${items.length} components (iPhone)`)}
                                  onClick={() => captureGroup(key, items)}
                                >
                                  Capture all
                                </button>
                              </div>
                            )}
                          </div>
                        </div>
                        {isOpen && (
                          <div className="cmp-nav__group-items">
                            {items.map((c) => (
                              <button key={c.id} className={`nav__item cmp-nav__component${c.id === id ? ' nav__item--active' : ''}`} onClick={() => c.error ? null : goto(c.id)}>
                                <span className="cmp-nav__component-title">{c.error ? c.id : c.title}</span>
                                {!c.error && c.rating != null && <RatingDot rating={c.rating} />}
                                {!c.error && c.unresolvedComments > 0 && <span className="cmp-open-badge">{c.unresolvedComments}</span>}
                                {!c.error && c.completion && (
                                  <span
                                    className={`cmp-nav__pct${c.completion.pct === 100 ? ' cmp-nav__pct--done' : ''}`}
                                    title={`iPhone ${c.completion.iphoneCaptured}/${c.completion.total} captured · web ${c.completion.webBuilt}/${c.completion.total} built`}
                                  >
                                    {c.completion.pct}%
                                  </span>
                                )}
                                {!c.error && <ChevronR />}
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>

            {/* Level 2 — variants of the selected component (no versions) */}
            <div className="cmp-nav__pane">
              <button className="cmp-nav__back" onClick={() => navigate('/compare')}>
                <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6" /></svg>
                Components
              </button>
              <div className="cmp-nav__versions-title">{activeTitle}<span className="cmp-nav__versions-sub">variants</span></div>
              {/* Two header metadata: how many variants render on each platform. */}
              <div className="cmp-nav__counts">
                <span className="cmp-nav__count"><span className="cmp-nav__count-dot cmp-nav__count-dot--iphone" />iPhone render <strong>{variantInfo.counts.iphone}</strong></span>
                <span className="cmp-nav__count"><span className="cmp-nav__count-dot cmp-nav__count-dot--web" />web render <strong>{variantInfo.counts.web}</strong></span>
              </div>
              <div className="cmp-variant-list">
                {variantInfo.variants.map((v) => (
                  <NavLink key={v.name} to={`/compare/${id}/${encodeURIComponent(v.name)}`}
                    className={({ isActive }) => `cmp-variant-item${isActive ? ' cmp-variant-item--active' : ''}`}>
                    <span className="cmp-variant-item__name">{v.name}</span>
                    <span className="cmp-variant-item__platforms">
                      <span className={`cmp-variant-item__dot${v.iphone ? ' is-on' : ''}`} title={v.iphone ? 'iPhone captured' : 'iPhone not captured'}>iOS</span>
                      <span className={`cmp-variant-item__dot${v.web ? ' is-on' : ''}`} title={v.web ? 'renders on web' : 'no web twin'}>web</span>
                    </span>
                  </NavLink>
                ))}
                {id && variantInfo.variants.length === 0 && <div className="cmp-comments__empty">No variants defined for this component.</div>}
              </div>
            </div>
          </div>
        </aside>

        <main className={`layout__main${isDetail ? ' layout__main--bleed' : ' layout__main--browse'}`}>
          <Outlet />
        </main>
      </div>
    </CompareContext.Provider>
  );
}
