---
description: Retire a UI 2.0 registry row that should never have existed or is no longer designed — `/ui2-component-delete <C-###> [reason]`. Strikes the row WITHOUT reusing its ID, removes its build artifacts, and reports every consumer it had. Refuses while any screen or component still renders it, because delete has no keeper to absorb anything. (Copied by the /components 2.0 UI's Prompt ▸ Delete dialog.)
argument-hint: <C-###> [reason]  — e.g. C-054 "orphaned by the study-program-home re-spec"
---

# UI 2.0 component delete — $ARGUMENTS

Retire the registry row named in `$ARGUMENTS`. The first token is the `C-###`; everything after
it is the **reason**, which is written into the row and is not optional in spirit — a struck row
with no stated reason is indistinguishable from a mistake.

**Read `docs/ui2/design-system/registry.md`'s rules header before moving anything.** The
append-only ID rule is the constraint this command works under, and D6 is why the row existed.

## Delete vs. merge — pick the right one

| | `/ui2-component-merge` | **this command** |
|---|---|---|
| There is a keeper | yes — it absorbs states, props, OQs | **no** |
| Consumers | repointed to the keeper | **must already be zero** |
| The design | still rendered, by another row | **rendered by nothing** |

**If anything still renders this component, you want merge, not delete.** Delete has nowhere to
put the design, so a row with a live consumer cannot be deleted without silently dropping what
that consumer draws. §1 enforces this.

Three things are never removed — identical to merge, for identical reasons:

- **The ID.** `C-###` is append-only and never reused. The row stays, struck through, dated.
- **The history.** `Comparison`, `Version`, `Screenshot` and `Comment` rows are never deleted.
- **The evidence.** Frozen snapshots and exported artwork under `components/assets/` stay on
  disk. They are the record of what was once designed, and they cost nothing.

**Figma is untouched.** Deleting a registry row says *this program does not use this component*,
not *this component should be removed from the design file*.

## 0. Resolve the row

```bash
grep -n "^| C-### " docs/ui2/design-system/registry.md
ls docs/ui2/design-system/components/C-###-*.md
curl -s "localhost:5951/api/ui2/detail?id=C-###"
```

Stop, and say which, if any:

- **No such row** in `registry.md`.
- **Already `removed`** — its Status cell says so. Say when and why, and stop.
- **No reason given** in `$ARGUMENTS`. Ask for one rather than inventing it; the reason is the
  row's epitaph and the next reader has nothing else.

Print the row's name, status, Figma ref, "Defined in", "Consumed by", state count, and whether
it is built.

**Exit checklist 0:** row resolved ✓ · not already removed ✓ · reason present ✓

## 1. PROVE it is unconsumed — the gate

```bash
grep -rn "C-###" docs/ui2/ iphone/MakeReady/UI2Preview/ capture/fixtures/ui2/ iphone/MakeReadyCaptureTests/
grep -c '"C-###"' docs/ui2/screens/assets/*.elements.json
```

Classify **every** hit as one of:

- **Live consumer** — a screen spec's §2/§4 renders it, another contract's §5 *Consumes* it, or
  an element-map box refs it. **Any of these and the delete STOPS.**
- **Historical citation** — an OQ, a deviation, a dated change list, a `tokens.md` observation.
  These stay, and are repointed only in the sense of §3's annotation.
- **Its own contract / artifacts** — handled by §2 and §4.

**If there is a live consumer, stop and report it.** Say what still renders the row and offer
the two real options: `/ui2-component-merge <keeper> C-###` if another row should absorb it, or
a screen re-spec (`/ui2-screen <screen>`) if the consumer should stop rendering it. **This is a
success, not a failure** — it is the whole reason the gate exists.

**A row is also un-deletable while its design is still in Figma AND a screen spec is pending
against it.** Say so; that is an owner call, not a mechanical one.

**Exit checklist 1:** every hit classified ✓ · zero live consumers, or STOPPED with them named ✓
· element-map boxes counted ✓

## 2. The contract

- **Its own file** (`components/C-###-*.md`) → **keep it, and head it with a dated retirement
  note** saying the row is struck, why, and that nothing renders it. Do not delete the file: it
  is the written record of a design decision, and `registry.md`'s Defined-in still points at it.
- **A §4 subsection in a screen spec** → replace with a one-line pointer saying the row was
  retired and when. Do not delete the prose; the screen's own history needs it.
- **Notes** (`components/notes/C-###.md`) → **keep, untouched.** Notes are owner intent
  (`ui2-notes.mjs`); a retired row's notes are still what the owner said.

**Exit checklist 2:** contract kept and headed with the retirement note ✓ · screen §4 left as a
pointer ✓ · notes untouched ✓

## 3. ANNOTATE the historical citations

Every OQ, deviation and `tokens.md` observation naming this row stays, but a reader must not be
left thinking the row is live. Add `~~C-###~~` strikethrough plus a dated "retired" clause at
each site. In particular:

- **`tokens.md`** — a token whose *only* observation source was this row is now evidenced by
  nothing. **Say so at the token row.** Do not delete the token: it may still be correct, and
  that is a separate ruling. Flag it for the owner in the report.
- **Other contracts' §6** — an OQ that turns on this row's existence is usually answered by the
  deletion. Mark it closed, with the date and this command.

**Exit checklist 3:** every historical citation struck and dated ✓ · tokens left standing but
orphan-sourced ones flagged ✓ · OQs that the deletion answers marked closed ✓

## 4. Remove the build artifacts

Only if the row is **built** (`capture/fixtures/ui2/C-###.json` exists). Unlike merge, nothing
absorbs these — they are removed outright, because they render a component the program no longer
has:

1. **Delete the fixture** `capture/fixtures/ui2/C-###.json`. Fixture presence *is* built-ness
   (`preview-build.md` §6).
2. **Delete the view** `iphone/MakeReady/UI2Preview/<Name>.swift`, then
   `ruby iphone/scripts/ui2-preview-sync.rb` so target membership follows.
   ⚠️ **First check nothing else imports it** — a preview view can be composed by another
   (C-025 builds C-071 inline). If it is, that is a **live consumer** and §1 should have caught
   it; go back.
3. **Remove its `case "component.ui2.C-###"`** from `ViewRegistry.swift`.
4. **Leave `CaptureComponent` fields alone.** They are additive optionals and another contract
   may read one (`preview-build.md` §3 rule 3). Removing a field is how you silently break a
   different component. Re-comment any field this row solely owned to say it is now unused.
5. **SwiftLint + sync** to prove the target still builds. There is nothing to recapture.

**Exit checklist 4:** built-ness stated ✓ · fixture, view and registry case removed ✓ · no
`CaptureComponent` field removed ✓ · SwiftLint clean and target synced ✓

## 5. STRIKE — the registry, last

Edited last, so a failure earlier never leaves a struck row with live artifacts. C-041's row is
the shape; the only difference is that there is no keeper to point at:

- **Name cell** → `~~Name~~` *(no arrow — nothing absorbed it)*
- **Status cell** → `~~<status>~~ **removed**`. ⚠️ **This cell is the mechanism:**
  `capture/lib/ui2-index.mjs` drops any row whose status matches `/removed/i`. Nothing else
  takes it out of the browser, the tree or the counts.
- **Variants cell** → `**REMOVED <date> (owner): <the reason from $ARGUMENTS>.** Its ID is kept
  and struck through per the append-only rule. Nothing renders it: <N> historical citation(s)
  annotated, <N> element-map box(es), build artifacts <removed | never existed>.`
- **Defined in** → unchanged if the contract file was kept (§2); it is still where the record
  lives.
- **Consumed by** → `*(none — retired <date>)*`.

**Exit checklist 5:** Status cell contains `removed` ✓ · ID struck, not deleted ✓ · reason
recorded verbatim ✓ · registry edited after everything else ✓

## 6. The database — leave it alone

The row's `Comparison` `ui2-c-###`, its `Version`s, `Screenshot`s and `Comment`s **stay**, for
merge's reasons: they cannot be regenerated, and the strike in §5 already hides the row. Report
the counts:

```bash
node --input-type=module -e '
import { PrismaClient } from "@prisma/client";
const p = new PrismaClient();
const id = "ui2-c-###";
console.log(id,
  "| versions:", await p.version.count({ where: { comparisonId: id } }),
  "| comments:", await p.comment.count({ where: { comparisonId: id } }),
  "| unresolved:", await p.comment.count({ where: { comparisonId: id, resolved: false } }));
await p.$disconnect();
'
```

**Unresolved comments on a row nobody will look at again are the real cost of a delete.** Read
them and say what happens to each: answered by the retirement, or a live question the deletion
does not address — in which case it belongs on whatever row inherits the concern, or the delete
is premature.

**Exit checklist 6:** DB untouched ✓ · counts reported ✓ · every unresolved comment accounted
for ✓

## 7. VERIFY and report

```bash
curl -s "localhost:5951/api/ui2/tree" | grep -c "C-###"     # expect: 0
grep -rn "C-###" docs/ui2/ iphone/ capture/ | grep -v "~~"   # expect: only registry.md + the kept contract
ls capture/fixtures/ui2/C-###.json                           # expect: no such file (if it was built)
cd iphone && swiftlint lint --quiet --baseline .swiftlint-baseline.json
```

**Report:**
- **the gate result** — zero live consumers, and what each historical citation was;
- **the reason**, as recorded in the row;
- **what was kept** — contract file, notes, snapshots, DB history;
- **what was removed** — fixture, view, registry case, or "never built";
- **tokens left orphan-sourced** by the deletion, flagged for the owner;
- **OQs the deletion closes**, on this row and on others;
- **the DB** — parked counts and the fate of every unresolved comment;
- **the registry row's new text**;
- **anything you did NOT do**, and why.

**Exit checklist 7:** tree no longer lists it ✓ · no live reference remains ✓ · SwiftLint clean ✓
· report covers all nine points ✓

## Rules

- **Refuse while anything still renders it.** §1 is the whole point of this command.
- **Never reuse or delete a `C-###`.** Struck through, never gone.
- **Never delete a Version, Comment, Screenshot, note, snapshot or contract file.**
- **Never remove a `CaptureComponent` field.**
- **A reason is required.** The row's Variants cell carries it verbatim.
- Docs + build artifacts only: `docs/ui2/`, `iphone/MakeReady/UI2Preview/`,
  `capture/fixtures/ui2/`, and `ViewRegistry.swift`. Never `client/`, never Figma.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
