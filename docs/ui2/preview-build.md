# UI 2.0 Preview Build (DECISIONS.md D11 mechanics)

**What this lane is.** A per-component build that turns a specced 2.0 component into a
**capturable preview** — a real SwiftUI view, rendered in the simulator, registered as the
`iphone` side of the component's existing comparison so the browser shows it beside its
frozen Figma snapshot and diffs the two. It is driven by `/ui2-component-build <C-###>`,
one component per run, and it is the 2.0 analogue of what `/compare` does for 1.0 (iOS as
reference, web as the twin) with **Figma as the reference and Swift as the twin**.

**What this lane is not.** It is not the app build. Preview code is wired into no screen,
no route, no navigation shell and no flag. It commits the program to nothing that
`migration.md` reserves for the `ui2-shell` suite — in particular it does **not** decide
the real 2.0 tree path, the shell flag, or the navigation namespace. When `ui2-shell`
lands, it promotes these files (§7); until then they exist to be looked at and diffed.

Related program docs: `migration.md` (isolation rules this lane obeys), `DECISIONS.md`
D2/D6/D7/D10, `design-system/registry.md` (the component universe), `design-system/tokens.md`
(the token source this lane generates from).

## 1. The loop

```
contract (components/C-###-<slug>.md)
   │  §4 props table × §3 state matrix
   ▼
tokens.md ──▶ UI2Preview/Tokens.swift       (generated, every run)
   │
   ▼
UI2Preview/<Name>.swift                     (the view, states driven by props)
   │
   ▼
fixtures/ui2/C-###.json                     (one entry per §3 state, props from §4)
   │
   ▼
ViewRegistry.swift  case "component.ui2.C-###"  (decodes the fixture into the view)
   │
   ▼
simulator capture ──▶ iphone screenshot on comparison `ui2-c-###`
   │
   ▼
browser: Figma snapshot ⇄ built render, per state, with the existing diff + comments
```

## 2. Where things live

| Artifact | Path | Owner |
|---|---|---|
| The view | `iphone/MakeReady/UI2Preview/<RegistryName>.swift` | this lane |
| Generated tokens | `iphone/MakeReady/UI2Preview/Tokens.swift` | generated from `tokens.md` — never hand-edited |
| Folder README | `iphone/MakeReady/UI2Preview/README.md` | states the preview-only rule + promotion path |
| Xcode target | `UI2Preview` (framework) in `iphone/MakeReady.xcodeproj` | membership synced by `iphone/scripts/ui2-preview-sync.rb` |
| Fixture | `capture/fixtures/ui2/C-###.json` | generated from the contract |
| Registry case | `iphone/MakeReadyCaptureTests/ViewRegistry.swift` | one `case "component.ui2.C-###"` appended |
| Command | `.claude/commands/ui2-component-build.md` | beside `/ui2-component`, `/ui2-screen` |

### The module (decided 2026-09-06 by the owner; binding from here)

**Preview views compile into their own Swift module, `UI2Preview`, and their types carry no
prefix.** Registry row `TextInput` → `struct TextInput` in
`iphone/MakeReady/UI2Preview/TextInput.swift`. The registry name **is** the type name, with
nothing bolted on.

**Why a module and not a folder.** A folder is not a namespace in Swift. Every file in a
target shares one flat namespace no matter which directory it sits in, so
`MakeReady/UI2Preview/PageHeader.swift` and `MakeReady/Components/Navigation/PageHeader.swift`
were two declarations of the same name in the same module — a redeclaration error against a
legacy file rule 2 forbids touching. Measured 2026-09-06: **6 of the 69 registry rows** name a
`struct` that already exists in `MakeReady/` — `Avatar`, `FieldGroup`, `PageHeader`,
`RecordButton`, `SearchField`, `TextInput`. A **module** is a namespace: `UI2Preview.PageHeader`
and `MakeReady.PageHeader` are different types that coexist, and inside `UI2Preview/` the plain
name resolves to the 2.0 one with no ceremony.

A uniform `UI2` type prefix was tried first (2026-09-06, C-045) and **rejected by the owner**:
it made 69 types carry a marker for a collision that only 6 of them had, and it deferred the
whole rename to cutover — see §7.

**The sources stay on disk at `iphone/MakeReady/UI2Preview/`** even though they are not in the
`MakeReady` target. The path is stable across the whole lane's docs and commands, and
SwiftLint's `included: MakeReady` keeps covering them. The pbxproj is the authority on
membership, not the directory: **a file in that folder is in the `UI2Preview` target and
nowhere else.**

**The module does not depend on `MakeReady`.** It imports SwiftUI and nothing else. If a
preview view ever needs a 1.0 type, that is a spec defect (rule 2 territory), not a linkage to
add.

**The test target reaches it with `@testable import UI2Preview`**, beside its existing
`@testable import MakeReady`. Testability is enabled by the project's Debug configuration,
which is the configuration the scheme's TestAction — and therefore every capture — builds
under; the types stay internal rather than being made `public` for the sake of one importer.
Because `ViewRegistry.swift` imports *both* modules, the six colliding names are ambiguous
**there**: every 2.0 reference in it is written `UI2Preview.TextInput`, and the pre-existing
1.0 references to a colliding name are written `MakeReady.TextInput`. That qualification is
confined to `ViewRegistry.swift` and is the only place the collision is still visible.

**The `ViewRegistry` case key does not change.** It stays `component.ui2.C-###`, and the
fixture, the comparison row and the browser URL all key on the registry **ID** — never on the
type name.

**No `#if DEBUG` wrapper.** Unreferenced SwiftUI views cost binary bytes and no behaviour, and
a DEBUG wrapper is one more thing `ui2-shell` would have to unpick at promotion.

## 3. Binding rules

1. **Preview code is never wired into the app.** No screen, route, tab, flag or
   `NavigationCoordinator` case references `UI2Preview/`. A build run that would need one
   stops and says so.
2. **Legacy is untouched** (D2). `Colors.swift`, `Typography.swift`, `Pages/`,
   `Services/Route.swift` are not edited by this lane. The one legacy-adjacent file it
   writes is `ViewRegistry.swift` — see rule 3.
3. **Test-target capture plumbing is allowed.** `ViewRegistry.swift` lives in the *test*
   target and is a fixture-key → view map, not shipping UI, so appending a case does not
   blend 2.0 UI into legacy and does not engage D2. Recorded here so a later audit does not
   flag it.

   **Amended 2026-09-06:** the same reasoning extends to `CaptureFixture.swift`'s
   `CaptureComponent` struct in that target. Props reach Swift through it, and it is a fixed
   `Codable` type — an unknown JSON key decodes to **nothing, silently**, so a prop the
   struct has no field for is dropped without an error and the state renders wrong with no
   diagnostic. Additions there are permitted under two bounds: **additive optional fields
   only**, and **never bend a prop name to fit an existing field** — a contract's prop name
   is the contract's, not something to rename into whatever the struct already has. Every
   field added is named in the run's report.
4. **Tokens are generated, by name** (D7, `migration.md` rule 4). Every colour, type,
   spacing, radius and elevation value in a preview view resolves to a
   `UI2Preview/Tokens.swift` symbol generated from `tokens.md`. A contract's **flagged
   literal** (e.g. C-034's `#1f2124`) is emitted as a literal with the contract's flag
   repeated in a comment — never silently promoted to a token. A value that is
   **contract-traceable but has no token row** (C-045's `py9` inset, OQ-PB-5) is emitted as a
   literal with a `GAP —` comment citing the contract line, and raised as an OQ — distinct
   from a value that is **neither tokened nor traceable**, which still stops the build as a
   spec defect (rule 5).
5. **Every prop value traces to the contract.** A fixture entry's props come from §4's prop
   table crossed with that state's row in the §3 matrix, plus the contract's own sample
   strings. The build invents no prop, no state and no value; needing one is a spec defect,
   resolved by a `/ui2-component` re-run, not in Swift.
6. **States are the contract's states.** Fixture variant names are the §3 matrix labels
   verbatim (the same strings the browser uses as version and comment keys — see §5), and
   every `consumed` / `designed-unconsumed` row gets one. `undesigned` rows are **skipped**:
   there is no design to render, so rendering one would be inventing the ruling its OQ is
   waiting for.
7. **Re-runs are idempotent in what they WRITE, and additive in what they capture.** A
   second run against an unchanged contract rewrites the same generated files byte-for-byte.
   Capture is different: `captureVariant` creates a Version per run unconditionally, so a
   re-capture always appends to the timeline rather than deduplicating on an unchanged
   render. That is deliberate — the version history is a capture log, and the browser's
   diff is what shows whether anything moved. (Corrected 2026-09-06: an earlier wording
   claimed a new version was created "only if the render changed", which the runner has
   never done.)

## 4. Dependencies

A component consumes other registry rows (C-040 consumes C-021 GlyphButton). Resolution
order per consumed row:

1. **Component contract file** (`components/C-###-*.md`) — build against it; build that
   component first if it has no preview yet.
2. **Screen-spec §4 anchor** — D10 accepts a screen spec's §4 as a full contract anchor, so
   this is a legitimate source. Build from it.
3. **Registry row only** — emit a **flagged stub**: correct size and layout slot, obviously
   unfinished fill, a `// STUB — C-###, no prop-level contract` comment, and a line in the
   run's report naming what would spec it.

Refusing outright at level 3 would make almost every component unbuildable today, which
defeats the lane. A stub is visible in the render, so the diff shows the gap rather than
hiding it.

## 5. The comparison row — one owner

The browser already registers each specced row as comparison `ui2-c-###` with the contract's
states as variants and the Figma PNG as a `design` screenshot
(`capture/server.mjs` `syncUi2Row`). The built preview adds an `iphone` screenshot to
**those same variants**, so the version timeline, pinned comments and pixel diff work
unchanged.

**Hazard found while designing this (2026-09-06):** `syncComparison`
(`capture/db/index.mjs`) upserts `type`, `groupName`, `title` and `adapter` on *every*
call. If the preview fixture were dropped under `capture/fixtures/compare/`, the compare
loader (`runners/compare/lib.mjs` `loadComparisons`) would sync the same id with its own
values and the two writers would overwrite each other on every request.

**Therefore the fixture lives at `capture/fixtures/ui2/`, a root the compare loader does not
read,** and `syncUi2Row` stays the single writer of the `ui2-c-###` comparison row. The ui2
capture path reads the fixture directly and registers screenshots against the row
`syncUi2Row` owns.

Rejected alternatives: making the generated fixture mirror `syncUi2Row`'s exact
`type`/`group`/`title` (fragile — a registry rename silently reopens the fight); teaching
`syncUi2Row` to defer when a fixture exists (splits ownership on a condition, which is the
same bug with more steps).

**Known side effect of every capture (observed 2026-09-06, C-045).** The ui2 runner reaches
the simulator through `capture/runners/iphone/capture.sh`, which runs the **whole**
`CaptureRunner` test suite — there is no per-view filter. So one ui2 capture also re-renders
roughly 20 unrelated 1.0 baselines under `capture/fixtures/iphone/*/screenshots/`, and they
show up as modified files having nothing to do with the component being built. This is
pre-existing runner behaviour, not something this lane introduced, and nothing is broken.
Leave them out of the commit; restore them with:

```bash
git checkout capture/fixtures/iphone
```

## 6. What "built" means

A row is **built** when its fixture exists at `capture/fixtures/ui2/C-###.json` — an fs
check, mirroring how the 1.0 era derives `wired` from fixture + adapter presence. The
browser surfaces three states per row, and the Details tab keys its empty state off them:

| State | Condition | Details tab shows |
|---|---|---|
| not specced | no contract file | the `/ui2-component` command that specs it |
| specced, not built | contract, no fixture | props + derived sample call, and the `/ui2-component-build` command |
| built | fixture present | props + sample call + the built render beside the Figma snapshot |

## 7. Promotion (what `ui2-shell` inherits)

At cutover **1.0 is deleted** — D2's "parallel shell, hard cutover", with the legacy-tree
removal already a phase in `migration.md`'s cutover execution. The two UIs never run
side by side in production; the parallel period exists only while 2.0 is being built.

Two things follow, and they are the argument for the module:

1. **The collisions this module solves are temporary.** They exist only while
   `MakeReady/Components/` still holds the 1.0 `Avatar`, `FieldGroup`, `PageHeader`,
   `RecordButton`, `SearchField` and `TextInput`. Once those are deleted, nothing in the app
   owns those names.
2. **Which is exactly why the types are named plainly now.** Because they are already
   `PageHeader` and `TextInput` rather than `UI2PageHeader`/`UI2TextInput`, promotion is a
   file move with **zero renames** — `ui2-shell` can keep `UI2Preview` as a module or dissolve
   it into the app target, and no type changes name either way. A prefix would have bundled a
   69-type mechanical rename into the same change that deletes the legacy tree, which is the
   worst possible moment for it.

So: `ui2-shell` decides the tree path and whether the module survives; the files move,
`Tokens.swift` comes with them (same generator, new path), ViewRegistry cases stay — a
promoted component is still worth capturing — and **no type is renamed at any point**. Stubs
from §4 rule 3 must be resolved before promotion; the cutover checklist in `migration.md`
gains that gate. `migration.md` owns the cutover plan; this section only says how the module
lands in it.

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-PB-1 | Viewports: the 1.0 fixtures capture `pro-max` + `se`. Is a component preview captured at both, or at the master width the contract states (387/398pt) plus one device? | No — proposed default: the contract's master width plus `pro-max` | owner |
| OQ-PB-2 | Does a built preview render on `color-layout-background`, or on transparency so the diff isolates the component? C-040's bar is itself transparent, so the choice is visible | No — proposed default: `color-layout-background`, matching how the Figma snapshot is framed | owner |
| OQ-PB-3 | Interaction-bearing props (`onBack`, `onChange`) have no render effect. Emit them as no-ops for signature fidelity, or omit them from the preview view entirely? | No — proposed default: emit as no-ops, so the promoted view keeps its real signature | owner |
| OQ-PB-4 | When a contract changes after a build, does the command auto-rebuild every affected component, or report drift and wait? | No — proposed default: report drift, rebuild on request | owner |
| OQ-PB-5 | **Live rule-4 deviation (C-045, 2026-09-06):** the Multi state's `py9` vertical inset has no row in `tokens.md` (the spacing family is 16/16/8/32/4/2/24), so `UI2Preview/TextInput.swift` emits `9` as a literal with a `GAP —` comment citing C-045 §2. The value is contract-traceable — only its token *name* is missing — so this is not an invented value, but it is also not a token by name. Fix either way: a `/ui2-component` re-run that lands a 9pt spacing row in `tokens.md`, or one that flags the literal in C-045 §2 so rule 4's flagged-literal path covers it properly. Until then the literal stands and this row is why. | No | owner (which of the two fixes) |
