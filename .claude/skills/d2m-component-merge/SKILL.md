---
name: d2m-component-merge
description: Merge a duplicate registry row into the row that survives — `/d2m-component-merge <keep> <duplicate>`. Absorbs the duplicate's designed states into the keeper's contract, repoints every consumer, screen spec, element map and build artifact, then strikes the duplicate's row WITHOUT reusing its ID — and goes on, in the same session, to re-spec the keeper (and rebuild it, when it was already built) so the merged row is read against its design and the rulebook. Destructive by nature: the command is the owner's ruling that the duplicate goes, so it never declines — it reads both contracts to decide the SHAPE of the merge (state-for-state, or an absorbing axis it asks the owner to name), asks what only the owner can answer, and never deletes history. (Copied by the workbench's Prompt ▸ Merge dialog.)
argument-hint: <keep C-###> <duplicate C-###> [--project <slug>] [--era <key>]  — e.g. C-062 C-073
---

# Component merge — $ARGUMENTS

Merge the **duplicate** registry row into the **keeper**, so the project has one row for one
component again. `$ARGUMENTS` is `<keep> <duplicate>`, in that order — **the first id survives,
the second is struck through.** Getting them backwards deletes the wrong row's identity, which is
why the workbench's Merge dialog makes you pick a side explicitly.

`--project <slug>` / `--era <key>` override the pinned scope, and the copied command always
carries them. **Pass them through to every tool call**, and **state the project and era you
resolved in your first report line** — a merge run against the wrong era is unrecoverable
attention, even though nothing is deleted.

**Read `get_registry_rules()` and BOTH contracts before moving anything.** One row per component
is why this skill exists; the append-only ID rule is the constraint it works under. Ids are
allocated by an atomic counter, never by `max+1` over the live rows — which is exactly why a
struck row's id is safe to leave struck.

## What a merge is, and is not

**It is** a registry-and-contract operation: the keeper's contract absorbs whatever the duplicate
designed, every reference in the project is repointed, and the duplicate's row stops being
listed. **It is not** a delete. Three things are never removed:

- **The ID.** `C-###` is append-only and never reused. The duplicate's row stays, struck through,
  with a dated note saying where it went.
- **The history.** Versions, renders and comments are the one artifact that cannot be
  regenerated. Nothing in d2m is ever hard-deleted, and this run deletes none of it. See §6.
- **The evidence.** The duplicate's frozen snapshot and exported artwork stay in d2m's storage —
  they are the record of what the duplicate designed before it was absorbed.

**Figma is untouched.** A merge is a decision about *this project's* registry, not about the
design file. If Figma still has two components, §7 says so and raises the OQ.

## 0. Resolve both rows

Split `$ARGUMENTS` into `<keep>` and `<duplicate>`. Both are required and both must be `C-###`.
Then, for each: `get_component(code)` and `build_status(code)`.

Stop, and say which, if any of these hold:

- **Same id twice** — nothing to merge.
- **Either row is missing** from the registry.
- **The duplicate is already removed** — it has been merged before. Say where it went and stop.
- **The KEEPER is removed** — you are about to merge a live row into a dead one. Almost certainly
  the arguments are backwards. Stop and say so.
- **The keeper has no contract and the duplicate does.** Merging would destroy the only written
  contract. Stop and point at `/d2m-component <keep>`, or at re-running with the arguments
  swapped.

Print both rows' name, status, Figma ref, "Defined in", "Consumed by", state count, and whether
each is **built**.

**Exit checklist 0:** project + era stated ✓ · both ids resolved to real rows ✓ · neither already
removed ✓ · keeper has a contract ✓ · built-ness of each known ✓

## 1. DECIDE how they merge

**The command is the ruling.** The owner ran `<keep> <duplicate>` on purpose: the duplicate is
going, and everything it designed is landing on the keeper (Luke, 2026-09-21: *"the duplicate
should never remain"*). This phase never decides WHETHER — that was decided by typing the
command — only HOW. Read both contracts' §2 and §3 and produce a **difference table**, because
the shape of the merge follows from it:

| | keep | duplicate |
|---|---|---|
| Anatomy | | |
| Size | | |
| Type | | |
| Colour / tokens | | |
| Designed states | | |
| Props | | |
| Figma source | | |

Then classify, and say which you concluded:

- **True duplicate** — same anatomy, same role, two rows by accident. Merge absorbs the duplicate
  wholesale.
- **Overlapping siblings** — one is a *variant* of the other: same role, different size, ground
  or state set. The merge is real, but the duplicate's form must survive **as an axis value on
  the keeper**. Say which axis, and name it per the registry's naming rules before you write it.
- **Distinct roles under one name** — the two differ in anatomy, parts and props with little
  overlap (a metric card and a day card, say). **Still a merge**, the widest kind of sibling
  merge: the absorbing axis selects the whole form (`kind: metric | day`), the duplicate's parts
  and props land on the keeper scoped to their kind, and the report says plainly that the
  keeper's props are now optional-by-kind and which rulebook rules that strains. Say so, ask
  the owner to name the axis, and proceed. **Never stop here** — a report saying "these are
  not duplicates" with nothing moved is the one outcome the owner has ruled out; if they have
  reconsidered, they cancel the run.

**When the two differ in a way the owner has to rule on** — which anatomy survives, what the
absorbing axis is called, whether the keeper's name still fits, whether a state is dropped
rather than carried — **ask in this run.** Parking it as an ordinary OQ ships a half-merge.

**How to ask the owner, always:** `await_answers(subject, questions: [{ question, options, recommended }])`
— every question this decision needs in ONE call, each with the answers it offers (your proposal
first) — then END YOUR TURN with one line naming what you filed. The questions land on the
document as real `OQ-…` rows; the owner answers them from the Contract tab or the terminal,
and this session is resumed with the answers by code — read them as rulings and continue from
where you paused. Never ask in prose: a prose question ends the run with nothing filed and
nothing to resume.

**Exit checklist 1:** both contracts read in full ✓ · difference table printed ✓ · classified as
true-duplicate / sibling / distinct-roles, and the merge's shape (the axis) named ✓ · owner
asked about anything material, and answered ✓ · nothing declined ✓

## 2. ABSORB — the keeper's contract

Everything the duplicate designed has to land in the keeper's contract, because after §5 the
duplicate's contract is no longer an anchor. One `upsert_component(keep, …)` carrying:

1. **§3 matrix** — every one of the duplicate's designed states becomes a row on the keeper,
   carrying its consumption status verbatim. A sibling merge adds the absorbing **axis** (§1); a
   true duplicate maps state-for-state. Supplying `states` is a partial write in one direction
   only: a state already on the keeper and missing from your array is **left in place** and
   reported as a warning, never dropped — read the warnings and answer each, and strike one
   deliberately with `removeStates` if that is genuinely what the merge decided.
   **⚠️ Never lose an existing state.** d2m keys versions and comments on a state's **id**, with
   the slug fixed at birth and the label free to change — so a relabel no longer silently re-keys
   a thread. Use the guard in §4 step 2 anyway: it is what turns "the tool warned me" into "I
   checked".
2. **§2** — the duplicate's geometry, for the states you just added. Tokens by name; a flagged
   literal stays flagged, with its flag text carried across.
3. **§1** — add the duplicate's Figma node(s) as a normative source of the keeper, and add a
   **deviation** recording the merge: that this row now spans two Figma components, and that the
   merge is a registry decision Figma has not made. Keep the duplicate's frozen snapshot
   citation; note if it covers only part of the row. The duplicate's **saved references** move
   too — `merge_components` (§5) repoints them onto the keeper, non-primary and labelled
   `from C-<dup>`, and regenerates the keeper's registry cell — so the re-spec in §8 reads the
   absorbed design from the keeper's own refs. Do not paste the node ids into `figmaRef` by
   hand; the cell follows the refs.
4. **§4** — the duplicate's props. A prop that means the same thing under a different name is the
   keeper's name; a prop with no counterpart is added, with its type and default.
5. **§5** — union of both rows' Consumes/Consumed-by.
6. **§6** — carry every open `OQ-C-<dup>-#` across as an OQ of the keeper, renumbered, with its
   original id in the text so the trail survives. **Add one OQ for the merge itself**: does Figma
   unify the two components, or does this row stay a two-source merge?
7. **Head the contract** with a dated closed change list saying what was absorbed and from where.
8. **Give each absorbed state its own picture.** The keeper's frozen snapshot is the keeper's
   set; the absorbed states' symbols are in the DUPLICATE's set, so "Re-read snapshot" would
   hand them the wrong picture (Luke, 2026-09-21: three `day · …` previews with no snapshot and
   a Re-read button that would have shown a metric card). The write above minted a preview per
   absorbed state; for each, `set_preview_figma(keep, <preview slug>, <the duplicate's symbol
   URL for that state>)` — the symbol, not the set — then `capture_preview_figma(keep, <slug>)`.
   An undesigned state has no symbol and gets neither. Read each capture's reply; report any
   that did not land, with the node id, so the owner can paste it.

**Exit checklist 2:** every designed state of the duplicate present on the keeper ✓ · no existing
state lost ✓ · props unioned ✓ · duplicate's OQs carried, not dropped ✓ · merge recorded as a §1
deviation + an OQ ✓ · each absorbed designed state's preview given its symbol and captured ✓

## 3. REPOINT — every reference in the project

**Divide this correctly or you will do it twice.** `merge_components` (§5) repoints the
*structural* references itself: the duplicate's composition edges, its element-map entries, its
note mentions and the screen roll-call entries that name it all move to the keeper when the row
is struck. What no tool can move is **prose** — a §2 sentence, a §4 subsection that WAS the
duplicate's contract, a deviation, a dated change list.

So this phase does two things: it **fixes the prose**, and it **counts what §5 is about to
move**, so the report can state it and §7 can verify it happened. d2m holds the structural
references as real edges, so the counting is an enumeration, not a text hunt:

- `get_component(dup)` → its **consuming screens** (with the frames and instance counts) and its
  **composition** edges in both directions;
- `get_screen(id)` for each of those screens → §2 prose, §4 closed list, and the element map;
- `list_components()` + `get_component` for any row whose §5 names the duplicate;
- `get_tokens()` for a token whose observation source names the duplicate;
- `read_notes("C-<dup>")`.

**What has no tool: free-text search.** A citation that lives only in prose — inside another
row's §6 OQ, a deviation sentence, a dated change list — is not an edge and nothing indexes it.
The enumeration above covers every *structural* reference exhaustively; for prose, read the
sections you fetched and say in the report that prose citations were checked by reading, not by
search.

**Count them all in the report** (a real merge moved 19 element-map boxes across 5 maps — a
number worth stating, because it is the part most easily missed), and handle each kind:

- **Screen spec prose** — `upsert_screen` for §2 prose and amendment blocks, and for a §4
  subsection that WAS the duplicate's contract, which becomes a pointer to the keeper. The §4
  **roll-call** itself is structural: §5 moves it, and re-supplying `components` here would
  replace the whole closed list, so do not.
- **Element maps** — count the boxes now (`get_screen` gives them per frame); §5 repoints them.
  Use `put_element_map` only for a frame whose geometry or per-instance `state` is genuinely
  wrong — and remember it REPLACES that frame's map, so send every entry, not just the moved
  ones.
- **Other contracts** — `upsert_component` for §5 Composition prose on both sides, and for any
  §6 OQ or deviation text citing the duplicate. Supplying `consumes` replaces the edge set: the
  edges that leave are struck, not deleted.
- **The keeper's Consumed-by prose** — union with the duplicate's (part of §2's write).
- **Notes** — the duplicate's note *mentions* are repointed by §5, but the notes themselves stay
  on the duplicate. Carry their content forward with `append_note("C-<keep>", …)` as a new note
  saying it came over on merge. **Never delete a note**; it is owner intent and it outranks the
  contract.
- **Tokens** — `upsert_tokens` for any observation-source attribution naming the duplicate. The
  token values do not change; the attribution does.

**Exit checklist 3:** every structural reference enumerated and counted, ready for §5 to move ✓ ·
prose citations read in the sections fetched, and said so ✓ · element-map boxes counted ✓ ·
duplicate's notes carried over, none deleted ✓ · screen §4 left as a pointer where it was the
contract ✓

## 4. MIGRATE — the build artifacts

Only if the duplicate is **built** (`build_status("C-<dup>")`). If it is not, say so and skip to
§5 — there is nothing to migrate. If the project's `captureAdapter` is `noop` there is no render
lane at all: repoint the code if the project has any, say the keeper cannot be recaptured, and do
not claim a verified render.

**And only the fold below if the KEEPER was built at §0.** An unbuilt keeper gets no view from a
merge (Luke, 2026-09-21: a merge into an unspecced-or-unbuilt row must not half-build it outside
`/d2m-component-build`). For an unbuilt keeper this phase is retirement only: remove the
duplicate's view file under `project.previewDir` and its case in `project.registryCasePath`
(decoding fields stay, re-commented — step 4 below), run `project.targetSyncCmd` and
`project.lintCmd`, let §5 retire the fixture, and say in the report that the keeper's view is
`/d2m-component-build C-<keep>`'s to write from the merged contract. Skip steps 1, 3, 6 and 7.

1. **Fixture** — `get_fixture("C-<keep>")`, then write the absorbed states' props with
   `put_fixture`. The state list itself follows the contract you wrote in §2; `put_fixture`
   writes props only and will not invent a state.
2. **Guard the keys** — snapshot the keeper's state labels and slugs from `get_fixture` **before**
   the §2 write, and after it confirm every one still resolves:

   > `DB KEY LOST: "<label>" — versions and comments would orphan`

   Stop on that rather than continuing; a lost state is a reshaped §3 matrix, which is a contract
   edit to redo, not something to patch downstream.
3. **View** — fold the duplicate's view into the keeper's under `project.previewDir`, driven by
   the absorbing axis. Delete the duplicate's file **only after** its behaviour is reachable
   through the keeper's props, then run `project.targetSyncCmd` so target membership follows.
4. **Capture case + decoding struct** — the duplicate's case in `project.registryCasePath` is
   removed and its props are served by the keeper's case. Decoding fields are **additive
   optionals and are never removed** — another contract may have come to rely on one. Leave them;
   re-comment them to name the keeper.
5. **The duplicate's fixture goes** — fixture presence *is* built-ness, so leaving it would keep
   claiming a row that no longer exists. `merge_components` (§5) retires the duplicate's fixture
   with its row; if anything is left behind, say so rather than working around it.
6. **Lint, sync, recapture the keeper** — `project.lintCmd`, then `capture("C-<keep>", "*")`, so
   the merged states have renders. Read the job log.
7. `record_build_artifacts(component: "C-<keep>", previewPath/tokensPath/registryCasePath/otherPaths)` — every file this run left in the project repo.

**Exit checklist 4:** duplicate's built-ness stated ✓ · keeper's fixture props written through
`put_fixture` ✓ · no state key lost ✓ · duplicate's view folded in and its case removed ✓ · lint
clean, target synced, keeper recaptured ✓

## 5. STRIKE — the registry, last

The registry is changed **last**, so a failure earlier never leaves a struck row with a
half-merged contract:

```
merge_components(keep: "C-<keep>", duplicate: "C-<dup>", reason: "<why they are the same>")
```

Write the reason in the shape the canonical merge used — it is rendered on the struck row, so
write it for the next reader:

> **REMOVED <date> (owner): <one line on why>.** Its ID is kept and struck through per the
> append-only rule; <N> consumer(s), <N> screen-spec reference(s), <N> element-map bounding
> box(es), <N> drawing(s) and <N> Figma reference(s) were repointed to C-<keep> the same run.

⚠️ **The tool is the mechanism, not decoration.** `merge_components` sets the duplicate's
removal stamp, its removal note and the link to the keeper — that is what strikes the row
through in the tree, excludes it from the counts, and keeps its id resolvable so no old link
404s — and in the same move it repoints the composition edges, element-map entries,
**drawings** (the reply's `drawings: { repointed, assets }`, with those images' maps
re-projected), **Figma references** (the reply's `figmaRefs`; non-primary on the keeper,
labelled `from C-<dup>`, the keeper's cell regenerated), note mentions and screen roll-call
entries §3 counted. Writing "removed" into
prose does none of that. **Nothing undoes it automatically either**, which is why §1 has to have settled the shape
and asked its questions before you get here. Never fake a strike by editing text — `upsert_component` refuses a
`removed` status and any `~~struck~~` name or status cell, because a row struck that way stays
live in every view, crossed out and unspecced (C-044 was struck by hand on 2026-09-10, before
this tool existed, and is listed that way until it is merged for real). And never call the tool "to tidy up"
a row you have not actually merged.

Then the keeper: its dated closed change list, its Figma ref gaining the duplicate's node, its
Consumed-by unioned, "Defined in" unchanged — all of that landed in §2's `upsert_component`.
Confirm it reads correctly now that the strike has happened.

**Exit checklist 5:** duplicate struck through `merge_components` with the reason ✓ · ID kept, not
deleted ✓ · keeper's row carries a dated change list ✓ · registry changed after everything else ✓

## 6. The history — leave it alone, and say why

The duplicate's subject, its versions, renders and comments **stay**. They are the only artifact
in this whole operation that cannot be regenerated from the spec, and a merged-away row's capture
history is still the record of what was once rendered and what people said about it. d2m never
hard-deletes; there is no tool here that would, and you should not go looking for one.

The strike in §5 already removes the row from the workbench, so the orphaned subject is invisible
without being destroyed. **Report the counts** — `list_unresolved_comments` scoped to the
duplicate, and the version count from `get_component("C-<dup>")`'s per-state `versions[]` — so
the owner knows what is parked.

**If the duplicate has UNRESOLVED comments, they are about to become unreachable.** `get_comment`
each one, and either answer it against the keeper (it may already be fixed by the merge) with
`reply_comment` + `resolve_comment`, or carry it forward as an OQ on the keeper's contract. Never
strike a row with live questions on it without saying what happened to them.

**Exit checklist 6:** history untouched ✓ · version/comment/unresolved counts reported ✓ ·
unresolved comments answered or carried forward ✓

## 7. VERIFY and report

- `list_components()` — the duplicate no longer appears among the live rows, and the counts
  dropped by one.
- `get_component("C-<dup>")` — still resolvable, struck, pointing at the keeper. That is the
  correct outcome, not a leftover.
- `read_notes("C-<keep>")` — the carried notes are present.
- `get_component("C-<keep>")` — its pre-existing state labels are byte-identical and the absorbed
  ones are present.

**Report:**
- **project + era** — the scope line, first;
- **the verdict from §1** — true duplicate, sibling, or distinct roles — the axis, and the difference table;
- **what was absorbed** — states, props, OQs, notes;
- **what was repointed** — counts per kind (screen specs, element-map boxes, drawings, Figma references, contracts, notes);
- **build artifacts** — migrated, or "the duplicate was never built";
- **the history** — counts parked under the orphaned subject, and what happened to any unresolved
  comments;
- **the registry** — both rows as they now read;
- **open questions** — including whether Figma should unify the two components;
- **anything you did NOT merge**, and why;
- **what follows** — which of §8's runs this session goes on to, from the keeper's state at §0,
  or "none — the keeper was unspecced".

**Exit checklist 7:** no live reference to the duplicate remains ✓ · the tree no longer lists it ✓
· keeper's pre-existing state labels unchanged ✓ · report covers all ten points ✓

## 8. THE RUNS THAT FOLLOW — in this session, by the keeper's state at §0

A merge leaves the keeper's contract absorbed but not re-read: its §5 parts are unioned by name
and not placed, the absorbed states have no place measured in any picture, and nothing has
re-read the design or the rulebook against the merged row. The owner asked for one command that
finishes the job (Luke, 2026-09-21), so this run goes on — **after §7's report is printed, in
this same session, sequentially, through the Skill tool** — according to what the keeper was
when this run started (§0's facts, not what §4 may have changed):

| keeper at §0 | then |
|---|---|
| **built** | `/d2m-component <keep> --project <slug> --era <key>`, then `/d2m-component-build <keep> --project <slug> --era <key>` |
| **specced, not built** | `/d2m-component <keep> --project <slug> --era <key>` |
| **unspecced** | nothing — the merge was the whole run |

Invoke each as the skill it is (`d2m-component`, then `d2m-component-build`), with the same
`--project` / `--era` this run resolved, and follow that skill **in full** — its own phases,
its own exit checklists, its own report, printed under this one. Do not summarise it, do not
skip its questions: the re-spec is where the absorbing axis meets the rulebook and where the
absorbed states get their §5 parts placed and their place in the set picture measured (its
step 2c), which is the point of running it. The build, when it runs, builds the contract the
re-spec just wrote, never the one §2 absorbed.

**Do not run the build for an unbuilt keeper** even if §4 retired a built duplicate's view —
that is the owner's call from the Details tab once the re-spec's questions are answered.

**Exit checklist 8:** the keeper's §0 state named and the matching row of the table followed ✓ ·
each follow-on skill run in full with its own report ✓ · no build for an unbuilt keeper ✓

## Rules

- **`<keep>` first, `<duplicate>` second.** The argument order is the whole safety model.
- **Never reuse a `C-###`.** Struck through, never gone, never reissued.
- **Never delete a version, comment or render.** §6.
- **Never delete a note.** Carry it to the keeper as a new note.
- **Never decline the merge.** The command is the owner's ruling; §1 decides the shape, asks
  what only the owner can answer, and goes on. The one way this run ends with the duplicate
  still live is a §0 refusal (a missing, already-struck or backwards row) or the owner
  cancelling it.
- Spec content through the tools, code only under `project.previewDir`, `project.tokensOutPath`
  and `project.registryCasePath`. Never another part of the project repo, never Figma, and
  **never d2m itself** — a tool that fails is REPORTED (the error, verbatim, and where the run
  stopped), not patched: on 2026-09-21 a run answered a `merge_components` failure by editing
  d2m's own repository mid-run, which reloaded the server under it and killed the run. d2m's
  source is the owner's to fix; end the run with the error and what remains to be done.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
