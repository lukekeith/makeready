---
name: d2m-component-delete
description: Retire a registry row that should never have existed or is no longer designed — `/d2m-component-delete <C-###> [reason]`. Strikes the row WITHOUT reusing its ID, removes its build artifacts, and reports every consumer it had. Refuses while any screen or component still renders it, because delete has no keeper to absorb anything. (Copied by the workbench's Prompt ▸ Delete dialog.)
argument-hint: <C-###> [reason] [--project <slug>] [--era <key>]  — e.g. C-054 "orphaned by the study-program-home re-spec"
---

# Component delete — $ARGUMENTS

Retire the registry row named in `$ARGUMENTS`. The first token is the `C-###`; everything after
it (minus the scope flags) is the **reason**, which is written into the row and is not optional
in spirit — a struck row with no stated reason is indistinguishable from a mistake.

`--project <slug>` / `--era <key>` override the pinned scope, and the copied command always
carries them. **Pass them through to every tool call**, and **state the project and era you
resolved in your first report line.**

**Read `get_registry_rules()` before moving anything.** The append-only ID rule is the constraint
this skill works under, and "one row per component" is why the row existed.

## Delete vs. merge — pick the right one

| | `/d2m-component-merge` | **this skill** |
|---|---|---|
| There is a keeper | yes — it absorbs states, props, OQs | **no** |
| Consumers | repointed to the keeper | **must already be zero** |
| The design | still rendered, by another row | **rendered by nothing** |

**If anything still renders this component, you want merge, not delete.** Delete has nowhere to
put the design, so a row with a live consumer cannot be deleted without silently dropping what
that consumer draws. §1 enforces this.

Three things are never removed — identical to merge, for identical reasons:

- **The ID.** `C-###` is append-only and never reused. The row stays, struck through, dated, and
  still resolvable, so no old link 404s.
- **The history.** Subjects, versions, renders and comments are never deleted. d2m never
  hard-deletes anything.
- **The evidence.** Frozen snapshots and exported artwork stay in d2m's storage. They are the
  record of what was once designed, and they cost nothing.

**Figma is untouched.** Deleting a registry row says *this project does not use this component*,
not *this component should be removed from the design file*.

## 0. Resolve the row

`get_component(code)` and `build_status(code)`.

Stop, and say which, if any:

- **No such row** in this project and era.
- **Already removed** — say when and why, and stop.
- **No reason given** in `$ARGUMENTS`. Ask for one rather than inventing it; the reason is the
  row's epitaph and the next reader has nothing else.

Print the row's name, status, Figma ref, "Defined in", "Consumed by", state count, and whether it
is built.

**Exit checklist 0:** project + era stated ✓ · row resolved ✓ · not already removed ✓ · reason
present ✓

## 1. PROVE it is unconsumed — the gate

Enumerate every reference. The structural ones are edges in d2m, so they are a query, not a text
hunt:

- `get_component(code)` → its consuming **screens** (with frames and instance counts) and its
  composition edges in both directions;
- `get_screen(id)` for each screen the registry names → §2 prose, the §4 closed list, and the
  element map's boxes for this ref;
- `list_components()` + `get_component` for any row whose §5 *Consumes* names it;
- `get_tokens()` for a token whose only observation source is this row;
- the project repo, for a preview view that composes this one (phase 4 step 2).

Classify **every** hit as one of:

- **Live consumer** — a screen spec's §2/§4 renders it, another contract's §5 *Consumes* it, or
  an element-map box refs it. **Any of these and the delete STOPS.**
- **Historical citation** — an OQ, a deviation, a dated change list, a token observation. These
  stay, and are annotated per §3.
- **Its own contract / artifacts** — handled by §2 and §4.

**What has no tool: free-text search.** A citation that lives only in prose is not an edge and
nothing indexes it. The enumeration above is exhaustive for *structural* references; for prose,
read the sections you fetched and say in the report that prose citations were checked by reading,
not by search. Where that leaves you unsure, prefer stopping: a delete is cheap to postpone.

**If there is a live consumer, stop and report it.** Say what still renders the row and offer the
two real options: `/d2m-component-merge <keeper> C-###` if another row should absorb it, or a
screen re-spec (`/d2m-screen <screen>`) if the consumer should stop rendering it. **This is a
success, not a failure** — it is the whole reason the gate exists.

**A row is also un-deletable while its design is still in Figma AND a screen spec is pending
against it.** Say so; that is an owner call, not a mechanical one.

**Exit checklist 1:** every hit classified ✓ · zero live consumers, or STOPPED with them named ✓ ·
element-map boxes counted ✓ · prose checked by reading and said so ✓

## 2. The contract

- **Its own contract** → **keep it, and head it with a dated retirement note** (`upsert_component`)
  saying the row is struck, why, and that nothing renders it. Do not empty it: it is the written
  record of a design decision, and the registry's "Defined in" still points at it.
- **A §4 subsection in a screen spec** → `upsert_screen` replacing it with a one-line pointer
  saying the row was retired and when. Do not delete the prose; the screen's own history needs it.
- **Notes** → **keep, untouched.** Notes are owner intent; a retired row's notes are still what
  the owner said. There is no tool that removes one, and that is deliberate.

**Exit checklist 2:** contract kept and headed with the retirement note ✓ · screen §4 left as a
pointer ✓ · notes untouched ✓

## 3. ANNOTATE the historical citations

Every OQ, deviation and token observation naming this row stays, but a reader must not be left
thinking the row is live. Add a strikethrough plus a dated "retired" clause at each site
(`upsert_component` / `upsert_screen` / `upsert_tokens` as appropriate). In particular:

- **Tokens** — a token whose *only* observation source was this row is now evidenced by nothing.
  **Say so at the token row.** Do not remove the token: it may still be correct, and that is a
  separate ruling. Flag it for the owner in the report.
- **Other contracts' §6** — an OQ that turns on this row's existence is usually answered by the
  deletion. Mark it closed, with the date and this skill.

**Exit checklist 3:** every historical citation struck and dated ✓ · tokens left standing but
orphan-sourced ones flagged ✓ · OQs that the deletion answers marked closed ✓

## 4. Remove the build artifacts

Only if the row is **built**. Unlike merge, nothing absorbs these — they go, because they render
a component the project no longer has. If `captureAdapter` is `noop` there is no render lane and
no code to remove beyond whatever a previous lane left: say so and check anyway.

1. **The fixture** goes with the row — fixture presence *is* built-ness, and `delete_component`
   (§5) retires it. If anything survives, report it rather than working around it.
2. **The view** under `project.previewDir` → delete the file, then run `project.targetSyncCmd` so
   target membership follows.
   ⚠️ **First check nothing else imports it** — a preview view can be composed by another. If it
   is, that is a **live consumer** and §1 should have caught it; go back.
3. **Remove its case** from `project.registryCasePath`.
4. **Leave the decoding struct's fields alone.** They are additive optionals and another contract
   may read one. Removing a field is how you silently break a different component. Re-comment any
   field this row solely owned to say it is now unused.
5. **Lint and sync** (`project.lintCmd`, `project.targetSyncCmd`) to prove the target still
   builds. There is nothing to recapture.
6. `record_build_artifacts(component: <code>, previewPath/tokensPath/registryCasePath/otherPaths)` — record the removal, so the repo's record of what this
   row owned matches what is now there.

**Exit checklist 4:** built-ness stated ✓ · fixture, view and case removed ✓ · no decoding field
removed ✓ · lint clean and target synced ✓

## 5. STRIKE — the registry, last

Changed last, so a failure earlier never leaves a struck row with live artifacts:

```
delete_component(component: "C-###", reason: "<the reason from $ARGUMENTS>")
```

Write the reason in the shape the canonical retirement used — it is rendered on the struck row,
so write it for the next reader:

> **REMOVED <date> (owner): <the reason, verbatim>.** Its ID is kept and struck through per the
> append-only rule. Nothing renders it: <N> historical citation(s) annotated, <N> element-map
> box(es), <N> drawing(s) unlinked (their rects stay on <M> image(s), confirmed and no longer
> linked to a row), build artifacts <removed | never existed>.

⚠️ **The tool is the mechanism.** `delete_component` sets the removal stamp and note, which is
what strikes the row through in the tree, takes it out of the counts, and keeps its id
resolvable by `get_component` — so every link made before the strike keeps working, and the
code is never reissued. Nothing else does that, and writing "removed" into prose does none of
it. "Defined
in" stays pointing at the kept contract (§2) — that is still where the record lives — and
"Consumed by" reads as retired, with the date.

`delete_component`'s reply carries `drawings: { unlinked, assets }` — the drawings that
identified this row on screenshots. They are NOT deleted: each keeps its box and its
`confirmed` status with no row, so the user can re-link it in the Drawings tab; the element maps
of those images are re-projected without it. Use the reply's numbers in the note above and the
report below.

**Exit checklist 5:** row struck through `delete_component` ✓ · ID kept, not reused ✓ · reason
recorded verbatim ✓ · registry changed after everything else ✓

## 6. The history — leave it alone

The row's subject, its versions, renders and comments **stay**, for merge's reasons: they cannot
be regenerated, and the strike in §5 already hides the row. Report the counts —
`list_unresolved_comments` scoped to the row, and the version count from the per-state
`versions[]` on `get_component(code)`.

**Unresolved comments on a row nobody will look at again are the real cost of a delete.**
`get_comment` each one and say what happens to it: answered by the retirement (`reply_comment`,
then `resolve_comment`), or a live question the deletion does not address — in which case it
belongs on whatever row inherits the concern, or the delete is premature.

**Exit checklist 6:** history untouched ✓ · counts reported ✓ · every unresolved comment accounted
for ✓

## 7. VERIFY and report

- `list_components()` — the row no longer appears among the live rows, and the counts dropped by
  one.
- `get_component(code)` — still resolvable, struck, with its reason. That is the correct outcome.
- The project repo — no view, no case, no fixture file for this row; `project.lintCmd` clean.

**Report:**
- **project + era** — the scope line, first;
- **the gate result** — zero live consumers, and what each historical citation was;
- **the reason**, as recorded in the row;
- **what was kept** — contract, notes, snapshots, history;
- **what was removed** — fixture, view, case, or "never built";
- **drawings unlinked** — the count and the images, from the tool's reply;
- **tokens left orphan-sourced** by the deletion, flagged for the owner;
- **OQs the deletion closes**, on this row and on others;
- **the history** — parked counts and the fate of every unresolved comment;
- **the registry row as it now reads**;
- **anything you did NOT do**, and why.

**Exit checklist 7:** the tree no longer lists it ✓ · no live reference remains ✓ · lint clean ✓ ·
report covers all eleven points ✓

## Rules

- **Refuse while anything still renders it.** §1 is the whole point of this skill.
- **Never reuse a `C-###`.** Struck through, never gone, never reissued.
- **Never delete a version, comment, render, note, snapshot or contract.**
- **Never remove a decoding field.**
- **A reason is required.** The row carries it verbatim.
- Spec content through the tools, code only under `project.previewDir` and
  `project.registryCasePath`. Never another part of the project repo, never Figma.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
