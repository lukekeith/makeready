---
description: Verify ONE built UI 2.0 component preview against its spec AND its notes, fix what fails, recapture, and report. Derives the effective requirement set (contract + notes, newer wins per property), checks the built view and fixture against it, edits only UI2Preview/ and the fixture, and reports every place a note has overtaken the spec as drift for the owner to resolve. Never writes under docs/ui2. Designed to run in a FRESH session.
argument-hint: [C-### registry id; omit to be shown the components that have notes]
---

# UI 2.0 component update — $ARGUMENTS

Verify the built preview for **$ARGUMENTS** against **spec + notes**, fix what fails,
recapture, report. The sibling of `/ui2-component-build`: that command builds a preview from
the contract, this one keeps it honest as the owner's intent accumulates in notes.

**Why this exists.** A contract says what a component *is*; Figma says what it *looks like*;
notes say what it is *for* and how it should behave in a particular place
(`docs/features/ui2-component-notes/01-architecture.md`). Notes arrive after the build, and
they are normative — so a component that was correct when it was built drifts out of
conformance as notes are written, and nothing was checking.

**Read before phase 1:** `docs/ui2/preview-build.md` in full, and
`docs/features/ui2-component-notes/03-data-and-api.md` §3, which defines the derivation this
command implements.

**Arguments:** `<C-###>`. **No argument → list the components that HAVE notes**, newest-note
first, with each one's note count and whether it is built, then ask with AskUserQuestion.
Never pick for the user.

## Hard rules (re-read before EVERY phase)

**This command edits the preview lane, so `/ui2-component-build`'s Hard-rules block binds it
in full.** Re-print that block at the head of every phase and check the diff against it:

- **Wired into nothing** · **Legacy untouched** and the same file-write allow-list ·
  **Tokens by name** (SwiftLint bans `Color(hex:)`, raw `.system(size:)`, `print`/`NSLog`,
  `LazyVStack`/`LazyVGrid`) · **Value sets have one owner** · **Every prop traces** ·
  **States are the contract's states** · **Name ≠ slug** · **No `#if DEBUG`, no `#Preview`** ·
  **Idempotent and visible** · **Never fudge.**

Four more of its own:

- **Notes win over the contract, and newer notes win over older — per property** (D3/R13).
  An older note's non-conflicting statements stay in force.
- **The pixel diff against Figma is not the oracle** when the drift list explains the
  difference. A render that a note deliberately changed SHOULD differ from the snapshot.
- **`docs/ui2` is read-only.** A spec the notes have overtaken is *reported*, never
  rewritten — the owner decides whether Figma or the doc moves (D3).
- **Ask before capturing.** `iphone/.claude/CLAUDE.md`'s carve-out permits
  `capture/runners/ui2/capture.mjs` without asking on the strength of "running
  `/ui2-component-build` IS the permission"; that reasoning does not transfer to this
  command, so phase 4 asks first. (If the owner extends the carve-out to name this command,
  delete this rule in the same edit.)

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. LOAD

1. Resolve the row in `docs/ui2/design-system/registry.md`; note its name, status and
   "Defined in".
2. **The normative spec**: the contract file
   `docs/ui2/design-system/components/C-###-<slug>.md`, or — for a row anchored only in a
   screen spec — that spec's §4 subsection. Read it in full.
3. The frozen snapshot named in §1, and `capture/fixtures/ui2/C-###.json` if it exists.
4. The built view at `iphone/MakeReady/UI2Preview/<Name>.swift`, and its `ViewRegistry` case.
5. **The notes**, always through the parser, never by eye:

   ```
   node capture/lib/ui2-notes.mjs read C-###                    # the target
   node capture/lib/ui2-notes.mjs read <each dependency>        # a dep's note binds its hosts
   node capture/lib/ui2-notes.mjs read <each consuming screen>  # registry "Consumed by"
   ```

6. The current render: `capture/fixtures/compare/_shots/ui2-c-###/…` (the browser shows it at
   `http://localhost:5950/components/2.0/C-###`).

**Exit checklist 0:** row resolved ✓ · contract (or screen §4) read in full ✓ · snapshot +
fixture located ✓ · built view located, or NOT BUILT established ✓ · notes loaded from all
three sources via the CLI and printed with their ids ✓

## 1. DERIVE — the effective requirement set

Implement `03-data-and-api.md` §3 exactly:

1. Start from the normative spec: contract (or screen §4), registry row, frozen snapshot.
2. Read every note oldest → newest, across target, dependencies and consuming screens.
3. Read each note as statements about **named properties** — geometry, colour, state, prop,
   behaviour, copy, interaction.
4. **A later statement about the same property replaces an earlier one**, whether the earlier
   one came from another note or from the spec. Supersession is **per property**: everything
   else an older note says stays in force.
5. Emit two artefacts:
   - the **effective set** — every requirement with its source (`spec` | `note <id>`);
   - the **drift list** — every requirement where a note overrode the spec, with both values.

**Print both before changing anything.** The derivation is the reviewable artefact of this
command, and a wrong reading here corrupts everything after it.

**Not built?** Stop here. Print the effective set and:
`/ui2-component-build C-###  ← build it first; there is nothing to verify against`.
That is a complete, useful run — not a failure.

**Exit checklist 1:** effective set printed with a source per requirement ✓ · drift list
printed with both values ✓ · superseded statements named with the note that replaced them ✓ ·
unbuilt target stopped here ✓

## 2. VERIFY

Check the built view and its fixture against **each** requirement in the effective set.

| Verdict | Meaning |
|---|---|
| **PASS** | traced to `file:line` in the view or the fixture, or to a measured value in the render |
| **FAIL** | the requirement is not met — say what the code does instead |
| **UNVERIFIABLE** | nothing a still render can show: a gesture, a transition, a scroll behaviour, an interaction. Report it; **never guess it into a pass** |

A requirement whose source is a note gets the note's id in its row, so the owner can see which
of their instructions are actually holding.

**Exit checklist 2:** every requirement has a verdict ✓ · every PASS carries file:line or a
measured value ✓ · every FAIL says what the code does instead ✓ · UNVERIFIABLE rows listed as
such, none guessed ✓

## 3. FIX

Edit **only** `iphone/MakeReady/UI2Preview/` and `capture/fixtures/ui2/`.

- One edit per FAIL, each citing the requirement and — when its source is a note — that note's
  id in a code comment, exactly as `/ui2-component-build` phase 3 does.
- The Hard rules above bind every edit. Tokens by name; no new files outside the allow-list.
- **Never edit `docs/ui2`.** A contract the notes have overtaken is drift to report, not a
  doc to rewrite.
- A FAIL you cannot close without a spec decision is left failing and reported. Do not invent
  a requirement to make it pass.

**Exit checklist 3:** one edit per FAIL ✓ · every note-driven edit carries its note id ✓ ·
nothing written outside `UI2Preview/` and `capture/fixtures/ui2/` (`git status docs/ui2` shows
only note files, if anything) ✓ · unclosable FAILs named ✓

## 4. RECAPTURE + RE-VERIFY

1. **Ask the user before capturing** (Hard rules). Then run the capture for the states that
   changed: `node capture/runners/ui2/capture.mjs C-### <state-slug>`.
2. Re-run phase 2 against the new render for every requirement that was FAIL.
3. A fix that does not close its requirement is **reported as such** — not retried
   indefinitely. Two attempts is the limit; after that it is a finding, not a task.
4. Re-diff against the frozen snapshot. **Classify every remaining difference**: explained by
   the drift list (expected — a note caused it), or unexplained (a real gap).

**Exit checklist 4:** capture asked for and run ✓ · every FAIL re-verified ✓ · residual
failures reported, not retried in a loop ✓ · diff differences classified drift-vs-gap ✓

## 5. REPORT

- **What changed** — file by file, each edit with the requirement and note id behind it.
- **The drift list** — every place a note has overtaken the spec, with both values. This is
  the owner's action list: it tells them where Figma or the contract has fallen behind their
  own intent.
- **Still failing / unverifiable** — with what each one needs.
- **Note-driven divergence from Figma** — differences the snapshot shows that the notes
  explain, so nobody "fixes" them later.
- **Whether `docs/ui2` now lags badly enough to want a re-spec** — if the drift list has grown
  to where the contract no longer describes the component, say so and name the run:
  `/ui2-component <name> <figma-url>`.

**Exit checklist 5:** changes listed with their sources ✓ · drift list handed over as an
action list ✓ · residuals named ✓ · re-spec recommendation made or explicitly declined ✓
