---
description: Merge a duplicate UI 2.0 registry row into the row that survives — `/ui2-component-merge <keep> <duplicate>`. Absorbs the duplicate's designed states into the keeper's contract, repoints every consumer, screen spec, element map and build artifact, then strikes the duplicate's row WITHOUT reusing its ID. Destructive by nature: it proves the two are duplicates before it moves anything, and never deletes history. (Copied by the /components 2.0 UI's Prompt ▸ Merge dialog.)
argument-hint: <keep C-###> <duplicate C-###>  — e.g. C-062 C-073
---

# UI 2.0 component merge — $ARGUMENTS

Merge the **duplicate** registry row into the **keeper**, so the program has one row for one
component again. `$ARGUMENTS` is `<keep> <duplicate>`, in that order — **the first id
survives, the second is struck through.** Getting them backwards deletes the wrong row's
identity, which is why the browser's Merge dialog makes you pick a side explicitly.

**Read `docs/ui2/design-system/registry.md`'s rules header and BOTH contracts before moving
anything.** D6 (one row per component) is why this command exists; the append-only ID rule is
the constraint it works under.

## What a merge is, and is not

**It is** a registry-and-contract operation: the keeper's contract absorbs whatever the
duplicate designed, every reference in the program is repointed, and the duplicate's row stops
being listed. **It is not** a delete. Three things are never removed:

- **The ID.** `C-###` is append-only and never reused (registry rule 1). The duplicate's row
  stays in `registry.md`, struck through, with a dated note saying where it went.
- **The history.** Versions, screenshots and comments in the capture DB are the one artifact
  that cannot be regenerated. This command **never** deletes a `Comparison`, `Version` or
  `Comment` row. See §6.
- **The evidence.** The duplicate's frozen snapshot and exported artwork under
  `components/assets/` stay on disk — they are what proved the two were the same thing.

**Figma is untouched.** A merge is a decision about *this program's* registry, not about the
design file. If Figma still has two components, §7 says so and raises the OQ.

## 0. Resolve both rows

Split `$ARGUMENTS` into `<keep>` and `<duplicate>`. Both are required and both must be
`C-###`. Then, for each:

```bash
grep -n "^| C-### " docs/ui2/design-system/registry.md
ls docs/ui2/design-system/components/C-###-*.md
curl -s "localhost:5951/api/ui2/detail?id=C-###"
```

Stop, and say which, if any of these hold:

- **Same id twice** — nothing to merge.
- **Either row is missing** from `registry.md`.
- **The duplicate is already `removed`** (its Status cell says so) — it has been merged
  before. Say where it went and stop.
- **The KEEPER is `removed`** — you are about to merge a live row into a dead one. Almost
  certainly the arguments are backwards. Stop and say so.
- **The keeper has no contract file** and the duplicate does. Merging would destroy the only
  written contract. Stop and point at `/ui2-component <keep>`, or at re-running with the
  arguments swapped.

Print both rows' name, status, Figma ref, "Defined in", "Consumed by", state count, and
whether each is **built** (`capture/fixtures/ui2/C-###.json` exists).

**Exit checklist 0:** both ids resolved to real rows ✓ · neither already removed ✓ · keeper has
a contract ✓ · built-ness of each known ✓

## 1. PROVE they are duplicates

**This is the phase that earns the rest.** "They look similar in the UI" is not a merge
warrant — C-022 and C-071 are both stacked two-line pairs and are NOT the same row. Read both
contracts' §2 and §3 and produce a **difference table**:

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

- **True duplicate** — same anatomy, same role, two rows by accident (C-041 DetailPair vs
  C-022 MetaPair, 2026-09-11). Merge absorbs the duplicate wholesale.
- **Overlapping siblings** — one is a *variant* of the other: same role, different size,
  ground or state set. The merge is real, but the duplicate's form must survive **as an axis
  value on the keeper** (how C-041's stacked anatomy became C-022's `layout=stacked`). Say
  which axis, and name it per registry rule 6 before you write it.
- **Not duplicates** — different roles that happen to share a shape. **Stop.** Report the
  difference table and say a merge would lose a real component. This is a legitimate outcome
  of this command and it is not a failure.

**When the two differ in a way the owner has to rule on** — which anatomy survives, what the
absorbing axis is called, whether a state is dropped rather than carried — **ask in this run**
(registry rule 6's last bullet). Parking it as an OQ ships a half-merge.

**Exit checklist 1:** both contracts read in full ✓ · difference table printed ✓ · classified
as true-duplicate / sibling / not-duplicates ✓ · owner asked about anything material ✓

## 2. ABSORB — the keeper's contract

Everything the duplicate designed has to land in the keeper's contract, because after §5 the
duplicate's contract is no longer an anchor.

1. **§3 matrix** — every one of the duplicate's designed states becomes a row on the keeper,
   carrying its consumption status verbatim. A sibling merge adds the absorbing **axis**
   (§1); a true duplicate maps state-for-state.
   **⚠️ Never re-key an existing state.** Variant names are DB keys for versions and pinned
   comments (`preview-build.md` §3 rule 7) and they are *derived* from the matrix, so adding a
   column or row can silently rename a sibling. Use the guard in §4 step 2.
2. **§2** — the duplicate's geometry, for the states you just added. Tokens by name; a flagged
   literal stays flagged, with its flag text carried across.
3. **§1** — add the duplicate's Figma node(s) as a normative source of the keeper, and add a
   **deviation** recording the merge: that this row now spans two Figma components, and that
   the merge is a registry decision Figma has not made. Keep the duplicate's frozen snapshot
   citation; note if it covers only part of the row (C-022's partial-snapshot flag).
4. **§4** — the duplicate's props. A prop that means the same thing under a different name is
   the keeper's name; a prop with no counterpart is added, with its type and default.
5. **§5** — union of both rows' Consumes/Consumed-by.
6. **§6** — carry every open `OQ-C-<dup>-#` across as an OQ of the keeper, renumbered, with its
   original id in the text so the trail survives. **Add one OQ for the merge itself**: does
   Figma unify the two components, or does this row stay a two-source merge?
7. **Head the contract** with a dated closed change list saying what was absorbed and from
   where — the same shape C-022's head carries.

**Exit checklist 2:** every designed state of the duplicate present on the keeper ✓ · no
existing state re-keyed ✓ · props unioned ✓ · duplicate's OQs carried, not dropped ✓ · merge
recorded as a §1 deviation + an OQ ✓

## 3. REPOINT — every reference in the program

Find them all before editing any:

```bash
grep -rn "C-<dup>" docs/ui2/ iphone/MakeReadyUI/ capture/fixtures/ui2/
```

Repoint each, and **count them in the report** (C-041's merge moved 19 element-map boxes
across 5 maps — a number worth stating, because it is the part most easily missed):

- **Screen specs** (`docs/ui2/screens/*.md`) — §2 prose, §4 closed lists, amendment blocks.
  A §4 subsection that WAS the duplicate's contract becomes a pointer to the keeper's file.
- **Element maps** (`docs/ui2/screens/assets/*.elements.json`) — each box carries `ref` **and**
  `name`; repoint **both**, or the browser highlights a component under a stale name.
- **Other contracts** — §5 Composition on both sides, and any prose citing the duplicate.
- **The keeper's own Consumed-by** in `registry.md` — union with the duplicate's.
- **Notes** (`components/notes/C-<dup>.md`) — notes are normative build input
  (`ui2-notes.mjs`). If the duplicate has one, **append its content to the keeper's notes file
  as a new timestamped note** that says it was carried over on merge. Never delete a note; it
  is owner intent and it outranks the contract.
- **`tokens.md`** — any per-run note naming the duplicate as a token's observation source. The
  token rows themselves do not change; the attribution does.

**Exit checklist 3:** grep run and every hit accounted for ✓ · element-map `ref` AND `name`
repointed, count known ✓ · duplicate's notes carried over, none deleted ✓ · screen §4 left as
a pointer where it was the contract ✓

## 4. MIGRATE — the build artifacts

Only if the duplicate is **built** (`capture/fixtures/ui2/C-<dup>.json` exists). If it is not,
say so and skip to §5 — there is nothing to migrate.

1. **Fixture** — regenerate the KEEPER's fixture from its now-absorbed contract, through
   `writeUi2Fixture`, exactly as `/ui2-component-build` phase 4 does. Never hand-write it.
2. **Guard the DB keys** before writing:

   ```js
   const before = await readUi2Fixture("C-<keep>");        // BEFORE the contract edit
   // …absorb, re-derive with fixtureFromContract…
   for (const v of before.variants) {
     if (!fixture.variants.some((n) => n.name === v.name)) {
       throw new Error(`DB KEY LOST: "${v.name}" — versions and comments would orphan`);
     }
   }
   ```
3. **View** — fold the duplicate's SwiftUI view into the keeper's under
   `iphone/MakeReadyUI/`, driven by the absorbing axis. Delete the duplicate's file
   **only after** its behaviour is reachable through the keeper's props, then re-run
   `ruby iphone/scripts/makereadyui-sync.rb` so the target membership follows.
4. **ViewRegistry + CaptureFixture** — the duplicate's `case "component.ui2.C-<dup>"` is
   removed and its props are served by the keeper's case. `CaptureComponent` fields are
   **additive optionals and are never removed** — another contract may have come to rely on
   one (`preview-build.md` §3 rule 3). Leave them; re-comment them to name the keeper.
5. **Delete the duplicate's fixture** `capture/fixtures/ui2/C-<dup>.json` — fixture presence
   *is* built-ness (`preview-build.md` §6), so leaving it would keep claiming a row that no
   longer exists.
6. **Lint, sync, recapture the keeper** — `/ui2-component-build`'s phase 5, unchanged, so the
   merged states have renders.

**Exit checklist 4:** duplicate's built-ness stated ✓ · fixture re-derived, not hand-written ✓
· no DB key lost ✓ · duplicate's view folded in and its fixture removed ✓ · SwiftLint clean,
target synced, keeper recaptured ✓

## 5. STRIKE — the registry, last

The registry is edited **last**, so a failure earlier never leaves a struck row with a
half-merged contract. Follow C-041 DetailPair's row exactly — it is the canonical shape:

- **Name cell** → `~~DupName~~ → **C-<keep> KeeperName**`
- **Status cell** → `~~new~~ **removed**`. ⚠️ **This cell is the mechanism**, not decoration:
  `capture/lib/ui2-index.mjs` drops any row whose status matches `/removed/i`, which is what
  takes it out of the browser, the tree and the counts. Nothing else hides it.
- **Variants cell** → `**REMOVED <date> (owner): <one line on why>.** Its ID is kept and struck
  through per the append-only rule; <N> consumer(s), <N> screen-spec reference(s) and <N>
  element-map bounding box(es) were repointed to C-<keep> the same run.` Add any anatomy note
  the keeper's contract had to settle.
- **Defined in** → `~~<old anchor>~~ — now `design-system/components/C-<keep>-….md`` (naming
  the axis value it became, when it is a sibling merge).
- **Consumed by** → `*(none — merged into C-<keep>)*`.
- **Then the keeper's row**: dated closed change list of what it absorbed, Figma ref gains the
  duplicate's node, Consumed-by unioned, "Defined in" unchanged.

**Exit checklist 5:** duplicate's Status cell contains `removed` ✓ · ID struck, not deleted ✓ ·
keeper's row carries a dated change list ✓ · registry edited after everything else ✓

## 6. The database — leave it alone, and say why

The duplicate's `Comparison` row `ui2-c-<dup>`, its `Version`s, `Screenshot`s and `Comment`s
**stay**. They are the only artifact in this whole operation that cannot be regenerated from
the docs, and a merged-away row's capture history is still the record of what was once
rendered and what people said about it.

The registry strike in §5 already removes the row from the browser, so the orphaned comparison
is invisible without being destroyed. **Report the counts** so the owner knows what is parked:

```bash
node --input-type=module -e '
import { PrismaClient } from "@prisma/client";
const p = new PrismaClient();
const id = "ui2-c-<dup>";
console.log(id,
  "| versions:", await p.version.count({ where: { comparisonId: id } }),
  "| comments:", await p.comment.count({ where: { comparisonId: id } }),
  "| unresolved:", await p.comment.count({ where: { comparisonId: id, resolved: false } }));
await p.$disconnect();
'
```

**If the duplicate has UNRESOLVED comments, they are about to become unreachable.** Read them,
and either answer them against the keeper (they may already be fixed by the merge) or carry
them forward as an OQ on the keeper's contract. Never strike a row with live questions on it
without saying what happened to them.

**Exit checklist 6:** DB untouched ✓ · version/comment/unresolved counts reported ✓ ·
unresolved comments answered or carried forward ✓

## 7. VERIFY and report

```bash
grep -rn "C-<dup>" docs/ui2/ iphone/ capture/ | grep -v "registry.md"   # expect: none, or only historical citations
curl -s "localhost:5951/api/ui2/tree" | grep -c "C-<dup>"                # expect: 0
node capture/lib/ui2-notes.mjs read C-<keep>                             # carried notes present
```

Re-parse the keeper's contract and confirm its state names — the pre-existing ones byte-identical,
the absorbed ones present:

```bash
node --input-type=module -e '
import fs from "node:fs/promises";
import { parseContract } from "./capture/lib/ui2-index.mjs";
const f = "docs/ui2/design-system/components/C-<keep>-….md";
const c = parseContract(await fs.readFile(f, "utf8"), { file: f });
console.log(c.states.map((s) => `${s.name} → ${s.slug}`));
'
```

**Report:**
- **the verdict from §1** — true duplicate, sibling, or not-duplicates — and the difference table;
- **what was absorbed** — states, props, OQs, notes;
- **what was repointed** — counts per kind (screen specs, element-map boxes, contracts, notes);
- **build artifacts** — migrated, or "the duplicate was never built";
- **the DB** — counts parked under the orphaned comparison, and what happened to any unresolved comments;
- **the registry** — both rows' new text;
- **open questions** — including whether Figma should unify the two components;
- **anything you did NOT merge**, and why.

**Exit checklist 7:** no live reference to the duplicate remains ✓ · tree no longer lists it ✓ ·
keeper's pre-existing state names unchanged ✓ · report covers all eight points ✓

## Rules

- **`<keep>` first, `<duplicate>` second.** The argument order is the whole safety model.
- **Never reuse or delete a `C-###`.** Struck through, never gone.
- **Never delete a Version, Comment or Screenshot.** §6.
- **Never delete a note.** Carry it to the keeper as a new timestamped note.
- **Stop rather than merge two things that are not the same component.** §1's third outcome is
  a success.
- Docs + build artifacts only: `docs/ui2/`, `iphone/MakeReadyUI/`,
  `capture/fixtures/ui2/`, and the two test-target files `preview-build.md` §3 rule 3 permits.
  Never `client/`, never Figma.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
