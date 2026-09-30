---
name: d2m-screen-build
description: Build ONE specced screen as a capturable preview — compose its §4 components (every one already built) into a presentational screen view in the project's preview module, create one preview per §3 state with sample data, add its capture-registry case, render every state through the project's configured renderer, and diff each render against that state's frozen frame. The build-side sibling of d2m-screen; wired into no app screen, route or flag. Designed to run in a FRESH session.
argument-hint: [screen slug, e.g. edit-text-single-field — omit to be shown the buildable screens] [--project <slug>] [--era <key>]
---

# Screen preview build — $ARGUMENTS

Build the specced screen **$ARGUMENTS** into a **capturable preview**: a presentational screen
view in the project's preview module, composed only of the screen's §4 components, rendered once
per §3 state by the project's configured renderer, and registered as the built side of the
screen's subject so the workbench shows each render beside its frozen frame. Figma is the
reference, the generated view is the twin. Work ONE screen per run; each phase ends with
something verifiable.

**Arguments:** `<screen-slug>` → build that screen. A screen *name* → resolve it against
`list_screens()` and say which slug you resolved to (two candidates → ask, never guess).
`--project <slug>` / `--era <key>` override the pinned scope; **pass them through to every tool
call.**

**This run reads spec content out of d2m and writes CODE into the project repo.** Those are the
only two places anything moves. It never edits a screen spec, a contract, a registry row or a
token row: a gap discovered here (a state with no rendering rule, an element with no §4 row, an
unnamed value) is a **spec defect**, fixed by re-running `/d2m-screen` on that screen (or
`/d2m-component` on that component), never improvised in code. It never writes `Screen.status`
either — "built" is the build record, which `build_status(screen: "<slug>")` answers.

## Before anything: is there a render lane?

`project_info()` — its `capture` block answers this outright (`canCapture`, and `missing` when
the lane is half-configured). If `captureAdapter` is **`noop`**, this project **has no render
lane**:

> `<project>` has no renderer configured (`captureAdapter: noop`). There is nothing to
> capture and nothing to diff, so there is no honest way to report a build. Configure the
> project's render command, output glob and devices in its d2m settings, then re-run.

**Say that and stop.** Do not generate a screen and call it a build; a preview nobody can render
is not the artifact this skill exists to produce. `capture` refuses on a `noop` project for the
same reason, so this check is not the only guard — but discovering it here costs nothing and
discovering it in phase 5 costs a whole run. The same stop applies when the adapter is real but
the lane is half-configured: print the `missing` list by name (`repoPath`, `previewDir`,
`renderJobDir`, `renderCmd`, `renderOutGlob`, `devices`) rather than failing minutes later inside
someone else's shell script.

`codeFlavor` decides what the generated view is written in. `swift` is the only flavour this
skill implements; on any other value, say so and stop rather than guessing a syntax.

## No argument → print the buildable screens, then ask

**Print the list, then ask which one with AskUserQuestion; never pick for the user.**

1. `list_screens()` — every screen with `specced` and `built`.
2. For each specced one, `get_screen(screen: "<slug>")` → `commands.build` (present exactly when
   the screen is buildable), `buildBlockedReason` (why not, when it is absent), `built`, and
   `components[]`.

Read the result out in these groups, in this order:

- **Buildable** — `commands.build` is present and `built` is false.
- **Blocked** — `commands.build` is absent: print `buildBlockedReason`, and for an unbuilt §4
  component the `/d2m-component-build C-### --project <slug> --era <key>` run that clears it.
- **BUILT** — `built` is true; choosing it is a *re-build* (every preview re-rendered, drift
  reported).

One question, `header: "Build target"`, `multiSelect: false`: one option per buildable or built
screen (`label` = the slug, `description` = `first build · N states in §3` or
`re-build · N previews`), buildable before built, the one with the fewest §4 components first
with `(Recommended)`. Blocked screens are not options. Four options is the ceiling; "Other"
takes any slug the user types. Continue at phase 0 with the selection exactly as if it had been
passed on the command line.

## Hard rules (re-read before EVERY phase)

- **Preview only, wired into nothing.** No app screen, route, tab, flag or navigation case
  references the preview module. A build that would need one stops and says so.
- **Legacy untouched.** The project's shipping colour, typography, page and routing sources are
  never edited. Outside `project.previewDir` this run writes exactly the files the capture
  harness requires: `project.tokensOutPath`, `project.registryCasePath`, the fixture-decoding
  type that sits beside it, and whatever `project.targetSyncCmd` rewrites to make a generated
  file compile. **Name every one of them in the report**, and write nothing else. No change to
  the project's capture scripts.
- **Composed only of §4 components.** Every visible element of the screen is an instance of a
  §4 component's built view, or layout between them (stacks, spacing, the page background, the
  page margins). An element §4 does not list is a spec defect — stop and name the
  `/d2m-screen <slug>` re-run. Never inline a component's view, never stub one: an unbuilt §4
  component stops the run in phase 0. **One exception:** a §4 part the owner has **deferred** on
  this screen (`deferred` set on its `components[]` entry, or a container / unlinked drawing with
  `deferred` set in `get_drawings`) is built as the placeholder phase 3 describes when it is
  drawn, and as nothing when it is not.
- **Presentational, not wired (D6).** One `State` input decoded from the preview's props makes
  every §3 state reachable by parameters alone. UI-only rules §3 states (a control's
  enabled/disabled, a field's local text, a value compared with its initial value) are real
  local state. Every action that leaves the screen — save, cancel, back, navigation, network, AI
  suggestions — is an `on<Verb>` closure defaulting to a no-op. §5 endpoints are cited in the
  file header only. No networking, view models, service protocols, routes or navigation cases.
- **Tokens by name.** Every colour, type, spacing and radius value resolves to a member of the
  token file generated from `get_tokens()` (phase 2). A flagged literal stays a literal with its
  flag repeated as a code comment. A value neither tokened nor traceable to the spec is a spec
  defect: stop. The project's `lintCmd` enforces the sharp edges; run it before you burn a
  render.
- **The rulebook is the convention.** How local state is owned, how actions leave a view, how a
  callback, a boolean, an acronym or a domain word is spelled — `get_rules()` (phase 0) answers
  each of those, ruled or defaulted, and this file does not. One exception, and it is not a
  convention: the capture harness's own files — the registry case at `project.registryCasePath`
  keyed `screen.<era>.<slug>`, the decoding type beside it, the capture runner's `screen.*`
  device-canvas branch (phase 4g) — and the file location, which is the server's
  `get_screen.buildPath` under `previewDir` and never derived here, are what make a screen
  reviewable here. A ruled entry
  that would remove or relocate them is reported as a **conflict** in the report's rulebook
  section, and the harness wins until the owner re-rules.
- **States are §3's states — ALL of them (D2, D17).** One preview per state in §3's closed list.
  On the first build you derive that list from §3; from then on the previews ARE the list: a
  re-build adds a preview for a new §3 state and **never deletes, renames or relabels** one — a
  state no longer in §3 is reported, not removed. A state with no frozen frame is still built,
  captured and reported as "not diffed — no frozen frame"; it is not a failure.
- **Frames are frozen by `/d2m-screen`, not here (D10).**
  This run never calls `attach_asset` or `refresh_snapshot`. A §3 state whose Figma node the spec names but which has no frozen frame is
  reported with the `/d2m-screen <slug>` run that would freeze it.
- **Name ≠ slug.** d2m keys a preview's history on its **id**; the **slug** is assigned once
  from the label and is what a URL and a `state:` argument take; the **label** is §3's display
  string, verbatim.
- **Idempotent and visible.** A re-run against an unchanged spec rewrites the same files
  byte-for-byte; a changed spec is a re-build event, reported as drift.
- **Never fudge.** A render that cannot match its frame is a gap to surface, not a geometry to
  nudge.
- **Capture without asking.** The skill's invocation is the permission: phase 5 syncs, lints,
  re-checks the gate and then captures, with no question in between. If the project repo's own
  agent instructions forbid builds without explicit permission, this run's renderer is the named
  carve-out and **nothing else** is — a bare build command, or "let me just check it compiles",
  still needs a yes.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why.

## 0. Load context

1. `project_info()` — **state the project slug and era key in your first report line.** Keep
   `repoPath`, `previewDir`, `tokensOutPath`, `registryCasePath`, `renderJobDir`, `devices`,
   `targetSyncCmd`, `lintCmd`, `codeFlavor`, `captureAdapter`. Every path this run touches comes
   from here; a hardcoded one is a bug even when it happens to be right.
2. **Resolve the screen.** `get_screen(screen: "<slug>")` — name, status, `spec`, `components`,
   `identifiedFrom`, `variants`, `built`, `commands`, `buildBlockedReason`, `canCapture`,
   `namespace`, `buildPath`, `relocate`. If it answers that the id **is a collection, not a
   screen**, stop and say: mint a screen out of it in the app, then build that screen.
   - **The file location is `buildPath` (screen-organization D5).** It is
     `Screens/<NamespaceFolder>/<Name>Screen.swift`, relative to `previewDir`, computed by the
     server from the screen's namespace. Never derive a path yourself. If `buildPath` is null the
     screen has no namespace: stop, print `buildBlockedReason` verbatim, and print
     `set a namespace on the screen's Screen tab in d2m, then re-run`.
   - **A built sibling with no namespace (F10).** When `identifiedFrom` is set: `list_screens()`
     → the built siblings (rows with `built: true`; `get_screen` on each — a sibling has the same
     `identifiedFrom`). If any built sibling has `namespace: null`, STOP before writing anything
     and print, for each: `<sibling> is built with no namespace — set a namespace on <sibling>
     first: a template build re-records every built sibling, and a sibling with no namespace
     cannot record`. This is the only D8 check made here — d2m never writes the target repo ahead
     of the gate below, so the actual moves wait until it passes (step 4).
3. **The gate (D4, D15). Stop on the first condition that fails**, print it, and print the run
   that clears it:
   - **Status.** `status` must be one of `specced`, `gap_checked`, `built`, `verified`. Anything
     else: `/d2m-screen <slug> --project <slug> --era <key>  ← spec it first`.
   - **Spec present.** `spec` null → the same `/d2m-screen` line.
   - **Every §4 component built or deferred.** Every entry of `components[]` must have
     `built: true`, or `deferred` set (a deferred part never blocks; note it for phase 1). An
     entry with `name: null` is a struck or merged row — a spec defect, cleared by a
     `/d2m-screen` re-run. A deferred entry with `name: null` is struck or merged too and still blocks:
     its deferral does not clear it; the same `/d2m-screen` re-run does. For each unbuilt one, deepest first:
     `/d2m-component-build C-### --project <slug> --era <key>  ← <Name>, a §4 part of <slug>`,
     then `re-run this build once they are green`. Never build around an unbuilt part.
   - **No blocking open question.** In `spec.openQuestions`, any row with `status: open`,
     `blocking: true` and `reference: false` stops the run: print id + question, then
     `answer it in d2m (Spec tab → click the question) and re-run`. A NON-blocking open question
     does not stop the run: take its proposed default (`options[recommended]`, or the
     "Proposed default" in its prose) and list it under **Defaults taken** in the report.
   - `commands.build` is the server's own answer to the same gate: when it is absent,
     `buildBlockedReason` names the first failing condition (on a built screen, the missing
     namespace or, while `relocate` holds, the gate's own reason) — print it verbatim. The namespace is the gate's last check. If your reading and
     the server's disagree, trust the server and say so.
4. **Move now that the gate has passed (D7, D8).** Nothing before this step wrote to the target
   repo — a build the gate above refused leaves nothing staged there. From `project.repoPath`:
   - **Relocate (D7).** When `relocate` is true the screen was built at a path that is no longer
     its `buildPath` (its namespace was set or renamed since). Read the old path from
     `build_status(screen: "<slug>")` → `previewPath`; create the new folder and
     `git mv <previewDir>/<previewPath> <previewDir>/<buildPath>`. If the old file is gone, say so
     and write the new one fresh in phase 3. Phase 4 records `previewPath: "<buildPath>"`, and
     phase 5's `targetSyncCmd` picks the move up. Print `relocated: <old> → <new>`.
   - **Shared template (D8).** When `identifiedFrom` is set and step 2 found no built sibling
     missing a namespace: read each built sibling's template path from the `other:` lines of
     `build_status(screen: "<sibling>").lastBuildLog`. Already under `Screens/Shared/`, or the
     recorded file is missing → don't move anything, just re-record. Otherwise `git mv` it to
     `<previewDir>/Screens/Shared/<CollectionName>Template.swift`. Phase 4 re-records every built
     sibling's `otherPaths` with that path.
5. **Read the spec in full** — all eight sections, `spec.sections`. From §3, the CLOSED states
   list with how each renders; from §2, the layout top→bottom; from §4, the roll-call and the
   role of each component here; from §5, the endpoints (cited in the file header, never called).
6. **The frames.** `variants[]`: before the first build, one entry per frozen frame (`slug`,
   `name` = the frame's label, `snapshotFile`, `frame` = `{slug, width, height, scale}`); once
   built, one entry per preview, each with the `frame` it is linked to or null. A frame's height
   in points is `frame.height / (frame.scale ?? 1)`. Print every frame: slug, label, width ×
   height in points.
7. **The device.** The render canvas is `devices[0]` itself (D22): its width, at least its full
   screen height, and its top safe-area inset. Read all three where the project's capture harness
   defines its devices — under `repoPath`, beside `project.registryCasePath` (e.g. `size:
   CGSize(width: 440, height: 956)`, `safeArea: UIEdgeInsets(top: 59, …)`). Print them. The frozen
   frames' widths in points should agree with the device width; a frame's height never sizes
   anything. If the harness states no device size, stop and say which setting is missing.
8. **Rebuild check:** `build_status(screen: "<slug>")`. Already built? This is a re-build — read
   the existing previews now with `get_previews(screen: "<slug>")` (label, slug, `frame`,
   `props`, `propsAuthored`) and diff §3 against them in phase 4, reporting what moved.
9. **Load the NOTES.** `read_notes(target: "<slug>")` — every note on the screen, pending first.
   (`requirement_inputs` is component-only; the §4 components' own notes were applied by their
   builds and are not re-applied here.) Only PENDING notes are live requirements; an assimilated
   note is already in the spec and is history.
   - Read each note as statements about **named properties**, and apply *a later statement about
     the same property replaces an earlier one, per property* — everything else an older note
     says stays in force. **A note supersedes the spec** the same way.
   - **Print the effective set and the drift list before changing anything** — every requirement
     with its source (`spec` | `note <id>`), and every place a note overrode the spec with both
     values. A build that silently honours an instruction the owner cannot see is worse than one
     that ignores it.
10. **Read the rulebook.** `get_rules()` — every code-pattern decision of this era answered once.
    `ruled` is what the owner chose: each entry's `instruction` is a sentence this view OBEYS,
    and its `samples` are what the view is patterned on — they are already spelled under the
    era's naming rulings. `defaulted` is every decision not yet ruled, answered with the catalog's
    ★: USE each one, and list it in the report as "defaulted, unruled". **Never stop on an unruled
    decision**; the default stands until ruled. An answered open question or a note on THIS screen
    wins over a rulebook entry for this screen alone — say which entry it overrode. Print the
    rulebook's counts now: `rulebook: N ruled, M defaulted`.
11. `get_tokens()` for the families the spec cites, and read the **generated token file** at
    `project.tokensOutPath` — that file is the authority on **real member names**.

**Exit checklist 0:** project + era stated ✓ · render lane ready and `codeFlavor` is `swift` ✓ ·
screen resolved ✓ · status buildable, every §4 component built or deferred, no blocking open
question ✓ ·
spec read in full ✓ · frames listed with their heights in points ✓ · device width known ✓ ·
rebuild-or-first-build known ✓ · notes loaded, effective set + drift list printed ✓ ·
rulebook read: N ruled, M defaulted ✓ · tokens + generated member names read ✓

## 1. RESOLVE — the §4 components

Skip `get_component` and `build_status` for a deferred entry. Instead call
`get_drawings(subject: "<slug>")` once and, for each deferred part — a deferred `components[]`
entry (its drawings carry `deferred.inherited`), or a drawing with `deferred` set and no `row` —
note its `points` rect on the FIRST frame that draws it, one placeholder per instance; a deferred
entry with no drawing gets nothing. A deferred entry whose row is now `built: true` still gets the
placeholder — say so in the report, so the owner can resume it.

For each other `components[]` entry, `get_component(component: "C-###")` → its §4 props (names,
types, defaults) and its §3 states, and `build_status(component: "C-###")` → `previewPath`, the
built view's file under `project.previewDir`. Open that file: the view's type name, its
parameters as built, and how it names its own anatomy with the preview module's
element-annotation helper.
Print the table:

| C-### | Name | View (file) | Role here (§4) | Props this screen sets |
|---|---|---|---|---|

- A component this screen places more than once gets one row per role (a primary and a
  secondary button are two rows).
- A §4 role whose rendering needs a prop value the component's contract does not offer is a spec
  defect — stop and name the `/d2m-screen` or `/d2m-component` run that closes it.
- A component view whose parameters differ from its current contract means that component's
  build is stale: report it (its `/d2m-component-build` re-run) and compose against the view as
  built.

**Exit checklist 1:** every §4 row resolved to a built view with its file ✓ · each view's
parameters read from the file ✓ · every role this screen gives a component mapped to props ✓ ·
stale component builds reported ✓ · every deferred part listed with its rect, or noted as
undrawn ✓

## 2. TOKENS

Regenerate `project.tokensOutPath` from `get_tokens()`. The token rows are d2m's; the file is the
project's, and it is **generated, never hand-edited** — the next run overwrites it.

- A row with `parsed: false` produced **no value d2m could read**; it ships with a `parseNote`
  saying why, and **cannot be used by name**. List them, and check none is one this screen needs.
- For `codeFlavor: swift`, the member name drops the family prefix and lowerCamels the rest:

  | token row | member |
  |---|---|
  | `color-card-border` | `Token.cardBorder` |
  | `color-text-primary` | `Token.textPrimary` |
  | `type-input` | `.designTextStyle(Token.TypeStyle.input)` |
  | `space-page-margin` | `Token.Space.pageMargin` |
  | `radius-card-sm` | `Token.Radius.cardSm` |

  Inside the preview module those names need no qualification; in the capture-registry file,
  which imports both the preview module and the app, they are qualified with the module name
  (phase 4).

Then write down, per value §2 cites (page background, page margins, the gaps between components),
the exact member you will use. Every value the screen needs is one of exactly four things:

1. a token member → use it;
2. the spec's **flagged literal** → emit the literal with the flag repeated as a comment
   (`// FLAGGED LITERAL — <slug> §2: #1f2124, no token`);
3. **spec-traceable, but no token row** → emit it as a literal with a `GAP —` comment citing the
   spec line (`// GAP — <slug> §2: 24pt section gap, no spacing token`), and raise it in the
   report for the owner;
4. **neither tokened nor traceable** → a spec defect. **Stop**, name the value and the spec line,
   and say the fix is a `/d2m-screen` re-run that lands it in the token register or flags it. Do
   not invent a token.

Diff the regenerated token file against its previous contents: if it moved, the token register
moved since the last build — report it.

**Exit checklist 2:** token file regenerated from `get_tokens()` and the diff read ✓ · no
`parsed: false` row is one this screen needs ✓ · every §2 value mapped to a member, a flagged
literal, a cited `GAP —`, or stopped on as a spec defect ✓ · generated file not hand-edited ✓

## 3. WRITE — the screen view

**Notes bind here.** Where a note and the spec disagree, **the note wins**, and the code that
implements it carries the note's id in a comment (`// note 2026-09-11T14:32:05.412Z — …`).

**a. The working state list.** Take §3's closed states list, in §3's order, with each state's
label verbatim (on a re-build: the existing previews in preview order, plus any §3 state none of
them covers). Phase 4 turns exactly this list into previews. For each state, write down the
sample data that makes it render the way §3 says: every value traces to the spec (§2/§3 text,
§4 roles, the component contracts' own sample strings) or to the text visible on that state's
frozen frame. A value you would have to invent is a spec defect — stop.

**b. The file (D5).** One file, at `get_screen.buildPath` under `<previewDir>` —
`Screens/<NamespaceFolder>/<Name>Screen.swift`, where `<Name>` is the screen slug in UpperCamelCase
(`edit-text-single-field` → `EditTextSingleFieldScreen`) and the folder is its namespace's. The
server computes it and this run never derives it (screen-organization D5 supersedes the flat D8
path). The module imports the UI framework only; a screen that needs an application type is a spec
defect.

**c. The view (D6).**

- **One `State` input**, nested in the view: one field per value that differs between §3 states
  (a field label, the initial text, whether a save is in flight…), each a JSON-native type
  (`String`, `Bool`, `Int`, `Double`, arrays of those), because it is decoded from the preview's
  props. Every §3 state must be reachable **through `State` alone**.
- **UI-only rules are real local state**, seeded from `State` — a field's local text, a value
  compared with its initial value, a control's enabled/disabled. The nested `State` type shadows
  SwiftUI's property wrapper inside the view, so spell the wrapper `@SwiftUI.State`.
- **Every action that leaves the screen is an `on<Verb>` closure defaulting to a no-op**, spelled
  as the rulebook's callback rule says. Say in the report that you took that default.
- **Composed only of the §4 views** from phase 1, placed as §2 lays them out. A deferred part
  with a drawing is placed as a placeholder instead: a `Rectangle()` frame of its drawn rect's
  point size — the two size literals flagged `// GAP — deferred rect` — with
  `.strokeBorder(<the muted text token>, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))`, the
  centred caption `deferred · <code or drawing name>` in the caption text style, and a
  `// DEFERRED — <reason>` comment above it. Never `Token.error` — a deferred part is not a bug.
  The screen owns its page background and page margins (tokens, phase 2). It draws no status
  bar, home indicator or safe-area insets — the harness draws the device around it (D22, phase
  4g), never the view.
- **no `ScrollView` at the page root** (D22): the view lays its content out at full length — top
  to bottom, however long — because the canvas is the device width × the larger of the device
  height and that length, which is how a scrolling screen is captured whole. A horizontal
  carousel inside the page keeps its own `ScrollView`.
- **Part highlights (D11).** Wrap every §4 component instance with the preview module's
  element-annotation helper — the same helper and call shape the component views use (phase 1) —
  named `"C-### <Name>"` (`"C-049 Button"`; a component placed twice gets `" 2"` on the second:
  `"C-049 Button 2"`). A deferred placeholder is wrapped too, named `"C-### <Name>"` from its
  entry, or the drawing's name for an unlinked one. The component's own internal annotations
  nest inside by rect containment; nothing else to declare.
- **Tokens only**, per phase 2. No raw hex, no raw point sizes (a deferred placeholder's rect is
  the one exception, flagged `// GAP — deferred rect`), no legacy colour or typography types.
  No debug-only conditionals, no lazy containers, no console printing.
- File header:

```swift
//
//  <Name>Screen.swift
//  <the preview module>
//
//  Built from screen <slug> in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: <METHOD /path> · <METHOD /path>
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//
```

The shape, patterned on the rulebook's samples:

```swift
import SwiftUI

struct <Name>Screen: View {
    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        var <field>: <Type>
    }

    let state: State
    var on<Verb>: () -> Void = {}

    // §3 UI-only rule: <quote the rule>
    @SwiftUI.State private var <local>: <Type>

    init(state: State, on<Verb>: @escaping () -> Void = {}) {
        self.state = state
        self.on<Verb> = on<Verb>
        _<local> = SwiftUI.State(initialValue: state.<field>)
    }

    var body: some View {
        // §2 top→bottom, each §4 instance wrapped by the element-annotation helper
    }
}
```

**d. Screens minted from one collection (D7).** If `identifiedFrom` is set, find this screen's
built siblings: `list_screens()` → rows with `built: true`, then `get_screen(screen: …)` on each
— a sibling has the same `identifiedFrom`.

- **No built sibling** → this screen gets its own view (above). No template on a first build.
- **A built sibling whose §2 layout differs from this screen's only in content** — labels, sample
  data, which §4 rows appear in the field area — → move the shared layout into
  `<previewDir>/Screens/Shared/<CollectionName>Template.swift` — whatever namespaces its screens
  are in (D8) — (`<CollectionName>` = the collection slug
  in UpperCamelCase, e.g. `SharedEditFieldTemplate`), taking the differing content as
  parameters, and rewrite BOTH screen files as thin wrappers over it that keep their own
  `State`, closures and `#Preview` blocks. The earlier sibling is re-captured in phase 5 and its
  new renders compared with its previous ones in phase 6.
- **A sibling whose layout differs structurally** (a different §2 order, a component in a
  different region, a different page structure) → stays standalone; the report says why, citing
  the two §2 lines that differ.

**e. `#Preview` blocks (D21).** End the file with one `#Preview("<state label>")` block per state
in the working list, in its order, each constructing the screen with that state's sample data
written as Swift literals — the same values phase 4 writes as the preview's props — inside the
device canvas (D22): `.padding(.top, <device top inset>)`, then
`.frame(width: <device width>, alignment: .top)`, then
`.frame(minHeight: <device height>, alignment: .top)`:

```swift
#Preview("<state label>") {
    <Name>Screen(state: .init(<field>: <literal>))
        .padding(.top, <device top inset>)
        .frame(width: <device width>, alignment: .top)
        .frame(minHeight: <device height>, alignment: .top)
}
```

These blocks are regenerated on every build from the current previews, so they never drift from
the fixture. They belong to screen files and the D7 template's wrappers only — a component view
built by `/d2m-component-build` never gets one.

If the preview directory has no README, write one now: it states the preview-only rule and the
promotion path, and nothing else.

**Exit checklist 3:** working state list in §3 order with traced sample data ✓ · one file at
`get_screen.buildPath` ✓ · one `State` input, every §3 state reachable by it
alone ✓ · UI-only rules as `@SwiftUI.State`, exits as no-op `on<Verb>` closures ✓ · composed only
of §4 views, tokens/flagged literals only ✓ · every §4 instance annotated `C-### <Name>` ✓ · header
cites §5 and the preview-only rule ✓ · D7 template decision made and reasoned ✓ · one `#Preview`
per state, in order ✓ · preview-directory README present ✓

## 4. PREVIEWS + CAPTURE CASE

**a. Fix the state list (D17).** First build: the working list from phase 3 is the list. Re-build:
`get_previews(screen: "<slug>")` is the list; a §3 state no preview covers is added; a preview
whose state is no longer in §3 is **kept** and listed under **No longer in §3** — never deleted.

**b. Link each new state to a frame (D17).** Normalise a string by lower-casing it and replacing
every non-alphanumeric character with `-`. A frame whose normalised label or slug equals the
state's normalised label links to that state. If the screen has exactly one frame and no state
matched any frame by name, that frame links to the FIRST state in §3 order. Otherwise the state's
frame is null. Write down every link and the rule that made it — the report lists them.

**c. Create the missing previews (D9).** For each state with no preview, one
`create_preview(screen: "<slug>", label: "<state label>", props: {}, frame: "<frame slug>")`
call — omit `frame` for a state with no linked frame. The label is §3's, verbatim; the server derives the slug once. Never rename, relabel or delete an
existing preview.

**d. Write the sample data.** One `put_preview_props(screen: "<slug>", previews: {…})` call
with every preview's bag: the phase-3 sample data, one key per `State` field, typed exactly as
the field (`3` and `"3"` are different values), and nothing else — no size of any kind: the
canvas is the device's (D22, step g). Screen previews' props are the build's own, so a re-build
rewrites them from §3 and reports each changed value as drift. Re-read with
`get_previews(screen: "<slug>")` and confirm every preview came back with the props you wrote,
its `frame` as linked, and its label untouched.

**e. The capture case (D8).** Append one case to `project.registryCasePath`, immediately before
its final fallback, decoding the fixture's payload exactly as the neighbouring cases do.
**Module-qualify every preview name** — that file imports both modules:

```swift
    case "screen.<era>.<slug>":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.<era>.<slug>: missing state.component")
        }
        return AnyView(<PreviewModule>.<Name>Screen(
            state: .init(/* every State field from `c`, with this build's sample default for a missing one */)
        ))
```

The case returns the bare screen: the canvas is the harness's (step g), per device, so the same
case renders correctly on every device the project captures.

**f. The fixture-decoding type.** Props reach the harness through a fixed decodable struct beside
the registry case. **A JSON key with no matching field decodes to nothing, silently**, and the
render comes out default-valued with no error. So check every `State` field name against that struct and add the missing ones as purely additive optionals in one
block at the end of it:

```swift
    // ── screen <slug> ──
    let fieldLabel: String?
    let isSaving: Bool?
```

Two bounds, both absolute: **additive optional fields only**, and never modify, retype, rename or
reorder an existing field. A field that already exists with the same name AND type is reused. One
that exists with the same name and a different type is a collision: rename your `State` field
(screen `State` names are this build's own, not a contract's), everywhere — view, props,
`#Preview` blocks, case — and say so. **Name every field you add in the report.**

**g. The device canvas (D22) — the one harness requirement.** The capture runner (beside
`project.registryCasePath`, the file that picks each fixture's snapshot layout) must render a
`screen.*` view key on the DEVICE: its width, at least its height, growing with the content, under
its top safe-area inset with the harness's own status bar, and with the element map collected.
Check for exactly this branch — keyed on `fixture.view.hasPrefix("screen.")`, placed before the
full-content and device-chrome branches — and add it if it is missing (a `component.*`-only check
that also lets `screen.*` through is replaced by it). This is the one edit outside the preview
directory this skill makes; name it in the report:

```swift
                } else if fixture.view.hasPrefix("screen.") {
                    // A 2.0 screen preview: the device's width × max(its height, the content's
                    // full length), content under the top safe area with the status bar drawn.
                    let size = device.config.size ?? CGSize(width: 393, height: 852)
                    // A ZStack of the device rectangle and the content measures as their union.
                    // NOT `.frame(minHeight: size.height)`: `.sizeThatFits` proposes a ZERO
                    // height, and a min-height frame answers that with exactly its minimum
                    // whatever its content measures (a 2,372pt screen came out 956pt).
                    view = AnyView(
                        ZStack(alignment: .top) {
                            Color.clear.frame(width: size.width, height: size.height)
                            baseView
                                .padding(.top, device.config.safeArea.top)
                                .frame(width: size.width, alignment: .top)
                        }
                            .background(Color.appBackground)
                            .overlay(alignment: .top) { StatusBarView(style: device.statusBarStyle) }
                            .ui2ElementMap(elementMap)
                    )
                    snapshotting = .image(layout: .sizeThatFits, traits: device.config.traits)
                }
```

Element-map rects therefore include the top inset, exactly as the Figma frames include their
status bar — the two are compared in the same coordinates.

**h. `#Preview` blocks agree with the previews.** Same count, same order, same labels, same values
as `get_previews` now answers. Rewrite them if steps a–d changed anything.

**i. Record what you wrote.**

```
record_build_artifacts(screen: "<slug>", viewKey: "screen.<era>.<slug>", devices: ["<devices[0]>"],
  previewPath: "<buildPath>", tokensPath: "<tokensOutPath>",
  registryCasePath: "<registryCasePath>", otherPaths: [<decoding type file>, "Screens/Shared/<CollectionName>Template.swift" when there is one, <files the sync rewrote>],
  sha: "<repo sha>")
```

`previewPath` is relative to `project.previewDir` and is exactly `get_screen.buildPath` (D5; after a
relocation, the new path — D7); `devices` is `devices[0]` alone, because the
canvas width is that device's. This call also ensures the screen's subject and a design version
per frozen frame (D16). It **refuses (409) while the gate fails** — the gate can change between
phase 0 and now: print the refusal verbatim and stop. On a run that failed after writing files,
record `built: false` with `error` — a half-finished build recorded honestly is worth more than a
silent one. On a D8 template move, record every built sibling too, one call each — at the
sibling's own CURRENT path, never at its `buildPath` (recording it there would flip that
sibling's own `relocate` to false while its file still sits wherever it is; an unmoved sibling
must keep `relocate: true` so it moves on its own next build):
`record_build_artifacts(screen: "<sibling>", previewPath: "<the sibling's build_status(screen: "<sibling>").previewPath>", otherPaths: ["Screens/Shared/<CollectionName>Template.swift"])`
— for every built sibling, so each one's `otherPaths` names the template's new home (D8).

**Exit checklist 4:** state list fixed (first build from §3; re-build from the previews) ✓ ·
every frame link made by the D17 rule and written down ✓ · a preview per state, none renamed or
deleted ✓ · props written (State fields only), re-read and verified ✓ · capture case keyed
`screen.<era>.<slug>` before the fallback, returning the bare screen ✓ · every field decodable,
additions reported ✓ · the runner's `screen.*` device-canvas branch present ✓ · `#Preview` blocks equal the previews ✓ · artifacts
recorded ✓

## 5. SYNC THE TARGET, THEN CAPTURE

**1. Sync.** Run `project.targetSyncCmd` from `project.repoPath`, if the project configures one.
**A file that is not in the target does not compile — the capture then fails minutes later with
an unknown-view error.** Check the command's output names your new file (and the template, if
you wrote one). A project with no sync command needs none; say so rather than inventing a step.

**2. Lint before you burn a render.** Run `project.lintCmd` from `project.repoPath`. Fix
violations in the preview files. **Never** regenerate a lint baseline to silence one.

**3. Re-check the gate.** `build_status(screen: "<slug>")` — the fixture names the view
`screen.<era>.<slug>` and the build is recorded — and `get_screen(screen: "<slug>")` still
carries `commands.build`. A component struck or a blocking question filed since phase 0 stops
the run here, before minutes are spent.

**4. Preconditions.** `project_info()`'s `capture.canCapture` is d2m's own answer to "is this
lane ready". The renderer's own preconditions (a simulator, a device, a toolchain) belong to the
project's render command: when the capture fails, read its log rather than guessing.

**5. NO ASK — capture is part of the run.** Invoking this skill IS the permission. Do not ask, do
not offer, do not wait — go straight to step 6 as soon as steps 1–4 are green. Steps 1–4 are the
gate that replaces the question; a red ✗ there is not something to ask about — fix it or report
it.

**6. Capture.**

```
capture(screen: "<slug>", state: "*", wait: true)                # every preview
capture(screen: "<slug>", state: "<preview-slug>", wait: true)   # one state, by SLUG
```

`capture` answers a **handle, not a result**: one renderer run per preview (~30s each on a
simulator lane). `wait: true` follows the run for up to 10 minutes and answers its final state
and the tail of its log. If it still comes back `timedOut: true`, **call
`capture_status(runId: "<runId>", wait: true)` until `state` is not `running`**. **Never** poll
the filesystem for renders or read d2m's own source to work out whether a capture finished: the
run's log is in `capture_status`, and the renders are in `get_screen(screen: "<slug>")` once it
ends. **Read the log** — it is the only place a toolchain error appears. On a D7 template build,
also `capture(screen: "<sibling>", state: "*", wait: true)`, without asking: its file changed.

**7. Read the renders.** `get_screen(screen: "<slug>")` → `built` is now true, and each preview's
variant carries this run's render as the newest entry of `versions[]`. Beside each render sits
its element map — the phase-3 annotations, resolved. Check it names every `C-### <Name>` you
annotated; a missing one means that part will not highlight.

**Expected collateral:** a project whose renderer re-runs a whole harness suite will rewrite
unrelated baseline images in its repo. Nothing broke. Leave them out of any commit.

**Exit checklist 5:** sync run and the new files named in its output (or "no sync command
configured") ✓ · lint clean ✓ · gate re-checked ✓ · lane ready ✓ · `capture` invoked without
asking and its job succeeded ✓ · a render per preview located, element maps name the parts ✓ ·
D7 sibling re-captured (or "no template") ✓

## 6. DIFF AND REPORT

1. **Per preview with a frame** (its variant's `frame` is set and the frame is not struck), open
   the render beside the frozen frame and read both against §2 — order, dimensions, spacing,
   type, colour, which components appear. A preview whose `frame` is null, or whose frame is
   struck, is rendered and labelled **"not diffed — no frozen frame"**: read its render against
   §2/§3 and against the diffed states it varies from (the same layout with one state changed
   should differ in exactly that state's effect). That is not a failure.
2. **Refine the view** (phase 3) and re-capture the state(s) that moved (phase 5 step 6; the sync
   is only needed when a file was added or removed). Prefer the named state over `*`. **Budget
   the loop: at most three refine-and-recapture rounds.** Read the element map's rects BEFORE the
   next edit so each round fixes a measured delta, not a guess; if the third round still leaves a
   delta, report it as a gap rather than capture again. A delta INSIDE a component's own rect is
   that component's build — report it with its `/d2m-component-build` run; never patch around it
   in the screen.
3. **Stop refining when the remaining delta is a real gap**, and name its class:
   - **note-driven divergence** — a note told the build to do something the frame does not show.
     EXPECTED, not a failure: report it with the note id, never "fix" the view back;
   - the UI framework genuinely cannot express §2's construction;
   - the spec underspecifies what the frame shows (→ a `/d2m-screen` re-run);
   - a component's own render differs from its frame (→ that component's re-build);
   - a deviation §1's closed list already declares.
   **Surface the gap; never fudge the view to match the picture.**
4. **D7 comparison.** When this build wrote or rewrote a template, open the earlier sibling's new
   render beside its previous one, per state, and state what changed (expected: nothing).
5. **Look at it in the workbench:** `/<project>/<era>/<slug>/<preview-slug>` — design ⇄ built
   toggle and the part highlights, per state.
6. **Report to the user:**
   - **Scope** — project + era, the scope line, first;
   - **Previews** — every preview (label + slug): captured and diffed, or "not diffed — no frozen
     frame"; which ones you re-captured, and how many refine rounds each took;
   - **Frame links** — every link made this run and the D17 rule that made it (name match, or
     the single-frame rule), and every state left with no frame;
   - **#Preview blocks** — the `#Preview` labels written into the screen file, in order;
   - **Defaults taken** — device width, no-op closures, every non-blocking open question answered
     by its proposed default (id + the default), and anything else this run chose, so an owner
     ruling has a list to overturn;
   - **Rulebook** — every `ruled` entry obeyed (`R-## label`), every `defaulted` entry used
     (`R-## label — defaulted, unruled`), any entry a note or answered question overrode for this
     screen, and any conflict with the harness files;
   - **Files written** — every file in the project repo, as recorded by `record_build_artifacts`,
     including each decodable field added;
   - **Template** — the D7 action (none / written / sibling kept standalone, with why) and the
     comparison from step 4;
   - **Drift** — on a re-build, what changed in §3 or the sample data since the previous build;
   - **Note-driven divergence** — every difference a note caused, with its note id;
   - **Gaps** — step 3's list, by class;
   - **Deferred parts** — every deferred part (code or drawing name, and its reason): built as a
     placeholder with its rect, or built as nothing because it is undrawn; and any whose row is
     now built — resume it on the screen to use it;
   - **Frames to freeze** — every §3 state whose Figma node the spec names but which has no
     frozen frame, each with `/d2m-screen <slug> --project <slug> --era <key>` to freeze it;
   - **No longer in §3** — every preview kept whose state §3 no longer lists.

**Exit checklist 6:** every framed preview diffed against its frame ✓ · frameless previews
labelled "not diffed — no frozen frame" ✓ · refinements re-captured, at most three rounds ✓ ·
remaining deltas classified as gaps, none fudged ✓ · D7 comparison stated (or "no template") ✓ ·
workbench path given ✓ · report covers scope/previews/frame links/#Preview blocks/defaults/
rulebook/files/template/drift/gaps/deferred parts/frames to freeze/no longer in §3 ✓
