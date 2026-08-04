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

- [x] 3.1 ✅ **DONE — `server/src/scripts/backfill-highlights.ts`**, dry-run by default, `--apply`
      to write. · spec: 03 §4, 04 §Migration & backfill
      · **Moved from `scripts/` to `src/scripts/` mid-build**, for two reasons: it matches the
      existing convention (`src/scripts/backfill-study-sync.ts`), and `tsconfig.json` includes only
      `src` — so a script in the repo-root `scripts/` dir is **invisible to `npx tsc --noEmit`**,
      the phase gate. The move immediately surfaced **four real type errors** the gate had been
      silently skipping, including a variable used but never declared. The riskiest code in this
      feature does not get to skip the typechecker. Recorded as 09 §G-m.
- [x] 3.2 ✅ **DONE — pre-flight part one, `selections` byte-identity. Reports CLEAN.**
      49 blocks / 67 spans to migrate; 16 blocks already have rows and are skipped (idempotent).
      Compares **element-wise on `(start, end, style)` in array order** — deliberately NOT
      `JSON.stringify`. `selections` is `jsonb`, and Postgres normalises key order on write, so the
      "key order" check this task originally asked for can never mean anything; comparing stringified
      key order produced a **false STOP on all 49 blocks** in the first version. See 09 §G-l.
      Also reports blocks holding duplicate `(start,end)` spans, which the unique constraint would
      reject (task 3.10) — none found today.
- [x] 3.3 ✅ **DONE.** `orderNumber` = the span's index in the existing array, so the
      `orderNumber`-sorted projection re-emits the original order. **Verified on real data after
      the apply:** block `07ec505c` stored `[{231,256},{584,609}]` and now has rows at
      `orderNumber` 0 and 1 with exactly those spans, in that order.
- [x] 3.4 ✅ **DONE — pre-flight part two, the hash delta.** Measured on production-synced local
      data, 2026-08-04: **13 lessons touched, 13 hashes move** (none neutral, as X-k predicted).
      Re-stamp surface, per location: `LessonScheduleVersion.sourceContentHash` **16 re-stampable ·
      1 already drifted** · `StudyProgramVersion.snapshot[].contentHash` **11 · 1** ·
      `StudyProgramVersion.lessonHashes` **11 · 1**. The already-drifted rows are the ones that must
      be left alone; there is exactly one in each category today.
- [x] 3.5 ✅ **DONE and demonstrated.** Second `--apply` reported `0 blocks to migrate · 0 spans ·
      0 baselines updated`, and the row count stayed at **103**. · spec: 03 §4.2
- [x] 3.6 ✅ **DONE.** Row count **36 → 103 = exactly +67**, the number of spans the pre-flight
      said it would create. `selections` unchanged: **65 blocks / 100 spans** before and after
      (67 migrated + 33 already on Exegesis blocks). Nothing deleted. · spec: 03 §4.3
- [x] 3.7 ✅ **DONE — implemented and run.** All four locations updated inside one
      `prisma.$transaction`, each guarded by "only if the stored value still equals `hash_before`".
      Snapshot `contentHash` and `content` move together. Manifest written before the transaction
      commits, so a throw leaves nothing behind. Result: **49 updated, 3 skipped** (one genuinely
      drifted lesson, consistently skipped in all three of its locations).
      *(design settled by 09 §X-l — the table below is the spec it was built from)*
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
- [x] 3.8 ✅ **DONE.** `selections` pre-flight **CLEAN**; the already-drifted list had exactly one
      lesson (`09abe81f`, read blocks last edited 2026-07-29 — genuine drift, predating this work),
      appearing consistently in all three baseline locations. The apply refuses to run at all on a
      dirty pre-flight or on duplicate spans.
- [x] 3.9 ✅ **APPLIED ON LOCAL 2026-08-04.** 49 blocks got rows; **49 baselines updated**
      (16 schedule + 11 snapshot hash + 11 snapshot content + 11 map); **3 left alone**, all the
      same genuinely-drifted lesson. **Post-run sweep: ✅ every affected lesson hashes to its
      re-stamped baseline.** A full `pg_dump` of the four affected tables was taken first and sits
      beside the ledger at `highlighting-phase3-backup/pre-backfill.sql` (689K).
- [x] 3.10 ✅ **DONE.** Spans are copied as-is; no merging. The script reports blocks holding
      duplicate `(start,end)` spans, which the unique constraint would reject, and **refuses to
      apply** if any exist. None found in this data. · spec: 03 §4
- [ ] 3.11 Tests: idempotence, span equality, `selections` untouched on disk, the re-stamp
      condition (matching → updated, non-matching → untouched), and a post-run hash sweep.
      · files: `server/scripts/__tests__/` · **the existing hash-stability guard
      (`lesson-content-hash-stability.test.ts`) must stay green throughout** — this phase changes
      data, never the hash's shape.
- [x] 3.12 ✅ **DONE — verified in the database.** Blocks matching the guard's condition ("has
      selections, has no rows") went from **49 to 0**. The guard is now inert and stays in place as
      a permanent invariant check (09 §X-i).

## Phase gates

```
cd server && npx tsc --noEmit
cd server && npm run lint
cd server && npm run test:run
cd server && npm run migrate:status
docker restart makeready-server
```

## Verification checklist

- [x] `selections` pre-flight is **clean** — zero blocks whose serialisation would change
- [x] The hash-delta report is understood: 13 lessons moved, 12 fully re-stamped, 1 (`09abe81f`)
      explicitly listed as already-drifted in all three locations and left alone.
- [x] Post-run sweep: ✅ every affected lesson's recomputed hash equals its stored baseline
- [x] No schedule that was already drifted before the run had its baseline touched — 3 skips, all
      the same lesson, reported by name
- [x] Second `--apply` run is a no-op — 0 rows, 0 baselines, count still 103
- [x] Spot-check: block `07ec505c` stored `[{231,256},{584,609}]`; rows landed at `orderNumber`
      0 and 1 with exactly those spans, in that order
- [x] `ActivityReadBlock.selections` untouched — 65 blocks / 100 spans before and after. The script
      deliberately never writes that column: it already holds what the projection would regenerate
- [x] Row count only increased: 36 → 103, exactly +67 as predicted. Nothing deleted
- [~] Rollback: the **manifest exists and is complete** — 98 entries beside the ledger at
      `highlighting-phase3-backup/backfill-highlights-manifest-98.json`, breaking down as 49 row
      creations + 16 schedule hashes + 11 snapshot hashes + 11 snapshot contents + 11 map entries,
      each with its old value. A full `pg_dump` of all four tables was taken before the run.
      **The rollback has NOT been rehearsed** — restoring from the manifest is untested, and
      "we have a backup" is not the same as "we have restored from it". Owed with 3.11.

## VERIFIED

*(unsigned)*
