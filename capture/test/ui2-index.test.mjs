/**
 * UI 2.0 spec index — registry + contract parsing (lib/ui2-index.mjs).
 *
 * The parsers are pure, so they run against fixture markdown shaped like the
 * real docs (including the three state-matrix table shapes the seven current
 * contracts use); buildUi2Index() is then exercised once against the REAL
 * docs/ui2 to catch drift between the parser and the documents it indexes.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseRegistry, parseContract, buildUi2Index, ui2ComparisonId, ui2Counts } from '../lib/ui2-index.mjs';

const REGISTRY = `# UI 2.0 Component Registry

## Rules

- IDs are \`C-###\`.

## Row format

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |

## Primitives

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-021 | GlyphButton | new | ios | set 3499:27547 | 9 designed glyphs | glyph, action | \`screens/home-dashboard.md\` §4 | home-dashboard |
| C-052 | DayChip (renamed from DayCell 2026-09-02; ID stable) | new | ios | mains 3495:2777 | Default / Active | day, state | \`screens/study-program-home.md\` §4 | study-program-home |

## Overlays

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-066 | ActionMenuOverlay | existing-modified | both | set 3883:9315 | single designed variant | actions | \`components/C-066-action-menu-overlay.md\` | — |
`;

test('parseRegistry reads only row-bearing sections, splitting rename notes', () => {
  const sections = parseRegistry(REGISTRY);
  assert.deepEqual(sections.map((s) => s.name), ['Primitives', 'Overlays']);

  const [glyph, day] = sections[0].rows;
  assert.equal(glyph.id, 'C-021');
  assert.equal(glyph.name, 'GlyphButton');
  assert.equal(glyph.nameNote, null);
  assert.equal(glyph.status, 'new');
  assert.equal(glyph.platform, 'ios');
  assert.equal(glyph.section, 'Primitives');

  assert.equal(day.name, 'DayChip');
  assert.match(day.nameNote, /renamed from DayCell/);

  assert.equal(sections[1].rows[0].status, 'existing-modified');
});

test('ui2ComparisonId is a stable, path-safe DB key that cannot collide with 1.0', () => {
  assert.equal(ui2ComparisonId('C-042'), 'ui2-c-042');
});

const CONTRACT = `# C-042 EditableFieldRow — tappable field row

Status: new · Specced: 2026-09-01 · Full-set contract: 2026-09-03

## 1. Normative source

- Figma: https://www.figma.com/design/abc/Make-Ready-Mobile?node-id=3517-29304
- Frozen snapshot: \`assets/C-042-editable-field-row.png\` — captured 2026-09-03

## 3. Variant & state matrix

| \`state\` | Delta vs Default | Consumption |
|---|---|---|
| \`Default\` | label over value | consumed — members-profile |
| \`Tags\` | TagChip row | designed-unconsumed |
| \`Multiline\` | value wraps | designed-unconsumed; wrap bound undesigned (OQ-C-042-2) |
| pressed / disabled | — undesigned | proposed defaults — OQ-C-042-3 |

## 4. Props contract

\`label: String\` · \`value: String?\`

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-042-1 | Ratify build-as-Default | No — default proposed | owner |
| OQ-C-042-4 | Tags editor is a pattern gap | Yes — gates the first consumer | owner |
`;

test('parseContract extracts the source, snapshot, states and open questions', () => {
  const c = parseContract(CONTRACT, { file: 'docs/ui2/…/C-042.md' });
  assert.equal(c.id, 'C-042');
  assert.equal(c.name, 'EditableFieldRow');
  assert.equal(c.summary, 'tappable field row');
  assert.match(c.statusLine, /^Status: new/);
  assert.equal(c.figmaUrl, 'https://www.figma.com/design/abc/Make-Ready-Mobile?node-id=3517-29304');
  assert.equal(c.snapshotFile, 'C-042-editable-field-row.png');
  assert.match(c.props, /label: String/);

  assert.deepEqual(c.states.map((s) => [s.name, s.consumptionState]), [
    ['Default', 'consumed'],
    ['Tags', 'designed-unconsumed'],
    // A state whose CONSUMPTION says designed-unconsumed stays designed even
    // though a detail of it ("wrap bound") is undesigned.
    ['Multiline', 'designed-unconsumed'],
    // …whereas one whose DELTA is "undesigned" is not in the snapshot.
    ['pressed / disabled', 'undesigned'],
  ]);

  assert.deepEqual(c.openQuestions.map((q) => [q.id, q.blocking]), [
    ['OQ-C-042-1', false],
    ['OQ-C-042-4', true],
  ]);
});

test('parseContract handles the axis-shaped matrix, dropping node refs from labels', () => {
  const c = parseContract(`# C-024 SparkBarChart — miniature chart

## 3. Variant & state matrix

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| align | center (\`3672:9688\` et al.) | bars mirror | **consumed** — C-025 |
| align | top | undesigned | **owner-required** — proposed default (OQ-C-024-1) |
| — | loading / error | undesigned | none proposed |
`, { file: 'x.md' });

  assert.deepEqual(c.states.map((s) => [s.name, s.consumptionState]), [
    ['align · center', 'consumed'],
    ['align · top', 'undesigned'],
    ['loading / error', 'undesigned'],
  ]);
});

test('buildUi2Index indexes the real docs/ui2 registry', async () => {
  const index = await buildUi2Index();
  const counts = ui2Counts(index);
  assert.ok(counts.total > 0, 'registry has rows');
  assert.ok(index.sections.length > 0);

  // Every row is addressable and carries a comparison id.
  for (const section of index.sections) {
    for (const row of section.rows) {
      assert.match(row.id, /^C-\d{3}$/);
      assert.equal(row.comparisonId, ui2ComparisonId(row.id));
      assert.equal(index.byId.get(row.id), row);
      // A row has states to browse iff there is something to browse: a contract
      // (its designed states) or, since 2026-09-10, artwork captured by the
      // /ui2-screen run that minted it (one `set` state carrying the picture).
      // A row with neither is a name only.
      assert.equal(row.variants.length > 0, !!row.contract || !!row.snapshot);
    }
  }
  // Every contract that names a frozen snapshot resolves to a file on disk.
  for (const row of index.byId.values()) {
    if (row.contract?.snapshotFile) assert.ok(row.snapshot, `${row.id} snapshot missing on disk`);
  }
});

// ── §4 props + per-state prop assignments (Details tab) ────────────────────

const MULTI_AXIS = `# C-040 PageHeader — pushed-page bar

Status: new · Specced: 2026-09-05

## 3. Variant & state matrix

| \`style\` | \`showTitle\` | \`showIcons\` | Renders | Consumption |
|---|---|---|---|---|
| Default | true | n/a | back · title · settings | designed-unconsumed |
| Two icons | true | false | back · title | consumed — invite-home |
| Two icons | true | true | back · title · export + settings | consumed — study-program-home |
| scrolled | — undesigned | | | proposed default + OQ-C-040-3 |

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| \`style\` | \`default \\| textButtons \\| twoIcons\` | the variant axis |
| \`title\` | \`String?\` | centred title |
| \`showTitle\` | \`Bool\` | gates the title |
| \`showIcons\` | \`Bool\` | gates the trailing group — \`twoIcons\` only |
| \`onBack\` | \`() -> Void\` | pops the pushed page |
`;

test('parseContract reads a §4 prop TABLE into rows', () => {
  const c = parseContract(MULTI_AXIS, { file: 'x/C-040.md' });
  assert.deepEqual(c.propRows.map((p) => p.name), ['style', 'title', 'showTitle', 'showIcons', 'onBack']);
  assert.equal(c.propRows[0].type, 'default | textButtons | twoIcons');
  assert.equal(c.propRows[1].purpose, 'centred title');
  // The prose body is still carried for contracts whose §4 is not a table.
  assert.match(c.props, /Prop \| Type \| Purpose/);
});

test('a state assigns only the matrix columns that NAME a prop', () => {
  const c = parseContract(MULTI_AXIS, { file: 'x/C-040.md' });
  const [dflt, twoIcons] = c.states;

  // "Renders" and "Consumption" are prose columns — not props, so not assigned.
  assert.deepEqual(twoIcons.propValues, [
    { name: 'style', value: 'Two icons' },
    { name: 'showTitle', value: 'true' },
    { name: 'showIcons', value: 'false' },
  ]);
  // An inapplicable cell ("n/a") is dropped rather than assigned a junk value.
  assert.deepEqual(dflt.propValues.map((p) => p.name), ['style', 'showTitle']);
  assert.equal(c.propsAreNamed, true);
});

test('a matrix whose columns name no prop falls back to the Figma axis', () => {
  const c = parseContract(`# C-034 SearchField — search input

## 3. Variant & state matrix

| \`state\` | Fill | Border | Consumption |
|---|---|---|---|
| Default | card | card-border | consumed — members-home |
| Focus | none | white | designed-unconsumed |

## 4. Props contract

\`text: Binding<String>\` · \`placeholder: String\` · \`focused: Bool\`
`, { file: 'x/C-034.md' });

  assert.equal(c.propRows.length, 0);      // §4 is prose here
  assert.equal(c.propsAreNamed, false);    // so nothing can be matched by name
  assert.deepEqual(c.states[1].propValues, [{ name: 'state', value: 'Focus', axisOnly: true }]);
});

test('states keep unique names and slugs when the first column repeats', () => {
  const c = parseContract(MULTI_AXIS, { file: 'x/C-040.md' });
  const names = c.states.map((s) => s.name);
  const slugs = c.states.map((s) => s.slug);
  assert.equal(new Set(names).size, names.length);
  assert.equal(new Set(slugs).size, slugs.length);
  // Both 'Two icons' rows share showTitle, so only showIcons — the column that
  // actually separates them — widens the label.
  assert.deepEqual(names.slice(1, 3), ['Two icons · no showIcons', 'Two icons · showIcons']);
  assert.equal(slugs[1], 'two-icons-no-showicons');
});

test('a prose column is not read as a prop just because §4 shares its name', () => {
  // C-034's shape: the axis column is `state` (not a prop), and the `Text`
  // column describes the render while §4 declares a `text` prop.
  const c = parseContract(`# C-034 SearchField — search input

## 3. Variant & state matrix

| \`state\` | Fill | Text | Consumption |
|---|---|---|---|
| Default | card | placeholder in \`color-nav-text\` | consumed — members-home |

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| \`text\` | \`Binding<String>\` | current query |
| \`focused\` | \`Bool\` | drives border + caret |
`, { file: 'x/C-034.md' });

  assert.equal(c.propRows.length, 2);
  assert.equal(c.propsAreNamed, false);
  assert.deepEqual(c.states[0].propValues, [{ name: 'state', value: 'Default', axisOnly: true }]);
});
