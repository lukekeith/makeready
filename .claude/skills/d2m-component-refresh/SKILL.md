---
name: d2m-component-refresh
description: Bring ONE built component's contract back up to what its build and every ruling since have decided. Reads the built preview and its fixture, the row's Figma references and frozen snapshot, its notes, the decision register and the closed rulings it cites; rewrites the contract sections and state matrix that have fallen behind; closes the open questions whose premise is gone, that a ruling elsewhere already answers, or that only defer to another open question; and lists every other one by what it needs. Only for a BUILT row — the reverse of /d2m-component-build. Never edits the preview, never answers as the owner. Mints an open question for what the build does that nothing decided. Reads PENDING notes as rulings and names /d2m-notes-assimilate to fold them in. (Copied by the workbench's Prompt ▸ Refresh the contract.) Designed to run in a FRESH session.
argument-hint: <C-###> [--project <slug>] [--era <key>]  — e.g. C-064
---

# Component refresh — $ARGUMENTS

Refresh the contract for **$ARGUMENTS** to what the component *now is*: what its build shipped,
what the owner has ruled since (notes, answered questions, decisions, rulings on other rows), and
what its Figma references say today. The reverse of `/d2m-component-build`: that skill makes a
preview from the contract; this one makes the contract describe the preview and the rulings again.

**Why this exists.** A contract is written once, from Figma, with a list of open questions. Then
the component gets built, the owner writes notes, answers some questions, rules on the same
question on a *different* row, adds a Figma reference the spec run never saw — and the contract
keeps saying what was true the day it was written. Its questions go stale in four ways: the
premise is gone (a "no snapshot on disk" that blocks a build of a component that is built), a
closed ruling elsewhere already answers it (the raw-hex-bind question, asked on seven rows and
ruled once), it only defers to another open question, or it is one of four copies of one
program-wide question. And because every open question gates the build lane, a stale question
blocks a rebuild for no reason. This run is the audit that clears it.

**Arguments:** `<C-###>`, required. `--project <slug>` / `--era <key>` override the pinned scope;
**pass them through to every tool call**, and state the project and era you resolved in your
first report line.

## Hard rules (re-read before EVERY phase)

- **Only a BUILT row.** The preview and the fixture are this run's evidence of what was decided.
  `build_status(component)` says. Not built → stop at phase 0 and name the run that applies:
  `/d2m-component-build C-###` if the contract is current, `/d2m-component C-###` if it is not.
  That is a complete answer, not a failure.
- **A pending note is a ruling.** `read_notes(component)` lists every note; the `pending` ones are
  the owner's intent that no run has folded into the contract yet, and this run reads them as
  rulings like any other — a deviation a pending note explains is ADOPTED with that note as its
  evidence, never minted as a question. The note stays pending (this run never marks notes);
  the report names `/d2m-notes-assimilate C-###` as the run that folds them in. An
  `assimilated` note is history: already in the contract, not re-applied.
- **The build plus the rulings are the truth — the build alone is not.** What the preview does
  is adopted into the contract when a ruling supports it: a note, a closed question, a D#
  decision, a ruling on another row this row's question defers to. A thing the build does that
  *no* ruling supports is a **deviation to report AND an open question to mint** (phase 3),
  **never a contract change**: `blocking: false` — the row is built and a blocking question would
  stop a rebuild over something the build already answered one way — with the options "Ratify
  what the build does — …" and "Keep the contract — the build is wrong", and no `recommended`,
  because the choice is genuinely the owner's. The one exception is a **proposed default the
  contract itself wrote** ("§3c proposes …") which the build shipped as proposed — that is still
  the owner's to ratify (phase 2), and the contract already says it.
- **Never answer as the owner.** A question this run closes carries `decidedBy: "refresh"` and a
  `closedNote` that names the evidence — the ruling, the note id, the payload field. `"owner"` is
  the workbench's word for a click the owner made, and this run never writes it. A question with
  no mechanical answer stays open; the most this run does for it is make it one click to answer.
- **Never write into the preview lane.** No file under `previewDir`, no `put_preview_props`, no
  `capture`. The preview is what this run *reads*.
- **Never strike a row, never mint one.** A consolidation this run finds is `/d2m-component-merge`'s
  (phase 2 names it); a row that turns out to be two is `/d2m-component`'s.
- **Never invent a Figma fact.** d2m holds a reference's node id, its picture and whether that
  picture is stale — not whether the node is a published component, not how a fill is bound, not
  whether a layer is hidden. A question whose premise is one of those is *verify in Figma*, and
  stays open, however likely the answer looks.
- **Tools describe themselves; d2m's code does not.** Never read d2m's own source, your own
  session transcripts, or another skill's SKILL.md to work out how a tool behaves. If a tool
  cannot do what this skill says, say so in the report and continue with what you have.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. LOAD + GATE

1. `project_info()` — **state the project slug and era key in your first report line**; keep
   `repoPath`, `previewDir`, `registryCasePath`.
2. `build_status(component)`. **Not built → stop** (Hard rules). Print the reason and the run
   that applies.
3. `read_notes(component)` — print every note with its id and status. The pending ones are
   rulings for phase 1 (Hard rules); count them for the report.
4. `get_component(component)` — the whole normative record: the registry row, every contract
   section, the closed §3 state matrix with each state's `consumptionState` and `undesigned`, the
   §4 prop rows, the §5 composition, **every open question with its `status`, `blocking`,
   `blocks`, `options` and — for closed ones — its `answer`**, the frozen `snapshot` (file, sha,
   capture date), every `figmaRefs` entry (node id, label, `isPrimary`, `snapshotStale`,
   `snapshotError`), each state's `versions[]`, and the `screens` that consume it.
4b. **An open build stop is part of the brief.** `get_component(component).buildRun.stop` on the
   same payload: when it is not null, the last build stopped on this contract, and its `reason`,
   `evidence` and `ownerNote` are part of this run's brief. Say in the report what the refresh
   changes for it. The stop ticks itself off when the contract meets it — never try to close it.
5. `get_previews(component)` — the prop bag each preview renders with, `propsAuthored` per
   preview, and any Figma URL the owner gave one; a preview whose props fall outside §4's sets is
   a deviation to report.
6. `requirement_inputs(component)` — the sections, the snapshot, the dependencies, the consuming
   screens and **every note oldest → newest across all three**, in one call so this run and
   `/d2m-component-update` cannot gather them two ways. `read_notes(target)` when you want one
   source alone.
7. `get_decisions()` — the D# register, for the rulings a question may already be answered by.
8. **Every question this contract's open questions cite.** A question that names another
   (`OQ-C-022-4`, `OQ-enrollment-home-3`) is judged against that question's status and answer:
   `get_component(<that row>)` for a component's, `get_screen(<that screen>)` for a screen's. Read
   them all before phase 2; a verdict that guesses at a cited ruling is worse than no verdict.
9. **The built view**, under `previewDir` — the file `build_status` names — and the fixture from
   step 5. Read the view in full. Note its state cases, its props and their types and defaults,
   its tokens, and every code comment that cites a note id or a question id: those comments are
   the build lane's own record of which default it took and why.

**Exit checklist 0:** project + era stated ✓ · built established (else stopped with the run named)
✓ · notes printed with id and status ✓ · contract read in full ✓ · fixture +
preview read in full ✓ · notes + decisions loaded, each note printed with its id ✓ · every cited
question's status and answer read ✓ · `buildRun.stop` read (its reason, evidence and owner note
in the brief, or none open) ✓

## 1. THE LEDGER — what has moved since the contract was written

Four columns, each compared against the contract's own text. Print the ledger before changing
anything; it is the reviewable artefact of this run.

| Column | Compare | A row in the ledger is |
|---|---|---|
| **Preview vs §2–§4** | the built view's states, geometry, tokens, props (names, types, defaults, option sets) against §2 Anatomy, §3 the matrix, §4 the props | each place they differ, with both values and — from the view's comments or a note — the ruling behind it, or **NONE** |
| **Rulings vs the text** | every note (per property, newest wins), every closed question's `answer`, every D# that names this row or its family, against the sections that still say the old thing | each sentence the ruling overtook, with the ruling's id |
| **Figma vs §1** | `figmaRefs` (which nodes, which is primary, which is `snapshotStale`, which errored) and `snapshot` (sha, date) against §1 Normative source | a ref §1 does not cite, a §1 node no ref holds, a snapshot re-frozen since the spec date, a stale ref |
| **Fixture vs §4** | each state's `fixtureProps` against the §4 rows: a prop the fixture sets that §4 lacks, a §4 prop the fixture never sets, a value outside §4's option set, a type that disagrees | each mismatch, with both sides |

A ledger row whose ruling is **NONE** is a deviation: it goes to the report (phase 5) and phase 3
mints a question for it (Hard rules) — never a contract change on its own. A ledger row with a
ruling is a contract change.

**A stale reference is a stop for that column, not for the run.** `snapshotStale: true` means the
picture no longer matches the node: say so, name the workbench's capture button on that reference
as the way to re-freeze it, and judge §1 on the ref's node id alone. Never describe artwork you
have not seen.

**Exit checklist 1:** four columns printed ✓ · every row carries both values ✓ · every preview
divergence carries its ruling or NONE ✓ · stale refs named, not described ✓

## 2. TRIAGE — every open question, one verdict each

Read every question with `status: open` (a `reference: true` row is another document's — note
it, never touch it). Give each exactly one verdict, with the evidence, and print the table before
writing anything. A verdict without evidence you can point at is **still open**.

| Verdict | The rule | Phase 3 does |
|---|---|---|
| **STALE** | the premise is no longer true *in the payload*: "no snapshot" and `snapshot` is set; "not buildable" and `built` is true; "state X is undesigned" and the matrix now designs X; "no Figma source" and a ref exists whose label or note says it is the component's set | close: `closedNote` = the field that refutes it, dated |
| **RULED ELSEWHERE** | a *closed* question on another row, a D#, or a note answers the same question, and this one says so or asks the identical thing (the raw-hex-bind family; the unify-two-sets family; a glyph-row consolidation) | close: `closedNote` = "answered by <id>: <its answer, quoted>" |
| **POINTER** | the question's own text hands the substance to another question that is still open ("what is left is wholly OQ-X"; "defers to OQ-X") and adds nothing of its own | close: `closedNote` = "carried by <id>", and make sure that question exists and is open |
| **CONSOLIDATE** | one of several copies of one program-wide question on several rows (a hit-target minimum asked on four rows; a type-scale question asked on three) | keep open; rewrite its text to cite every sibling, so one ruling can close them all; name the family in the report. **Never close a copy on another row** — this run owns one row |
| **VERIFY IN FIGMA** | the premise is a fact only the file holds — a binding, a hidden layer, a symbol name, whether a node is a component, a designer's intent | keep open; add the node id to its text if it lacks one; list it for the owner |
| **RATIFY** | the contract proposed a default and the build shipped it; nothing has ruled | keep open; give it `options` — the proposal as one complete sentence ("Ratify the proposed default — …") plus each real alternative — and `recommended` pointing at the proposal, so the owner answers with one click. Never close it |
| **STILL OPEN** | a real question with no proposal and no ruling | keep open; `options` only if the question already names concrete alternatives |

Two rules that bind the whole table:

- **A cited ruling is read, not remembered.** RULED ELSEWHERE quotes the cited question's
  `answer` as phase 0 step 8 read it. If the cited question is *open*, the verdict is POINTER or
  CONSOLIDATE, never RULED.
- **Blocking is not a verdict.** A `blocking: true` question gets the same rule as any other; what
  its blocking-ness changes is the report, which says in one line what unblocks the build.

**Exit checklist 2:** every open question has one verdict and its evidence ✓ · no RULED verdict
rests on an open citation ✓ · every RATIFY has options and a recommended index ✓ · reference
rows noted and untouched ✓

## 3. WRITE — the contract, in one edit

One `upsert_component(code, …)` call. Every field is partial, so pass only what changed — except
the lists, which are closed lists and are passed whole.

1. **Sections.** For each section the ledger's *ruled* rows overtook, the rewritten section text,
   with the change recorded where the program records changes: a **dated closed change list**
   in `changeList` ("2026-09-15 refresh — closed change list: (1) §3 md height 8 per build +
   OQ-C-057-8 ratified …; (2) …") and `respeccedAt` = the current full ISO datetime (never a bare date). Rewrite what a ruling changed;
   leave every other sentence as it was. A section the ledger did not touch is not passed.
2. **The state matrix.** `states` whole, in order. A state a ruling designed is no longer
   `undesigned`; a state the build added *with* a ruling behind it is added; a state nothing
   supports is not. Never remove a state (`removeStates` is deliberate and rare; a state's
   preview carries versions and threads and outlives the strike).
3. **Props.** `props` whole. Names, types, defaults and option sets to match the built signature
   *where a ruling supports the difference*; otherwise §4 stays and the difference is a deviation
   in the report.
4. **§1 and the references.** §1's text names every ref the row holds and which is primary;
   a re-frozen snapshot's date replaces the old one. The refs themselves are the intake's — this
   run does not add or supersede one.
5. **The questions.** `openQuestions` **whole, in the contract's order**, every row carrying its
   `code` and its `question` verbatim except:
   - STALE / RULED ELSEWHERE / POINTER → `status: "closed"`, `decidedBy: "refresh"`, `closedNote`
     as phase 2 says, dated;
   - CONSOLIDATE / VERIFY IN FIGMA → the amended `question` text;
   - RATIFY / STILL OPEN → `options` and `recommended` as phase 2 says.
   A question whose subject is a passage this run rewrote away is `superseded`, `closedNote`
   naming the section.
   A question the owner already closed is passed back exactly as read, so its answer is not
   disturbed. `blocking` and `blocksText` pass through unchanged.
6. **Deviation questions.** For every ledger row whose ruling is **NONE** (phase 1), mint a
   **new** `openQuestions` entry (Hard rules): `blocking: false`, options "Ratify what the build
   does — …" and "Keep the contract — the build is wrong", no `recommended` — the choice is the
   owner's. Skip a row that already has an open question covering it.
7. **The registry row.** `status` is not this run's to change. `consumedBy` only if the ledger's
   consuming-screens list disagrees with the cell.

Then `get_component(code)` again and check: `openCount` is what phase 2 predicted plus the
deviation questions step 6 minted; every closed question shows its note; `commands.build` is
present exactly when `openCount` is 0.

**Snapshot.** If the ledger found the snapshot re-frozen since the last design version,
`refresh_snapshot(target)` registers it per designed state (idempotent on the sha — `created: 0`
is the normal answer and not an error).

**Exit checklist 3:** one upsert ✓ · change list dated and closed ✓ · states and props passed
whole, nothing removed ✓ · every closed question carries `decidedBy: "refresh"` and its evidence ✓
· owner-closed questions untouched ✓ · every NONE-ruling ledger row has its deviation question,
`blocking: false`, no `recommended` ✓ · re-read matches the triage ✓

## 4. VERIFY — the preview still matches the contract it now has

No recapture — nothing in the preview changed. What can have changed is the *relationship*:

1. Walk the ledger's **preview vs §2–§4** rows once more against the rewritten contract. A row
   with a ruling is now closed: the contract says what the view does. A row with **NONE** is a
   deviation, and the contract (unchanged there) still disagrees with the view.
2. For each remaining deviation, name the deviation question phase 3 step 6 minted for it (its
   OQ id) — never say which way it should go; the Hard rule gives that question no `recommended`,
   because the choice is the owner's.
3. Confirm no note was left unapplied: every note id from phase 0 appears either in a change-list
   line or in a deviation row.

**Exit checklist 4:** every ledger row is either closed by the rewrite or listed as a deviation ✓
· each deviation names its minted question's OQ id ✓ · every note id accounted for ✓

## 5. REPORT

- **Project + era** — the scope line, first.
- **The ledger** — four columns, as printed in phase 1, with each row's outcome (adopted with
  ruling <id> / deviation).
- **What the contract now says that it did not** — the change list, line by line.
- **Questions closed** — id, verdict, the evidence, in a table the owner can spot-check in one
  pass.
- **Pending notes** — how many this run read as rulings, and the run that folds them in:
  `/d2m-notes-assimilate C-###`. None → say so.
- **Questions left, by verdict:**
  - **RATIFY** — the owner's action list: id, the proposal in one line, "one click in the
    Contract tab";
  - **VERIFY IN FIGMA** — id, node id, the fact to check;
  - **CONSOLIDATE** — the family, every sibling's id and row, and the one sentence a ruling
    would have to say;
  - **STILL OPEN** — id and what an answer needs to decide.
- **Deviations** — every place the build differs from the contract with no ruling, and the run
  for each.
- **The build lane** — `openCount` before and after; if it is still gated, the shortest path
  to zero (usually: the RATIFY list, clicked).
- **Consolidations found** — if two rows describe one component, the exact merge command for
  the owner: `/d2m-component-merge <keep> <duplicate>`. Never run it here.

**Exit checklist 5:** ledger handed over with outcomes ✓ · closed questions listed with evidence
✓ · the owner's ratify list is one-click-ready ✓ · deviations name their run ✓ · build-lane state
before/after stated ✓
