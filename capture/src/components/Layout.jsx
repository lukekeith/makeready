import React, { useContext, useEffect, useState } from 'react';
import { NavLink, Outlet, useParams } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';
import CaptureButton from './CaptureButton.jsx';
import LogDrawer from './LogDrawer.jsx';

const COLLAPSED_KEY = 'capture-ui:collapsed-sets';

export default function Layout() {
  const { platforms, canCapture, manifest, manifestError, currentPlatform, setCurrentPlatform, activeRun, drawerVisible, setDrawerVisible } = useContext(CaptureContext);
  const params = useParams();

  // Sync platform from URL
  useEffect(() => {
    if (params.platform && params.platform !== currentPlatform) {
      setCurrentPlatform(params.platform);
    }
  }, [params.platform, currentPlatform, setCurrentPlatform]);

  const hasSet = Boolean(params.folder);
  const hasScreen = Boolean(params.folder && params.screen);

  const [collapsed, setCollapsed] = useState(() => {
    try {
      const raw = localStorage.getItem(COLLAPSED_KEY);
      return new Set(raw ? JSON.parse(raw) : []);
    } catch {
      return new Set();
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(COLLAPSED_KEY, JSON.stringify([...collapsed]));
    } catch {}
  }, [collapsed]);

  const toggleSet = (folder) => {
    setCollapsed((prev) => {
      const next = new Set(prev);
      if (next.has(folder)) next.delete(folder);
      else next.add(folder);
      return next;
    });
  };

  const p = params.platform || (platforms.length > 0 ? platforms[0].id : '');

  return (
    <div className="layout">
      <header className="layout__header">
        <div className="layout__brand">
          <span className="layout__brand-dot" />
          <NavLink to={`/${p}`}>MakeReady Capture</NavLink>
        </div>

        {/* Platform tabs */}
        <div className="layout__platform-tabs">
          {platforms.map((plat) => (
            <NavLink
              key={plat.id}
              to={`/${plat.id}`}
              className={({ isActive }) =>
                `layout__platform-tab${params.platform === plat.id ? ' layout__platform-tab--active' : ''}`
              }
            >
              {plat.title}
            </NavLink>
          ))}
        </div>

        {canCapture && (
          <div className="layout__capture-group">
            <span className="layout__capture-label">Capture</span>
            <CaptureButton scope="all" label="All" primary />
            <CaptureButton
              scope="set"
              target={hasSet ? params.folder : undefined}
              label="Set"
              primary
              disabled={!hasSet}
            />
            <CaptureButton
              scope="screen"
              target={hasScreen ? `${params.folder}/${params.screen}` : undefined}
              label="Screen"
              primary
              disabled={!hasScreen}
            />
            {activeRun && !drawerVisible && (
              <button
                className="layout__activity-btn"
                onClick={() => setDrawerVisible(true)}
                title="Show capture activity"
              >
                <span className="layout__activity-spinner" />
                Capturing…
              </button>
            )}
          </div>
        )}
      </header>

      <aside className="layout__sidebar">
        {manifestError && <div className="error-banner">{manifestError}</div>}
        <div className="nav__section">
          <div className="nav__section-title">Workflows</div>
          <NavLink
            to={`/${p}`}
            end
            className={({ isActive }) =>
              `nav__item${isActive ? ' nav__item--active' : ''}`
            }
          >
            All sets
          </NavLink>
        </div>
        {manifest?.sets?.map((set) => {
          const isCollapsed = collapsed.has(set.folder);
          return (
            <div key={set.folder} className="nav__section">
              <div className="nav__set-row">
                <button
                  type="button"
                  className={`nav__set-toggle${isCollapsed ? '' : ' nav__set-toggle--open'}`}
                  onClick={() => toggleSet(set.folder)}
                  aria-label={isCollapsed ? `Expand ${set.title}` : `Collapse ${set.title}`}
                  aria-expanded={!isCollapsed}
                >
                  <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden="true">
                    <path d="M3 2l4 3-4 3z" fill="currentColor" />
                  </svg>
                </button>
                <NavLink
                  to={`/${p}/set/${set.folder}`}
                  className={({ isActive }) =>
                    `nav__set${isActive ? ' nav__item--active' : ''}`
                  }
                >
                  <span>{set.title}</span>
                  <span className="nav__set-count">{set.screens?.length ?? 0}</span>
                </NavLink>
              </div>
              {!isCollapsed && (
                <div className="nav__screens">
                  {(set.screens ?? []).map((screen) => (
                    <NavLink
                      key={screen.file}
                      to={`/${p}/screen/${set.folder}/${screen.screen}`}
                      className={({ isActive }) =>
                        `nav__item${isActive ? ' nav__item--active' : ''}`
                      }
                    >
                      {screen.title}
                    </NavLink>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </aside>

      <main className="layout__main">
        <Outlet />
      </main>

      <LogDrawer />
    </div>
  );
}
