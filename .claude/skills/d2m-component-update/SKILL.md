---
name: d2m-component-update
description: Verify ONE built component preview against its spec AND its notes, fix what fails, recapture, and report. Derives the effective requirement set (contract + notes, newer wins per property), checks the built view and fixture against it, edits only the project's preview directory and the fixture, and reports every place a note has overtaken the spec as drift for the owner to resolve. Never writes spec content. Designed to run in a FRESH session.
argument-hint: [C-### registry id; omit to be shown the components that have notes] [--project <slug>] [--era <key>]
---

# Component update — $ARGUMENTS

Verify the built preview for **$ARGUMENTS** against **spec + notes**, fix what fails, recapture,
report. The sibling of `/d2m-component-build`: that skill builds a preview from the contract,
this one keeps it honest as the owner's intent accumulates in notes.

**Why this exists.** A contract says what a component *is*; Figma says what it *looks like*;
notes say what it is *for* and how it should behave in a particular place. Notes arrive after
the build, and they are normative — so a component that was correct when it was built drifts out
of conformance as notes are written, and nothing was checking.

**Arguments:** `<C-###>`. **No argument → list the components that HAVE notes**, newest-note
first, with each one's note count and whether it is built, then ask with AskUserQuestion. Never
pick for the user. (`list_components()` for the rows and their built-ness; `read_notes(code)` for
the counts.) `--project <slug>` / `--era <key>` override the pinned scope; **pass them through to
every tool call.**

## Hard rules (re-read before EVERY phase)

**This skill edits the preview lane, so `/d2m-component-build`'s Hard-rules block binds it in
full.** Re-print that block at the head of every phase and check the diff against it:

- **Wired into nothing** · **Legacy untouched** and the same file-write allow-list · **Tokens by
  name** (the project's `lintCmd` bans raw hex, raw point sizes, console printing and lazy
  containers) · **Value sets have one owner** · **Every prop traces** · **States are the
  contract's states** · **Name ≠ slug** · **No debug conditional, no in-file preview block** ·
  **Idempotent and visible** · **Never fudge.**

Four more of its own:

- **Notes win over the contract, and newer notes win over older — per property.** An older note's
  non-conflicting statements stay in force.
- **The pixel diff against Figma is not the oracle** when the drift list explains the difference.
  A render that a note deliberately changed SHOULD differ from the snapshot.
- **Spec content is read-only here.** A contract the notes have overtaken is *reported*, never
  rewritten — the owner decides whether Figma or the contract moves. No `upsert_component`, no
  `upsert_tokens`, no `add_decision` in this run.
- **Ask before capturing.** `/d2m-component-build` captures without asking on the strength of
  "invoking the build IS the permission"; that reasoning does not transfer here, so phase 4 asks
  first.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. LOAD

1. `project_info()` — **state the project slug and era key in your first report line**, and keep
   `repoPath`, `previewDir`, `lintCmd`, `captureAdapter`. An adapter of `noop` means there is no
   render lane: you can still derive and verify against the code, but say plainly that phase 4
   cannot recapture and that a verdict resting on a render is unavailable.
2. `get_component(code)` — the registry row (name, status, "Defined in"), the **normative spec**
   (its contract in full, or — for a row anchored only in a screen spec — that spec's §4
   subsection via `get_screen(id)`), the frozen `snapshot`, and each state's `versions[]` (the
   newest is the current render).
3. `get_fixture(code)` if the row is built; `build_status(code)` if you need the plain answer.
4. The built view under `project.previewDir`, and its case in `project.registryCasePath`.
5. **The inputs to the derivation**: `requirement_inputs(code)`. It returns the contract
   sections, the frozen snapshot, and every note ordered oldest→newest **across the target, its
   dependencies and its consuming screens** — a dependency's note binds its hosts, and a screen's
   note binds what that screen renders. Only PENDING notes come through here — an assimilated
   note is already in the contract and is not re-applied. Use it rather than assembling the
   three sources yourself; assembling them by hand in two different skills is precisely the
   drift it removes. `read_notes(target)` is the per-target read when you want one source on its
   own; it still shows every note, pending first, so an assimilated one appears as history.

**Exit checklist 0:** project + era stated ✓ · row resolved ✓ · contract (or screen §4) read in
full ✓ · snapshot + fixture located ✓ · built view located, or NOT BUILT established ✓ ·
`requirement_inputs` loaded and every note printed with its id ✓

## 1. DERIVE — the effective requirement set

`requirement_inputs` **assembles; it does not derive.** The reduction is this skill's job, and it
is a reading task, not a computation:

1. Start from the normative spec: contract (or screen §4), registry row, frozen snapshot.
2. Read every note oldest → newest, across target, dependencies and consuming screens.
3. Read each note as statements about **named properties** — geometry, colour, state, prop,
   behaviour, copy, interaction.
4. **A later statement about the same property replaces an earlier one**, whether the earlier one
   came from another note or from the spec. Supersession is **per property**: everything else an
   older note says stays in force.
5. Emit two artefacts:
   - the **effective set** — every requirement with its source (`spec` | `note <id>`);
   - the **drift list** — every requirement where a note overrode the spec, with both values.

**Print both before changing anything.** The derivation is the reviewable artefact of this skill,
and a wrong reading here corrupts everything after it.

**Not built?** Stop here. Print the effective set and:
`/d2m-component-build C-###  ← build it first; there is nothing to verify against`.
That is a complete, useful run — not a failure.

**Exit checklist 1:** effective set printed with a source per requirement ✓ · drift list printed
with both values ✓ · superseded statements named with the note that replaced them ✓ · unbuilt
target stopped here ✓

## 2. VERIFY

Check the built view and its fixture against **each** requirement in the effective set.

| Verdict | Meaning |
|---|---|
| **PASS** | traced to `file:line` in the view or to a prop in the fixture, or to a measured value in the render |
| **FAIL** | the requirement is not met — say what the code does instead |
| **UNVERIFIABLE** | nothing a still render can show: a gesture, a transition, a scroll behaviour, an interaction. Report it; **never guess it into a pass** |

A requirement whose source is a note gets the note's id in its row, so the owner can see which of
their instructions are actually holding.

**Exit checklist 2:** every requirement has a verdict ✓ · every PASS carries file:line or a
measured value ✓ · every FAIL says what the code does instead ✓ · UNVERIFIABLE rows listed as
such, none guessed ✓

## 3. FIX

Edit **only** files under `project.previewDir`, and the fixture through `put_fixture`.

- One edit per FAIL, each citing the requirement and — when its source is a note — that note's id
  in a code comment, exactly as `/d2m-component-build` phase 3 does.
- The Hard rules above bind every edit. Tokens by name; no new files outside the allow-list.
- **Never write spec content.** A contract the notes have overtaken is drift to report, not a
  document to rewrite. `put_fixture` writes props only and cannot add, rename or remove a state —
  that is the contract's business, and if a FAIL needs one, it is a finding for
  `/d2m-component`, not an edit here.
- A FAIL you cannot close without a spec decision is left failing and reported. Do not invent a
  requirement to make it pass.

**Exit checklist 3:** one edit per FAIL ✓ · every note-driven edit carries its note id ✓ · nothing
written outside the preview directory and the fixture ✓ · unclosable FAILs named ✓

## 4. RECAPTURE + RE-VERIFY

1. **Ask the user before capturing** (Hard rules). Then
   `capture(component: "C-###", state: "<state-slug>", wait: true)` for the states that changed,
   and read the run's log. `capture` answers a handle, not a result; `wait: true` follows it for
   up to 10 minutes, and a render still going after that comes back `timedOut: true` — then
   `capture_status(runId)` every ~30s until it is not `running`, never the filesystem. On a project with no
   render lane the tool refuses outright — report that and stop rather than working around it.
2. Re-run phase 2 against the new render for every requirement that was FAIL.
3. A fix that does not close its requirement is **reported as such** — not retried indefinitely.
   Two attempts is the limit; after that it is a finding, not a task.
4. Re-diff against the frozen snapshot. **Classify every remaining difference**: explained by the
   drift list (expected — a note caused it), or unexplained (a real gap).

**Exit checklist 4:** capture asked for and run ✓ · every FAIL re-verified ✓ · residual failures
reported, not retried in a loop ✓ · diff differences classified drift-vs-gap ✓

## 5. REPORT

- **Project + era** — the scope line, first.
- **What changed** — file by file, each edit with the requirement and note id behind it.
- **The drift list** — every place a note has overtaken the spec, with both values. This is the
  owner's action list: it tells them where Figma or the contract has fallen behind their own
  intent.
- **Still failing / unverifiable** — with what each one needs.
- **Note-driven divergence from Figma** — differences the snapshot shows that the notes explain,
  so nobody "fixes" them later.
- **Whether the spec now lags badly enough to want a re-spec** — if the drift list has grown to
  where the contract no longer describes the component, say so and name the run:
  `/d2m-component <name> <figma-url>`.

**Exit checklist 5:** changes listed with their sources ✓ · drift list handed over as an action
list ✓ · residuals named ✓ · re-spec recommendation made or explicitly declined ✓
