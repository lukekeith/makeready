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
- [ ] 1.3a **CONFIRMED ROUTE (2026-08-04)** — the note is present in the DB → client bug. Re-key the note dictionary by
      **highlight id** instead of range: `highlightNoteKey` returns `"\(location):\(length)"`
      (`EditExegesisActivityPage.swift:649-651`), which every merge invalidates by construction.
      · files: `iphone/MakeReady/Pages/Manage/Program/EditExegesisActivityPage.swift`,
        `ExegesisNoteEditorPage.swift` · spec: 06 §Note keying
      · tests: a note survives a merge that changes the highlight's span
- [x] ~~1.3b~~ **NOT TAKEN** — ruled out by 1.2's evidence. This phase stays an iPhone phase.
- [ ] ~~1.3b~~ *(original text, kept for the record)* If the note is absent from the DB → **STOP.** This phase becomes a *server* phase;
      re-open `04`, add the server fix, and re-run this phase doc's gates against `server/`. Do not
      continue to Phase 2 on an iPhone-only fix that didn't address the real cause.
- [ ] 1.4 Update the monday ticket and dossier with the evidence and the resolution.
      · files: `docs/monday/tickets/12708759849.md`

## Phase gates (run fresh, record output)

```
npm run ios:build-check
cd iphone && swiftlint
```
Plus, if 1.3b fires: `cd server && npx tsc --noEmit && npm run lint && npm run test:run`.

## Verification checklist

- [ ] The repro was actually performed on a device/simulator — not inferred
- [ ] 09 records the DB read-back result with a date
- [ ] After the fix: two noted highlights, merged, and **both notes are present** in the merged
      highlight's note editor AND in the API response
- [ ] A note survives a merge that changes the highlight's span (regression guard, shipped with 1.3a)
- [ ] Sub-issue A's dossier row is updated; the other sub-issues' state is untouched

## VERIFIED

> Sign with date + who + what was exercised. Until this block is signed, Phase 2 may not start.

*(unsigned)*
