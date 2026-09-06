// The one header every capture UI renders (/client, /iphone, /compare,
// /components). Brand → tab row → per-UI actions slot → live indicator.
// Keeping it in a single component is why the four UIs can't drift apart again:
// the tab list, the active-tab rule and the Live pill have one implementation.
import React, { useContext } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';

// Rendered until /api/platforms answers so the tab row never pops in. Ids and
// titles mirror server.mjs's sharedPlatforms.
const FALLBACK_PLATFORMS = [
  { id: 'client', title: 'Web' },
  { id: 'iphone', title: 'iPhone' },
];

export default function AppHeader({ children }) {
  const ctx = useContext(CaptureContext);
  const { pathname } = useLocation();

  const platforms = ctx?.platforms?.length ? ctx.platforms : FALLBACK_PLATFORMS;
  const liveConnected = ctx?.liveConnected ?? false;

  // The first path segment IS the tab: /client, /iphone, /compare, /components.
  const active = pathname.split('/')[1] ?? '';

  const tabs = [
    ...platforms.map((p) => ({ key: p.id, to: `/${p.id}`, label: p.title })),
    { key: 'compare', to: '/compare', label: 'Compare' },
    { key: 'components', to: '/components', label: 'Components' },
  ];

  return (
    <header className="layout__header">
      <div className="layout__brand">
        <span className="layout__brand-dot" />
        <NavLink to="/">MakeReady Capture</NavLink>
      </div>

      <nav className="layout__platform-tabs" aria-label="Capture sections">
        {tabs.map((t) => {
          const isActive = active === t.key;
          return (
            <NavLink
              key={t.key}
              to={t.to}
              className={`layout__platform-tab${isActive ? ' layout__platform-tab--active' : ''}`}
              aria-current={isActive ? 'page' : undefined}
            >
              {t.label}
            </NavLink>
          );
        })}
      </nav>

      <div className="layout__header-right">
        {children}
        <span
          className={`layout__live${liveConnected ? ' is-on' : ''}`}
          title={liveConnected ? 'Live — the view auto-updates when captures complete' : 'Live updates offline'}
        >
          <span className="layout__live-dot" />
          Live
        </span>
      </div>
    </header>
  );
}
