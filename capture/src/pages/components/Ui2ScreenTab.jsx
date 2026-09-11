// Column 4, UI 2.0 era — a SCREEN's normative spec.
//
// The screen counterpart of Ui2ContractTab. A component's truth is its contract
// doc; a screen's is `docs/ui2/screens/<id>.md`, and the one thing this tab adds
// over dumping that file is the component roll-call: §4's C-### list resolved
// against the registry, so every part of the screen is one click away and a row
// that has never been specced is visible AS unspecced right here.
import React from 'react';
import { useNavigate } from 'react-router-dom';

function Field({ label, children }) {
  if (!children) return null;
  return (
    <div className="cmp-ui2c__field">
      <div className="cmp-ui2c__label">{label}</div>
      <div className="cmp-ui2c__value">{children}</div>
    </div>
  );
}

export default function Ui2ScreenTab({ detail, variant }) {
  const navigate = useNavigate();
  if (!detail) return <div className="cmp-cb-col__empty">Select a screen</div>;
  const spec = detail.spec;

  if (!spec) {
    return (
      <div className="cmp-ui2d">
        <div className="cmp-ui2c__head">
          <span className="cmp-ui2c__name">{detail.id}</span>
          <span className={`cmp-ui2c__status cmp-ui2c__status--${detail.status}`}>{detail.status}</span>
        </div>
        <p className="cmp-ui2d__prose">
          This screen is a row in the README screen table with no spec yet, so it has no
          layout contract, no components and no frozen frames. {detail.figma === 'pending-figma'
            ? 'Its design has not arrived — the row is waiting on Figma.'
            : 'Run the spec command to write it.'}
        </p>
        {detail.notes && <p className="cmp-ui2d__prose cmp-ui2c__note">{detail.notes}</p>}
      </div>
    );
  }

  return (
    <div className="cmp-ui2c">
      <div className="cmp-ui2c__head">
        <span className="cmp-ui2c__name">{detail.id}</span>
        <span className={`cmp-ui2c__status cmp-ui2c__status--${detail.status}`}>{detail.status}</span>
      </div>
      {spec.name && <div className="cmp-ui2c__summary">{spec.name}</div>}
      {spec.statusLine && <div className="cmp-ui2c__note">{spec.statusLine}</div>}

      <Field label="Figma">
        {spec.figmaUrl
          ? <a href={spec.figmaUrl} target="_blank" rel="noreferrer" className="cmp-ui2c__link">open the frame in Figma</a>
          : (detail.figma || null)}
      </Field>
      <Field label="Platform">{detail.platform}</Field>

      {variant && (
        <Field label={`Frame — ${variant.name}`}>
          <code className="cmp-ui2c__file">{variant.snapshotFile}</code>
        </Field>
      )}

      {detail.components?.length > 0 && (
        <Field label={`Components (${detail.components.length})`}>
          <div className="cmp-ui2s__chips">
            {detail.components.map((c) => (
              <button
                key={c.id}
                className={`cmp-ui2s__chip${c.specced ? '' : ' cmp-ui2s__chip--unspecced'}`}
                onClick={() => navigate(`/components/2.0/${c.id}`)}
                title={c.specced ? 'specced — open its contract' : 'registry row only — no contract yet'}
              >
                <span className="cmp-ui2s__chipid">{c.id}</span>
                {c.name && <span className="cmp-ui2s__chipname">{c.name}</span>}
              </button>
            ))}
          </div>
        </Field>
      )}

      {spec.openQuestions?.length > 0 && (
        <Field label={`Open questions (${spec.openQuestions.length})`}>
          <ul className="cmp-ui2c__oq">
            {spec.openQuestions.map((q) => (
              <li key={q.id ?? q.question} className={q.blocking ? 'is-blocking' : ''}>
                {q.id && <span className="cmp-ui2c__oqid">{q.id}</span>}
                {q.question}
              </li>
            ))}
          </ul>
        </Field>
      )}

      {spec.normativeSource && <Field label="Normative source"><pre className="cmp-ui2c__pre">{spec.normativeSource}</pre></Field>}
      {spec.layout && <Field label="Layout contract"><pre className="cmp-ui2c__pre">{spec.layout}</pre></Field>}
      {spec.behavior && <Field label="Behavior contract"><pre className="cmp-ui2c__pre">{spec.behavior}</pre></Field>}
      {spec.dataApi && <Field label="Data & API"><pre className="cmp-ui2c__pre">{spec.dataApi}</pre></Field>}
      {spec.connections && <Field label="Connections"><pre className="cmp-ui2c__pre">{spec.connections}</pre></Field>}
      {spec.legacy && <Field label="Legacy mapping"><pre className="cmp-ui2c__pre">{spec.legacy}</pre></Field>}
      {spec.file && <Field label="Spec"><code className="cmp-ui2c__file">{spec.file}</code></Field>}
    </div>
  );
}
