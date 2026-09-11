---
description: Build ONE specced UI 2.0 component as a capturable SwiftUI preview — resolve its dependencies, regenerate the tokens, write the view under iphone/MakeReady/UI2Preview/, generate its fixture + ViewRegistry case, capture it in the simulator, and diff the render against its frozen Figma snapshot. The build-side sibling of /ui2-component; wired into no screen, route or flag. Designed to run in a FRESH session.
argument-hint: [C-### registry id (or component name); omit to be shown the specced-but-unbuilt rows]
---

# UI 2.0 component preview build — $ARGUMENTS

Build the specced component **$ARGUMENTS** into a **capturable preview**: a real SwiftUI
view, rendered in the simulator, registered as the `iphone` side of the component's
existing comparison so the browser shows it beside its frozen Figma snapshot and diffs the
two. Figma is the reference, Swift is the twin. Work ONE component per run; each phase
ends with something verifiable.

**Read `docs/ui2/preview-build.md` in full before phase 1** — it is the spec this command
executes. Its §3 binding rules and §4 dependency order are cited below, not restated.

**Arguments:** `<C-###>` → build that registry row. A component *name* → resolve it against
`docs/ui2/design-system/registry.md` and say which row you resolved to (two candidates →
ask, never guess).

**No argument → print the build queue, then ask which one with AskUserQuestion; never pick
for the user.** The
queue is every row that is *buildable* — a contract file at
`docs/ui2/design-system/components/C-###-*.md` (a row anchored only in a screen spec's §4
is a legal dependency but not a legal target, phase 0.3) — annotated with what a build would
actually cost, because "specced but not built" alone hides the thing that decides the run:
whether its dependencies have contracts of their own. A component whose dependency resolves
at level 2 or 3 will hit an artwork or prop gap it cannot close without a `/ui2-component`
run, and the user deserves to know that *before* choosing, not in the phase 6 report.

Run this from the repo root and print its table verbatim:

```bash
node --input-type=module -e '
import fs from "node:fs/promises";
import path from "node:path";
const dir = "docs/ui2/design-system/components";
const rows = [];
for (const f of (await fs.readdir(dir)).filter((f) => /^C-\d{3}-.*\.md$/.test(f)).sort()) {
  const md = await fs.readFile(path.join(dir, f), "utf8");
  const id = f.slice(0, 5);
  const name = (md.match(/^# C-\d{3} (\S+)/m) ?? [])[1] ?? "?";
  const built = await fs.access(`capture/fixtures/ui2/${id}.json`).then(() => true, () => false);
  const snap = (md.match(/Frozen snapshot:\s*`assets\/([^`]+)`/) ?? [])[1];
  const hasSnap = snap ? await fs.access(path.join(dir, "assets", snap)).then(() => true, () => false) : false;
  // §5 Consumes — the first bullet only; "Consumed by" is not a dependency.
  const consumes = (md.match(/\*\*Consumes:\*\*([\s\S]*?)(?=\n- \*\*|\n## )/) ?? [])[1] ?? "";
  const deps = [...new Set(consumes.match(/C-\d{3}/g) ?? [])];
  const levels = await Promise.all(deps.map(async (d) => {
    const hit = (await fs.readdir(dir)).find((x) => x.startsWith(d));
    return { d, level: hit ? 1 : 2 };   // 2 = screen-spec anchor or registry row only
  }));
  const gapped = levels.filter((l) => l.level > 1).map((l) => l.d);
  // Notes are requirements BEYOND the contract (phase 0.7), so they are part of
  // what a build costs: a row with notes has intent the contract does not carry.
  const notes = await fs.readFile(`docs/ui2/design-system/components/notes/${id}.md`, "utf8")
    .then((t) => (t.match(/^## \d{4}-/gm) ?? []).length, () => 0);
  rows.push({ id, name, built, hasSnap, deps: deps.length, gapped, notes });
}
for (const r of rows) {
  const state = r.built ? "BUILT" : !r.hasSnap ? "no snapshot" : r.gapped.length ? `gaps: ${r.gapped.join(",")}` : "clean";
  const notes = r.notes ? `${r.notes} note${r.notes === 1 ? "" : "s"}` : "";
  console.log(`${r.id}  ${r.name.padEnd(20)} ${(r.built ? "—" : "buildable").padEnd(10)} ${state.padEnd(22)} ${notes}`);
}
'
```

Read the result out as three groups, in this order, and say what each means:

- **Clean** — contract, snapshot, and every dependency has its own contract. A build here
  should produce no dependency gap at all.
- **Gaps: C-0xx** — buildable now, but the named dependency has no contract of its own, so
  it resolves at level 2 or 3 (`preview-build.md` §4) and the run will surface an artwork or
  prop gap it cannot honestly close. Name the `/ui2-component` run that would close it, and
  let the user decide whether to build now and rebuild later, or spec the dependency first.
- **BUILT** — already has a fixture; choosing it is a *re-build* (rule 8), which reports
  drift against the contract rather than starting fresh. A BUILT row **with notes** is
  usually a `/ui2-component-update` run rather than a rebuild: that command verifies the
  existing preview against spec + notes instead of regenerating it.
- **N notes** — this row carries owner intent the contract does not: requirements beyond the
  spec that phase 0.7 loads and phases 3–4 treat as binding. Say the count out loud when
  briefing the choice; a component with notes costs more to build than its contract suggests.

A component that is `no snapshot` is not buildable — §1 cites a frozen snapshot that is not
on disk, so there is nothing to diff against. Say so and point at `/ui2-component`.

**Then offer the pick list — always, with AskUserQuestion.** Prose alone makes the user
retype an id the run already knows; the groups above are the *briefing*, the picker is the
*choice*. One question, `header: "Build target"`, `multiSelect: false`:

- **One option per buildable row**, `label` = `C-### Name` (e.g. `C-026 DualSeriesBarChart`),
  `description` = the cost of *that* build in one line — `clean · no dependency gaps` for a
  clean row, `gaps: C-069 NavTabButton (level 2) — will stub` for a gapped one.
- **Recommend one** — the cheapest clean row — by putting it first with `(Recommended)` on the
  label, and give the reason in its description.
- **BUILT rows are options too**, described as `re-build · reports drift (rule 8)`, and they
  sort last. Never omit them: a re-build is a legal target.
- **`no snapshot` rows are NOT options.** They cannot be built; they were named in the prose.
- Four options is the ceiling, so when more than four rows are buildable, offer the clean
  rows, the recommended row, and the cheapest gapped row — the full list is already printed
  above, and "Other" takes any `C-###` the user types.

Take the selection as the run's argument and continue at phase 0 exactly as if it had been
passed on the command line. Never build a row the user did not pick.

## How this differs from /ui2-component

`/ui2-component` WRITES the contract and touches nothing but `docs/ui2/`. This run READS a
frozen contract and produces code. It never edits `docs/ui2/` — not the contract, not the
registry, not `tokens.md` by hand. A gap discovered here (a missing prop, an unnamed value,
a state with no ruling) is a **spec defect**, fixed by re-running `/ui2-component` on that
component, never improvised in Swift. "Built" is not a registry field either: it is fixture
presence (`preview-build.md` §6), so a successful run needs no registry edit at all.

## Hard rules (re-read before EVERY phase)

- **Wired into nothing** (`preview-build.md` §3 rule 1). No screen, route, tab, flag or
  `NavigationCoordinator` case references `UI2Preview/`. A step that would need one stops
  and says so.
- **Legacy untouched** (rule 2). `Colors.swift`, `Typography.swift`, `Pages/`,
  `Services/Route.swift` are never edited. Outside `UI2Preview/` and `capture/fixtures/ui2/`
  this command writes exactly three files: the two **test-target** files of phase 4
  (`ViewRegistry.swift`, `CaptureFixture.swift` — rule 3, amended 2026-09-06), and
  `iphone/MakeReady.xcodeproj/project.pbxproj`, rewritten by the sync script in phase 5
  because the target membership is what makes the view compile at all.
- **Tokens by name** (rule 4). Every colour, type, spacing and radius value resolves to a
  `Token` member generated from `tokens.md`. A contract's **flagged literal** stays a
  literal with the contract's flag repeated as a Swift comment — never silently promoted to
  a token. SwiftLint enforces the sharp edges as build errors (`iphone/.swiftlint.yml`):
  no `Color(hex:)`, no raw `.system(size:)`, no `print`/`NSLog`, no `LazyVStack`/`LazyVGrid`.
- **Value sets have one owner** (rule 5). A prop whose §4 Type cell enumerates values gets
  exactly those in the Data tab. A prop taking another row's set **cites that row** —
  `C-021 glyph`, `[C-021 glyph]` — and the options resolve from that contract, so adding a
  glyph to C-021 updates every consumer at once. Where the providing row ships artwork
  (`assets/<C-###>-<prop>-<value>.svg`), the Data tab renders a **picture picker**. Nothing
  to wire per component: it follows from the contract.
- **Every prop traces** (rule 6): §4's prop table crossed with that state's §3 row, plus the
  contract's own sample strings. Inventing a prop, a state or a value is a spec defect.
- **States are the contract's states** (rule 7). Fixture variant names are the §3 labels
  **verbatim** — they are the DB key for versions and comments. `undesigned` rows are
  skipped entirely: there is no design to render, and rendering one pre-empts the ruling its
  OQ is waiting for.
- **Name ≠ slug.** The variant `name` is the DB key; the `slug` is only for filenames and
  CLI arguments. Never key anything on the slug, never hand-type the name (phase 4b).
- **No `#if DEBUG`** (`preview-build.md` §2), and no `#Preview` block — the capture *is* the
  preview.
- **Idempotent and visible** (rule 8). A re-run against an unchanged contract rewrites the
  same files byte-for-byte; a changed contract is a re-build event, reported as drift.
- **Never fudge.** A render that cannot match the snapshot is a gap to surface, not a
  geometry to nudge.
- **Capture without asking** (owner ruling 2026-09-08). The command's invocation is the
  permission: phase 5 syncs, lints, checks the preconditions and then captures, with no
  question in between. `iphone/.claude/CLAUDE.md` carries a carve-out naming
  `capture/runners/ui2/capture.mjs` for this; every OTHER build path there still requires an
  explicit yes.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why.

## 0. Load context

1. Read `docs/ui2/preview-build.md` in full, and `docs/ui2/DECISIONS.md` D10 + D11.
2. **Resolve the row.** Grep `docs/ui2/design-system/registry.md` for the id; note its name,
   status, section, Figma ref and "Defined in".
3. **The contract is required.** It is `docs/ui2/design-system/components/C-###-<slug>.md`.
   If the row has none, **stop** and print:
   `/ui2-component <name> <figma-url>  ← spec it first; there is nothing to build from`.
   (A row whose contract lives only in a screen spec's §4 is level 2 for a *dependency*
   (§4), but not a legal target for a build run — it has no frozen snapshot of its own to
   diff against. Say so and point at `/ui2-component`.)
4. Read the contract in full — all six sections — and confirm its frozen snapshot exists at
   `docs/ui2/design-system/components/assets/<file>.png` (the `Frozen snapshot:` line in §1).
   No snapshot ⇒ nothing to diff against: stop and say so.
5. Read `docs/ui2/design-system/tokens.md` (the families the contract cites) and
   `iphone/MakeReady/UI2Preview/Tokens.swift` — the generated file is the
   authority on **real member names**. Do not guess them.
6. **Rebuild check:** does `capture/fixtures/ui2/C-###.json` already exist? If so this is a
   re-build (rule 8) — read it now and diff the contract against it in phase 4, reporting
   what moved.
7. **Load the NOTES.** Notes are the owner's statements of intent about what a component is
   *for* — normative build input, not annotations
   (`docs/features/ui2-component-notes/01-architecture.md` D3/R11). Run:

   ```
   node capture/lib/ui2-notes.mjs read C-###          # the target
   node capture/lib/ui2-notes.mjs read <each dependency from phase 1>
   node capture/lib/ui2-notes.mjs read <each screen whose §4 names this row>
   ```

   - **Always through the CLI, never by reading the markdown.** The module is the parser; a
     second, eyeballed reading is exactly the divergence it exists to prevent.
   - **Dependencies count**: a note on `C-021` binds every component that renders a `C-021`.
   - **Screen notes count too**: the natural place to write "on @home-dashboard this chip
     pins to the leading edge" is while looking at that screen, and the note lands on the
     screen. The registry's "Consumed by" column names the screens to check.
   - Order every note oldest → newest across all sources. **Newer supersedes older, and a
     note supersedes the contract** — per property, not per note (R13).
   - Print the notes you loaded, with their ids, before doing anything with them. A build
     that silently honours an instruction the owner cannot see is worse than one that ignores
     it.

**Exit checklist 0:** preview-build.md + D11 read ✓ · row resolved with its registry fields ✓ ·
contract file present and read in full ✓ · frozen snapshot located ✓ · tokens.md + generated
token members read ✓ · rebuild-or-first-build known ✓ · notes loaded for target + dependencies +
consuming screens, and printed ✓

## 1. RESOLVE — dependencies

Read the contract's **§5 Composition**, and only its **Consumes** half — "Consumed by" names
the components that use *this* one and is not a dependency.

Resolve each consumed row by `preview-build.md` §4's order, and print the table:

| C-### | Name | Level | Source | Action |
|---|---|---|---|---|
| C-0xx | … | 1 · component contract | `docs/ui2/design-system/components/C-0xx-….md` | build against it |
| C-0xx | … | 2 · screen-spec §4 anchor | `docs/ui2/screens/<screen>.md` §4 | build against it (D10 accepts §4 as a full anchor) |
| C-0xx | … | 3 · registry row only | `registry.md` row | **flagged stub** |

- **Level 1** and the dependency has no preview of its own yet: prefer running
  `/ui2-component-build C-0xx` for it **first** — it has a contract and a snapshot, so it
  earns its own view, fixture and comparison row, and this component then composes the real
  thing. Building it inline as a private view in this file is the fallback; if you take it,
  say so and say why.
- **Level 3 stub** (§4 rule 3 — refusing here would make almost every component unbuildable,
  which defeats the lane): correct size and layout slot, obviously unfinished fill, and the
  comment `// STUB — C-###, no prop-level contract`. A stub is **recorded for the build
  report**, naming the `/ui2-component <name> <figma-url>` run that would spec it — never
  silently emitted. `preview-build.md` §7 gates promotion on stubs being resolved.

**Exit checklist 1:** §5 Consumes read (not Consumed-by) ✓ · every consumed row resolved to a
level with its source path ✓ · level-1 dependencies ordered (built first, or inline with a
reason) ✓ · every level-3 stub recorded with the command that would spec it ✓

## 2. TOKENS

From the repo root:

```bash
node capture/lib/ui2-tokens.mjs
```

It reads `docs/ui2/design-system/tokens.md` and rewrites
`iphone/MakeReady/UI2Preview/Tokens.swift`. Read its output: the counts line, and
any `NOT PARSED (no token emitted): …` line — those rows produced **no** token and cannot be
used by name.

Then read the generated file and write down, per value the contract cites, the exact member
you will use. The generator drops the family prefix and lowerCamels the rest:

| tokens.md | Swift |
|---|---|
| `color-card-border` | `Token.cardBorder` |
| `color-text-primary` | `Token.textPrimary` |
| `type-input` | `.designTextStyle(Token.TypeStyle.input)` |
| `space-page-margin` | `Token.Space.pageMargin` |
| `radius-card-sm` | `Token.Radius.cardSm` |

(Inside the `UI2Preview` module those names need no qualification. In
`ViewRegistry.swift`, which imports both modules, they are written
`UI2Preview.Token.…` — phase 4d.)

Every value the view needs is now one of exactly four things:

1. a `Token` member → use it;
2. the contract's **flagged literal** → emit the literal with the contract's flag repeated
   as a comment (`// FLAGGED LITERAL — C-034 §2: #1f2124, no token`);
3. **contract-traceable, but no token row** → the value traces cleanly to a specific
   contract line (a measured inset, a stated size) but `tokens.md` simply has no row for it
   yet — emit it as a literal with a `GAP —` comment citing the contract line
   (`// GAP — C-045 §2: py9, no spacing token`), and raise it as an OQ for the owner (a new
   `tokens.md` row, or a flag on the contract line). This is not a flagged literal (the
   contract never flagged it) and not a spec defect (it traces cleanly) — it is the path
   C-045's `py9` inset took (OQ-PB-5), and `preview-build.md` §3 rule 4 states it the same
   way.
4. **neither tokened nor traceable** → a spec defect. **Stop**, name the value and the
   contract line, and say the fix is a `/ui2-component` re-run that lands it in `tokens.md`
   or flags it. Do not invent a token, and never hand-edit the generated file (the next run
   overwrites it).

`git diff --stat iphone/MakeReady/UI2Preview/Tokens.swift` after the run tells you
whether `tokens.md` moved since the last build — report it if it did.

**Exit checklist 2:** generator run and its output read ✓ · no `NOT PARSED` row is one this
view needs ✓ · every contract value mapped to a member, a flagged literal, a cited `GAP —`
OQ, or stopped on as a spec defect ✓ · generated file not hand-edited ✓

## 3. WRITE — the view

**Notes bind here.** Where a note and the contract disagree, **the note wins** (D3), and the
code that implements it carries the note's id in a comment:

```swift
// note 2026-09-11T14:32:05.412Z — the active chip pins to the leading edge
```

That comment is what makes an override reviewable: without it, the next reader sees the view
contradicting its own contract and "fixes" it back.

**Naming — the registry name, plain** (`preview-build.md` §2). The view type and its file are
the registry name with nothing added: row `TextInput` → `struct TextInput` in
`iphone/MakeReady/UI2Preview/TextInput.swift`. **Do not check for a 1.0 namesake and do not
prefix.** `UI2Preview/` is its own Swift module — a folder is not a namespace in Swift, a
module is — so `UI2Preview.PageHeader` and `MakeReady.PageHeader` coexist and the six colliding
registry rows (`Avatar`, `FieldGroup`, `PageHeader`, `RecordButton`, `SearchField`,
`TextInput`) need no special handling here. The one place the collision is still visible is
`ViewRegistry.swift`, which imports both modules: qualify every 2.0 reference there
(`UI2Preview.TextInput`) — phase 4d.

The module imports **SwiftUI only**. A preview view that needs a `MakeReady` type is a spec
defect, not a linkage to add.

**The ViewRegistry case key does not change**: it stays `component.ui2.C-###`, keyed on the
**registry ID**, never on the Swift type name. The fixture, the comparison row and the browser
URL all key on `C-###` too.

One SwiftUI view in that file:

- **Parameters are §4's props** — same names, same types, in the contract's order. Every
  designed §3 state must be reachable **through the parameters alone**: a fixture can only
  set props, so a state driven by internal `@State` is uncapturable. (`focused`, `selected`
  and friends are props here, not `@FocusState`.)
- **Interaction-bearing props** (`onTap`, `onChange`, `onBack`) have no render effect. Emit
  them as defaulted no-op closures so the promoted view keeps its real signature —
  `preview-build.md` OQ-PB-3's proposed default. Say in the report that you took it.
- **Chrome-free and width-driven.** The view fills the width it is given and states its own
  intrinsic height; it paints no page background and adds no outer padding. The frame,
  background and padding belong to the ViewRegistry call site (phase 4d), so OQ-PB-1's
  master width and OQ-PB-2's `color-layout-background` are one line each to change when the
  owner rules, and the file itself is promotable unchanged (`preview-build.md` §7).
- **Tokens only**, per phase 2. No `Color(hex:)`, no `.system(size:)`, no legacy
  `Color.brand*` / `Typography.*` — those are rule-2 files.
- **No `#if DEBUG`, no `#Preview`, no lazy containers, no `print`/`NSLog`.**
- **Name the anatomy** with `.ui2Element("<part>")` (`UI2Preview/UI2Element.swift`). The 2.0
  browser has no web twin to hit-test, so a comment gets its element context from the parts
  the view names itself: the capture harness resolves each annotated rect and writes it
  beside the PNG, and the browser highlights it under the cursor in comment mode. Annotate
  the **root** (the registry name), **each §2 named slot**, and **each repeated item**
  (`"Bar \(index + 1)"`); use §2's own anatomy vocabulary, since that string is what the
  comment carries. A part whose identity changes with a prop says so — C-045's text run is
  `"Placeholder"` or `"Value"`. Nesting is NOT declared: the browser derives it from rect
  containment, so a dependency that names itself is reported inside whatever slot placed it.
  An unannotated component is not an error — it just has no highlights.
- File header: what it is, the contract path it was built from, and the preview-only rule —

```swift
//
//  <RegistryName>.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-###-<slug>.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
```

If `iphone/MakeReady/UI2Preview/README.md` does not exist, write it now —
`preview-build.md` §2 makes this folder's README part of the lane: it states the
preview-only rule and the §7 promotion path, and nothing else.

**Exit checklist 3:** one view, parameters == §4 props ✓ · every designed §3 state reachable
by props alone ✓ · tokens/flagged literals only ✓ · no `#if DEBUG` / `#Preview` / lazy
container / legacy import ✓ · root + every §2 named slot + every repeated item carries
`.ui2Element` ✓ · header cites the contract and the preview-only rule ✓ · folder README
present ✓

## 4. FIXTURE + REGISTRY CASE

**a. Derive** the fixture from the parsed contract — never hand-write it. From the repo root:

```bash
node --input-type=module -e '
import fs from "node:fs/promises";
import { parseContract } from "./capture/lib/ui2-index.mjs";
import { fixtureFromContract } from "./capture/lib/ui2-fixture.mjs";
const file = "docs/ui2/design-system/components/C-045-text-input.md";   // ← this contract
const contract = parseContract(await fs.readFile(file, "utf8"), { file });
console.log(JSON.stringify(fixtureFromContract(contract), null, 2));
console.log("§4 propRows:", JSON.stringify(contract.propRows));
'
```

This is the same parser the browser uses (`buildUi2Index`), which is the point: it already
skipped the `undesigned` rows, and its `name`/`slug` per state are exactly the keys
`syncUi2Row` registered the Figma snapshot under.

**b. Audit the draft** — it is a starting point, not an answer:

- **`name`** — leave every one exactly as printed. The design versions and the pinned
  comments for this state are keyed on that string; a hand-typed variation silently opens a
  second timeline beside the snapshot's.
- **`props`** — every key must be a **§4 prop name**. When §4 is prose, or the §3 matrix's
  leading column does not name a prop, the parser falls back to the Figma **axis** and emits
  a pseudo-prop: C-045 yields `{"state × lines": "Default × Single"}`. That is not a prop.
  Translate the axis value into §4 props yourself, per rule 6 — §4's table crossed with that
  state's §3 row (`Default × Single` → `text: ""`, `placeholder: "Placeholder"`,
  `lines: "single"`, `focused: false`). If the contract does not determine the translation,
  **stop**: that is the spec defect rule 6 describes, and it is fixed by `/ui2-component`.
- **`devices`** — **confirm**, don't override: the value must be a real `CaptureDevice`
  **raw value** from `iphone/MakeReadyCaptureTests/CaptureDevices.swift` (`iphone-se`,
  `iphone-15-pro`, `iphone-16-pro-max`), never a compare viewport key. `fixtureFromContract`
  emitted the viewport key `"pro-max"` until commit `2e22b74` fixed it at source; it now
  derives `iphone-16-pro-max` from `COMPARE_VIEWPORTS`, so the draft should already be right
  and the check is cheap. If it is ever a viewport key again, that is a regression in the
  module — fix it there, not in the fixture. (`iphone-16-pro-max` is OQ-PB-1's proposed
  default: the contract's master width plus `pro-max`.)
- **`view`** — `component.ui2.C-###`, matching the case you are about to add.

**c. Write** it through the module — `writeUi2Fixture` owns the path and the byte format, so
a later programmatic rewrite is identical (rule 8). Re-derive, apply the audited props keyed
by variant **name**, and let the loop throw if the audit missed a state:

```bash
node --input-type=module -e '
import fs from "node:fs/promises";
import { parseContract } from "./capture/lib/ui2-index.mjs";
import { fixtureFromContract, writeUi2Fixture } from "./capture/lib/ui2-fixture.mjs";
const file = "docs/ui2/design-system/components/C-045-text-input.md";   // ← this contract
const contract = parseContract(await fs.readFile(file, "utf8"), { file });
const fixture = fixtureFromContract(contract);
// devices comes from the module (fixed in 2e22b74) — verify, do not override:
if (!/^iphone-/.test(fixture.devices[0])) throw new Error(`not a CaptureDevice raw value: ${fixture.devices[0]}`);
const audited = {                               // §4 props per state, keyed by variant NAME
  "Default × Single": { text: "", placeholder: "Placeholder", lines: "single", focused: false },
  // … one entry per designed state, exactly the names printed in step a
};
for (const v of fixture.variants) {
  if (!audited[v.name]) throw new Error(`no audited props for state "${v.name}"`);
  v.props = audited[v.name];
}
await writeUi2Fixture(contract.id, fixture);
console.log(`wrote capture/fixtures/ui2/${contract.id}.json — ${fixture.variants.length} state(s)`);
'
```

Then round-trip it:

```bash
node --input-type=module -e '
import { readUi2Fixture } from "./capture/lib/ui2-fixture.mjs";
const f = await readUi2Fixture("C-045");
console.log(f.view, f.devices, f.variants.map((v) => `${v.name} → ${v.slug}`));
'
```

**d. The registry case.** Append one case to `iphone/MakeReadyCaptureTests/ViewRegistry.swift`,
immediately before the final `default:` (~line 2509), decoding `fixture.state?.component`
exactly as the neighbouring `component.*` cases do (`component.card-study`, line 104).
**Module-qualify every 2.0 name** — the file imports both `MakeReady` and `UI2Preview`, and
the six colliding registry names are ambiguous without it (the pre-existing 1.0 call sites for
those names are qualified `MakeReady.…` for the same reason):

```swift
    case "component.ui2.C-###":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-###: missing state.component")
        }
        return AnyView(
            UI2Preview.<RegistryName>(/* §4 props from `c`, with the contract's defaults */)
                .frame(width: <master width from §2>)   // OQ-PB-1 default: the contract's master width
                .padding(UI2Preview.Token.Space.pageMargin)
                .frame(maxWidth: .infinity)             // fill the device width the runner renders at
                .background(UI2Preview.Token.layoutBackground)  // OQ-PB-2 default
        )
```

Every field on `c` is optional (see phase 4e) — supply **the contract's** default for a
missing one (`c.text ?? ""`), never an invented one; a prop the contract gives no default
for is required, so a nil is a fixture bug, not a value to guess.

The runner renders a `component.*` fixture at device width with intrinsic height and no
chrome, so the frame/padding/background live here, not in the view (phase 3) — an owner
ruling on OQ-PB-1/2 then changes this call site alone.

**e. `CaptureComponent` fields.** Props reach Swift through `CaptureComponent`
(`iphone/MakeReadyCaptureTests/CaptureFixture.swift:150`) — a fixed `Codable` struct. **A
JSON key with no matching field decodes to nothing, silently**, and the render comes out
default-valued with no error. So check every prop name in the fixture against the struct, and
add the missing ones as purely additive optionals in a UI 2.0 block at the end of it
(after `let organizations:`, ~line 354):

```swift
    // ── UI 2.0 preview (docs/ui2/preview-build.md) ──
    let lines: String?                         // C-045 TextInput
    let focused: Bool?
```

`preview-build.md` §3 rule 3 (amended 2026-09-06) permits this explicitly and states its two
bounds: **additive optional fields only**, and **never bend a prop name to fit an existing
field** — a contract's prop name is the contract's, not something to rename into whatever the
struct already has (that would break rule 6 as well). So: never modify, retype, rename or
reorder an existing field, and **name every field you add in the run's report**, as rule 3
requires. It is also how every 1.0 card was onboarded — see the struct's "added as cards were
onboarded" block.

**Exit checklist 4:** fixture derived from the parser, not hand-written ✓ · variant names
untouched ✓ · every prop key is a §4 prop with a contract-traceable value ✓ · `devices` is a
CaptureDevice raw value ✓ · fixture round-trips ✓ · ViewRegistry case added before `default:`
with the frame/background at the call site ✓ · every prop has a `CaptureComponent` field,
additions reported ✓

## 5. SYNC THE TARGET, THEN CAPTURE

**1. Sync.**

```bash
ruby iphone/scripts/ui2-preview-sync.rb
```

Files under `UI2Preview/` are **not** auto-included by folder — the project has no
filesystem-synchronised groups, so a generated file is invisible to the compiler until it is
referenced in the pbxproj. The script makes every `.swift` file under that folder a member of
the **`UI2Preview` framework target** (not `MakeReady` — `preview-build.md` §2). **A file that
is not in the target does not compile, and the capture fails minutes later with an
unknown-view error.** The script is idempotent and recursive; check its `added:` line names
your new view (and that `Tokens.swift` is in the count).

**2. Lint before you burn a build.** SwiftLint runs as a build phase, so a violation fails
the capture build *after* `xcodebuild` has already spent minutes:

```bash
cd iphone && swiftlint lint --quiet --baseline .swiftlint-baseline.json
```

That is the build phase's exact invocation (see the `SwiftLint - audit conventions` script
in `MakeReady.xcodeproj`): the `--baseline` flag is not optional here — without it the ~1,000
grandfathered violations print and drown the one you introduced. It runs in about a second.
Fix violations in the preview file. **Never** regenerate the baseline to silence one.

**3. Preconditions.** The runner writes `Version`/`Screenshot` rows *before* it captures, so
the capture Postgres must be up, and the simulator `runners/iphone/capture.sh` names must
exist:

```bash
pg_isready -h localhost -p 5434            # else: run /capture-start steps 1–2
xcrun simctl list devices available | grep 'iPhone 17 Pro Max'
```

(`simctl list` is the one simulator command allowed without asking.)

**4. NO ASK — capture is part of the run** (owner ruling 2026-09-08). Invoking
`/ui2-component-build` IS the permission: a build that stops before capturing has produced
nothing anyone can look at, which is the entire point of the lane. Do not ask, do not offer,
do not wait — go straight to step 5 as soon as steps 1–3 are green.

The blanket prohibition in `iphone/.claude/CLAUDE.md` ("NEVER build without explicit
permission") carries a **named carve-out for this runner** so the two documents agree; if
that carve-out is ever removed, this step reverts to asking. The carve-out is narrow on
purpose — it covers `capture/runners/ui2/capture.mjs` and nothing else. `/rebuild-iphone`,
a bare `xcodebuild`, and "let me just check it compiles" all still require an explicit yes.

Steps 1–3 are the gate that replaces the question: an unsynced file, a lint violation, a
dead Postgres or a missing simulator each stop the run **before** minutes are spent. A red
✗ there is not something to ask about — fix it or report it.

**5. Capture**, from the repo root, invoking the runner **directly**:

```bash
node capture/runners/ui2/capture.mjs C-### '*'
```

Not `POST /api/ui2/capture`: that endpoint returns `{ runId }` immediately and streams
progress over SSE — it is built for the browser, which subscribes and refreshes when the job
lands. A command that POSTed and then read the PNGs would race the simulator and read a
directory that is not written yet. The runner blocks until it finishes, prints its own log,
and exits non-zero if any state failed. One state at a time takes its **slug**:
`node capture/runners/ui2/capture.mjs C-045 default-single`.

**6. Read the renders** under

```
capture/fixtures/compare/_shots/ui2-c-###/design/iphone/<versionId>.png
```

`design` there is the DB **viewport** column `syncUi2Row` registers the Figma snapshot under
— not a device. The newest file per state is this run's.

Beside each render sits `<versionId>.elements.json` — the phase-3 `.ui2Element` annotations,
resolved. Check it exists and names the parts you annotated; if it is missing, the run said
`(no element map for …)` and the component's comments will have no element context. Its rects
are fractions of the render, so they are readable without opening the PNG.

**Expected collateral, do not commit it:** `capture.sh` re-runs the whole `CaptureRunner`
suite, so roughly 20 unrelated 1.0 baseline PNGs under `capture/fixtures/iphone/*/screenshots/`
are rewritten every capture (`preview-build.md` §5). Nothing broke. Leave them out of the
commit, or restore them with `git checkout capture/fixtures/iphone`.

**Exit checklist 5:** sync run and the new file named in its output ✓ · SwiftLint clean ✓ ·
Postgres + simulator present ✓ · runner invoked directly, without asking, and exited 0 ✓ · a
PNG per built state located ✓

## 6. DIFF AND REPORT

1. **Per state**, open the render beside the frozen snapshot
   (`docs/ui2/design-system/components/assets/<file>.png`) and read both against §2's
   geometry — dimensions, spacing, border, type, colour.
2. **Refine the view** (phase 3) and re-capture the state(s) that moved (phase 5 step 5;
   the sync in step 1 is only needed when a file was added or removed). Prefer the named
   state over `'*'` — each state is minutes.
3. **Stop refining when the remaining delta is a real gap**, and name its class:
   - **note-driven divergence** — a note (phase 0) told the build to do something the Figma
     snapshot does not show. This is EXPECTED, not a diff failure: the render is correct and
     the snapshot is what has fallen behind. Report these in their own list with the note id
     that caused each one, and never "fix" the view back toward the picture — that would undo
     the owner's own instruction;
   - SwiftUI genuinely cannot express the contract's construction;
   - the contract underspecifies what the snapshot shows (→ `/ui2-component` re-run);
   - a **stub** from phase 1 level 3;
   - a deviation the contract's §1 closed list already declares.
   **Surface the gap; never fudge the view to match the picture.** A render that matches by
   nudged geometry hides exactly what this lane exists to reveal.
4. **Look at it in the browser:** `http://localhost:5950/components/2.0/C-###/<slug>` —
   design ⇄ built toggle, pixel diff and pinned comments, per state (start it with
   `/capture-start` if 5950 is not up).
5. **Report to the user:**
   - **states built** — name + slug, and which ones you re-captured;
   - **states skipped** — every `undesigned` §3 row and the OQ it waits on;
   - **dependencies** — each with its resolution level, and every level-3 stub with the
     `/ui2-component` run that would spec it;
   - **tokens** — regenerated counts, anything `NOT PARSED`, any flagged literal emitted,
     and whether `UI2Preview/Tokens.swift` changed since the last build;
   - **test-target edits** — the `ViewRegistry` case, and every `CaptureComponent` field
     added (rule 3 requires them named);
   - **the view's name** — the registry name, plain, in module `UI2Preview`;
   - **OQ-PB defaults taken** (device/width, background, no-op closures, drift, and any
     later OQ-PB row), so an owner ruling has a list to overturn;
   - **drift** — on a re-build, what changed in the contract since the previous fixture
     (rule 8);
   - **note-driven divergence** — every difference a note caused, with its note id, kept
     separate from the gap list so the owner can see what their own instructions changed;
   - **gaps** — step 3's list, by class.

**Exit checklist 6:** every built state diffed against its snapshot ✓ · refinements
re-captured ✓ · remaining deltas classified as gaps, none fudged ✓ · browser URL given ✓ ·
report covers states/skips/dependencies/tokens/test-target edits/OQ defaults/drift/gaps ✓
