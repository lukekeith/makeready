// Column 4, UI 2.0 era — what the SELECTED STATE sets, and what calling it looks like.
//
// The Contract tab describes the whole component; this one is about one state.
// Everything here is derived from the contract doc: the assignments come from
// §3's matrix row crossed with §4's prop table, and the sample call is built
// from those two. Nothing is invented — a prop the contract doesn't carry does
// not appear, which is why the call is labelled derived rather than normative.
import React from 'react';
import CopyCode from '../../components/CopyCode.jsx';
import { sampleCall, previewTypeName } from '../../lib/ui2-sample-call.js';

function Section({ label, note, children }) {
  return (
    <div className="cmp-ui2d__section">
      <div className="cmp-ui2d__label">{label}{note && <span className="cmp-ui2d__note">{note}</span>}</div>
      {children}
    </div>
  );
}

/**
 * The screens that render this component — the mirror of the Screen tab's
 * component roll-call, and the same interaction: a chip SELECTS into the screen
 * pane rather than navigating away, so you can read what a screen says about this
 * component without losing the component you are looking at. The pane's own
 * open-in-new is the only thing that leaves.
 *
 * The count beside a chip is instances, summed over the screen's frames — how
 * many times the component is actually drawn there, which §4's roll-call cannot
 * say because it lists a row once however often it appears. A frame with no
 * element map contributes nothing rather than a zero, so a screen whose frames
 * are all unmapped shows no count at all instead of a false "×0".
 */
function ScreenChips({ screens, selected, onSelect }) {
  return (
    <div className="cmp-ui2s__chips">
      {screens.map((s) => {
        const counted = s.frames.filter((f) => f.instances !== null);
        const total = counted.reduce((n, f) => n + f.instances, 0);
        return (
          <button
            key={s.id}
            type="button"
            className={`cmp-ui2s__chip${s.specced ? '' : ' cmp-ui2s__chip--unspecced'}${s.id === selected ? ' is-active' : ''}`}
            onClick={() => onSelect(s.id)}
            title={s.specced
              ? `${s.name} — open what this screen says about this component`
              : `${s.id} is a README row with no spec yet`}
          >
            <span className="cmp-ui2s__chipname">{s.id}</span>
            {counted.length > 0 && <span className="cmp-ui2s__chipid">×{total}</span>}
          </button>
        );
      })}
    </div>
  );
}

export default function Ui2DetailsTab({ detail, variant, selectedScreen = null, onSelectScreen = null }) {
  if (!detail) return <div className="cmp-cb-col__empty">Select a component</div>;
  const screens = detail.screens ?? [];
  // Rendered in both branches below — an unspecced row can still be consumed by a
  // screen, and that is often the most useful thing the tab can say about it.
  const screensSection = onSelectScreen && screens.length > 0 && (
    <Section label={`Screens (${screens.length})`} note="every screen whose §4 renders this row">
      <ScreenChips screens={screens} selected={selectedScreen} onSelect={onSelectScreen} />
    </Section>
  );

  // No contract means no §3 and no §4 — there is nothing this state could set,
  // so the tab's job is to say what would produce one.
  if (!detail.contract) {
    return (
      <div className="cmp-ui2d">
        <Section label="Not specced yet">
          <p className="cmp-ui2d__prose">
            <code>{detail.id} {detail.name}</code> is a registry row without a contract, so it has
            no states and no props. Spec it first — then this tab shows what each state sets.
          </p>
          {detail.snapshot && (
            <p className="cmp-ui2d__prose">
              The render is the artwork a <code>/ui2-screen</code> run captured when it minted this
              row — enough to see what the row refers to, but it is a picture, not a contract:
              nothing here says which states exist or what they set.
            </p>
          )}
          <CopyCode value={detail.commands.spec} />
          {!detail.registry?.figmaUrl && detail.registry?.figmaRef && (
            <p className="cmp-ui2d__prose">
              Append the node URL — the registry’s ref doesn’t resolve to one:{' '}
              <code>{detail.registry.figmaRef}</code>
            </p>
          )}
        </Section>
        {screensSection}
      </div>
    );
  }

  const propRows = detail.contract.propRows ?? [];
  const propValues = variant?.propValues ?? [];
  const axisOnly = propValues.length > 0 && propValues.every((p) => p.axisOnly);
  const undesigned = variant?.consumptionState === 'undesigned';

  return (
    <div className="cmp-ui2d">
      <Section
        label={axisOnly ? 'Figma axis for this state' : 'Props set by this state'}
        note={variant?.name}
      >
        {undesigned && (
          <p className="cmp-ui2d__prose">
            This state is <strong>undesigned</strong> — the contract proposes a default and an open
            question is waiting on a ruling, so nothing is set here yet.
          </p>
        )}
        {!undesigned && propValues.length === 0 && (
          <p className="cmp-ui2d__prose">The matrix sets no props for this state.</p>
        )}
        {!undesigned && propValues.length > 0 && (
          <table className="cmp-ui2d__assign">
            <tbody>
              {propValues.map((p) => (
                <tr key={p.name}>
                  <td className="cmp-ui2d__pname">{p.name}</td>
                  <td className="cmp-ui2d__pval">{p.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {axisOnly && !undesigned && (
          <p className="cmp-ui2d__prose cmp-ui2d__prose--dim">
            §4 doesn’t name these columns as props, so this is the Figma variant axis rather than a
            prop assignment — see the Contract tab for how the axis maps onto props.
          </p>
        )}
      </Section>

      {screensSection}

      {!detail.built && (
        <Section label="Not built yet" note="no render to compare against Figma">
          <p className="cmp-ui2d__prose">
            The contract exists, so the props above are known — but nothing renders them yet.
            Build it, and this component gets a SwiftUI preview captured beside its Figma snapshot.
          </p>
          <CopyCode value={`/ui2-component-build ${detail.id}`} />
        </Section>
      )}

      {propRows.length > 0 && !undesigned && (
        <Section label="Sample call" note="derived from §4 — not normative">
          <CopyCode
            className="cmp-ui2d__code"
            value={sampleCall(previewTypeName(detail.name), propRows, propValues)}
            title="Click to copy the sample call"
          >
            <pre className="cmp-ui2d__pre">{sampleCall(previewTypeName(detail.name), propRows, propValues)}</pre>
          </CopyCode>
        </Section>
      )}

      {propRows.length > 0 ? (
        <Section label="Props contract" note="§4">
          {/* Stacked, not a 3-column table: a union type ("default |
              textButtons | twoIcons") shreds one character per line in a
              340px column. */}
          <dl className="cmp-ui2d__props">
            {propRows.map((p) => (
              <div className="cmp-ui2d__prop" key={p.name}>
                <dt>
                  <span className="cmp-ui2d__pname">{p.name}</span>
                  {p.type && <span className="cmp-ui2d__ptype">{p.type}</span>}
                </dt>
                {p.purpose && <dd className="cmp-ui2d__ppurpose">{p.purpose}</dd>}
              </div>
            ))}
          </dl>
        </Section>
      ) : (
        detail.contract.props && (
          <Section label="Props contract" note="§4 — written as prose">
            <pre className="cmp-ui2d__pre">{detail.contract.props}</pre>
          </Section>
        )
      )}
    </div>
  );
}
