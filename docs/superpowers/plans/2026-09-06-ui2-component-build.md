# UI 2.0 Preview Build (`/ui2-component-build`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn a specced UI 2.0 component into a capturable SwiftUI preview, so the component browser renders it beside its frozen Figma snapshot and diffs the two.

**Architecture:** A registry row already exists in the browser as comparison `ui2-c-###` whose variants are the contract's states and whose render is a `design` screenshot. This lane adds an `iphone` screenshot to those same variants: a generated fixture at `capture/fixtures/ui2/C-###.json` drives a `component.ui2.C-###` ViewRegistry case, captured through the existing XCTest snapshot runner. No new comparison, no new comment or version machinery.

**Tech Stack:** Node 22 ESM + `node --test` (capture), Prisma/Postgres (capture DB), React 18 (browser), SwiftUI + XCTest/SnapshotTesting (iPhone), markdown contracts under `docs/ui2/`.

**Spec:** `docs/ui2/preview-build.md` (DECISIONS.md D11). Read it before Task 1 — every rule below is derived from it.

## Global Constraints

- **Preview code is wired into no screen, route, tab or flag.** A step that would require one stops and reports instead. (`preview-build.md` §3 rule 1)
- **Legacy is untouched:** `Colors.swift`, `Typography.swift`, `Pages/`, `Services/Route.swift` are never edited. `ViewRegistry.swift` is the one permitted edit — it is a test-target map, not shipping UI. (§3 rules 2–3)
- **Tokens are generated from `docs/ui2/design-system/tokens.md`, never hand-edited.** A contract's flagged literal stays a literal, with the contract's flag repeated as a Swift comment. (§3 rule 4)
- **Every prop value traces to the contract.** §4's prop table crossed with that state's §3 row. Inventing a prop, state or value is a spec defect fixed by a `/ui2-component` re-run. (§3 rule 5)
- **Variant names are the §3 matrix labels verbatim** — they are the DB key for versions and comments. `undesigned` states are skipped entirely. (§3 rule 6)
- **The fixture lives at `capture/fixtures/ui2/`, never `capture/fixtures/compare/`.** The compare loader must never see it, and `syncUi2Row` stays the single writer of the `ui2-c-###` comparison row. (§5)
- **No `#if DEBUG`** around preview views. (§2)
- Capture tests run with `npm test` from `capture/` (`node --test test/*.test.mjs`).
- The capture server must be restarted after editing `server.mjs` or `lib/*.mjs` — it does not hot-reload.

## File Structure

| File | Responsibility |
|---|---|
| `capture/lib/ui2-fixture.mjs` | **Create.** Fixture path/read/write, and deriving a fixture from a parsed contract. |
| `capture/lib/ui2-tokens.mjs` | **Create.** `tokens.md` → `UI2PreviewTokens.swift`. |
| `capture/db/index.mjs` | **Modify.** `finalizeVariantVersion` takes the platform list to copy forward. |
| `capture/runners/ui2/capture.mjs` | **Create.** Fixture → temp iPhone fixture → `capture.sh` → Version + screenshots. |
| `capture/server.mjs` | **Modify.** Expose `built`; add `POST /api/ui2/capture`. |
| `capture/src/pages/components/Ui2DetailsTab.jsx` | **Modify.** Build button for a specced-but-unbuilt row. |
| `capture/src/pages/components/Ui2Layout.jsx` | **Modify.** Platform toggle when a built render exists. |
| `iphone/MakeReady/UI2Preview/` | **Create.** Generated tokens + one file per built component + README. |
| `iphone/MakeReadyCaptureTests/ViewRegistry.swift` | **Modify.** One `case "component.ui2.C-###"` per built component. |
| `.claude/commands/ui2-component-build.md` | **Create.** The command itself. |

---

### Task 1: The ui2 fixture module

**Files:**
- Create: `capture/lib/ui2-fixture.mjs`
- Test: `capture/test/ui2-fixture.test.mjs`

**Interfaces:**
- Consumes: `parseContract(md, {file})` from `lib/ui2-index.mjs` — returns `{ id, name, states: [{ name, slug, propValues: [{name, value, axisOnly?}], consumptionState }], propRows: [{name, type, purpose}] }`.
- Produces: `ui2FixtureDir`, `ui2FixturePath(registryId) -> string`, `readUi2Fixture(registryId) -> object|null`, `writeUi2Fixture(registryId, fixture) -> void`, `isBuilt(registryId) -> Promise<boolean>`, `fixtureFromContract(contract) -> object`.

- [ ] **Step 1: Write the failing test**

```javascript
// capture/test/ui2-fixture.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseContract } from '../lib/ui2-index.mjs';
import { fixtureFromContract, ui2FixturePath } from '../lib/ui2-fixture.mjs';

const CONTRACT = `# C-040 PageHeader — pushed-page bar

## 3. Variant & state matrix

| \`style\` | \`showTitle\` | Renders | Consumption |
|---|---|---|---|
| Default | true | back · title | consumed — members-profile |
| Two icons | false | back | designed-unconsumed |
| scrolled | — undesigned | | proposed default + OQ-C-040-3 |

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| \`style\` | \`default \\| textButtons \\| twoIcons\` | the variant axis |
| \`showTitle\` | \`Bool\` | gates the title |
`;

test('fixtureFromContract emits one entry per DESIGNED state', () => {
  const fixture = fixtureFromContract(parseContract(CONTRACT, { file: 'x/C-040.md' }));

  assert.equal(fixture.id, 'ui2-c-040');
  assert.equal(fixture.registryId, 'C-040');
  assert.equal(fixture.component, 'PageHeader');
  assert.equal(fixture.view, 'component.ui2.C-040');
  // The undesigned row is skipped — there is no design to render.
  assert.deepEqual(fixture.variants.map((v) => v.name), ['Default · showTitle', 'Two icons · no showTitle']);
  // Props come from the matrix row, keyed by the §4 prop name.
  assert.deepEqual(fixture.variants[0].props, { style: 'Default', showTitle: 'true' });
  assert.deepEqual(fixture.variants[1].props, { style: 'Two icons', showTitle: 'false' });
});

test('ui2FixturePath is case-stable and outside fixtures/compare', () => {
  const p = ui2FixturePath('C-040');
  assert.match(p, /capture\/fixtures\/ui2\/C-040\.json$/);
  assert.doesNotMatch(p, /fixtures\/compare/);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd capture && npm test 2>&1 | grep -E "not ok|# fail"`
Expected: FAIL — `Cannot find module '../lib/ui2-fixture.mjs'`

- [ ] **Step 3: Write the implementation**

```javascript
// capture/lib/ui2-fixture.mjs
/**
 * The ui2 preview fixture (docs/ui2/preview-build.md §5).
 *
 * Deliberately NOT under fixtures/compare/: that tree is walked by
 * runners/compare/lib.mjs loadComparisons(), which would sync the same
 * `ui2-c-###` comparison id with its own type/group/title and fight
 * syncUi2Row on every request (syncComparison overwrites those columns on
 * every call). Keeping it in its own root leaves syncUi2Row the single writer.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { makereadyRoot } from './fs-index.mjs';
import { ui2ComparisonId } from './ui2-index.mjs';

export const ui2FixtureDir = path.resolve(makereadyRoot, 'capture/fixtures/ui2');
export const ui2FixturePath = (registryId) => path.join(ui2FixtureDir, `${registryId.toUpperCase()}.json`);

export async function readUi2Fixture(registryId) {
  try { return JSON.parse(await fs.readFile(ui2FixturePath(registryId), 'utf-8')); }
  catch { return null; }
}

export async function writeUi2Fixture(registryId, fixture) {
  await fs.mkdir(ui2FixtureDir, { recursive: true });
  await fs.writeFile(ui2FixturePath(registryId), `${JSON.stringify(fixture, null, 2)}\n`, 'utf-8');
}

/** "Built" is fixture presence — the 2.0 twin of how 1.0 derives `wired`. */
export async function isBuilt(registryId) {
  try { await fs.access(ui2FixturePath(registryId)); return true; }
  catch { return false; }
}

/**
 * Contract → fixture. Only DESIGNED states get an entry: an `undesigned` row
 * has a proposed default waiting on a ruling, and rendering one would pre-empt
 * that ruling (preview-build.md §3 rule 6).
 */
export function fixtureFromContract(contract) {
  const variants = contract.states
    .filter((s) => s.consumptionState !== 'undesigned')
    .map((s) => ({
      name: s.name,
      slug: s.slug,
      props: Object.fromEntries(s.propValues.map((p) => [p.name, p.value])),
    }));
  return {
    id: ui2ComparisonId(contract.id),
    registryId: contract.id,
    component: contract.name,
    view: `component.ui2.${contract.id}`,
    devices: ['pro-max'],
    variants,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd capture && npm test 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# fail 0`

- [ ] **Step 5: Commit**

```bash
git add capture/lib/ui2-fixture.mjs capture/test/ui2-fixture.test.mjs
git commit -m "feat(capture): ui2 preview fixture module"
```

---

### Task 2: Surface `built` through the API

**Files:**
- Modify: `capture/server.mjs` (`ui2RowBase`, and the `/api/ui2/tree` counts)
- Test: `capture/test/ui2-fixture.test.mjs`

**Interfaces:**
- Consumes: `isBuilt(registryId)`, `ui2FixturePath(registryId)` from Task 1.
- Produces: `GET /api/ui2/tree` and `/api/ui2/detail` return `built: boolean` and
  `fixtureFile: string|null` per row; the tree's `counts` gains `built`.

**Controller ruling (pre-flight scan):** the original plan put this lookup inside
`buildUi2Index`, which would have made `ui2-index.mjs` import `ui2-fixture.mjs` while
`ui2-fixture.mjs` already imports `ui2ComparisonId` from `ui2-index.mjs` — a circular
import. Node ESM tolerates it, but it is fragile and a reviewer would rightly flag it.
`server.mjs` already imports both modules, so the lookup lives there and `ui2-index.mjs`
stays unaware of fixtures. Consequence: `built` is computed per request (one `fs.access`
per row, 69 rows) rather than memoised with the index, and `ui2Counts` is NOT changed.

- [ ] **Step 1: Write the failing test**

```javascript
// append to capture/test/ui2-fixture.test.mjs
import { isBuilt, writeUi2Fixture, ui2FixturePath } from '../lib/ui2-fixture.mjs';
import fs from 'node:fs/promises';

test('isBuilt tracks fixture presence', async () => {
  const id = 'C-999';                       // a registry id no contract uses
  await fs.rm(ui2FixturePath(id), { force: true });
  assert.equal(await isBuilt(id), false);

  await writeUi2Fixture(id, { id: 'ui2-c-999', registryId: id, variants: [] });
  try {
    assert.equal(await isBuilt(id), true);
  } finally {
    await fs.rm(ui2FixturePath(id), { force: true });
  }
  assert.equal(await isBuilt(id), false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd capture && npm test 2>&1 | grep -E "not ok"`
Expected: it fails only if Task 1's `isBuilt`/`writeUi2Fixture` are wrong. If Task 1 is
correct this test passes immediately — that is fine; it is the regression net for the
behaviour Task 2's API change depends on. Do not weaken it to force a failure.

- [ ] **Step 3: Implement the API change**

In `capture/server.mjs`, import from Task 1's module beside the existing `ui2-index` import:

```javascript
import { isBuilt, ui2FixturePath } from './lib/ui2-fixture.mjs';
```

`ui2RowBase` is a plain function today; it becomes async because the lookup hits the disk:

```javascript
/** Shared row → API shape (the registry half; contract fields added per-caller). */
const ui2RowBase = async (row) => ({
  id: row.id,
  name: row.name,
  nameNote: row.nameNote,
  status: row.status,
  platform: row.platform,
  section: row.section,
  comparisonId: row.comparisonId,
  specced: !!row.contract,
  built: await isBuilt(row.id),
  fixtureFile: (await isBuilt(row.id)) ? path.relative(repoRoot, ui2FixturePath(row.id)) : null,
  hasSnapshot: !!row.snapshot,
  stateCount: row.variants.length,
});
```

Call it with `await` at both existing call sites — the tree handler's row loop and the
detail handler's `base`. Both are already inside `async` functions.

In the tree handler, add the built count to the response, counting the rows you just shaped
rather than re-reading the disk:

```javascript
    const builtCount = sections.reduce((n, s) => n + s.rows.filter((r) => r.built).length, 0);
    res.json({ root: 'docs/ui2/design-system/registry.md', sections, counts: { ...ui2Counts(index), built: builtCount } });
```

- [ ] **Step 4: Run tests**

Run: `cd capture && npm test 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# fail 0`

- [ ] **Step 5: Restart the server and check the payload**

```bash
kill $(pgrep -f "node server.mjs"); sleep 1; (cd capture && nohup node server.mjs > /tmp/capture-server.log 2>&1 &)
sleep 3 && curl -s "http://localhost:5951/api/ui2/detail?id=C-045" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['built'], d['fixtureFile'])"
curl -s "http://localhost:5951/api/ui2/tree" | python3 -c "import sys,json;print(json.load(sys.stdin)['counts'])"
```
Expected: `False None`, and a counts object containing `built`.

- [ ] **Step 6: Commit**

```bash
git add capture/server.mjs capture/test/ui2-fixture.test.mjs
git commit -m "feat(capture): report ui2 built state from fixture presence"
```

---

### Task 3: The token generator

**Files:**
- Create: `capture/lib/ui2-tokens.mjs`
- Test: `capture/test/ui2-tokens.test.mjs`

**Interfaces:**
- Consumes: `docs/ui2/design-system/tokens.md` — markdown tables under `## Color`, `## Typography`, `## Spacing`, `## Radius`, `## Elevation / materials`, each row `| token | value | figma variable | ios | web |`.
- Produces: `parseTokens(md) -> { colors, type, spacing, radii, skipped }`, `tokensToSwift(parsed) -> string`, and a CLI (`node capture/lib/ui2-tokens.mjs`) that writes `iphone/MakeReady/UI2Preview/UI2PreviewTokens.swift`.

**Controller ruling (pre-flight, before dispatch):** the task as first written emitted
colour, spacing and radius only — but `preview-build.md` §3 rule 4 requires that **every
colour, type, spacing, radius and elevation** value resolves to a generated symbol, and
almost every component renders text (`type-page-title`, `type-input`, `type-nav-label`…).
A generator without typography would force literal fonts into every preview view, breaking
the rule it exists to enforce. Typography is therefore in scope here. `tokens.md` writes its
17 type rows as prose ("SF Pro Text Semibold 16 / 21, letter-spacing −0.32"), so the parser
is a documented tolerant regex, and **any row it cannot parse is reported by the CLI rather
than silently dropped** — a silently missing token is how a literal sneaks back in. Elevation
(one row, a shadow triple) stays out of scope: `elevation-thumbnail` has a single consumer
(C-056) which has no contract file, so nothing can consume it yet; Task 6 emits it as a
flagged literal if it ever comes up. Cost if wrong: a component needing a shadow before
`ui2-shell` gets a literal with a comment instead of a token.

- [ ] **Step 1: Write the failing test**

```javascript
// capture/test/ui2-tokens.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTokens, tokensToSwift } from '../lib/ui2-tokens.mjs';

const TOKENS = `# UI 2.0 Design Tokens

## Color

| Token | Value | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| color-card-background | #1f2124 | \`card/background\` | (new) | (new) |
| color-accent-20 | #6c47ff33 | \`Purple/20%\` | (new) | (new) |

## Spacing

| Token | Value (pt/px) | Figma variable | Notes |
|---|---|---|---|
| space-page-margin | 16 | observed | inset |

## Radius

| Token | Value | Figma variable | Notes |
|---|---|---|---|
| radius-card-sm | 4 | observed | |
| radius-circle | 50% | observed | |
`;

test('parseTokens reads the typography family, and reports what it cannot parse', () => {
  const t = parseTokens(`## Typography

| Token | Font / size / weight / line-height | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| type-callout-bold | SF Pro Text Semibold 16 / 21, letter-spacing −0.32 | \`Callout / Bold\` | (new) | (new) |
| type-body | SF Pro Regular 14 | observed | (new) | (new) |
| type-nav-action | SF Pro Regular 14 / 24, tracking +0.56 | observed | (new) | (new) |
| type-mystery | a hand-drawn font, vibes only | observed | (new) | (new) |
`);

  assert.deepEqual(t.type, [
    // "SF Pro Text" and "SF Pro" are the same family; the Text suffix is Apple's
    // optical size, not a different typeface.
    { name: 'type-callout-bold', weight: 'semibold', size: '16', lineHeight: '21', tracking: '-0.32' },
    // No "/ N" means no designed line-height — null, never a guessed one.
    { name: 'type-body', weight: 'regular', size: '14', lineHeight: null, tracking: null },
    { name: 'type-nav-action', weight: 'regular', size: '14', lineHeight: '24', tracking: '0.56' },
  ]);
  // Unparseable rows are surfaced, not dropped: a missing token is how a literal
  // font sneaks back into a preview view.
  assert.deepEqual(t.skipped, ['type-mystery']);
});

test('tokensToSwift emits a text style per type token', () => {
  const swift = tokensToSwift(parseTokens(`## Typography

| Token | Font / size / weight / line-height | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| type-page-title | SF Pro Regular 14 / 20 | observed | (new) | (new) |
`));
  assert.match(swift, /struct UI2TextStyle/);
  assert.match(swift, /static let pageTitle = UI2TextStyle\(weight: \.regular, size: 14, lineHeight: 20, tracking: 0\)/);
});

test('parseTokens reads each family, skipping prose rows', () => {
  const t = parseTokens(TOKENS);
  assert.deepEqual(t.colors, [
    { name: 'color-card-background', value: '#1f2124' },
    { name: 'color-accent-20', value: '#6c47ff33' },
  ]);
  assert.deepEqual(t.spacing, [{ name: 'space-page-margin', value: '16' }]);
  // "50%" is not a CGFloat — a non-numeric radius is dropped, not guessed at.
  assert.deepEqual(t.radii, [{ name: 'radius-card-sm', value: '4' }]);
});

test('tokensToSwift emits camelCased members with 8-digit hex alpha', () => {
  const swift = tokensToSwift(parseTokens(TOKENS));
  assert.match(swift, /enum UI2Token/);
  assert.match(swift, /static let cardBackground = Color\(red: [\d.]+, green: [\d.]+, blue: [\d.]+, opacity: 1\)/);
  // #6c47ff33 → opacity 0.2
  assert.match(swift, /static let accent20 = Color\(red: [\d.]+, green: [\d.]+, blue: [\d.]+, opacity: 0\.2\)/);
  assert.match(swift, /static let pageMargin: CGFloat = 16/);
  assert.match(swift, /static let cardSm: CGFloat = 4/);
  // Generated file — say so, and say what regenerates it.
  assert.match(swift, /DO NOT EDIT.*ui2-tokens\.mjs/s);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd capture && npm test 2>&1 | grep -E "not ok"`
Expected: FAIL — `Cannot find module '../lib/ui2-tokens.mjs'`

- [ ] **Step 3: Implement**

```javascript
// capture/lib/ui2-tokens.mjs
/**
 * tokens.md → UI2PreviewTokens.swift (preview-build.md §3 rule 4).
 *
 * migration.md rule 4 says 2.0 tokens are GENERATED into the 2.0 namespace and
 * Colors.swift/Typography.swift are never touched. This is that generator: it
 * makes tokens.md executable instead of aspirational.
 *
 * Color goes through Color(red:green:blue:opacity:) rather than Color(hex:) —
 * the SwiftLint gate reserves that initialiser for Colors.swift.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { makereadyRoot } from './fs-index.mjs';

const tokensPath = path.resolve(makereadyRoot, 'docs/ui2/design-system/tokens.md');
export const tokensOutPath = path.resolve(makereadyRoot, 'iphone/MakeReady/UI2Preview/UI2PreviewTokens.swift');

const cells = (line) => line.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.replace(/\\\|/g, '|').trim());

/** Rows of the table under `## <heading>`, as [token, value] pairs. */
function familyRows(md, heading) {
  const section = md.split(/^## /m).find((s) => s.toLowerCase().startsWith(heading.toLowerCase()));
  if (!section) return [];
  return section.split('\n')
    .filter((l) => l.trim().startsWith('|'))
    .filter((l) => !/^\|[\s:-]+\|/.test(l.trim()))
    .map(cells)
    .filter((c) => /^[a-z]+-[a-z0-9-]+$/.test(c[0] ?? ''))
    .map((c) => ({ name: c[0], value: c[1] }));
}

/**
 * Typography is prose, not a value: "SF Pro Text Semibold 16 / 21, letter-spacing
 * −0.32". Parse what the program actually writes and report the rest.
 * - "SF Pro" and "SF Pro Text" are one family (Text is Apple's optical size).
 * - No "/ N" means no designed line-height — null, never a guess.
 * - tokens.md uses the Unicode minus U+2212 for negative tracking.
 */
const TYPE_RE = /^SF Pro(?: Text)?\s+(Regular|Medium|Semibold|Bold)\s+(\d+(?:\.\d+)?)(?:\s*\/\s*(\d+(?:\.\d+)?))?/i;
const TRACK_RE = /(?:letter-spacing|tracking)\s*([+\u2212-]?\d+(?:\.\d+)?)/i;

function parseType(rows) {
  const type = [];
  const skipped = [];
  for (const row of rows) {
    const m = TYPE_RE.exec(row.value);
    if (!m) { skipped.push(row.name); continue; }
    const track = TRACK_RE.exec(row.value);
    type.push({
      name: row.name,
      weight: m[1].toLowerCase(),
      size: m[2],
      lineHeight: m[3] ?? null,
      tracking: track ? track[1].replace('\u2212', '-').replace('+', '') : null,
    });
  }
  return { type, skipped };
}

export function parseTokens(md) {
  const { type, skipped } = parseType(familyRows(md, 'Typography'));
  return {
    colors: familyRows(md, 'Color').filter((r) => /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(r.value)),
    type,
    skipped,
    spacing: familyRows(md, 'Spacing').filter((r) => /^\d+(\.\d+)?$/.test(r.value)),
    radii: familyRows(md, 'Radius').filter((r) => /^\d+(\.\d+)?$/.test(r.value)),
  };
}

/** color-card-background → cardBackground (the family prefix is the enum). */
const member = (name) => {
  const [, ...rest] = name.split('-');
  return rest.map((p, i) => (i === 0 ? p : p[0].toUpperCase() + p.slice(1))).join('');
};

const channel = (hex, i) => (parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16) / 255).toFixed(4).replace(/0+$/, '').replace(/\.$/, '.0');

function colorLine({ name, value }) {
  const alpha = value.length === 9 ? (parseInt(value.slice(7, 9), 16) / 255) : 1;
  const a = Number(alpha.toFixed(2));
  return `    static let ${member(name)} = Color(red: ${channel(value, 0)}, green: ${channel(value, 1)}, blue: ${channel(value, 2)}, opacity: ${a})`;
}

export function tokensToSwift(t) {
  return `//
//  UI2PreviewTokens.swift
//  MakeReady — UI 2.0 preview namespace
//
//  GENERATED FROM docs/ui2/design-system/tokens.md — DO NOT EDIT.
//  Regenerate with: node capture/lib/ui2-tokens.mjs
//  Rules: docs/ui2/preview-build.md §3 rule 4.
//

import SwiftUI

/// A designed text style: SwiftUI has no line-height, so the leading is applied
/// as lineSpacing (lineHeight − size) by the `ui2TextStyle` modifier.
struct UI2TextStyle {
    let weight: Font.Weight
    let size: CGFloat
    let lineHeight: CGFloat?
    let tracking: CGFloat

    var font: Font { .system(size: size, weight: weight) }
    var lineSpacing: CGFloat { max((lineHeight ?? size) - size, 0) }
}

extension View {
    func ui2TextStyle(_ style: UI2TextStyle) -> some View {
        font(style.font).tracking(style.tracking).lineSpacing(style.lineSpacing)
    }
}

enum UI2Token {
${t.colors.map(colorLine).join('\n')}

    // NOT `Type`: `UI2Token.Type` is Swift's metatype syntax for the enum itself.
    enum TypeStyle {
${t.type.map((r) => `        static let ${member(r.name)} = UI2TextStyle(weight: .${r.weight}, size: ${r.size}, lineHeight: ${r.lineHeight ?? 'nil'}, tracking: ${r.tracking ?? 0})`).join('\n')}
    }

    enum Space {
${t.spacing.map((r) => `        static let ${member(r.name)}: CGFloat = ${r.value}`).join('\n')}
    }

    enum Radius {
${t.radii.map((r) => `        static let ${member(r.name)}: CGFloat = ${r.value}`).join('\n')}
    }
}
`;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const md = await fs.readFile(tokensPath, 'utf-8');
  await fs.mkdir(path.dirname(tokensOutPath), { recursive: true });
  const parsed = parseTokens(md);
  await fs.writeFile(tokensOutPath, tokensToSwift(parsed), 'utf-8');
  console.log(`wrote ${path.relative(makereadyRoot, tokensOutPath)}`);
  console.log(`  ${parsed.colors.length} colors · ${parsed.type.length} type · ${parsed.spacing.length} spacing · ${parsed.radii.length} radius`);
  if (parsed.skipped.length) console.log(`  NOT PARSED (no token emitted): ${parsed.skipped.join(', ')}`);
}
```

Note the test expects `Space`/`Radius` members named without their family prefix (`pageMargin`, `cardSm`) — `member()` drops the first hyphen-separated segment, which is the family.

- [ ] **Step 4: Run tests**

Run: `cd capture && npm test 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# fail 0`

- [ ] **Step 5: Generate the real file and eyeball it**

```bash
node capture/lib/ui2-tokens.mjs && head -30 iphone/MakeReady/UI2Preview/UI2PreviewTokens.swift
```
Expected: a `UI2Token` enum with ~33 colours, ~17 type styles, 7 spacing and 4 radius
members, and a `NOT PARSED` line only for type rows `tokens.md` genuinely writes as prose.
If a token a contract cites is on that list, stop and report it — do not hand-write it in.

- [ ] **Step 6: Commit**

```bash
git add capture/lib/ui2-tokens.mjs capture/test/ui2-tokens.test.mjs iphone/MakeReady/UI2Preview/UI2PreviewTokens.swift
git commit -m "feat(ui2): generate UI2PreviewTokens.swift from tokens.md"
```

---

### Task 4: The ui2 capture runner

**Files:**
- Modify: `capture/db/index.mjs:129-145` (`finalizeVariantVersion`)
- Create: `capture/runners/ui2/capture.mjs`
- Modify: `capture/server.mjs` (add `POST /api/ui2/capture`)
- Test: `capture/test/versions.test.mjs`

**Interfaces:**
- Consumes: `readUi2Fixture(registryId)` (Task 1); `isBuilt` (Task 1); existing `createVersion`, `addScreenshot`, `finalizeVariantVersion` from `capture/db/index.mjs`; `runners/iphone/capture.sh <workflow> <id>`.
- Produces: `node capture/runners/ui2/capture.mjs <C-###> [stateSlug|*]`, and `POST /api/ui2/capture {id, variant}`.

**Why `finalizeVariantVersion` changes:** it copy-forwards only `CAPTURE_PLATFORMS = ['iphone','client']`. A ui2 capture creates a version carrying just the new `iphone` shot, so without a `design` copy-forward the Figma snapshot would vanish from the newest version.

- [ ] **Step 1: Write the failing test**

Add this as a NEW top-level test in `capture/test/versions.test.mjs`, placed **after** the
existing `test('component-browser version retention + anchoring', …)` block and **before**
the existing `test.after(…)`. It reuses that file's reserved comparison id `CID`, so the
existing teardown already deletes its rows; it uses a variant name and viewport the other
test never touches, so the two cannot collide. Do not invent a new comparison id — an id
beginning `ui2-` would collide with the real `ui2-c-###` namespace.

```javascript
test('DB-7: finalizeVariantVersion copies forward the platforms it is given', async () => {
  // The ui2 lane captures ONLY the iphone side; without an explicit platform
  // list the frozen Figma snapshot would not ride along to the new version,
  // and the newest version would show a built render with no reference.
  const variantName = 'ui2-copyforward';
  const viewport = 'design';
  await syncComparison({ id: CID, type: 'component', group: '__Test', title: 'Test', adapter: CID });

  const v1 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v1.id, platform: 'design', device: 'figma', path: `_test/${CID}-design.png` });

  await sleep(20);

  const v2 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v2.id, platform: 'iphone', device: 'pro-max', path: `_test/${CID}-iphone.png` });
  await finalizeVariantVersion({
    newVersionId: v2.id, comparisonId: CID, variantName, viewport,
    capturedPlatforms: ['iphone'], platforms: ['iphone', 'design'],
  });

  const shots = await prisma.screenshot.findMany({ where: { versionId: v2.id } });
  assert.deepEqual(shots.map((s) => s.platform).sort(), ['design', 'iphone']);

  // The default must not change: without `platforms`, only iphone+client are
  // considered, so `design` is NOT copied forward.
  const v3 = await createVersion({ comparisonId: CID, variantName, viewport });
  await addScreenshot({ versionId: v3.id, platform: 'iphone', device: 'pro-max', path: `_test/${CID}-iphone3.png` });
  await finalizeVariantVersion({
    newVersionId: v3.id, comparisonId: CID, variantName, viewport, capturedPlatforms: ['iphone'],
  });
  const shots3 = await prisma.screenshot.findMany({ where: { versionId: v3.id } });
  assert.deepEqual(shots3.map((s) => s.platform), ['iphone']);
});
```

`CID`, `sleep`, `prisma`, `syncComparison`, `createVersion`, `addScreenshot` and
`finalizeVariantVersion` are all already defined or imported at the top of that file —
add no new imports.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd capture && npm test 2>&1 | grep -E "not ok"`
Expected: FAIL — only `['iphone']`, because `design` was never considered.

- [ ] **Step 3: Implement the DB change**

```javascript
// capture/db/index.mjs — finalizeVariantVersion
/**
 * Copy forward the platforms this capture didn't produce, so the newest version
 * shows a complete set. `platforms` defaults to the two captured platforms; the
 * ui2 lane passes ['iphone','design'] so the frozen Figma snapshot rides along
 * with a freshly built render.
 */
export async function finalizeVariantVersion({ newVersionId, comparisonId, variantName, viewport, capturedPlatforms, platforms = CAPTURE_PLATFORMS }) {
  await prisma.$transaction(async (tx) => {
    for (const platform of platforms) {
      if (capturedPlatforms.includes(platform)) continue;
      const prior = await tx.screenshot.findFirst({
        where: { platform, versionId: { not: newVersionId }, version: { comparisonId, variantName, viewport } },
        orderBy: { createdAt: 'desc' },
      });
      if (prior) {
        await tx.screenshot.create({
          data: { versionId: newVersionId, platform, device: prior.device, path: prior.path, width: prior.width, height: prior.height },
        });
      }
    }
  });
}
```

- [ ] **Step 4: Run the test**

Run: `cd capture && npm test 2>&1 | grep -E "^# (pass|fail)"`
Expected: `# fail 0`

- [ ] **Step 5: Write the runner**

```javascript
#!/usr/bin/env node
// capture/runners/ui2/capture.mjs
/**
 * Capture the BUILT side of a UI 2.0 component (preview-build.md §5).
 *
 * Mirrors runners/compare/capture.mjs's captureIphone, minus the adapter: a ui2
 * fixture is already iPhone-shaped, because there is no web twin to project to.
 * The Figma snapshot stays the reference; this adds the `iphone` render to the
 * SAME comparison + variant, so the timeline and comments are untouched.
 *
 * Usage: node capture/runners/ui2/capture.mjs <C-###> [stateSlug|*]
 */
import { spawn, execSync } from 'node:child_process';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import path from 'node:path';
import { readUi2Fixture } from '../../lib/ui2-fixture.mjs';
import { makereadyRoot } from '../../lib/fs-index.mjs';
import { createVersion, addScreenshot, finalizeVariantVersion } from '../../db/index.mjs';

const VIEWPORT = 'design';          // the viewport syncUi2Row registers under
const DEVICE = 'pro-max';
const TMP_WORKFLOW = 'ztmp-ui2';
const captureRoot = path.resolve(makereadyRoot, 'capture');
const iphoneFixtures = path.resolve(captureRoot, 'fixtures/iphone');
const compareRoot = path.resolve(captureRoot, 'fixtures/compare');

function run(cmd, args, opts) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, opts);
    child.stdout?.on('data', (d) => process.stdout.write(d));
    child.stderr?.on('data', (d) => process.stderr.write(d));
    child.on('close', (code) => resolve(code ?? 0));
    child.on('error', () => resolve(1));
  });
}

function gitInfo() {
  try {
    return {
      sha: execSync('git rev-parse HEAD', { cwd: makereadyRoot }).toString().trim(),
      dirty: execSync('git status --porcelain', { cwd: makereadyRoot }).toString().trim().length > 0,
    };
  } catch { return { sha: null, dirty: false }; }
}

function pngSize(buf) {
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) return {};
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

async function captureVariant(fixture, variant, git) {
  const dir = path.join(iphoneFixtures, TMP_WORKFLOW);
  await fs.mkdir(dir, { recursive: true });
  const key = `${fixture.registryId}-${variant.slug}`;
  // The XCTest runner renders `component.*` views in isolation: device width,
  // intrinsic height, no chrome (CaptureRunner.swift testCaptureAll).
  await fs.writeFile(path.join(dir, `${key}.json`), JSON.stringify({
    view: fixture.view,
    output: `${key}.png`,
    devices: [DEVICE],
    title: `${fixture.registryId} ${fixture.component} — ${variant.name}`,
    state: { component: variant.props },
  }, null, 2), 'utf-8');

  const version = await createVersion({
    comparisonId: fixture.id,
    variantName: variant.name,
    viewport: VIEWPORT,
    gitSha: git.sha,
    gitDirty: git.dirty,
    sourceHash: crypto.createHash('sha1').update(JSON.stringify(variant.props)).digest('hex'),
    sharedData: variant.props,
    componentName: `${fixture.registryId} ${fixture.component}`,
    iphoneView: fixture.view,
  });

  try {
    console.log(`→ ${fixture.registryId} · ${variant.name} — xcodebuild, this takes a few minutes…`);
    const code = await run('bash', [path.resolve(captureRoot, 'runners/iphone/capture.sh'), TMP_WORKFLOW, key], {
      cwd: path.resolve(makereadyRoot, 'iphone'),
      env: { ...process.env, CAPTURE_ROOT: iphoneFixtures },
    });
    if (code !== 0) throw new Error(`iphone runner exited ${code}`);

    const src = path.join(dir, 'screenshots', DEVICE, `capture.${key}.png`);
    const rel = path.join('_shots', fixture.id, VIEWPORT, 'iphone', `${version.id}.png`);
    const dest = path.join(compareRoot, rel);
    await fs.mkdir(path.dirname(dest), { recursive: true });
    await fs.copyFile(src, dest);
    const dims = pngSize(await fs.readFile(dest));
    await addScreenshot({ versionId: version.id, platform: 'iphone', device: DEVICE, path: rel, width: dims.width ?? null, height: dims.height ?? null });
    // Carry the frozen Figma snapshot onto this version so the newest one shows both.
    await finalizeVariantVersion({
      newVersionId: version.id, comparisonId: fixture.id, variantName: variant.name,
      viewport: VIEWPORT, capturedPlatforms: ['iphone'], platforms: ['iphone', 'design'],
    });
    console.log(`✓ ${rel}`);
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

const [registryId, which = '*'] = process.argv.slice(2);
if (!registryId) { console.error('usage: capture.mjs <C-###> [stateSlug|*]'); process.exit(1); }
const fixture = await readUi2Fixture(registryId);
if (!fixture) { console.error(`${registryId} is not built — no fixture at capture/fixtures/ui2/`); process.exit(1); }
const targets = which === '*' ? fixture.variants : fixture.variants.filter((v) => v.slug === which);
if (!targets.length) { console.error(`no state matching "${which}"`); process.exit(1); }
const git = gitInfo();
for (const variant of targets) await captureVariant(fixture, variant, git);
process.exit(0);
```

- [ ] **Step 6: Add the endpoint**

In `capture/server.mjs`, beside the existing `POST /api/ui2/refresh`:

```javascript
  // Capture the BUILT side of a 2.0 component (preview-build.md §5).
  app.post('/api/ui2/capture', async (req, res) => {
    const id = String(req.body?.id ?? '').toUpperCase();
    const variant = String(req.body?.variant ?? '*');
    try {
      const args = [path.resolve(__dirname, 'runners/ui2/capture.mjs'), id, variant];
      const code = await new Promise((resolve) => {
        const child = spawn('node', args, { cwd: __dirname, env: process.env });
        child.on('close', (c) => resolve(c ?? 0));
        child.on('error', () => resolve(1));
      });
      if (code !== 0) return res.status(500).json({ error: `capture exited ${code}` });
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
```

- [ ] **Step 7: Commit**

```bash
git add capture/db/index.mjs capture/runners/ui2/capture.mjs capture/server.mjs capture/test/versions.test.mjs
git commit -m "feat(capture): ui2 preview capture runner + endpoint"
```

---

### Task 5: Browser — built state, build button, dual render

**Files:**
- Modify: `capture/src/pages/components/Ui2DetailsTab.jsx`
- Modify: `capture/src/pages/components/Ui2Layout.jsx`
- Modify: `capture/src/api.js` (add `captureUi2`)
- Modify: `capture/src/styles.css`

**Interfaces:**
- Consumes: `detail.built`, `detail.specced` (Task 2); `POST /api/ui2/capture` (Task 4).
- Produces: a Details tab that shows the build command for a specced-but-unbuilt row, and a platform toggle in the render pane once `built` is true.

- [ ] **Step 1: Add the build prompt to the Details tab**

In `Ui2DetailsTab.jsx`, after the existing "Props set by this state" section and before "Sample call", insert:

```jsx
      {!detail.built && (
        <Section label="Not built yet" note="no render to compare against Figma">
          <p className="cmp-ui2d__prose">
            The contract exists, so the props above are known — but nothing renders them yet.
            Build it, and this component gets a SwiftUI preview captured beside its Figma snapshot.
          </p>
          <CopyCode value={`/ui2-component-build ${detail.id}`} />
        </Section>
      )}
```

- [ ] **Step 2: Add the API call and WIRE it — the endpoint must not be dead code**

**Controller ruling (after Task 4):** Task 4's endpoint returns `{ runId }` immediately and
streams progress over SSE, matching `/api/compare/capture`, rather than blocking as the brief
first drafted. That is the right call — a simulator capture takes minutes and must not hold an
HTTP request open — but it means the endpoint has no consumer unless this task wires one, and
an endpoint nobody calls is dead code a reviewer would rightly flag. So this task gives it its
consumer: for a BUILT component, the render pane's action re-runs the simulator capture; for an
unbuilt one it keeps refreshing the Figma snapshot.

In `capture/src/api.js`, beside `refreshUi2Snapshot` (around line 297). **There is no shared
`post` helper in that file** — every function does its own `fetch` and throws the server's
`error` field. Match that shape exactly:

```javascript
/** Capture the BUILT side of a 2.0 component. Returns { runId } — the job streams
 *  over SSE; follow it with subscribeCapture(). */
export async function captureUi2(id, variant = '*') {
  const res = await fetch('/api/ui2/capture', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, variant }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 capture failed: ${res.status}`);
  }
  return res.json();
}
```

`subscribeCapture(runId, { onLine, onDone, onError })` already exists in that file (line ~216)
and is what `ComponentsLayout.jsx:247` uses to follow a job — reuse it, do not write a second
EventSource wrapper.

In `Ui2Layout.jsx`, add a second action beside the existing `runRefresh`, modelled on
`ComponentsLayout.jsx`'s capture handler (read lines ~240-270 first — it holds the
unsubscribe in a ref and calls `bumpShots()` on completion):

```jsx
  // A built component's "recapture" re-runs the simulator; an unbuilt one has
  // only the frozen snapshot to re-read.
  const runCapture = async () => {
    if (busy || !detail?.built || !activeVariant) return;
    setBusy(true); setLog([]);
    try {
      const { runId } = await captureUi2(detail.id, activeVariant.slug);
      unsubRef.current = subscribeCapture(runId, {
        onLine: (line) => setLog((l) => [...l, line]),
        onDone: () => { setBusy(false); bumpShots(); },
        onError: (err) => { setLog((l) => [...l, `Error: ${err}`]); setBusy(false); },
      });
    } catch (err) {
      setLog([`Error: ${err.message}`]); setBusy(false);
    }
  };
```

Pass `onRecapture={detail?.built ? runCapture : runRefresh}` and switch the `labels` object's
`recapture`/`busy` strings when `detail.built` is true (`'Recapture render'` / `'Capturing…'`).
Add `const unsubRef = useRef(null);` — `useRef` is already imported in that file — and clean it
up in the existing unmount path if there is one.

**Note the variant argument:** pass `activeVariant.slug`, because Task 4's endpoint validates
its `variant` argument with `safeId` and a state label like `Two icons · no showIcons` would be
rejected. The runner matches on slug.

- [ ] **Step 3: Show both platforms when built**

**Correction to this plan (controller, before dispatch):** an earlier draft of this step said
"the 1.0 era already renders a platform switch, so reuse its props". That is wrong.
`RenderPane.jsx:15-21` takes a single `platform = 'iphone'` string and renders exactly one
platform; there is no switch to reuse. The toggle has to be added.

`RenderPane` is shared with the 1.0 era, so the new control must be strictly opt-in: default it
off and 1.0's rendering is untouched.

In `RenderPane.jsx`, add two props to the existing destructure —
`platforms = null, onPlatform = null` — and, in the pane's header beside the existing viewport
badge, render a small segmented control ONLY when `platforms?.length > 1 && onPlatform`:

```jsx
      {platforms?.length > 1 && onPlatform && (
        <div className="cmp-render__platforms">
          {platforms.map((p) => (
            <button
              key={p}
              className={`cmp-render__platform${p === platform ? ' is-active' : ''}`}
              onClick={() => onPlatform(p)}
            >{p === 'design' ? 'Figma' : 'Built'}</button>
          ))}
        </div>
      )}
```

Style it in `styles.css` next to the existing `cmp-render__*` rules, matching the badge's scale.

In `Ui2Layout.jsx`, hold the state and pass it down:

```jsx
  const [platform, setPlatform] = useState('design');
  // A built component has an `iphone` render on the same version; before that
  // there is only the frozen snapshot, so the toggle has nothing to switch to.
  const platforms = detail?.built ? ['design', 'iphone'] : ['design'];
```

then `platform={platform} platforms={platforms} onPlatform={setPlatform}` on `RenderPane`.
Reset `platform` to `'design'` when the selected component changes, so switching to an unbuilt
component cannot leave the pane asking for an `iphone` render that does not exist.

- [ ] **Step 4: Verify in the browser**

```bash
open "http://localhost:5950/components/2.0/C-045/default-single"
```
Expected: the Details tab shows a **Not built yet** section with a copyable `/ui2-component-build C-045`, and no platform toggle in the render pane.

- [ ] **Step 5: Commit**

```bash
git add capture/src
git commit -m "feat(capture): ui2 build affordance + platform toggle"
```

---

### Task 6: The `/ui2-component-build` command

**Files:**
- Create: `.claude/commands/ui2-component-build.md`

**Interfaces:**
- Consumes: everything above — `node capture/lib/ui2-tokens.mjs`, `capture/fixtures/ui2/`, `POST /api/ui2/capture`, `docs/ui2/preview-build.md`.
- Produces: the command a user runs. Written in the same shape as `.claude/commands/ui2-component.md` — read that file first and match its structure: argument handling, hard rules, numbered phases, an exit checklist per phase.

- [ ] **Step 1: Write the command**

It takes `<C-###>` and runs these phases, each ending in a printed exit checklist:

**0. Load context** — read `docs/ui2/preview-build.md` in full, the component's contract, its registry row, and `tokens.md`. Refuse with the `/ui2-component` command if the row has no contract file.

**1. Resolve dependencies** — for every row named in the contract's §5 Composition, resolve by `preview-build.md` §4's order (component file → screen-spec §4 anchor → registry row = flagged stub). Print the resolution per dependency; a level-3 stub is recorded for the build report, not silently emitted.

**2. Tokens** — run `node capture/lib/ui2-tokens.mjs`. Every value the view needs must exist as a `UI2Token` member; a contract's flagged literal stays a literal with the flag repeated as a comment. A value that is neither is a spec defect — stop and say so.

**3. Write the view** — `iphone/MakeReady/UI2Preview/<Name>.swift`, one SwiftUI view whose parameters are §4's props, rendering every designed §3 state. No `#if DEBUG`, no legacy imports, wired into no screen.

**4. Fixture + registry case** — generate `capture/fixtures/ui2/C-###.json` (designed states only) and append `case "component.ui2.C-###"` to `ViewRegistry.swift`, decoding `state.component` into the view exactly as the neighbouring `component.*` cases do.

**5. Sync the Xcode target, then capture** — run `ruby iphone/scripts/ui2-preview-sync.rb`
(Task 8) so the new view and the token file are members of the `MakeReady` target; a file
that is not in the target does not compile and the capture fails with an unknown-view error.
Then run the capture **directly**, not through the HTTP endpoint:

```bash
node capture/runners/ui2/capture.mjs C-### '*'
```

**Controller ruling:** `POST /api/ui2/capture` returns `{ runId }` immediately and streams
progress over SSE — it is built for the browser, which subscribes and refreshes when the job
lands. A command that POSTed and then read the PNGs would race the simulator and read a
directory that is not written yet. Invoking the runner directly blocks until it finishes and
prints its own log, which is what a command needs. Then read the PNGs under
`capture/fixtures/compare/_shots/ui2-c-###/design/iphone/`.

**6. Diff and report** — compare each state against the Figma snapshot, refine the view, recapture. Report: states built, states skipped (undesigned), dependencies stubbed, tokens added, and any genuine gap between the contract and what SwiftUI can express. **Surface real gaps rather than fudging the view to match the picture.**

- [ ] **Step 2: Dry-run the command's own instructions**

Read the finished file start to finish as if you had no context. Every path it names must exist; every command it prints must be runnable. Fix what doesn't.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/ui2-component-build.md
git commit -m "feat(ui2): /ui2-component-build command"
```

---

### Task 7: First real build — C-045 TextInput

**Files:**
- Create: `iphone/MakeReady/UI2Preview/TextInput.swift`, `iphone/MakeReady/UI2Preview/README.md`
- Create: `capture/fixtures/ui2/C-045.json`
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift`

**Why C-045:** its §5 says "Consumes: nothing (leaf component)" — so it exercises the whole lane with no dependency resolution, and its 6 designed states cover a two-axis matrix. C-040 is the natural second (it consumes C-021).

- [ ] **Step 1: Run the command**

```
/ui2-component-build C-045
```

- [ ] **Step 2: Verify the fixture matches the contract**

```bash
python3 -c "
import json; f=json.load(open('capture/fixtures/ui2/C-045.json'))
print([v['name'] for v in f['variants']])"
```
Expected: the six designed states from §3 — the `error / disabled` and `Multi growth beyond 88pt` rows are undesigned and must NOT appear.

- [ ] **Step 3: Confirm nothing leaked into the app**

```bash
grep -rn "UI2Preview" iphone/MakeReady --include=*.swift | grep -v "^iphone/MakeReady/UI2Preview/"
```
Expected: no output. Any hit means a preview view was referenced from app code, which Global Constraints forbid.

- [ ] **Step 4: Confirm legacy is untouched**

```bash
git status --porcelain iphone/MakeReady/Colors.swift iphone/MakeReady/Typography.swift iphone/MakeReady/Pages iphone/MakeReady/Services/Route.swift
```
Expected: no output.

- [ ] **Step 5: Look at it**

Open `http://localhost:5950/components/2.0/C-045/default-single`, switch the render pane to `iphone`, and compare against the Figma snapshot state by state. Record genuine differences as comments on the render rather than filing them off in Swift.

- [ ] **Step 6: Commit**

```bash
git add iphone/MakeReady/UI2Preview capture/fixtures/ui2/C-045.json iphone/MakeReadyCaptureTests/ViewRegistry.swift
git commit -m "feat(ui2): build C-045 TextInput preview"
```

---

## Self-Review

**Spec coverage.** §1 loop → Tasks 3–6. §2 paths → Task 3 (tokens), Task 6 (view), Task 1 (fixture), Task 6 (registry case), Task 6 (command). §3 rules 1–3 → Global Constraints + Task 7 steps 3–4 verify them mechanically. Rule 4 → Task 3. Rules 5–6 → Task 1's `fixtureFromContract` (undesigned skipped, props from the contract) + Task 6 phase 2. Rule 7 (idempotent, visible re-runs) → `sourceHash` on the props in Task 4. §4 dependencies → Task 6 phase 1. §5 one owner → Task 1's module docstring + fixture root. §6 built state → Task 2 (`built`) and Task 5 (the three Details states). §7 promotion → not implemented, correctly: it is `ui2-shell`'s work.

**Gap found and left open on purpose:** §8's four OQs carry proposed defaults, and the plan bakes two of them in — `devices: ['pro-max']` (OQ-PB-1) and `Color.appBackground` via the existing component-fixture path (OQ-PB-2). Both are the spec's own proposed defaults; if the owner rules differently, Task 1 and the runner's `DEVICE` constant are the single places to change.

**Type consistency.** `registryId` is the bare `C-###` everywhere; `fixture.id` is the lowercased `ui2-c-###` comparison id, produced only by `ui2ComparisonId()`. `variant.name` is the contract's state label (the DB key) and `variant.slug` the URL/file key — Task 4's `key` uses the slug for filenames and the name for `variantName`, which is the distinction that matters.

---

### Task 8: Xcode target membership for the preview folder

> **Execution order: run this AFTER Task 4 and BEFORE Task 6.** It is numbered 8 only so the
> earlier task numbers — and the briefs already extracted from them — stay stable.

**Files:**
- Create: `iphone/scripts/ui2-preview-sync.rb`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (by running the script)

**Interfaces:**
- Consumes: the `xcodeproj` ruby gem (confirmed installed, v1.27.0) and system ruby at `/usr/bin/ruby`.
- Produces: `ruby iphone/scripts/ui2-preview-sync.rb` — idempotently makes every `.swift`
  file under `iphone/MakeReady/UI2Preview/` a member of the `MakeReady` target's Sources
  build phase. Tasks 6 and 7 run it after writing a new preview view.

**Why this task exists (controller ruling, discovered mid-execution):** the project is
`objectVersion = 56` and has **zero** `PBXFileSystemSynchronizedRootGroup` entries, so Xcode
does not auto-include files by folder. A `.swift` file dropped into `UI2Preview/` is not
compiled, `@testable import MakeReady` cannot see it, and the ViewRegistry case added in
Task 6 fails to compile. Without this, Tasks 6 and 7 cannot work at all. The plan as written
assumed folder-synchronised membership; it was wrong.

**Care required:** this task mutates `project.pbxproj`, the file that defines the whole iOS
build. It is under git, so a bad run is `git checkout` away — but verify with `git diff`
before committing, and never hand-edit the file.

- [ ] **Step 1: Write the script**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Make every Swift file under MakeReady/UI2Preview/ a member of the MakeReady
# target (docs/ui2/preview-build.md §2).
#
# The project has no file-system-synchronised groups (objectVersion 56), so a
# generated file is invisible to the compiler until it is referenced here. This
# script SYNCS the folder rather than adding one file: it is idempotent, so
# /ui2-component-build re-runs it after writing each new preview view without
# tracking what it added last time.

require 'xcodeproj'
require 'pathname'

repo_root   = Pathname.new(__dir__).parent.parent
project_path = repo_root.join('iphone/MakeReady.xcodeproj')
preview_dir  = repo_root.join('iphone/MakeReady/UI2Preview')

abort("no preview directory at #{preview_dir}") unless preview_dir.directory?

project = Xcodeproj::Project.open(project_path.to_s)
target  = project.targets.find { |t| t.name == 'MakeReady' }
abort('MakeReady target not found') if target.nil?

# The group is created relative to the MakeReady group so the pbxproj records a
# relative path, not this machine's absolute one.
parent = project.main_group.find_subpath('MakeReady', false)
abort('MakeReady group not found') if parent.nil?
group = parent.find_subpath('UI2Preview', true)
group.set_source_tree('<group>')
group.set_path('UI2Preview')

existing = group.files.to_h { |f| [f.display_name, f] }
added = []

Dir.glob(preview_dir.join('*.swift')).sort.each do |path|
  name = File.basename(path)
  ref = existing[name] || group.new_reference(name)
  next if target.source_build_phase.files_references.include?(ref)

  target.add_file_references([ref])
  added << name
end

# Drop references to files that no longer exist on disk, so a deleted preview
# does not break the build with a missing-file error.
removed = group.files.reject { |f| File.exist?(preview_dir.join(f.display_name)) }
removed.each(&:remove_from_project)

project.save
puts "UI2Preview: #{group.files.count} file(s) in target MakeReady"
puts "  added:   #{added.empty? ? '(none)' : added.join(', ')}"
puts "  removed: #{removed.empty? ? '(none)' : removed.map(&:display_name).join(', ')}"
```

- [ ] **Step 2: Run it and verify the file landed in the target**

```bash
ruby iphone/scripts/ui2-preview-sync.rb
grep -c "UI2PreviewTokens.swift" iphone/MakeReady.xcodeproj/project.pbxproj
```
Expected: the script reports 1 file added; the grep returns **2** — one `PBXFileReference`
and one `PBXBuildFile`. A count of 1 means the file was referenced but not added to the
build phase, which is the failure this task exists to prevent.

- [ ] **Step 3: Verify idempotency — the property the whole design rests on**

```bash
ruby iphone/scripts/ui2-preview-sync.rb
grep -c "UI2PreviewTokens.swift" iphone/MakeReady.xcodeproj/project.pbxproj
```
Expected: still **2**, and the script reports `added: (none)`. If the count grew, the
duplicate-detection is wrong and every `/ui2-component-build` run would corrupt the project.

- [ ] **Step 4: Verify the project still opens and builds**

```bash
xcodebuild -project iphone/MakeReady.xcodeproj -list 2>&1 | head -20
```
Expected: the schemes and targets list, no parse error. If this fails, `git checkout
iphone/MakeReady.xcodeproj/project.pbxproj` and report — do not attempt a hand repair.

- [ ] **Step 5: Inspect the diff before committing**

```bash
git diff --stat iphone/MakeReady.xcodeproj/project.pbxproj
```
Expected: a small diff adding a group, a file reference, and a build file. A diff that
reorders or rewrites large regions of the file means the gem normalised something — report
it rather than committing it.

- [ ] **Step 6: Commit**

```bash
git add iphone/scripts/ui2-preview-sync.rb iphone/MakeReady.xcodeproj/project.pbxproj
git commit -m "feat(ui2): sync UI2Preview folder into the MakeReady target"
```
