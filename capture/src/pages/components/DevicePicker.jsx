// Device picker — visible only when the fixture declares >1 viewport (D10).
import React from 'react';

export default function DevicePicker({ viewports = [], selected, onSelect }) {
  if (viewports.length <= 1) return null;
  return (
    <div className="cmp-tab-switch" role="group" aria-label="Viewport">
      {viewports.map((vp) => (
        <button
          key={vp}
          className={`cmp-tab-switch__btn${vp === selected ? ' cmp-tab-switch__btn--active' : ''}`}
          onClick={() => onSelect(vp)}
        >
          {vp}
        </button>
      ))}
    </div>
  );
}
