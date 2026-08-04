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
> ## ✅ UNBLOCKED — the second decision is in (09 §X-l)
>
> The delta audit of X-k found the hash lives in **four** places, not two, and that the drift check
> reads `StudyProgramVersion.snapshot.lessons[].contentHash` (`enrollment-sync.ts:238,322`) rather
> than the `lessonHashes` map X-k named. The same snapshot also stores `content` — the whole
> canonical lesson object at publish time — which is diffed to build the human-facing change summary.
>
> **DECIDED (Luke, 2026-08-04): re-stamp the snapshot too, `contentHash` and `content` together,
> with a rollback manifest.** Rewriting a published-version audit record is accepted deliberately:
> nothing a reader would recognise as content changed, and the alternative just defers the same
> churn to the next publish. Measured surface — **16 schedule versions, 11 snapshot entries, 11
> `lessonHashes` entries**, each with exactly **1 already-drifted** row that is left alone.

## Tasks (execute in order — no ∥ in this phase)

- [~] 3.1 `server/scripts/backfill-highlights.ts` **exists (committed `dc7c8fc`) — read-only.**
      Dry run is the default and the ONLY mode; `--apply` exits 2 rather than pretending. The write
      half is what remains. · spec: 03 §4, 04 §Migration & backfill
- [x] 3.2 ✅ **DONE — pre-flight part one, `selections` byte-identity. Reports CLEAN.**
      49 blocks / 67 spans to migrate; 16 blocks already have rows and are skipped (idempotent).
      Compares **element-wise on `(start, end, style)` in array order** — deliberately NOT
      `JSON.stringify`. `selections` is `jsonb`, and Postgres normalises key order on write, so the
      "key order" check this task originally asked for can never mean anything; comparing stringified
      key order produced a **false STOP on all 49 blocks** in the first version. See 09 §G-l.
      Also reports blocks holding duplicate `(start,end)` spans, which the unique constraint would
      reject (task 3.10) — none found today.
- [ ] 3.3 Normalisation: assign `orderNumber` = the span's **index in the existing `selections`
      array**, so the `orderNumber`-sorted projection re-emits the original order. Keys already
      match — `ReadBlockSelection` encodes exactly `start`/`end`/`style`.
      **Still required, no longer sufficient** — see the banner. · spec: 04 §How normalisation is achieved
- [x] 3.4 ✅ **DONE — pre-flight part two, the hash delta.** Measured on production-synced local
      data, 2026-08-04: **13 lessons touched, 13 hashes move** (none neutral, as X-k predicted).
      Re-stamp surface, per location: `LessonScheduleVersion.sourceContentHash` **16 re-stampable ·
      1 already drifted** · `StudyProgramVersion.snapshot[].contentHash` **11 · 1** ·
      `StudyProgramVersion.lessonHashes` **11 · 1**. The already-drifted rows are the ones that must
      be left alone; there is exactly one in each category today.
- [ ] 3.5 Idempotence: a selection counts as already migrated when a row exists on the same block
      with the same `(start, end, style)`. Second run creates nothing **and re-stamps nothing**.
      · spec: 03 §4.2 · tests: run twice, assert zero new rows and zero hash writes
- [ ] 3.6 Per-block assertions: every pre-run span exists as a row; the regenerated projection is
      set-equal to the pre-run `selections[]`; no block loses spans; total row count only increases.
      · spec: 03 §4.3
- [ ] 3.7 **The re-stamp, in the same transaction as the row creation** (design settled by 09 §X-l).
      For each affected lesson, having computed `hash_before` and `hash_after`, update **all four**
      stored locations — **only where the stored value still equals `hash_before`**:

      | # | Location | What to write | Why it matters |
      |---|---|---|---|
      | 1 | `LessonScheduleVersion.sourceContentHash` | `hash_after` | one side of the drift comparison |
      | 2 | `StudyProgramVersion.snapshot.lessons[i].contentHash` | `hash_after` | **the other side — what `enrollment-sync.ts:322` actually reads** |
      | 3 | `StudyProgramVersion.snapshot.lessons[i].content` | the freshly computed `canonicalLessonContent(lesson)` | keeps the snapshot internally consistent; it is also what `enrollment-sync-changes` diffs for the change summary |
      | 4 | `StudyProgramVersion.lessonHashes[lessonId]` | `hash_after` | stored alongside; leaving it stale is a latent trap |

      **Rules that make this safe:**
      - **2 and 3 move together or not at all.** A snapshot whose `contentHash` does not hash its own
        `content` is worse than one that is merely stale.
      - **Any stored value that does not equal `hash_before` is left untouched and reported.** It
        means that lesson was genuinely edited after the baseline was recorded; re-stamping it would
        mark a real edit as synced. Measured: exactly 1 such row in each category today.
      - `snapshot` and `lessonHashes` are JSON columns, so this is read-modify-write — do it inside
        the transaction, never as a blind overwrite of the whole column.
      - **Write a rollback manifest** — every `(table, rowId, field, oldValue, newValue)` — to a file
        before committing. Without it the re-stamp is not reversible, and 12's rollback checklist
        item cannot be honoured.
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
