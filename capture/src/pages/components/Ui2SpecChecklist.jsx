// The 2.0 counterpart of WiringChecklist: this registry row exists but has no
// contract doc yet, so there is nothing to render. Show what the registry knows
// and the command that specs it (/ui2-component — UI 2.0 D10).
//
// The command is RUNNABLE, not a template: the server resolves the row's Figma node URL
// out of the registry ref and appends it, so clicking copy gives you something you can
// paste as-is. When the ref cites several nodes (or none) there is no single node to
// link, so the bare command is copied and the raw ref is shown to append by hand — never
// a guessed link, which would point a spec run at the wrong symbol.
import React from 'react';
import CopyCode from '../../components/CopyCode.jsx';

export default function Ui2SpecChecklist({ detail }) {
  // A SCREEN reaches here the same way — a README row with no spec doc — but its
  // artefacts and its command are different, so it gets its own checklist rather
  // than being told to write a component contract.
  if (detail.kind === 'screen') {
    const pending = detail.figma === 'pending-figma';
    const screenChecks = [
      { ok: true, label: 'README screen row', hint: `${detail.section} · status ${detail.status}` },
      { ok: !pending, label: 'Figma frame', hint: pending ? 'not designed yet — the row is waiting on Figma' : detail.figma },
      { ok: false, label: 'Screen spec', hint: `docs/ui2/screens/${detail.id}.md` },
      { ok: false, label: 'Frozen frame(s)', hint: 'docs/ui2/screens/assets/ — the render this browser shows' },
    ];
    return (
      <div className="cmp-cb-wiring">
        <div className="cmp-cb-col__title">Not specced yet</div>
        <p className="cmp-cb-wiring__intro">
          <code>{detail.id}</code> is a row in the README screen table — the exhaustive screen
          universe — but its spec hasn’t been written, so there is nothing to render or comment
          on yet.
        </p>
        <ul className="cmp-cb-wiring__list">
          {screenChecks.map((c) => (
            <li key={c.label} className={`cmp-cb-wiring__check${c.ok ? ' is-ok' : ''}`}>
              <span className="cmp-cb-wiring__mark">{c.ok ? '✓' : '✗'}</span>
              <span>
                <strong>{c.label}</strong>
                <span className="cmp-cb-wiring__hint">{c.hint}</span>
              </span>
            </li>
          ))}
        </ul>
        {detail.notes && <p className="cmp-cb-wiring__intro"><strong>README says:</strong> {detail.notes}</p>}
        <CopyCode value={detail.commands.spec} />
        {pending && (
          <p className="cmp-cb-wiring__intro">
            <strong>Append the frame URL</strong> when the design lands — <code>/ui2-screen</code> takes
            it as its second argument.
          </p>
        )}
      </div>
    );
  }

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
      <CopyCode value={detail.commands.spec} />
      {!reg.figmaUrl && reg.figmaRef && (
        <p className="cmp-cb-wiring__intro">
          <strong>Append the node URL:</strong> the registry’s ref doesn’t resolve to a single
          node — <code>{reg.figmaRef}</code>
        </p>
      )}
    </div>
  );
}
