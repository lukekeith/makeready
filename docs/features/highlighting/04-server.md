# Server

## Prerequisite — the open data-loss fix (D8)

**Nothing in this phase proceeds until this is closed.**

monday#12708759849 sub-issue A: a leader highlighted over two existing highlights that had notes,
and the notes were erased. The deep dive
([dossier](../../monday/tickets/12708759849.md)) established:

- the server merge **does** concatenate absorbed notes (`programs.ts:3033-3045`) and returns the
  concatenation on the created row;
- `syncExegesisSelectionsForBlock` never touches `noteMarkdown`;
- therefore the loss is client-side — either the note survives but is unreachable (the iPhone keys
  notes by *range*, `highlightNoteKey` = `"location:length"`, which every merge invalidates by
  construction), or an empty draft overwrites it.

**Required before M3:** reproduce, then read the row back via `GET …/highlights` to determine
which. Note text present → client keying/display bug, fixed in 06. Note text absent → the server
path re-opens and this document grows a fix.

Why it gates the migration: M3 moves every Read highlight into the table whose write path
(`programs.ts:3056-3069`, `deleteMany` on absorbed rows) is the one under report. Migrating data
into an unproven destructive path contradicts governing rule 1.

## Route work

**Two files, eight routes** *(corrected 2026-08-04 — G-a; the original wording hid half the work)*:

| Context | File | Routes |
|---|---|---|
| program | `server/src/routes/programs.ts` | GET `:2954` · POST `:2997` · PATCH `:3086` · DELETE `:3137` |
| scheduled / enrollment | `server/src/routes/enrollments.ts` | GET `:4267` · POST `:4312` · PATCH `:4403` · DELETE `:4456` |

Both sets get the generalised `…/highlights` paths **and** keep their `…/exegesis-highlights`
aliases — 16 mounted routes in total. Every task below applies to both files.

| Task | Detail |
|---|---|
| Rename model references | `prisma.exegesisHighlight` → `prisma.highlight` throughout after `/schema` regenerates the client |
| Generalise **all eight** routes | mount at `…/highlights` in both files, keep all eight `…/exegesis-highlights` paths as aliases (03 §2.5) |
| Relax the activity-type gate | `EXEGESIS` **or** `READ`; 400 otherwise. **Different field per context** — `activity.activityType` in `programs.ts` (`:2968`, `:3020`, `:3105`, `:3151`) vs **`activity.type`** in `enrollments.ts` (`:4277` + siblings). Not a copy-paste |
| GET returns all locked blocks | replace `findFirst({isLocked:true})` with `findMany`, add `blockIds[]`, keep `readBlockId` as the deprecated first block (03 §2.1) |
| `style` on POST/PATCH | zod: `style: z.enum(['highlight','bold']).optional()`; incoming style wins on merge |
| `syncSelectionsForBlock` | generalise `syncExegesisSelectionsForBlock` (`:2894`) to emit the real `style` instead of the hardcoded `'highlight'`; call after every mutation and after M3 |
| Deletion cascade | `:2746` deletes highlights for a block set — verify it stays correctly scoped now that Read highlights live there too |

**Auth is unchanged**: `requireAuth` + `canManageOrgContent(userId, organizationId, creatorId)` on
every route, plus the second ownership check on PATCH/DELETE
(`highlight.readBlock.lessonActivityId === activityId`, `:3110-3117`). This feature must not widen
or narrow access; if it does, that is an `X#` row.

## Migration & backfill

M1/M2 are schema (03 §1.3) via the YAML → `/schema` workflow. **Never** `npx prisma migrate dev`.

M3 is a **script**, not a schema migration — `server/scripts/backfill-highlights.ts`, with
`--dry-run` as the default and `--apply` required to write. It implements 03 §4 exactly:
dry-run report → idempotent insert → per-block assertions → source column retained.

Ordering: M1 → M2 → prerequisite fix verified → **content-hash pre-flight** → M3 dry-run reviewed →
M3 apply → projection rebuild → assertions.

### Content-hash pre-flight (required — X-c, confirmed 2026-08-04)

`lesson-content-hash.ts:180` hashes `block.selections`, and `enrollment-sync.ts:322` treats a
changed hash as "this enrolled group's scheduled lesson is out of date". The projection is
therefore load-bearing on version resolution, and re-serialising it can mark **every enrolled
group's lessons stale** for content nobody edited.

The dry run must, before anything is written:

1. compute each block's **current** `selections` JSON and the **regenerated** projection;
2. report every block where the two differ — by value, by key order, or by array order;
3. report how many lessons and enrolled schedules those blocks roll up to.

**DECIDED (Luke, 2026-08-04): normalise — M3 must be hash-neutral.** Re-baselining the hashes was
rejected; a dirty report is a bug to fix, not a churn to announce. Do not run M3 on a dirty report.

**How normalisation is achieved (verified in code, 2026-08-04):**

- **Keys already match.** `ReadBlockSelection` (`StudyModels.swift:372`) is `Codable` over exactly
  `start`, `end`, `style` — its `id` is a computed property and is never encoded. The projection
  emits the same three keys.
- **Order is the only real variable.** The client appends new spans at the end —
  `mergeSelection` returns `kept + [new]` (`EditReadActivityPage.swift`) — so the stored array is
  in insertion order, while the projection sorts by `orderNumber`.
- **Therefore:** the backfill assigns `orderNumber` = the span's **index in the existing
  `selections` array**. The projection then re-emits the identical order, and the JSON is
  byte-identical. Exegesis blocks are unaffected (their rows already own `orderNumber`, and their
  projected style was and remains `'highlight'`).

The pre-flight is what proves this held, per block, before anything is written.

## Tests

- merge: overlapping create absorbs, unions the span, **concatenates notes**, keeps the earliest
  `orderNumber`, returns `absorbedIds` — the regression guard for the prerequisite
- merge with differing styles → incoming style wins
- GET on a READ activity with **three** locked blocks returns highlights from all three and a
  `blockIds` array of length 3
- GET on a non-READ/EXEGESIS activity → 400
- legacy `…/exegesis-highlights` alias returns byte-identical fields to today for an EXEGESIS
  activity
- PATCH `style` only, `noteMarkdown` only, both, neither (→400)
- PATCH/DELETE of a highlight belonging to a different activity → 404
- projection: after each mutation, `selections[]` equals the rows' `(start,end,style)` in order
- backfill: idempotence (second run is a no-op), span-equality assertions, and that `selections`
  is untouched on disk

## Gates

```
cd server && npx tsc --noEmit
cd server && npm run lint
cd server && npm run test:run
cd server && npm run schema:validate
cd server && npm run schema:diff
cd server && npm run migrate:status
docker restart makeready-server          # after ANY server/src edit — tsx watch misses bind-mount events
```
