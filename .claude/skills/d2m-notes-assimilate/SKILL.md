---
name: d2m-notes-assimilate
description: Fold ONE target's PENDING notes into its contract (a component) or spec (a screen), then mark them assimilated. Reads the pending notes oldest → newest, applies "a later statement about the same property replaces an earlier one", rewrites only the sections, props, states and questions the notes touch, closes a question a note answers as the OWNER's ruling, mints a question for what a note raises but cannot settle, and marks each note it acted on. Never writes the preview lane, never marks a note it did not act on. (Copied by the workbench's Update contract button.) Designed to run in a FRESH session.
argument-hint: <C-### | screen-id> [--project <slug>] [--era <key>]  — e.g. C-064, home-dashboard
---

# Notes assimilate — $ARGUMENTS

Fold the pending notes on **$ARGUMENTS** into its document, then mark them assimilated. A note is
the owner saying what the contract should become; this run is where it becomes that, so that
nothing reading the contract — the build, a screen citing it, a person — is misled by a document
its owner has already overruled.

**Why this exists.** Notes used to be forever: normative build input that WON over the contract
and was never folded in, so intent piled up beside the document and `/d2m-component-update`
reported the growing drift as a list the owner cleared by re-speccing from scratch. Now a note is
`pending` until this run assimilates it; after that it is history and the contract says it.

**Arguments:** a component code or a screen id, required. `--project <slug>` / `--era <key>`
override the pinned scope; **pass them through to every tool call**, and state the project and era
you resolved in your first report line.

## Hard rules (re-read before EVERY phase)

- **Never write into the preview lane.** No file under `previewDir`, no `put_fixture`, no
  `capture`.
- **Never mark a note you did not act on.** A note you could not read as a requirement, or that is
  about a different target, STAYS pending and is named in the report with why — a fully
  superseded note counts as acted on: its later note carried it.
- **Never edit a section no note touches; never answer a question no note answers.** The plan in
  phase 1 is the whole allowed diff.
- **The owner wrote the note, so a question a note answers closes as the owner's.** `decidedBy:
  "owner"`, `closedNote` quoting the note id and the answer. This is the one run that may write
  `"owner"`, because the owner did.
- **A note that contradicts the build still goes in.** The contract is the owner's intent. Say
  in the report that `/d2m-component-update` is now due.
- **Tools describe themselves; d2m's code does not.** Never read d2m's source, your transcripts, or
  another SKILL.md to learn a tool. If a tool cannot do what this says, report it and continue.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. LOAD

1. `project_info()` — state the project slug and era key first.
2. `get_component(component)` or `get_screen(screen)` — the whole document: every section with its
   anchor, the §3 matrix, the §4 prop rows, every open question with its status and options.
3. `read_notes(target)` — take the PENDING ones only, and read them OLDEST → NEWEST (the payload
   lists newest first; reverse it). **None pending → print "nothing pending on <target>" and
   stop.** That is a complete answer, not a failure.
4. For each anchored note (`anchor` present): print the section and the quote, and whether
   `anchor.found` is true. A note whose passage is gone is still a requirement — apply it to the
   section it names, and say the passage moved.

**Exit checklist 0:** project + era stated ✓ · document read in full ✓ · pending notes listed
oldest → newest with ids ✓ · anchors printed with found/not ✓ · stopped cleanly if none ✓

## 1. READ — the plan

Read each note as statements about **named properties** (geometry, colour, state, prop,
behaviour, copy, interaction). A later statement about the same property replaces an earlier one
— per property; the rest of the older note stands. Then print the plan, per note:

- the sections it changes (by anchor), with the passage before and after;
- the prop rows, states or matrix cells it changes;
- the open question it ANSWERS (quote the answer), if any;
- the question it RAISES (what the contract cannot settle from the note), if any;
- `SUPERSEDED by <note id>`, if a later note replaces EVERY statement in this one (per-property
  supersession leaving nothing of the older note to apply). It changed nothing on its own — the
  later note carries its intent — but it still counts as acted on;
- `CANNOT ACT` with why, if it is not a requirement on this target.

**The plan is the reviewable artefact.** Print it before writing anything.

**Exit checklist 1:** every pending note has a plan line ✓ · supersession named per property ✓ ·
a fully SUPERSEDED note names the note id that carries it ✓ · CANNOT ACT notes named with why ✓

## 2. WRITE

`upsert_component(code, …)` or `upsert_screen(id, …)` with ONLY what the plan says: the touched
`sections` (whole body per anchor — read it, change the passage, write it back), the touched props
or states — and, if any question closes or is minted, `openQuestions` **WHOLE, in the contract's
order**, the same rule `/d2m-component-refresh` states. The write numbers the list it is handed
(`ordinal` = position in the list), so a PARTIAL list re-numbers the untouched questions over the
rows it left out. Every row is passed back carrying its `code` and `question` verbatim; only the
rows the plan closes change (`status: "closed"`, `decidedBy: "owner"`, `closedNote` quoting the
note id and the answer), and the minted ones are appended at the end. A question a note ANSWERS is
CLOSED, not minted — omitting `code` mints a new question instead of closing the one the note
answered, which leaves the original open and adds a phantom closed row. A question a note RAISES
is minted fresh (`status: "open"`, with `options` as complete sentences the owner can click). A
question the owner already closed is passed back exactly as read. No question closes or is
minted → do not pass `openQuestions` at all. Untouched sections are not restated.

**Exit checklist 2:** one write, only the planned changes ✓ · `openQuestions` passed whole and in
order, or not at all ✓ · every untouched question passed back verbatim with its code ✓ · closed
questions carry their existing code ✓ · closed questions carry the note id ✓ · minted questions
carry options and come last ✓ · nothing written to the preview lane ✓

## 3. MARK

`assimilate_notes(target, ids, summary)` with the ids of every note phase 2 acted on and a summary
that says, per note, what it became. A fully SUPERSEDED note IS passed — the later note carried
its intent, which is what phase 2 acted on — with the summary saying which id superseded it. A
409 means the write did not land — go back to phase 2, do not retry the mark. A **400** means an
id is not a PENDING note of this target — it belongs to another document, or another run already
assimilated it: drop that id, name it in the report with the reason, and mark the rest; do not
retry with it. CANNOT ACT notes are not passed.

**Exit checklist 3:** every acted-on note marked ✓ · every SUPERSEDED note is marked with the id
that carried it named in the summary ✓ · no CANNOT ACT note marked ✓ · any 400-refused id dropped
and reported, not retried ✓ · summary names each note ✓

## 4. REPORT

- **Project + era.**
- **Per note → what changed**, with the section anchors.
- **Questions closed / minted.**
- **Build update due?** — yes if a change touches what the built preview renders (component only):
  `/d2m-component-update C-###`.
- **Collisions.** Any note whose statement contradicts a passage the owner hand-edited AFTER the
  note was written (the section's text at phase 0 already differed from what the note reads as
  before-text, or the note's anchor was no longer found). The note still won — this run applied
  it — but the owner made both changes and must see both to decide which stands.
- **Left pending**, each with why — CANNOT ACT, or refused by the mark with 400.

**Exit checklist 4:** changes listed per note ✓ · questions listed ✓ · update verdict given ✓ ·
collisions with later hand edits named ✓ · pending remainder named ✓
