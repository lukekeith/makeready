import React, { useContext, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';
import { fetchFixture, fetchBladeComponents } from '../api.js';
import CopyCode from '../components/CopyCode.jsx';
import { viewToBladePath } from '../util/paths.js';

function ViewportImage({ src, alt }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  if (failed) {
    return <div className="viewport__img--missing">not captured</div>;
  }
  return (
    <img
      className="viewport__img"
      src={src}
      alt={alt}
      onError={() => setFailed(true)}
    />
  );
}

function pickMinMaxViewports(viewports, dimensions) {
  if (!viewports?.length) return [];
  if (viewports.length === 1) return [viewports[0]];
  const withWidth = viewports
    .map((name) => ({ name, width: dimensions?.[name]?.width ?? null }))
    .filter((v) => v.width != null);
  if (withWidth.length < 2) {
    return [viewports[0], viewports[viewports.length - 1]];
  }
  const min = withWidth.reduce((a, b) => (a.width <= b.width ? a : b));
  const max = withWidth.reduce((a, b) => (a.width >= b.width ? a : b));
  return min.name === max.name ? [min.name] : [min.name, max.name];
}

export default function ScreenDetail() {
  const { platform, folder, screen } = useParams();
  const { manifest, capturesVersion, activeRun } = useContext(CaptureContext);
  const [fixture, setFixture] = useState(null);
  const [fixtureError, setFixtureError] = useState(null);
  const [selected, setSelected] = useState(() => new Set());
  const [activeTab, setActiveTab] = useState('json');
  const [components, setComponents] = useState(null);
  const [componentsError, setComponentsError] = useState(null);

  const isClient = platform === 'client';

  const set = manifest?.sets?.find((s) => s.folder === folder);
  const screenMeta = set?.screens?.find((s) => s.screen === screen);
  const file = screenMeta?.file ?? `${screen}.json`;
  const viewports = useMemo(() => screenMeta?.viewports ?? [], [screenMeta]);

  const seededKeyRef = useRef(null);
  useEffect(() => {
    const key = `${platform}/${folder}/${screen}`;
    if (seededKeyRef.current === key) return;
    if (viewports.length === 0) return;
    const defaults = pickMinMaxViewports(viewports, manifest?.viewportDimensions);
    setSelected(new Set(defaults));
    seededKeyRef.current = key;
  }, [platform, folder, screen, viewports, manifest?.viewportDimensions]);

  const isCapturing =
    !!activeRun &&
    (activeRun.scope === 'all' ||
      (activeRun.scope === 'set' && activeRun.target === folder) ||
      (activeRun.scope === 'screen' && activeRun.target === `${folder}/${screen}`));

  const [captureStartVersion, setCaptureStartVersion] = useState(null);
  useEffect(() => {
    if (isCapturing) setCaptureStartVersion(capturesVersion);
    else setCaptureStartVersion(null);
  }, [isCapturing]);
  const showSpinner =
    isCapturing && captureStartVersion !== null && capturesVersion === captureStartVersion;

  useEffect(() => {
    let cancelled = false;
    setFixture(null);
    setFixtureError(null);
    fetchFixture(platform, folder, file)
      .then((data) => { if (!cancelled) setFixture(data); })
      .catch((err) => { if (!cancelled) setFixtureError(err.message); });
    return () => { cancelled = true; };
  }, [platform, folder, file]);

  // Blade components (client-only)
  const view = fixture?.view ?? screenMeta?.view ?? null;
  const step = fixture?.step ?? null;
  useEffect(() => {
    if (!isClient || !view) {
      setComponents(null);
      setComponentsError(null);
      return;
    }
    let cancelled = false;
    setComponents(null);
    setComponentsError(null);
    fetchBladeComponents(view, step)
      .then((data) => { if (!cancelled) setComponents(data); })
      .catch((err) => { if (!cancelled) setComponentsError(err.message); });
    return () => { cancelled = true; };
  }, [isClient, view, step, capturesVersion]);

  if (!manifest) return <div className="empty-state">Loading manifest...</div>;
  if (!set || !screenMeta) {
    return (
      <div className="empty-state">
        Screen <code>{folder}/{screen}</code> not found.
      </div>
    );
  }

  const toggle = (v) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(v)) next.delete(v);
      else next.add(v);
      return next;
    });
  };
  const selectAll = () => setSelected(new Set(viewports));
  const selectNone = () => setSelected(new Set());
  const shown = viewports.filter((v) => selected.has(v));

  return (
    <>
      <div className="page-head">
        <div>
          <div className="page-head__crumbs">
            <Link to={`/${platform}`}>All sets</Link> /{' '}
            <Link to={`/${platform}/set/${folder}`}>{set.title}</Link> / {screen}
          </div>
          <h1 className="page-head__title">{screenMeta.title}</h1>
          <div className="page-head__subtitle">
            <CopyCode value={`capture/${folder}/${file}`} />
            {(() => {
              if (isClient) {
                const blade = viewToBladePath(fixture?.view ?? screenMeta.view);
                const stepVal = fixture?.step ?? screenMeta.step ?? null;
                if (!blade) return null;
                const value = stepVal ? `${blade} ($step === '${stepVal}')` : blade;
                return (
                  <>
                    {' \u00b7 '}
                    <CopyCode value={value} title="Blade path" />
                  </>
                );
              }
              if (fixture?.view) {
                return (
                  <>
                    {' \u00b7 '}
                    <CopyCode value={fixture.view} title="SwiftUI view identifier" />
                  </>
                );
              }
              return null;
            })()}
          </div>
        </div>
      </div>

      {viewports.length > 1 && (
        <div className="viewport-picker">
          <div className="viewport-picker__toolbar">
            <span className="viewport-picker__label">
              Compare <strong>{shown.length}</strong> of {viewports.length}
            </span>
            <div className="viewport-picker__actions">
              <button className="btn btn--mini" onClick={selectAll}>All</button>
              <button className="btn btn--mini" onClick={selectNone}>None</button>
            </div>
          </div>
          <div className="viewport-picker__chips">
            {viewports.map((v) => (
              <button
                key={v}
                className={`chip${selected.has(v) ? ' chip--active' : ''}`}
                onClick={() => toggle(v)}
                aria-pressed={selected.has(v)}
              >
                {v}
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="viewports">
        {shown.map((viewport) => {
          const src = `/screenshots/${platform}/${folder}/screenshots/${viewport}/${screenMeta.output}?v=${capturesVersion}`;
          const dims = manifest?.viewportDimensions?.[viewport];
          const previewHref = isClient && dims
            ? `/${platform}/preview/${encodeURIComponent(folder)}/${encodeURIComponent(screen)}/${dims.width}x${dims.height}?viewport=${encodeURIComponent(viewport)}`
            : null;
          return (
            <div className="viewport" key={viewport}>
              <ViewportImage src={src} alt={viewport} />
              <div className="viewport__actions">
                <a className="viewport__action" href={src} target="_blank" rel="noreferrer"
                  title="Open screenshot image in a new tab" aria-label="Open screenshot image">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
                    <circle cx="8.5" cy="8.5" r="1.5" />
                    <polyline points="21 15 16 10 5 21" />
                  </svg>
                </a>
                {previewHref && (
                  <a className="viewport__action" href={previewHref} target="_blank" rel="noreferrer"
                    title={`Open live preview in a new tab, locked to ${dims.width}\u00d7${dims.height}`}
                    aria-label="Open live preview">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <polyline points="16 18 22 12 16 6" />
                      <polyline points="8 6 2 12 8 18" />
                    </svg>
                  </a>
                )}
              </div>
              <div className="viewport__label">
                {viewport}
                {manifest?.viewportDimensions?.[viewport] && (
                  <span className="viewport__label-dims">
                    {' '}
                    {manifest.viewportDimensions[viewport].width}x
                    {manifest.viewportDimensions[viewport].height}
                  </span>
                )}
              </div>
              {showSpinner && (
                <div className="viewport__spinner-overlay" aria-hidden="true">
                  <div className="viewport__spinner" />
                </div>
              )}
            </div>
          );
        })}
        {shown.length === 0 && (
          <div className="empty-state" style={{ flex: 1 }}>
            {viewports.length === 0
              ? 'No viewports declared in this fixture.'
              : 'Pick one or more viewports above to compare.'}
          </div>
        )}
      </div>

      <div className="fixture-panel">
        <div className="fixture-panel__tabs" role="tablist">
          <button type="button" role="tab" aria-selected={activeTab === 'json'}
            className={`fixture-panel__tab${activeTab === 'json' ? ' fixture-panel__tab--active' : ''}`}
            onClick={() => setActiveTab('json')}>
            JSON
          </button>
          {isClient && (
            <button type="button" role="tab" aria-selected={activeTab === 'components'}
              className={`fixture-panel__tab${activeTab === 'components' ? ' fixture-panel__tab--active' : ''}`}
              onClick={() => setActiveTab('components')}>
              Components
              {components?.components?.length ? (
                <span className="fixture-panel__tab-count">{components.components.length}</span>
              ) : null}
            </button>
          )}
        </div>

        {activeTab === 'json' && (
          <pre className="fixture-panel__pre">
            {fixtureError ? fixtureError : fixture ? JSON.stringify(fixture, null, 2) : 'loading...'}
          </pre>
        )}

        {activeTab === 'components' && isClient && (
          <div className="fixture-panel__body">
            {componentsError ? (
              <div className="empty-state" style={{ padding: 16 }}>{componentsError}</div>
            ) : !view ? (
              <div className="empty-state" style={{ padding: 16 }}>This fixture has no <code>view</code> field.</div>
            ) : !components ? (
              <div className="component-list__loading">loading...</div>
            ) : components.components.length === 0 ? (
              <div className="empty-state" style={{ padding: 16 }}>
                No <code>&lt;x-*&gt;</code> or <code>data-vue</code> components found.
              </div>
            ) : (
              <ul className="component-list">
                <li className="component-list__view">
                  <span className="component-list__label">View</span>
                  <CopyCode value={components.viewPath}>{components.viewPath}</CopyCode>
                </li>
                {components.components.map((c) => (
                  <li key={c.name} className={`component-list__item${c.exists ? '' : ' component-list__item--missing'}`}>
                    <CopyCode value={c.name} className="component-list__name" title={`Copy: ${c.name}`}>{c.name}</CopyCode>
                    {c.path ? <CopyCode value={c.path} title={`Copy: ${c.path}`}>{c.path}</CopyCode>
                      : <span className="component-list__tag" title="No source file resolved">unresolved</span>}
                    {c.kind === 'vue-island' && <span className="component-list__tag" title="Vue island mounted via data-vue">vue island</span>}
                    {c.kind === 'vue-child' && <span className="component-list__tag" title={`Imported by ${c.parent}`}>vue - via {c.parent}</span>}
                    {!c.exists && c.path && <span className="component-list__tag" title="File not found on disk">missing</span>}
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>
    </>
  );
}
