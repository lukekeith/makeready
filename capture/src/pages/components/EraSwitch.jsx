// The 1.0 ⇄ 2.0 switch at the top of column 1.
//
// It switches the browser's SOURCE, not a filter over one list: 1.0 is the
// filesystem of built Swift components (lib/fs-index.mjs), 2.0 is the UI 2.0
// registry of specced-but-unbuilt components (lib/ui2-index.mjs). The two have
// different identity (fs path vs C-###) and different render truth (simulator
// capture vs frozen Figma snapshot), so a segment — permanent, never "off" —
// is the honest control. It sits ABOVE the search field because it changes what
// is being searched.
import React from 'react';
import { NavLink } from 'react-router-dom';

export const ERAS = [
  { id: '1.0', label: '1.0', title: 'Built iPhone components (iphone/MakeReady/Components)' },
  { id: '2.0', label: '2.0', title: 'UI 2.0 registry — specced components (docs/ui2)' },
];

export default function EraSwitch({ era }) {
  return (
    <div className="cmp-era" role="group" aria-label="UI era">
      {ERAS.map((e) => (
        <NavLink
          key={e.id}
          to={`/components/${e.id}`}
          title={e.title}
          className={`cmp-era__btn${era === e.id ? ' cmp-era__btn--active' : ''}`}
          aria-current={era === e.id ? 'page' : undefined}
        >
          UI {e.label}
        </NavLink>
      ))}
    </div>
  );
}
