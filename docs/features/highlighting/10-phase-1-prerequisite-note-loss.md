# Phase 1 — Prerequisite: the note-loss data bug  ·  app: iphone

> Part of docs/features/highlighting/. Preconditions: none — **first phase, and it gates every
> other one**. No schema change, no backfill and no other phase may start until this phase's
> VERIFIED block is signed.

## Goal

monday#12708759849 sub-issue A — a leader highlighted across two noted highlights and the notes
were erased — is reproduced, diagnosed to a side, and fixed. At the end we know from evidence, not
inference, whether the note text survives in the database, and the merge write path is safe to
migrate Read data into.

**Why it is first:** M3 backfills every existing Read highlight into the table whose write path is
under this report (`programs.ts:3056-3069` deletes absorbed rows). Governing rule 1 forbids moving
data into an unproven destructive path.

## Companion skills

`/monday-resolve 12708759849` for the fix + evidence comment + dossier update · `/ios-error-surface`
if the fix touches a catch block · `/transition-review` is **not** needed (no animation surface).

## Tasks (execute in order)

- [x] 1.1 **Reproduce.** ✅ 2026-08-04 — done at the **API level** against the local stack rather
      than the simulator, which is stronger: it isolates the server from the client entirely. iPhone, Exegesis activity: create two highlights, put distinct note text in
      each, save, then drag one highlight across both.
      · files: none (runtime) · spec: 04 §Prerequisite
- [x] 1.2 **Read the row back** ✅ 2026-08-04 — **THE NOTE IS PRESENT IN THE DATABASE.** via `GET /api/activities/:activityId/exegesis-highlights`
      (`programs.ts:2954`) and record whether the merged row's `noteMarkdown` contains both notes.
      **This single observation decides the fix's side.** → **routes to 1.3a (client-side).**

      **Evidence (local stack, `127.0.0.1:3010`, API-key auth, 2026-08-04).** On a block already
      carrying four real highlights, two of them noted, a new highlight spanning both was created —
      exactly the reported action. The merged row came back holding **all four notes concatenated
      in document order**, `\n\n`-separated:
      `"Why does John start his Gospel…"` + `"NOTE-ALPHA"` + `"The phrase “the Word” is a Greek
      philosophical term…"` + `"NOTE-BRAVO"`. Nothing was lost server-side.

      Corroborating, on a *different* block, production-synced data already shows a note that is
      visibly the output of this merge — `"Heading 1"` + `"…but I'm trying t"` + `"o add a whole
      bunch of characters…"`, split mid-word across the `\n\n` joins. The merge has been
      preserving notes in real data all along.

      **Local data was disturbed and restored**: the test merged two real pre-existing highlights.
      The merged row was deleted and both originals recreated with identical spans and note text;
      the block's final state matches the recorded before-state (4 highlights: 2-19, 24-33, 86-88,
      122-162). Row **ids** differ for the two recreated ones — local dev data only.
      · spec: 04 §Prerequisite
- [x] 1.3a ✅ **DONE 2026-08-04 (narrow fix — see 09 §C-b).** **CONFIRMED ROUTE (2026-08-04)** — the note is present in the DB → client bug. Re-key the note dictionary by
      **highlight id** instead of range: `highlightNoteKey` returns `"\(location):\(length)"`
      (`EditExegesisActivityPage.swift:649-651`), which every merge invalidates by construction.
      · files: `iphone/MakeReady/Pages/Manage/Program/EditExegesisActivityPage.swift`,
        `ExegesisNoteEditorPage.swift` · spec: 06 §Note keying
      · tests: a note survives a merge that changes the highlight's span

      **Call-site map (surveyed 2026-08-04 — this is bigger than "change one function").**
      Three dictionaries are range-keyed, not one: `noteDrafts` (`:183`),
      `attributedNoteDrafts` (`:184`) and `savedNoteMarkdownByHighlight` (`:185`). Seventeen sites
      in `EditExegesisActivityPage.swift` touch them:
      `:487-488` (the note-button lookup + the TEMPORARY diagnostic at `:495`) ·
      `:514-517` (delete clears all three) · `:618` (`noteMarkdown(for:)`) ·
      `:634-638` (`seedNoteDrafts`) · `:649-651` (`highlightNoteKey`) ·
      `:653` (`rangeFromHighlightNoteKey`) · `:689-695` (hydrate from server) ·
      `:705-706` (draft write) · `:715-718` (flush pending drafts) ·
      `:739-741` (post-save reconciliation) · `:949-950` (post-create).
      All three are passed as `@Binding` into `ExegesisNoteEditorPage` (`:1069-1070`, `:1088`,
      `:1094-1096`, `:1106-1108`) and into the action menu (`:505-507`, `:550-552`).

      **The design constraint that makes this non-trivial:** `ExegesisNoteEditorPage` navigates by
      **`NSRange`** (`highlightRanges: [NSRange]`, one page per range), so it has no id to key by.
      Either (a) keep the dictionaries range-keyed but **re-key them after every merge** from the
      server's returned row, or (b) thread highlight ids through the editor and convert at the
      boundary via `exegesisHighlights` (which carries `id` + `start`/`end`). (b) is the real fix
      and matches 06 §Note keying; (a) is a narrower patch. **Decide before writing.**

      Also delete the `TEMPORARY DIAGNOSTIC` block at `:487-503` while here — it was added to make
      this exact report decidable, and task 1.2 has now decided it. ✅ removed.

      **What shipped (2026-08-04):** the narrow fix, not the id-keying. At the single site where
      the client learns a merge happened (the create path in `applyStyle`), the absorbed spans'
      entries are removed from all three dictionaries and the merged row's note is written under
      the new span's key — into `savedNoteMarkdownByHighlight` **and** both draft maps, so the
      draft follows the server's concatenation instead of keeping one pre-merge fragment. The
      entity-keyed design and the `applyMerge` seam are Phase 4 task 4.8b; this is tracked as a
      deliberate stop-gap at 09 §C-b.
- [x] ~~1.3b~~ **NOT TAKEN** — ruled out by 1.2's evidence. This phase stays an iPhone phase.
  > ~~1.3b~~ *(original text, kept for the record — not a live task, deliberately not a checkbox)*
  > If the note is absent from the DB → **STOP.** This phase becomes a *server* phase;
  > re-open `04`, add the server fix, and re-run this phase doc's gates against `server/`. Do not
  > continue to Phase 2 on an iPhone-only fix that didn't address the real cause.
- [x] 1.4 ✅ **Dossier done 2026-08-04 · the monday.com comment is NOT posted (needs your go-ahead).**
      · files: `docs/monday/tickets/12708759849.md`

      **Landed in the dossier:** a `2026-08-04 — sub-issue A RESOLVED (6e349b5)` entry in the
      Resolution log with the decisive API evidence, the root cause, the fix, its deliberate
      narrowness (4.8b), the gates, Luke's runtime confirmation and the missing test (G-d). The
      Root cause §A heading no longer says "not yet isolated", and the three-hypothesis list now
      records that hypothesis 1 was the answer and why 2 and 3 are ruled out. Sub-issues B and C
      were not touched.

      **Not done, deliberately:** posting the evidence comment to monday.com and moving the ticket's
      status. That writes to an external system, so it wants an explicit go-ahead. It is also a
      status *decision* now, not just a comment: PIPELINE.md's comment-only rule applied because a
      sub-issue was still open, and with A resolved **all three sub-issues (A, B, C) are done** — so
      this ticket is now a candidate for Done rather than another comment. `/monday-resolve
      12708759849` is the route that posts it.

## Gate results — 2026-08-04

- `npm run ios:build-check` → **BUILD SUCCEEDED** (build 386)
- `cd iphone && swiftlint lint --baseline` → **0 violations, 0 serious, 268 files**
- Installed and launched on the iPhone 17 Pro Max simulator (PID 33676)
- 1.3b's server branch not taken, so the server gates do not apply

## Phase gates (run fresh, record output)

```
npm run ios:build-check
cd iphone && swiftlint
```
Plus, if 1.3b fires: `cd server && npx tsc --noEmit && npm run lint && npm run test:run`.

## Verification checklist

- [x] The repro was actually performed on a device/simulator — not inferred. **Both halves are
      real observations:** the *failing* behaviour was reproduced at the API level on the local
      stack (task 1.2 — stronger than the simulator for isolating server from client, because it
      removes the client entirely), and the *fixed* behaviour was exercised by hand on the
      simulator by Luke, 2026-08-04. Nothing here is inferred.
- [x] 09 records the DB read-back result with a date — `09 §Build findings`, row dated 2026-08-04
      ("the merge does NOT lose notes"), plus a second dated row for the human walkthrough.
- [x] After the fix: two noted highlights, merged, and **both notes are present** in the merged
      highlight's note editor (Luke, 2026-08-04) AND in the API response (task 1.2, all four notes
      concatenated in document order).
- [x] A note survives a merge that changes the highlight's span — **UPGRADED 2026-08-05: no longer
      human-walkthrough-only.** Phase 7 step 7.5 ran it over real HTTP against the live stack —
      two noted highlights absorbed by a spanning third returned `"Note A\n\nNote B"` character for
      character, and the data was restored to a byte-identical whole-table fingerprint. Phase 4's
      `HighlightDraftStoreTests` (15 tests) additionally guard the client-side succession. Original
      caveat retained below for the record. **verified by human walkthrough
      only. The automated regression guard named in 1.3a did NOT ship** (`6e349b5` touches one
      Swift file and three docs; no test). The succession logic is inline in the page's create
      path with no seam to call, so the test lands with the `applyMerge` extraction in Phase 4
      task 4.8b. Tracked as **09 §G-d** — do not read this line as "covered by tests".
- [x] Sub-issue A's dossier row is updated; the other sub-issues' state is untouched — task 1.4.
      (The monday.com comment itself is deliberately unposted — see 1.4.)

## VERIFIED

> Sign with date + who + what was exercised. Until this block is signed, Phase 2 may not start.

✅ **VERIFIED 2026-08-04 — signed on Luke's runtime confirmation.**

**What was exercised.** Luke opened an Exegesis activity on the iPhone 17 Pro Max simulator (build
386), created two highlights with different note text, saved, dragged one highlight across both, and
opened the merged highlight's note. **Both notes were present.** That is the reported symptom of
monday#12708759849 sub-issue A, and it is gone.

**Gates, run fresh 2026-08-04:** `npm run ios:build-check` → BUILD SUCCEEDED (386) ·
`cd iphone && swiftlint lint --baseline` → 0 violations, 0 serious, 268 files. Task 1.3b's server
branch was not taken, so the server gates do not apply. Commit `6e349b5`.

**Two things this sign-off does NOT claim, recorded so nothing reads stronger than it is:**

1. **No automated regression test exists** for note survival across a merge. The walkthrough above
   is the only guard. The extraction that makes it testable is Phase 4 task 4.8b — see 09 §G-d.
2. **The walkthrough's backend is unconfirmed.** The local database holds no merged row from it, and
   the simulator app has no `selectedEnvironment` set, which resolves to **production**
   (`Configuration.swift:126`). The most likely reading is that the check ran against
   `api.makeready.org` — which makes it a *stronger* verification, but means real highlight rows
   were merged. Flagged for Luke; it does not affect the verdict, since the code path is identical
   either way and the server was already exonerated at the API level in task 1.2.

**Phase 2 is unblocked.** The merge write path is proven not to lose notes, so governing rule 1's
bar for migrating Read data into it is met.
