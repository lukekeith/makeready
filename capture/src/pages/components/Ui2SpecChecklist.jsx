// The 2.0 counterpart of WiringChecklist: this registry row exists but has no
// contract doc yet, so there is nothing to render. Show what the registry knows
// and the command that specs it (/ui2-component — UI 2.0 D10).
import React from 'react';
import CopyCode from '../../components/CopyCode.jsx';

export default function Ui2SpecChecklist({ detail }) {
  const reg = detail.registry ?? {};
  const checks = [
    { ok: true, label: 'Registry row', hint: `${detail.section} · status ${detail.status}` },
    { ok: false, label: 'Contract doc', hint: `docs/ui2/design-system/components/${detail.id}-<slug>.md` },
    { ok: false, label: 'Frozen Figma snapshot', hint: 'design-system/components/assets/ — the render this browser shows' },
  ];
  return (
    <div className="cmp-cb-wiring">
      <div className="cmp-cb-col__title">Not specced yet</div>
      <p className="cmp-cb-wiring__intro">
        <code>{detail.id} {detail.name}</code> is in the 2.0 registry — the exhaustive component
        universe — but its contract hasn’t been written, so there is nothing to render or
        comment on yet.
      </p>
      <ul className="cmp-cb-wiring__list">
        {checks.map((c) => (
          <li key={c.label} className={`cmp-cb-wiring__check${c.ok ? ' is-ok' : ''}`}>
            <span className="cmp-cb-wiring__mark">{c.ok ? '✓' : '✗'}</span>
            <span>
              <strong>{c.label}</strong>
              <span className="cmp-cb-wiring__hint">{c.hint}</span>
            </span>
          </li>
        ))}
      </ul>
      {reg.variantsProse && (
        <p className="cmp-cb-wiring__intro"><strong>Registry says:</strong> {reg.variantsProse}</p>
      )}
      <CopyCode value={`${detail.commands.spec} <figma-url>`} />
    </div>
  );
}
