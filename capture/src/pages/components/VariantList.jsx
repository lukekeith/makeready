// Column 2 — variant navigation (component-browser 07 §3.2, R3).
//
// 1.0 variants are fixture variants; 2.0 variants are the contract's designed
// states, which carry a consumption status (consumed / designed-unconsumed /
// undesigned) instead of a captured-version count.
import React from 'react';

const CONSUMPTION_MARK = {
  consumed: { text: '●', title: 'consumed by a screen spec' },
  'designed-unconsumed': { text: '○', title: 'designed, not yet consumed' },
  unconsumed: { text: '○', title: 'not yet consumed' },
  undesigned: { text: '·', title: 'undesigned — proposed default awaiting a ruling' },
};

export default function VariantList({ detail, selectedVariant, onSelect, mode = 'code', emptyLabel }) {
  if (!detail) {
    return <div className="cmp-cb-col cmp-cb-col--variants"><div className="cmp-cb-col__empty">Select a component</div></div>;
  }
  const unwired = !detail.variants?.length;
  return (
    <div className="cmp-cb-col cmp-cb-col--variants">
      <div className="cmp-cb-col__title">{mode === 'design' ? 'States' : 'Variants'}</div>
      {unwired && <div className="cmp-cb-col__empty">{emptyLabel ?? 'no variants — component not capturable yet'}</div>}
      {!unwired && (detail.variants ?? []).map((v) => (
        <button
          key={v.name}
          className={`cmp-variant-item${v.name === selectedVariant ? ' cmp-variant-item--active' : ''}`}
          onClick={() => onSelect(v.name)}
        >
          <span className="cmp-variant-item__name" title={v.name}>{v.name}</span>
          {v.unresolvedComments > 0 && <span className="cmp-open-badge">{v.unresolvedComments}</span>}
          {mode === 'design' ? (
            <span
              className={`cmp-cb-variant__consumption cmp-cb-variant__consumption--${v.consumptionState}`}
              title={CONSUMPTION_MARK[v.consumptionState]?.title ?? v.consumption}
            >
              {CONSUMPTION_MARK[v.consumptionState]?.text ?? '·'}
            </span>
          ) : (
            <span className="cmp-cb-variant__vcount" title={`${v.versions.length} captured version(s)`}>{v.versions.length}</span>
          )}
        </button>
      ))}
    </div>
  );
}
