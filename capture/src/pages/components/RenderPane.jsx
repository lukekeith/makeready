// Column 3 — render pane. Phase 2 placeholder: shows the current shot statically
// (wiring checklist for unwired components); the ZoomPane + version timeline +
// comment mode + recapture land in Phase 3 (12-phase-3 doc).
import React from 'react';

export default function RenderPane({ detail, detailError, variant }) {
  if (detailError) return <div className="cmp-cb-col cmp-cb-col--render"><div className="error-banner">{detailError}</div></div>;
  if (!detail || !variant) {
    return <div className="cmp-cb-col cmp-cb-col--render"><div className="cmp-cb-col__empty">{detail ? 'Component not capturable yet' : 'Select a component and variant'}</div></div>;
  }
  const current = variant.versions?.[0] ?? null;
  return (
    <div className="cmp-cb-col cmp-cb-col--render">
      <div className="cmp-cb-col__title">{detail.name} · {variant.name}</div>
      {current?.shot
        ? <div className="cmp-cb-rendershell"><img className="cmp-cb-rendershell__img" src={current.shot} alt={`${detail.name} ${variant.name}`} /></div>
        : <div className="cmp-cb-col__empty">never captured</div>}
    </div>
  );
}
