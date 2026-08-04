# Phase 3 — The backfill  ·  app: server

> Part of docs/features/highlighting/. Preconditions: **Phase 1 VERIFIED** (the merge path is
> proven safe) **and Phase 2 VERIFIED** (the table and projection exist). This is the only phase
> that touches existing customer data. Governing rule 1 applies to every task in it.

## Goal

Every existing Read highlight exists as a `content_highlights` row and the derived projection
reproduces each block's previous `selections` JSON **byte-for-byte**. Lesson content hashes **do**
move — that is unavoidable (09 §X-k) — so the run re-stamps the stored baselines that recorded the
old value, leaving genuinely-drifted ones alone, with the net effect that **no enrolled group sees
a change it did not earn**. Nothing is deleted; `ActivityReadBlock.selections` is retained.

## Companion skills

None — this is a script plus assertions. Do **not** use `/schema`: M3 is a data migration, not a
schema migration.

> ## ⚠️ RE-PLANNED 2026-08-04 — the original premise was wrong (09 §X-k)
>
> **The backfill cannot be hash-neutral, and no amount of `selections` normalisation makes it so.**
> The lesson content hash covers the highlight **rows** as well as the `selections` column. A Read
> block goes from zero rows to N, so the hashed array goes from `[]` to N entries and the hash moves
> even with `selections` reproduced byte-for-byte. Simulated over 400 lessons: **13 of 13 candidates
> move. None are neutral.**
>
> **DECIDED (Luke, 2026-08-04): re-stamp the stored baselines in the same run.** The content did not
> change, so the honest repair is to correct the recorded baseline — but only where it still matched
> the pre-backfill value. Tasks below are rewritten accordingly; 3.3's normalisation survives
> (it is still needed for `selections` byte-identity, which consumers read) but it is no longer
> sufficient on its own, and 3.6's "dirty report = stop" now means something different.
>
> **Two facts the re-plan turns on, both verified in code (2026-08-04):**
> 1. Drift is **stored-vs-stored** — `StudyProgramVersion.lessonHashes[lessonId]` against
>    `LessonScheduleVersion.sourceContentHash` (`enrollment-sync.ts:322`). Nothing is recomputed
>    live, so the backfill marks nothing stale *at the time it runs*. It bites at the next
>    **publish** (rewrites `lessonHashes` from live content) or at the next **new enrollment**
>    (`enrollments.ts:286`, `:4900`, stamps from live content).
> 2. Therefore **both** stored sides must be re-stamped. Updating only the schedule side relocates
>    the churn to the next publish rather than preventing it.
>
> ## ⛔ STILL BLOCKED — the delta audit of that decision found it under-scoped (09 §X-l)
>
> The hash lives in **four** places, not two, and the drift check reads one the decision did not
> name: `StudyProgramVersion.snapshot.lessons[].contentHash` (`enrollment-sync.ts:238,322`) — not
> `lessonHashes`. Worse, the same snapshot stores `content`, the **whole canonical lesson object**
> at publish time, which embeds the highlight arrays and is diffed to build the human-facing change
> summary. Re-stamping the hash without the content leaves the snapshot claiming a hash its own
> stored content does not produce.
>
> And that raises a question that is genuinely Luke's, not the script's: **the snapshot is an audit
> record of what was published at version N. Is rewriting it acceptable for a no-op data
> migration?** Task 3.7 must not be implemented until that is answered.

## Tasks (execute in order — no ∥ in this phase)

- [ ] 3.1 Write `server/scripts/backfill-highlights.ts`. `--dry-run` is the **default**; `--apply`
      is required to write anything. · spec: 03 §4, 04 §Migration & backfill
- [ ] 3.2 **Pre-flight, part one — `selections` byte-identity.** For every candidate block, compute
      the current `selections` JSON and the projection that would be regenerated, and report any
      block where they differ by value, key order or array order. This must come back **clean**;
      consumers read that column and it must not move. · evidence: `lesson-content-hash.ts`
- [ ] 3.3 Normalisation: assign `orderNumber` = the span's **index in the existing `selections`
      array**, so the `orderNumber`-sorted projection re-emits the original order. Keys already
      match — `ReadBlockSelection` encodes exactly `start`/`end`/`style`.
      **Still required, no longer sufficient** — see the banner. · spec: 04 §How normalisation is achieved
- [ ] 3.4 **Pre-flight, part two — the hash delta (NEW).** For every affected lesson compute
      `hash_before` and the `hash_after` the backfill would produce, and roll up: how many lessons
      move, how many schedule versions still hold `hash_before` (**re-stampable**), and how many
      hold something else (**already genuinely drifted — must be left alone**). Report the second
      number prominently; it is the blast radius of getting the condition wrong.
- [ ] 3.5 Idempotence: a selection counts as already migrated when a row exists on the same block
      with the same `(start, end, style)`. Second run creates nothing **and re-stamps nothing**.
      · spec: 03 §4.2 · tests: run twice, assert zero new rows and zero hash writes
- [ ] 3.6 Per-block assertions: every pre-run span exists as a row; the regenerated projection is
      set-equal to the pre-run `selections[]`; no block loses spans; total row count only increases.
      · spec: 03 §4.3
- [ ] 3.7 **The re-stamp (NEW), in the same transaction as the row creation.** For each affected
      lesson, having computed `hash_before` and `hash_after`:
      - update `LessonScheduleVersion.sourceContentHash` → `hash_after` **only where it currently
        equals `hash_before`**;
      - update the matching entry in `StudyProgramVersion.lessonHashes` → `hash_after` **only where
        it currently equals `hash_before`**;
      - leave every other row untouched and **report each one**, because a mismatch means that
        lesson was genuinely drifted before the backfill and silently "fixing" it would mark a real
        edit as synced.
      Both sides or neither — updating one alone just relocates the churn.
- [ ] 3.8 **Run the dry run and read both reports.** A dirty `selections` report is a **stop** —
      fix normalisation and re-run. A non-empty "already drifted" list is **not** a stop, but it
      must be read and understood before proceeding.
- [ ] 3.9 Run `--apply` on local, then re-run the projection rebuild, the assertions, and a
      **post-run hash sweep**: recompute every affected lesson's hash and confirm it equals the
      stored baseline everywhere the re-stamp applied.
- [ ] 3.10 Overlapping spans within one block's existing array are migrated **as-is, without
      merging** — the backfill is a copy, not a normalisation of user intent. · spec: 03 §4
      · note: the table has a `(readBlockId, start, end)` unique constraint, so exact-duplicate
      spans in one array must be de-duplicated or the insert fails. Report any such block.
- [ ] 3.11 Tests: idempotence, span equality, `selections` untouched on disk, the re-stamp
      condition (matching → updated, non-matching → untouched), and a post-run hash sweep.
      · files: `server/scripts/__tests__/` · **the existing hash-stability guard
      (`lesson-content-hash-stability.test.ts`) must stay green throughout** — this phase changes
      data, never the hash's shape.
- [ ] 3.12 **Retire the 409 pre-backfill guard's reason for existing** (09 §X-i). After a successful
      apply, no block should match "has selections, has no rows". Assert that, and record it — the
      guard itself stays in place as a permanent invariant check.

## Phase gates

```
cd server && npx tsc --noEmit
cd server && npm run lint
cd server && npm run test:run
cd server && npm run migrate:status
docker restart makeready-server
```

## Verification checklist

- [ ] `selections` pre-flight is **clean** — zero blocks whose serialisation would change
- [ ] The hash-delta report is understood: every moved lesson is either re-stamped or explicitly
      listed as already-drifted. **"Zero lessons move" is NOT achievable and is no longer the
      target** — that was the original plan's error (09 §X-k)
- [ ] Post-run sweep: every re-stamped lesson's recomputed hash equals its stored baseline, on
      BOTH `LessonScheduleVersion.sourceContentHash` and `StudyProgramVersion.lessonHashes`
- [ ] No schedule that was already drifted before the run had its baseline touched
- [ ] Second `--apply` run is a no-op (idempotent)
- [ ] Spot-check three real blocks: pre-run `selections` JSON == post-run projection, byte for byte
- [ ] `ActivityReadBlock.selections` still populated on every block that had it
- [ ] Row count only increased; nothing deleted
- [ ] Rollback rehearsed: deleting the created rows AND restoring the re-stamped baselines to
      their recorded pre-run values returns the system to its exact previous state. **The run must
      therefore write a rollback manifest** — every `(table, id, oldValue, newValue)` it touched —
      or the re-stamp is not reversible, which the original single-table plan never had to consider.

## VERIFIED

*(unsigned)*
