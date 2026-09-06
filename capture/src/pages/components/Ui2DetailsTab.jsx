// Column 4, UI 2.0 era — what the SELECTED STATE sets, and what calling it looks like.
//
// The Contract tab describes the whole component; this one is about one state.
// Everything here is derived from the contract doc: the assignments come from
// §3's matrix row crossed with §4's prop table, and the sample call is built
// from those two. Nothing is invented — a prop the contract doesn't carry does
// not appear, which is why the call is labelled derived rather than normative.
import React from 'react';
import CopyCode from '../../components/CopyCode.jsx';

/** The Swift type the preview-build lane actually generates for a registry row
 *  (`docs/ui2/preview-build.md` §2, `.claude/commands/ui2-component-build.md`
 *  phase 3): `UI2` + the registry name, uniformly — not only on the six rows
 *  that collide with a 1.0 struct. This is a Swift-namespace fact only: the
 *  ViewRegistry case key and the registry id stay unprefixed. */
function previewTypeName(name) {
  return `UI2${name}`;
}

/** `default | textButtons | twoIcons` → the member matching a matrix cell. */
function enumCase(type, value) {
  const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
  const options = type.split('|').map((o) => o.trim()).filter(Boolean);
  return options.find((o) => norm(o) === norm(value)) ?? null;
}

/** A matrix cell rendered as Swift, read through the prop's declared type. */
function swiftValue(type = '', value = '') {
  if (/^(true|false)$/i.test(value)) return value.toLowerCase();
  if (type.includes('|')) {
    const match = enumCase(type, value);
    if (match) return `.${match}`;
  }
  if (/^-?\d+(\.\d+)?$/.test(value)) return value;
  return `"${value}"`;
}

/** A prop the state doesn't set still has to appear if it isn't optional. */
function swiftPlaceholder(type = '') {
  if (type.includes('->')) return '{ … }';
  if (/^Binding</.test(type)) return '$value';
  if (/^\[/.test(type)) return '[]';
  if (/\bBool\b/.test(type)) return 'true';
  if (/\bInt\b|\bDouble\b/.test(type)) return '0';
  if (/\bString\b/.test(type)) return '"…"';
  return '…';
}

/**
 * The call site. Assigned props take the state's values; unassigned ones appear
 * only when required (an optional type carries its own "omit me").
 */
function sampleCall(name, propRows, propValues) {
  const assigned = new Map(propValues.map((p) => [p.name.toLowerCase(), p.value]));
  const lines = [];
  for (const prop of propRows) {
    const value = assigned.get(prop.name.toLowerCase());
    if (value !== undefined) lines.push(`  ${prop.name}: ${swiftValue(prop.type, value)},`);
    else if (!prop.type.trim().endsWith('?')) lines.push(`  ${prop.name}: ${swiftPlaceholder(prop.type)},`);
  }
  if (!lines.length) return `${name}()`;
  lines[lines.length - 1] = lines[lines.length - 1].replace(/,$/, '');
  return `${name}(\n${lines.join('\n')}\n)`;
}

function Section({ label, note, children }) {
  return (
    <div className="cmp-ui2d__section">
      <div className="cmp-ui2d__label">{label}{note && <span className="cmp-ui2d__note">{note}</span>}</div>
      {children}
    </div>
  );
}

export default function Ui2DetailsTab({ detail, variant }) {
  if (!detail) return <div className="cmp-cb-col__empty">Select a component</div>;

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
          <CopyCode value={`${detail.commands.spec} <figma-url>`} />
        </Section>
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
