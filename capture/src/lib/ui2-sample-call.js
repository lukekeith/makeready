/**
 * Turning a contract state into the Swift call that renders it.
 *
 * Lifted out of Ui2DetailsTab (2026-09-12) when the screen pane needed the same
 * rendering for its schemas: a component's Details tab shows the call for the
 * SELECTED state, and the screen pane shows one per state a screen consumes.
 * Two readers, one derivation — a second copy would have drifted the moment
 * either changed.
 *
 * Everything here is derived from the contract: §3's matrix row crossed with
 * §4's prop table. Nothing is invented, which is why the call is always labelled
 * derived rather than normative.
 */
/** The Swift type the preview-build lane actually generates for a registry row
 *  (`docs/ui2/preview-build.md` §2, `.claude/commands/ui2-component-build.md`
 *  phase 3): the registry name, plain. Preview views compile into their own
 *  `MakeReadyUI` module, so the six rows that share a name with a 1.0 struct
 *  need no prefix — a module namespaces them, which a folder cannot. */
export function previewTypeName(name) {
  return name;
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
export function sampleCall(name, propRows, propValues) {
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
