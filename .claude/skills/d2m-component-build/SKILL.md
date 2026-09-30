---
name: d2m-component-build
description: Build ONE specced component as a capturable preview — resolve its dependencies, regenerate the project's token file, write the view into the project's preview directory, derive its fixture and capture-registry case, render it through the project's configured renderer, and diff the render against its frozen Figma snapshot. The build-side sibling of d2m-component; wired into no screen, route or flag. Designed to run in a FRESH session.
argument-hint: [C-### registry id (or component name); omit to be shown the specced-but-unbuilt rows] [--project <slug>] [--era <key>]
---

# Component preview build — $ARGUMENTS

Build the specced component **$ARGUMENTS** into a **capturable preview**: a real view in the
project's preview module, rendered by the project's configured renderer, registered as the
built side of the component's subject so the workbench shows it beside its frozen Figma
snapshot and diffs the two. Figma is the reference, the generated view is the twin. Work ONE
component per run; each phase ends with something verifiable.

**Arguments:** `<C-###>` → build that registry row. A component *name* → resolve it against
`list_components()` and say which row you resolved to (two candidates → ask, never guess).
`--project <slug>` / `--era <key>` override the pinned scope; **pass them through to every tool
call.**

**This run reads spec content out of d2m and writes CODE into the project repo.** Those are the
only two places anything moves. It never edits a contract (except phase 0.5, which reconciles it against a re-specced part), a registry row or a token row: a gap
discovered here (a missing prop, an unnamed value, a state with no ruling) is a **spec defect**,
fixed by re-running `/d2m-component` on that component, never improvised in code. "Built" is not
a registry field either — it is fixture presence, which `build_status(id)` answers — so a
successful run needs no registry edit at all.

## Before anything: is there a render lane?

`project_info()` — its `capture` block answers this outright (`canCapture`, and `missing` when
the lane is half-configured). If `captureAdapter` is **`noop`**, this project **has no render
lane**:

> `<project>` has no renderer configured (`captureAdapter: noop`). There is nothing to
> capture and nothing to diff, so there is no honest way to report a build. Configure the
> project's render command, output glob and devices in its d2m settings, then re-run.

**Say that and stop.** Do not generate a view and call it a build; a preview nobody can render
is not the artifact this skill exists to produce. `capture` refuses on a `noop` project for the
same reason, so this check is not the only guard — but discovering it in phase 0 costs nothing
and discovering it in phase 5 costs a whole run. The same stop applies when the adapter is real
but the lane is half-configured: print the `missing` list by name (`repoPath`, `previewDir`,
`renderJobDir`, `renderCmd`, `renderOutGlob`, `devices`) rather than failing minutes later
inside someone else's shell script.

**Record the stop before you end** (see *Reporting to the build box*):
`report_stop(component: "<C-###>", kind: "lane-not-ready", reason: "<project> has no renderer configured", target: "captureAdapter")`.
A half-configured lane is the same stop with `target` naming the `missing` fields
(`target: "renderCmd, devices"`). Then
`report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["the render lane is not ready — <what is missing>"])`.

`codeFlavor` decides what the generated view is written in. `swift` is the only flavour v1
implements; on any other value, say so and stop rather than guessing a syntax.
Record that stop too: `report_stop(component: "<C-###>", kind: "lane-not-ready", reason: "codeFlavor <value> is not implemented", target: "codeFlavor <value>")`,
then `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["codeFlavor <value> is not implemented"])`.

## No argument → print the build queue, then ask

**Print the queue, then ask which one with AskUserQuestion; never pick for the user.** The queue
is every row that is *buildable* — it has a contract of its own, because a row anchored only in
a screen spec's §4 is a legal dependency but not a legal target (phase 0.3) — annotated with
what a build would actually cost, because "specced but not built" alone hides the thing that
decides the run: whether its dependencies have contracts of their own. A component whose
dependency resolves at level 2 or 3 will hit an artwork or prop gap it cannot close without a
`/d2m-component` run, and the user deserves to know that *before* choosing, not in the phase 6
report.

Build it from tools, not from a directory listing:

1. `list_components()` — every row with `specced`, `built`, `hasSnapshot`, `stateCount`.
2. For each specced row, `get_component(code)` → its §5 **Consumes** (the first half only;
   "Consumed by" is not a dependency) and whether each named dependency is itself specced.
3. `read_notes(code)` for the rows you are about to offer — notes are requirements BEYOND the
   contract (phase 0.7), so they are part of what a build costs.

Read the result out as these groups, in this order, and say what each means:

- **Clean** — contract, snapshot, and every dependency has a contract of its own AND is built.
  A build here should produce no dependency gap at all.
- **Blocked on C-0xx** — a §5 part is not built. Not buildable: the system is built bottom-up
  (phase 0 step 4b), so this row is offered only as "build C-0xx first"; the part itself is the
  candidate to offer, deepest first.
- **Gaps: C-0xx** — the named dependency has no contract of its own, so it resolves at level 2
  or 3 (phase 1) and the run will surface an artwork or prop gap it cannot honestly close. Name
  the `/d2m-component` run that would close it; an unspecced part is also an unbuilt one, so
  this row is blocked until it is specced and built.
- **BUILT** — already has a fixture; choosing it is a *re-build*, which reports drift against the
  contract rather than starting fresh. A BUILT row **with notes** is usually a
  `/d2m-component-update` run rather than a rebuild: that skill verifies the existing preview
  against spec + notes instead of regenerating it.
- **N notes** — this row carries owner intent the contract does not. Say the count out loud when
  briefing the choice; a component with notes costs more to build than its contract suggests.

A component with **no snapshot** is not buildable — its §1 cites a frozen snapshot d2m does not
hold, so there is nothing to diff against. Say so and point at `/d2m-component`.

**Then offer the pick list — always, with AskUserQuestion.** Prose alone makes the user retype an
id the run already knows; the groups above are the *briefing*, the picker is the *choice*. One
question, `header: "Build target"`, `multiSelect: false`:

- **One option per buildable row**, `label` = `C-### Name`, `description` = the cost of *that*
  build in one line — `clean · no dependency gaps`, or `gaps: C-069 NavTabButton (level 2) —
  will stub`.
- **Recommend one** — the cheapest clean row — by putting it first with `(Recommended)` on the
  label, and give the reason in its description.
- **BUILT rows are options too**, described as `re-build · reports drift`, and they sort last.
  Never omit them: a re-build is a legal target.
- **`no snapshot` rows are NOT options.** They cannot be built; they were named in the prose.
- Four options is the ceiling, so when more than four rows are buildable, offer the clean rows,
  the recommended row, and the cheapest gapped row — the full list is already printed above, and
  "Other" takes any `C-###` the user types.

Take the selection as the run's argument and continue at phase 0 exactly as if it had been
passed on the command line. Never build a row the user did not pick.

## Hard rules (re-read before EVERY phase)

- **Wired into nothing.** No screen, route, tab, flag or navigation case references the preview
  module. A step that would need one stops and says so.
- **Legacy untouched.** The project's shipping colour, typography, page and routing sources are
  never edited. Outside `project.previewDir` this run writes exactly the files the capture
  harness requires: `project.tokensOutPath`, `project.registryCasePath`, the fixture-decoding
  type that sits beside it, and whatever `project.targetSyncCmd` rewrites to make a generated
  file compile. **Name every one of them in the report**, and write nothing else.
- **Tokens by name.** Every colour, type, spacing and radius value resolves to a member of the
  token file generated from `get_tokens()` (phase 2). A contract's **flagged literal** stays a
  literal with the contract's flag repeated as a code comment — never silently promoted to a
  token. The project's `lintCmd` enforces the sharp edges; run it before you burn a render.
- **The rulebook is the convention.** How state is owned, how actions leave a view, how a
  variant is typed, how a prop is defaulted, how styling is applied, where a file goes, how a
  callback, a boolean, an acronym or a domain word is spelled — `get_rules()` (phase 0.9)
  answers each of those, ruled or defaulted, and this file does not. Where a view already in
  `project.previewDir` does it another way, the rulebook still wins: the older view is a
  re-build waiting to happen, not a precedent. One exception, and it is not a convention: the
  capture harness's own files — the fixture, the registry case at `project.registryCasePath`,
  the decoding type beside it — and one capture case per `C-###` are what makes a component
  reviewable here. A ruled entry that would remove or relocate them (a layout with no
  per-component file, a preview-registration option that registers nothing) is reported as a
  **conflict** in the report's rulebook section, and the harness wins until the owner re-rules.
- **Value sets have one owner.** A prop whose §4 Type cell enumerates values gets exactly those.
  A prop taking another row's set **cites that row** — `C-021 glyph`, `[C-021 glyph]` — and d2m
  resolves the options through that contract, so adding a glyph to C-021 updates every consumer
  at once. Where the providing row ships per-value artwork, the workbench renders a picture
  picker; `get_component(code)`'s `propAssets` is where that comes from. Nothing to wire per
  component: it follows from the contract.
- **Every prop traces**: §4's prop table crossed with that state's §3 row, plus the contract's
  own sample strings. Inventing a prop, a state or a value is a spec defect.
- **States are the contract's states — ALL of them.** Fixture state labels are the §3 labels
  **verbatim**, and every §3 row that carries prop values gets a fixture entry and a render.
  `undesigned` is a fact about the DESIGN side only: the row has no Figma symbol, so there is
  no frozen snapshot to diff its render against. It is not a reason to skip the state — an
  owner-ruled row (an answered OQ, a note) is exactly as buildable as a drawn one, and a state
  the build does not have is a state the owner cannot capture, review or comment on. Build it
  from its §3 row and the rulings behind it, and report it under **built without a snapshot**
  (phase 6) rather than as a diff. The only rows that get no entry are the ones the contract
  itself marks not a state (`n/a`, `none proposed` — display-only rows that have nothing to
  render). The build writes these as PREVIEWS — `get_previews(code)` shows what exists. **One
  preview per §3 row is the seeding rule; on a rebuild the build never removes, renames or
  re-props a preview that exists** — the owner's previews are theirs, added, renamed and
  re-propped in the workbench. A new §3 row gets a new preview; that is all a rebuild adds.
- **Name ≠ slug.** d2m keys a state's history on its **id**; the **slug** is assigned once and is
  what a URL and a CLI argument take; the **label** is the §3 display string. Never hand-type a
  label to mean a state, and never key anything on the slug.
- **No debug-only conditionals and no in-file preview block** — the capture *is* the preview.
- **Idempotent and visible.** A re-run against an unchanged contract rewrites the same files
  byte-for-byte; a changed contract is a re-build event, reported as drift.
- **Contract writes: phase 0.5 only.** The only writes to d2m spec content this run makes are phase 0.5's `upsert_component` reconcile and its `await_answers` (which files questions on the contract); nothing else changes a contract.
- **Never fudge.** A render that cannot match the snapshot is a gap to surface, not a geometry to
  nudge.
- **Capture without asking.** The skill's invocation is the permission: phase 5 syncs, lints,
  checks the preconditions and then captures, with no question in between. If the project repo's
  own agent instructions forbid builds without explicit permission, this run's renderer is the
  named carve-out and **nothing else** is — a bare build command, or "let me just check it
  compiles", still needs a yes.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why.

## Reporting to the build box

The workbench's build box fills in from two tools as this run goes (build-run-panel), and from
nothing else:

- `report_progress(component, phase, status, bullets)` — once per phase, at its **Exit checklist**,
  or at the stop that ends the phase, whichever comes first. `phase` is `load` (0), `reconcile`
  (0.5), `resolve` (1), `tokens` (2), `write` (3), `fixture` (4), `capture` (5) or `diff` (6);
  `status` is `succeeded`, `failed` or `skipped`; `bullets` are 1–3 plain-English lines of what
  was done, what succeeded and what failed.
- `report_stop(component, kind, reason, evidence?, target?)` — at every stop below, with the kind
  it names, BEFORE that phase's `report_progress(…, status: "failed", …)`. `reason` is one plain
  sentence the owner reads; `evidence` the contract line, value or log tail that shows it.

A lifecycle requirement — no contract, open questions, an unbuilt part — is NOT a stop: the page
already shows it. Print it and end with `report_progress(component: "<C-###>", phase: "load", status: "failed", …)`
only.

A run that ends with neither a build nor a stop is recorded by the server as an `unexplained`
stop (its safety net). The net skips a run ended by one of those three lifecycle requirements, and
a row that already has an open HARD stop — the box keeps showing that hard stop in preference to
any newer soft one. So report the stop you hit; never end silently.

## 0. Load context

1. `project_info()` — **state the project slug and era key in your first report line.** Keep
   `repoPath`, `previewDir`, `tokensOutPath`, `registryCasePath`, `renderJobDir`, `devices`,
   `targetSyncCmd`, `lintCmd`, `codeFlavor`. Every path this run touches comes from here; a
   hardcoded one is a bug even when it happens to be right.
2. **Resolve the row.** `get_component(code)` — name, status, section, Figma ref, "Defined in",
   and `canCapture`.
   **2b. Obey the lifecycle.** `get_component(code).lifecycle` — its `build` step's `requirements`.
   Any requirement with `hard: true` and `met: false` means the workbench will not offer this
   build: print each one's `label` with its `action` (the command to run, or what to do) and
   **stop** with `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: [<up to three, see below>])`
   — never `report_stop`: the page already shows them. The report carries at most three bullets
   (the tool refuses more): with three or fewer unmet hard requirements, one bullet per label;
   with more, the first two labels and a third bullet `<N> more`, N being the rest. Print every
   requirement with its action as above; only the bullets are capped. A `stop:*` requirement is an earlier
   build's open stop; it clears only when its steps are met, and a new build does not clear it,
   so it stops this run too. Soft ones (`hard: false`) are warnings: print them and carry on.
3. **The contract is required.** If `contract` is null, **stop** and print:
   `/d2m-component <name> <figma-url>  ← spec it first; there is nothing to build from`.
   (A row whose contract lives only in a screen spec's §4 is a legal *dependency* (phase 1), but
   not a legal target for a build run — it has no frozen snapshot of its own to diff against.
   Say so and point at `/d2m-component`.)
   End with `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["no contract — spec it first"])`.
4. **Every open question must be answered.** `contract.openQuestions` on the same payload —
   if `contract.openCount > 0`, **stop** and print the open ones (id + question), then:
   `answer them in d2m (Contract tab → click the question) and re-run`.
   End with `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["<N> open questions stand"])`.
   Blocking or not: a "proposed default stands until ruled" is a decision the owner has not made, and a build
   that takes it silently is a build nobody asked for. (`commands.build` is absent from the
   payload for exactly this reason — the workbench does not offer this run until they are
   answered.) The ANSWERED ones (`status: closed`, `answer`, `answeredAt`) are owner rulings
   on this component: read them alongside the D# register and honour them in the build — an
   answer that names a value is that value, and a state an answer designed is no longer
   `undesigned`.
   **4b. Every §5 part must be built.** The system is built bottom-up (Luke, 2026-09-21): a
   part that is not built has nothing for this view to render it with, and a stub in its place
   is a build nobody asked for. `build_status(code).unbuiltParts` lists them (the same
   `consumes[].built` the workbench reads; `commands.build` is withheld while any stands). If
   it is not empty, **stop** and print each one with its own command, deepest first, so the
   owner works up:
   `/d2m-component-build C-071 --project <slug> --era <key>  ← ValuePair, a §5 part of C-023`
   then `re-run this build once they are green`.
   End with `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["<N> unbuilt parts — <codes>"])`.
   Never build around an unbuilt part — not with a placeholder, not by inlining its view.
   **4c. A part §5 names that is not a linked component is not a dependency.** This build
   depends only on `get_component(code).consumes` — the components the row is linked to, the
   ones the workbench's Components list shows. A name §5 **Consumes** writes (or an answered open
   question cites) that no `consumes` entry carries is **never a stop** — even when a ruling says
   the build waits for it. Build its slot in phase 1 as a **level-3 stub** (correct size and
   layout, obviously unfinished fill, `// STUB — <name>, not a linked component`), record it
   with `report_progress(component: "<C-###>", phase: "load", status: "succeeded", bullets: ["<name> is named in §5 but not a linked component — stubbed"])`,
   and list it under the report's gaps with the steps that would make it real (create it,
   spec it, build it, re-spec this row to link it). Linking it is the owner's call; until then
   the stub stands.
5. Read the contract in full — all six sections — and confirm its frozen snapshot: `snapshot` on
   the same payload, with its sha and capture date. No snapshot ⇒ nothing to diff against:
   `report_stop(component: "<C-###>", kind: "no-snapshot", reason: "<C-###> has no frozen Figma snapshot to diff against")`,
   then `report_progress(component: "<C-###>", phase: "load", status: "failed", bullets: ["no frozen snapshot"])`, and stop.
6. `get_tokens()` for the families the contract cites, and read the **generated token file** at
   `project.tokensOutPath` — that file is the authority on **real member names**. Do not guess
   them.
7. **Rebuild check:** `build_status(code)`. Already built? This is a re-build — read the existing
   previews with `get_previews(code)` now and diff the contract against them in phase 4, reporting
   what moved.
8. **Load the NOTES.** Notes are the owner's statements of intent about what a component is
   *for* — normative build input, not annotations. `requirement_inputs(code)` assembles them for
   you: the contract sections, the frozen snapshot, and the notes ordered oldest→newest **across
   the target, its dependencies and its consuming screens**. Only PENDING notes come through
   here — an assimilated note is already in the contract and is not re-applied. Use it —
   assembling those three sources by hand is exactly the drift this tool exists to remove.

   - `requirement_inputs` **assembles; it does not derive.** The semantic reduction is yours:
     read each note as statements about **named properties**, and apply *a later statement about
     the same property replaces an earlier one, per property* — everything else an older note
     says stays in force. **A note supersedes the contract** the same way.
   - **Print the effective set and the drift list before changing anything** — every requirement
     with its source (`spec` | `note <id>`), and every place a note overrode the spec with both
     values. A build that silently honours an instruction the owner cannot see is worse than one
     that ignores it.
   - `read_notes(target)` is the per-target read when you need one source on its own; it still
     shows every note, pending first, so an assimilated one appears as history.

9. **Read the rulebook.** `get_rules()` — every code-pattern decision of this era answered once.
   `ruled` is what the owner chose: each entry's `instruction` is a sentence this view OBEYS,
   and its `samples` are what the view is patterned on — they are already spelled under the
   era's naming rulings, so a callback, boolean, acronym or domain word reads in a sample the
   way it must read in the view. `defaulted` is every decision not yet ruled, answered with the
   catalog's ★: USE each one, and list it in the report as "defaulted, unruled" — that list is
   how the owner knows what to rule next. **Never stop on an unruled decision**; the default
   stands until ruled. One precedence rule: an answered open question or a note on THIS
   component is the owner's word about this row and wins over a rulebook entry for this row
   alone — say which entry it overrode. Print the rulebook's counts now: `rulebook: N ruled,
   M defaulted`.

**Exit checklist 0:** project + era stated ✓ · row resolved with its registry fields ✓ · contract
present and read in full ✓ · frozen snapshot located ✓ · tokens + generated member names read ✓ ·
rebuild-or-first-build known ✓ · `requirement_inputs` loaded, effective set + drift list printed
✓ · rulebook read: N ruled, M defaulted ✓ · reported:
`report_progress(component: "<C-###>", phase: "load", status, bullets)` ✓

## 0.5 RECONCILE — a part re-specced since

Runs only on an UNBUILT row (phase 0 step 7's `build_status(code)` says which), when
`get_component(code)` returns a non-empty `staleAgainst`, when phase 1 finds a §5 part whose
current contract lacks something this contract says about it, or when a closed question on this
row was filed in-run (its `blocks` field, as `get_component` returns it, is exactly `the run that
asked — it resumes when this is answered`) and its answer is not yet in the contract. Otherwise
`report_progress(component: "<C-###>", phase: "reconcile", status: "skipped", bullets: ["nothing re-specced since this contract"])`
and skip to phase 1.

**A built row never reconciles here.** A re-build of a built row with a non-empty `staleAgainst`
skips this phase: print one line naming the stale parts and `/d2m-component-refresh <code>` as
their route (`stale against C-061, C-062 — /d2m-component-refresh C-045 reconciles it`), and
continue to phase 1 (report `phase: "reconcile", status: "skipped"` the same way).

1. **Diff.** For each such part, `get_component(<part>)` and compare what THIS contract says about
   it — §4 prop types, §3 state rows, open questions — with the part's CURRENT contract and its
   closed rulings. List every difference.
2. **Sort each difference** — print both lists before writing anything:
   - **Bookkeeping** (fix it) — only these three: (a) a type, prop, state or axis value this
     contract takes from the part that the part's current contract no longer has, where that
     contract names the replacement or the removal; (b) a closed ruling on the part whose text
     names THIS row and says what it must change; (c) an open question here whose premise names
     something (a) or (b) struck — close it `decidedBy: "reconcile"` with a `closedNote` naming
     the evidence.
   - **A decision** — everything else, including any snapshot element no built component can
     render as the contract now reads.
3. **Write the bookkeeping** in ONE `upsert_component` call, skipped entirely when step 2's
   bookkeeping list is empty: always pass `name`; pass `props`, `states` and `deviations` WHOLE
   (each replaces its list). `openQuestions` is NOT replace-whole: the call updates only the
   questions passed and never removes another. Pass every question whose `status` is `open`, in
   the order `get_component` returned them (each one's `ordinal` becomes its index among the
   open ones you pass, so they keep their read order), and never re-send an already-closed
   question — a re-sent closed one gets a fresh `closedAt` and loses its `decidedBy` and
   `closedNote`. Also leave out every question whose `reference` is true: it cites a question
   another row owns and reads as `(ref) OQ-…`, so sending that `id` as a `code` would mint a
   duplicate row instead of updating it. Map each one read → write: `id` → `code`, `blocks` →
   `blocksText`, and keep `question`, `blocking`, `options`, `recommended` and `status`; a question re-written without its `blocking`,
   `options` or `blocks` loses them. The ones step 2(c) closes go in with `status` closed,
   `decidedBy: "reconcile"` and a `closedNote` naming the evidence. Re-read with
   `get_component`. THEN, in a SECOND call, write
   `respeccedAt` = the current full ISO datetime (e.g. `2026-09-29T13:02:25.000Z`, never a bare
   date) and `changeList` = one dated list of this run's fixes, replacing the old value
   (`"2026-09-29 reconcile against C-061 — (1) Slide.state removed …; (2) …"`). When the run
   fixed items AND has decisions to file, end the list with `; <n> question(s) filed`. When it
   fixed nothing but has decisions, write
   `"<date> reconciled against <codes> — no bookkeeping fixes; <n> question(s) filed"`. Write
   `"<date> reconciled against <codes> — no drift"` only when it fixed nothing AND step 2's
   decision list is empty. The stamp goes last so a failed fix never clears the warning. Two runs on one row are last-writer-wins:
   after each write, re-read with `get_component` and report what you find.
4. **File the decisions** — if any: ONE `await_answers` call, subject = this row's code, one
   question per decision with at least two options written as complete sentences and your
   proposal as `recommended`. Never pick an answer yourself, and never invent a component to
   fill the gap. End your turn with one line naming what you are waiting on. When the run is
   resumed with the answers, apply each one to the contract with `upsert_component` (the same
   open-questions-only rules as step 3), re-read with `get_component`, and continue to phase 1. An answer naming a
   row that is not built is honoured by phase 0 step 4b: stop and print its build command.

5. **Rebuild the working copy.** The re-read contract replaces the one phase 0 read of it: re-run
   `requirement_inputs(<code>)` and reprint the effective set and the drift list before phase 1,
   so nothing after this point builds from the contract as it stood before the reconcile.

**Exit checklist 0.5:** stale parts listed ✓ · every difference sorted bookkeeping / decision ✓ ·
bookkeeping written, re-read, then `respeccedAt` + `changeList` stamped ✓ · decisions filed via
`await_answers` (or none) ✓ · `requirement_inputs` re-run, effective set + drift list reprinted ✓ · reported:
`report_progress(component: "<C-###>", phase: "reconcile", status, bullets)` ✓

## 1. RESOLVE — dependencies

Read the contract's **§5 Composition**, and only its **Consumes** half — "Consumed by" names the
components that use *this* one and is not a dependency.

Resolve each consumed row and print the table:

| C-### | Name | Level | Source | Action |
|---|---|---|---|---|
| C-0xx | … | 1 · component contract | its own contract in d2m | build against it |
| C-0xx | … | 2 · screen-spec §4 anchor | the screen's §4 subsection | build against it (a §4 anchor is a full anchor) |
| C-0xx | … | 3 · registry row only | the registry row | **flagged stub** |

- **Level 1** and the dependency has no preview of its own yet: prefer running
  `/d2m-component-build C-0xx` for it **first** — it has a contract and a snapshot, so it earns
  its own view, fixture and subject, and this component then composes the real thing. Building it
  inline as a private view in this file is the fallback; if you take it, say so and say why.
- **Level 3 stub** (refusing here would make almost every component unbuildable, which defeats
  the lane): correct size and layout slot, obviously unfinished fill, and the comment
  `// STUB — C-###, no prop-level contract`. A stub is **recorded for the build report**, naming
  the `/d2m-component <name> <figma-url>` run that would spec it — never silently emitted.
  Promotion out of the preview lane is gated on stubs being resolved.
- A level-1 part whose current contract lacks what this contract says about it is not a stop: go back to **phase 0.5** for it.

**Exit checklist 1:** §5 Consumes read (not Consumed-by) ✓ · every consumed row resolved to a
level with its source ✓ · level-1 dependencies ordered (built first, or inline with a reason) ✓ ·
every level-3 stub recorded with the command that would spec it ✓ · reported:
`report_progress(component: "<C-###>", phase: "resolve", status, bullets)` ✓

## 2. TOKENS

Regenerate `project.tokensOutPath` from `get_tokens()`. The token rows are d2m's; the file is the
project's, and it is **generated, never hand-edited** — the next run overwrites it.

- A row with `parsed: false` produced **no value d2m could read**; it ships with a `parseNote`
  saying why, and **cannot be used by name**. List them, and check none is one this view needs.
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
  (phase 4d).

- A token whose `scale` is set (a palette step, e.g. `color-neutral-600`) is emitted only if
  `Tokens.swift` already declares it, so an existing member like `Token.neutral600` keeps
  compiling. Never add a new palette step to `Tokens.swift`: palette colors are
  `Color.palette.<swiftName>` (`Color.palette.brand500`) from the generated `Palette.swift`,
  which the Colors page's Sync writes. A token with `aliasOf` set is an ordinary semantic token
  here — emit it as before.

Then write down, per value the contract cites, the exact member you will use. Every value the
view needs is now one of exactly four things:

1. a token member → use it;
2. the contract's **flagged literal** → emit the literal with the contract's flag repeated as a
   comment (`// FLAGGED LITERAL — C-034 §2: #1f2124, no token`);
3. **contract-traceable, but no token row** → the value traces cleanly to a specific contract line
   (a measured inset, a stated size) but there is simply no token row for it yet — emit it as a
   literal with a `GAP —` comment citing the contract line (`// GAP — C-045 §2: py9, no spacing
   token`), and raise it as an OQ for the owner (a new token row, or a flag on the contract line).
   This is not a flagged literal (the contract never flagged it) and not a spec defect (it traces
   cleanly);
4. **neither tokened nor traceable** → a spec defect. **Stop**, name the value and the contract
   line, and say the fix is a `/d2m-component` re-run that lands it in the token register or flags
   it. Do not invent a token.
   Record it: `report_stop(component: "<C-###>", kind: "spec-defect", reason: "<value> in <contract line> is neither tokened nor traceable", evidence: "<the contract line>")`,
   then `report_progress(component: "<C-###>", phase: "tokens", status: "failed", bullets: [...])`.

Diff the regenerated token file against its previous contents: if it moved, the token register
moved since the last build — report it.

**Exit checklist 2:** token file regenerated from `get_tokens()` and the diff read ✓ · no
`parsed: false` row is one this view needs ✓ · every contract value mapped to a member, a flagged
literal, a cited `GAP —` OQ, or stopped on as a spec defect ✓ · generated file not hand-edited ✓ · reported:
`report_progress(component: "<C-###>", phase: "tokens", status, bullets)` ✓

## 3. WRITE — the view

**Notes bind here.** Where a note and the contract disagree, **the note wins**, and the code that
implements it carries the note's id in a comment:

```swift
// note 2026-09-11T14:32:05.412Z — the active chip pins to the leading edge
```

That comment is what makes an override reviewable: without it, the next reader sees the view
contradicting its own contract and "fixes" it back.

**Naming — the registry name, as the rulebook spells it.** The view type and its file are the
registry name; the rulebook's type-naming decision says whether an affix is added (its ★ is
"the registry name, plain"; a ruled affix — a catalog option's or a derived one — is the only
thing that changes it, and under one the file name is the spelled name too). **Do not
check for a namesake in the shipping app on your own account.** The preview directory is its
own module, so a collision with a shipping type of the same name is resolved by module
qualification, not by renaming the row. The one place the collision is visible is
`project.registryCasePath`, which imports both modules: qualify every preview reference there
(phase 4d).

The module imports the UI framework only. A preview view that needs an application type is a spec
defect, not a linkage to add.

**The capture case key does not change**: it is keyed on the **registry id**, never on the view
type name. The fixture, the subject and the workbench URL all key on `C-###` too.

One view in that file:

- **Parameters are §4's props, expressed as the rulebook rules.** Same names, same types, in
  the contract's order — §4 owns *which* props exist; the rulebook owns *how they are
  expressed*: whether a value comes with a change callback or a binding, whether actions are
  one closure each or one enum, whether a variant is an enum and where that enum is declared,
  whether a prop is required, and how every callback, boolean and acronym is spelled. A ruled
  entry's sample is the shape to copy. Every designed §3 state must be reachable **through the
  parameters alone**: a fixture can only set props, so a state driven by internal view state
  is uncapturable. (`focused`, `selected` and friends are props here.)
- **Interaction-bearing props** (the callbacks, spelled as the rulebook's callback rule says)
  have no render effect. Emit them as defaulted no-op closures so the promoted view keeps its
  real signature. Say in the report that you took that default.
- **Chrome-free and width-driven.** The view fills the width it is given and states its own
  intrinsic height; it paints no page background and adds no outer padding. The frame, background
  and padding belong to the capture call site (phase 4d), so the master width and the layout
  background are one line each to change when the owner rules, and the file itself is promotable
  unchanged.
- **Tokens only**, per phase 2. No raw hex, no raw point sizes, no legacy colour or typography
  types — those are files this run never touches.
- **No debug-only conditionals, no in-file preview block, no lazy containers, no console
  printing.**
- **Name the anatomy** with the preview module's element-annotation helper. The workbench has no
  web twin to hit-test, so a comment gets its element context from the parts the view names
  itself: the capture harness resolves each annotated rect and writes it beside the render, and
  the workbench highlights it under the cursor in comment mode. Annotate the **root** (the
  registry name), **each §2 named slot**, and **each repeated item** (`"Bar \(index + 1)"`); use
  §2's own anatomy vocabulary, since that string is what the comment carries. A part whose
  identity changes with a prop says so — a text run is `"Placeholder"` or `"Value"`. Nesting is
  NOT declared: it is derived from rect containment, so a dependency that names itself is
  reported inside whatever slot placed it. An unannotated component is not an error — it just has
  no highlights.
- File header: what it is, the contract it was built from, and the preview-only rule —

```swift
//
//  <ViewName>.swift            (the registry name as the rulebook's type-naming rule spells it)
//  <the preview module>
//
//  Built from C-###-<slug> in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
```

If the preview directory has no README, write one now: it states the preview-only rule and the
promotion path, and nothing else.

**Exit checklist 3:** one view, parameters == §4 props ✓ · every designed §3 state reachable by
props alone ✓ · tokens/flagged literals only ✓ · no debug conditional / in-file preview / lazy
container / application import ✓ · root + every §2 named slot + every repeated item annotated ✓ ·
header cites the contract and the preview-only rule ✓ · preview-directory README present ✓ · reported:
`report_progress(component: "<C-###>", phase: "write", status, bullets)` ✓

## 4. FIXTURE + CAPTURE CASE

**a. Start from d2m's fixture, not from a hand-written one.** `get_previews(code)` returns the
previews: one per §3 row the build seeded, plus any the owner added: the label, the slug, and the
props currently authored. The state list is the contract's §3 matrix — every row, `undesigned`
ones included — and the labels are exactly the keys the frozen snapshot and every comment thread
hang off. An `undesigned` row's props come from its §3 prop values the same way; only the
snapshot half of the diff is missing for it. Read
`propsAuthored` per preview rather than testing the bag for truthiness: never authored and
authored-empty are different answers, and only the first is yours to fill in.
A preview may carry its own Figma reference (`figmaUrl` on `get_previews`) — a designed instance the owner pointed at; the build renders the preview's props as ever and never edits or captures that reference.

**b. Audit the props** — the draft is a starting point, not an answer:

- **Labels and slugs** — leave them alone. They are the contract's, and `put_preview_props`
  writes props only: naming a state that is not in the fixture is an **error, never an insert**, and a
  state is added by putting it in the §3 matrix with `/d2m-component` and letting the build pick
  it up.
- **Types matter.** `3` and `"3"` are different values and generate different code; write each
  prop as the type §4 declares, not as whatever renders the same.
- **Every prop key must be a §4 prop name.** Where §4 is prose, or the §3 matrix's leading column
  does not name a prop, what you get is the Figma **axis** as a pseudo-prop — `{"state × lines":
  "Default × Single"}`. That is not a prop. Translate the axis value into §4 props yourself: §4's
  table crossed with that state's §3 row (`Default × Single` → `text: ""`, `placeholder:
  "Placeholder"`, `lines: "single"`, `focused: false`). If the contract does not determine the
  translation, **stop**: that is a spec defect, and it is fixed by `/d2m-component`.
  Record it: `report_stop(component: "<C-###>", kind: "spec-defect", reason: "the contract does not determine the props for <state>", evidence: "<the §3 row and the §4 props>")`,
  then `report_progress(component: "<C-###>", phase: "fixture", status: "failed", bullets: [...])`.
- **Devices** — they come from `project.devices`, which is a project setting, not a per-component
  choice. Confirm the fixture's devices are values that project's renderer understands; an empty
  list means "the adapter's own default", which is an authored answer and not a missing one.
- **The view key** — the identifier the project's harness resolves to the case you are about to
  write. If `build_status(code)` reports a fixture that names **no view**, say so plainly: d2m
  will refuse the capture ("its fixture names no view — the renderer would not know what to
  draw"), and that is a lane-configuration gap to report, not something to work around.

**c. Write it.** `put_preview_props(code, previews)` with the audited props per state. Then
re-read with `get_previews(code)` and confirm every state came back with the props you wrote and
the labels untouched. Write props ONLY for previews whose `propsAuthored` is false — a preview
the owner authored keeps its props.

**d. The capture case.** Append one case to `project.registryCasePath`, immediately before its
final fallback, decoding the fixture's component payload exactly as the neighbouring cases do.
**Module-qualify every preview name** — that file imports both modules, and a registry name that
collides with a shipping type is ambiguous without it:

```swift
    case "component.<era>.C-###":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.<era>.C-###: missing state.component")
        }
        return AnyView(
            <PreviewModule>.<RegistryName>(/* §4 props from `c`, with the contract's defaults */)
                .frame(width: <master width from §2>)
                .padding(<PreviewModule>.Token.Space.pageMargin)
                .frame(maxWidth: .infinity)
                .background(<PreviewModule>.Token.layoutBackground)
        )
```

Every field on `c` is optional (see step e) — supply **the contract's** default for a missing one
(`c.text ?? ""`), never an invented one; a prop the contract gives no default for is required, so
a nil is a fixture bug, not a value to guess.

The renderer draws a component fixture at device width with intrinsic height and no chrome, so
the frame, padding and background live here, not in the view (phase 3) — an owner ruling on the
master width or the layout background then changes this call site alone.

**e. The fixture-decoding type.** Props reach the harness through a fixed decodable struct beside
the registry case. **A JSON key with no matching field decodes to nothing, silently**, and the
render comes out default-valued with no error. So check every prop name in the fixture against
that struct, and add the missing ones as purely additive optionals in one block at the end of it:

```swift
    // ── preview props ──
    let lines: String?                         // C-045 TextInput
    let focused: Bool?
```

Two bounds, both absolute: **additive optional fields only**, and **never bend a prop name to fit
an existing field** — a contract's prop name is the contract's, not something to rename into
whatever the struct already has. Never modify, retype, rename or reorder an existing field, and
**name every field you add in the run's report.**

**f. Record what you wrote.** `record_build_artifacts(...)` with every file this run put into
the project repo: `previewPath` (relative to `project.previewDir`), `tokensPath` (recording one
stamps when tokens were last generated), `registryCasePath`, and `otherPaths` for the decoding
struct and whatever the sync command rewrote. Pass `sha` if you know the repo's, and on a run
that failed, `built: false` with `error` — a half-finished build recorded honestly is worth more
than a silent one. That record is how the next reader (and the delete skill) knows what this
build owns, without re-deriving it from the filesystem.

**Exit checklist 4:** fixture read from d2m, not hand-written ✓ · labels and slugs untouched ✓ ·
every prop key is a §4 prop with a contract-traceable value ✓ · devices confirmed against
`project.devices` ✓ · fixture re-read and verified ✓ · capture case added before the fallback with
the frame/background at the call site ✓ · every prop has a decodable field, additions reported ✓ ·
artifacts recorded ✓ · reported:
`report_progress(component: "<C-###>", phase: "fixture", status, bullets)` ✓

## 5. SYNC THE TARGET, THEN CAPTURE

**1. Sync.** Run `project.targetSyncCmd` from `project.repoPath`, if the project configures one.
A generated file is often invisible to the compiler until it is a member of the build target, and
**a file that is not in the target does not compile — the capture then fails minutes later with
an unknown-view error.** Check the command's output names your new file. A project with no sync
command needs none; say so rather than inventing a step.

**2. Lint before you burn a render.** Run `project.lintCmd` from `project.repoPath`. Linting is
usually a build phase, so a violation fails the render *after* the build has already spent
minutes; running it directly costs about a second. Fix violations in the preview file. **Never**
regenerate a lint baseline to silence one.

**3. Preconditions.** `project_info()`'s `capture.canCapture` (mirrored on
`get_component(code)`) is d2m's own answer to "is this lane ready". The renderer's *own* preconditions (a simulator, a device, a toolchain) belong to the
project's render command: when the capture fails, read its log rather than guessing.

**4. NO ASK — capture is part of the run.** Invoking this skill IS the permission: a build that
stops before capturing has produced nothing anyone can look at, which is the entire point of the
lane. Do not ask, do not offer, do not wait — go straight to step 5 as soon as steps 1–3 are
green. Steps 1–3 are the gate that replaces the question: an unsynced file, a lint violation or an
unready lane each stop the run **before** minutes are spent. A red ✗ there is not something to ask
about — fix it or report it.
Report it with the kind that names it — an unsynced file:
`report_stop(component: "<C-###>", kind: "sync-failed", reason: "…", evidence: "<the sync output>")`; a
lint violation you cannot fix in the preview file:
`report_stop(component: "<C-###>", kind: "lint-failed", reason: "…", evidence: "<the lint line>")`; an
unready lane: `report_stop(component: "<C-###>", kind: "lane-not-ready", reason: "…", target: "<what is missing>")`;
a capture job that fails: `report_stop(component: "<C-###>", kind: "capture-failed", reason: "…", evidence: "<the log tail>")`.
Then `report_progress(component: "<C-###>", phase: "capture", status: "failed", bullets: [...])`.

**5. Capture.**

```
capture(component: "C-###", state: "*", wait: true)             # every designed state
capture(component: "C-###", state: "<state-slug>", wait: true)  # one state, by SLUG
```

`capture` runs the project's configured renderer and answers a **handle, not a result**: a real
render is minutes of renderer time — one renderer run per state (~30s each on a simulator
lane), so `"*"` on a four-state component is ~2 minutes. `wait: true` follows the run for up to
10 minutes and answers its final state and the tail of its log. If it still comes back
`timedOut: true`, **call `capture_status(runId)` every ~30s until `state` is not `running`** —
that tool is the run's state and log by id. **Never** poll the filesystem for renders, read
`xcresult` bundles, or read d2m's own source to work out whether a capture finished: the run's
log is in `capture_status`, and the renders are in `get_component(code)` once it ends. **Read
the log** — it is the renderer's own, so it is the only place a toolchain error appears.

**6. Read the renders.** `get_component(code)` → each variant's `versions[]`, newest first; the
newest entry per state is this run's, and its URL is what you open. Beside each render sits its
element map — the phase-3 annotations, resolved. Check it exists and names the parts you
annotated; if it is missing, the component's comments will have no element context. Its rects are
fractions of the render, so they are readable without opening the image.

**Expected collateral:** a project whose renderer re-runs a whole harness suite will rewrite
unrelated baseline images in its repo. Nothing broke. Leave them out of any commit.

**Exit checklist 5:** sync run and the new file named in its output (or "no sync command
configured") ✓ · lint clean ✓ · lane ready ✓ · `capture` invoked without asking and its job
succeeded ✓ · a render per built state located ✓ · reported:
`report_progress(component: "<C-###>", phase: "capture", status, bullets)` ✓

## 6. DIFF AND REPORT

1. **Per state**, open the render beside the frozen snapshot (`get_component(code)`'s `snapshot`)
   and read both against §2's geometry — dimensions, spacing, border, type, colour. An
   `undesigned` state has no snapshot half: read its render against §2 and the ruling that
   designed it (the answered OQ or note), and check it against the DRAWN states it varies
   from — the same geometry with one prop changed should differ in exactly that prop's effect.
2. **Refine the view** (phase 3) and re-capture the state(s) that moved (phase 5 step 5; the sync
   in step 1 is only needed when a file was added or removed). Prefer the named state over `*` —
   each state is ~30s of renderer time and `*` is all of them. **Budget the loop: at most three
   refine-and-recapture rounds.** Read the element map's rects (they are in the capture's output
   beside the render) BEFORE the next edit so each round fixes a measured delta, not a guess;
   if the third round still leaves a delta, report it as a gap (step 3) rather than capture again.
3. **Stop refining when the remaining delta is a real gap**, and name its class:
   - **note-driven divergence** — a note (phase 0.7) told the build to do something the Figma
     snapshot does not show. This is EXPECTED, not a diff failure: the render is correct and the
     snapshot is what has fallen behind. Report these in their own list with the note id that
     caused each one, and never "fix" the view back toward the picture — that would undo the
     owner's own instruction;
   - the UI framework genuinely cannot express the contract's construction;
   - the contract underspecifies what the snapshot shows (→ a `/d2m-component` re-run);
   - a **stub** from phase 1 level 3;
   - a deviation the contract's §1 closed list already declares.
   **Surface the gap; never fudge the view to match the picture.** A render that matches by nudged
   geometry hides exactly what this lane exists to reveal.
4. **Look at it in the workbench:** the component's page for this project and era,
   `/<project>/<era>/C-###/<state-slug>` — design ⇄ built toggle, pixel diff and pinned comments,
   per state.
5. **Report to the user:**
   - **project + era** — the scope line, first;
   - **previews captured** — label + slug, and which ones you re-captured;
   - **built without a snapshot** — every `undesigned` §3 row: rendered from its prop values
     and the ruling behind it, with nothing frozen to diff against (the owner reads the render
     on its own until Figma draws it); and any row skipped because the contract marks it not
     a state, with the marking quoted;
   - **owner previews** — each preview with `stateSlug: null`, re-captured as-is;
   - **dependencies** — each with its resolution level, and every level-3 stub with the
     `/d2m-component` run that would spec it;
   - **tokens** — regenerated counts, anything `parsed: false`, any flagged literal emitted, and
     whether the generated token file changed since the last build;
   - **files written into the project repo** — every one, as recorded by
     `record_build_artifacts`, including each decodable field added;
   - **the view's name** — the registry name as the rulebook's type-naming rule spells it, in
     the preview module;
   - **defaults taken** (device/width, background, no-op closures, and any other open question
     this run answered by default), so an owner ruling has a list to overturn;
   - **rulebook** — every `ruled` entry obeyed (`R-## label`), every `defaulted` entry used
     (`R-## label — defaulted, unruled`), and any entry an answered open question or a note
     overrode for this component, with the OQ id or note id;
   - **drift** — on a re-build, what changed in the contract since the previous fixture; every phase 0.5 fix, and every question it filed;
   - **note-driven divergence** — every difference a note caused, with its note id, kept separate
     from the gap list so the owner can see what their own instructions changed;
   - **gaps** — step 3's list, by class.

**Exit checklist 6:** every built state diffed against its snapshot ✓ · refinements re-captured ✓ ·
remaining deltas classified as gaps, none fudged ✓ · workbench path given ✓ · report covers
scope/states/skips/dependencies/tokens/files/defaults/rulebook/drift/gaps ✓ · reported:
`report_progress(component: "<C-###>", phase: "diff", status, bullets)` ✓
