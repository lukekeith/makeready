// Column 2 — variant navigation (component-browser 07 §3.2, R3).
import React from 'react';

export default function VariantList({ detail, selectedVariant, onSelect }) {
  if (!detail) {
    return <div className="cmp-cb-col cmp-cb-col--variants"><div className="cmp-cb-col__empty">Select a component</div></div>;
  }
  const unwired = !detail.variants?.length && detail.wiring;
  return (
    <div className="cmp-cb-col cmp-cb-col--variants">
      <div className="cmp-cb-col__title">Variants</div>
      {unwired && <div className="cmp-cb-col__empty">no variants — component not capturable yet</div>}
      {!unwired && (detail.variants ?? []).map((v) => (
        <button
          key={v.name}
          className={`cmp-variant-item${v.name === selectedVariant ? ' cmp-variant-item--active' : ''}`}
          onClick={() => onSelect(v.name)}
        >
          <span className="cmp-variant-item__name">{v.name}</span>
          {v.unresolvedComments > 0 && <span className="cmp-open-badge">{v.unresolvedComments}</span>}
          <span className="cmp-cb-variant__vcount" title={`${v.versions.length} captured version(s)`}>{v.versions.length}</span>
        </button>
      ))}
    </div>
  );
}
