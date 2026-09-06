// Column 4, UI 2.0 era — the component's normative contract.
//
// The 2.0 counterpart of the Data tab: a 1.0 component's truth is its fixture
// data, a 2.0 component's truth is its spec. Everything here is read from
// docs/ui2 (registry row + contract doc) — the browser never edits specs.
import React from 'react';

const CONSUMPTION_LABEL = {
  consumed: 'consumed',
  'designed-unconsumed': 'designed, unconsumed',
  unconsumed: 'unconsumed',
  undesigned: 'undesigned',
  unknown: '—',
};

function Field({ label, children }) {
  if (!children) return null;
  return (
    <div className="cmp-ui2c__field">
      <div className="cmp-ui2c__label">{label}</div>
      <div className="cmp-ui2c__value">{children}</div>
    </div>
  );
}

export default function Ui2ContractTab({ detail, variant }) {
  if (!detail) return <div className="cmp-cb-col__empty">Select a component</div>;
  const c = detail.contract;
  const reg = detail.registry ?? {};

  return (
    <div className="cmp-ui2c">
      <div className="cmp-ui2c__head">
        <span className="cmp-ui2c__id">{detail.id}</span>
        <span className="cmp-ui2c__name">{detail.name}</span>
        <span className={`cmp-ui2c__status cmp-ui2c__status--${detail.status}`}>{detail.status}</span>
      </div>
      {c?.summary && <div className="cmp-ui2c__summary">{c.summary}</div>}
      {detail.nameNote && <div className="cmp-ui2c__note">{detail.nameNote}</div>}

      <Field label="Figma">
        {c?.figmaUrl
          ? <a href={c.figmaUrl} target="_blank" rel="noreferrer" className="cmp-ui2c__link">{reg.figmaRef || 'open in Figma'}</a>
          : (reg.figmaRef || null)}
      </Field>
      <Field label="Platform">{detail.platform}</Field>
      <Field label="Defined in">{reg.definedIn}</Field>
      <Field label="Consumed by">{reg.consumedBy}</Field>

      {variant && (
        <Field label={`State — ${variant.name}`}>
          <span className={`cmp-ui2c__consumption cmp-ui2c__consumption--${variant.consumptionState}`}>
            {CONSUMPTION_LABEL[variant.consumptionState] ?? variant.consumptionState}
          </span>
          {variant.consumption ? <div className="cmp-ui2c__body">{variant.consumption}</div> : null}
        </Field>
      )}

      {c?.props && (
        <Field label="Props contract"><pre className="cmp-ui2c__pre">{c.props}</pre></Field>
      )}

      {c?.openQuestions?.length > 0 && (
        <Field label={`Open questions (${c.openQuestions.length})`}>
          <ul className="cmp-ui2c__oq">
            {c.openQuestions.map((q) => (
              <li key={q.id ?? q.question} className={q.blocking ? 'is-blocking' : ''}>
                {q.id && <span className="cmp-ui2c__oqid">{q.id}</span>}
                {q.question}
              </li>
            ))}
          </ul>
        </Field>
      )}

      {c?.anatomy && <Field label="Anatomy & geometry"><pre className="cmp-ui2c__pre">{c.anatomy}</pre></Field>}
      {c?.composition && <Field label="Composition"><pre className="cmp-ui2c__pre">{c.composition}</pre></Field>}
      {c?.file && <Field label="Contract"><code className="cmp-ui2c__file">{c.file}</code></Field>}
    </div>
  );
}
