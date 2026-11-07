# text-activity production cutover — the owner's runbook

Run by the owner, never by an agent (SPEC D27). The cutover drops the 1.0 content tables and columns; the only undo
is the `pg_dump` restore in step 1. Commands run from `server/`.

What it does: converts every 1.0 program, lesson and activity into the new model (`content-export` then
`content-import`), then applies `server/atlas/cutover/20261107233000_text_activity_cutover.sql`, which deletes
enrollments and member rows (D13), the note links, preview state and client events that name old lesson ids (D42),
drops the 13 replaced tables and the old columns, and makes `Lesson.programId` and `position` NOT NULL.

## Before you start

- Any other feature's `migrate diff` run before the cutover will try to emit these drops, because the YAML no longer
  has the old models. Do not run one. `test/text-activity-cutover.test.ts` fails if a drop reaches
  `server/atlas/migrations/` early (D27, D30).
- The old routes stay writable until the drop, so keep the window between step 6 and step 8 short (D38).

## Steps, in order

1. **`pg_dump` production and verify it.**
   `pg_dump --format=custom --file=makeready-precutover.dump "$PROD_DATABASE_URL"`. Restore it into a scratch
   database (`createdb makeready_verify && pg_restore --no-owner -d makeready_verify makeready-precutover.dump`) and
   compare row counts of `study_programs`, `lessons`, `lesson_activities`, `activity_read_blocks`, `enrollments`,
   `users` and `media` against production. Do not continue until they match. Keep the dump: it is the undo.
2. **Restore to a scratch database** for the dry run: restore the same dump into `makeready_cutover_dry`.
3. **`content-export` dry run** against that scratch database, writing into a new directory:
   `DATABASE_URL=<scratch url> npx tsx scripts/content-export.ts --out ~/cutover/run1`.
4. **Read the report** at `~/cutover/run1/report.md`: counts by program, old type and new kind, everything converted
   with loss, unresolved media references. Spot-check three converted programs in the iPhone viewer (SPEC
   verification item 9). Rehearse the import against a second scratch restore if you want to see conflicts:
   `DATABASE_URL=<scratch url> npx tsx scripts/content-import.ts --bundle ~/cutover/run1/bundle.json`.
5. **Deploy this branch.** The additive migrations (new tables and nullable columns) run at boot. The old tables
   still exist and the old data is untouched.
6. **`content-export` and `content-import` against production**, immediately before the drop (D38), with the
   production flag. Re-export into the same `--out` directory as the dry run (`~/cutover/run1`), or pass
   `--ledger ~/cutover/run1/import-ledger.json` to the import, so the import's ledger of recorded hashes is found; without it
   every changed activity is reported as a conflict and the import warns `no ledger`. A re-run upserts by
   `activityKey` and updates published version 1 in place; a draft edited in the new model since the last import is
   kept and listed as a conflict.
   ```
   DATABASE_URL=<production url> npx tsx scripts/content-export.ts --out ~/cutover/run1 --confirm-production
   DATABASE_URL=<production url> npx tsx scripts/content-import.ts --bundle ~/cutover/run1/bundle.json --confirm-production
   ```
   Read `~/cutover/run1/import-report.md`. Resolve any conflicts you care about before going on.
7. **Move the cutover file into the migrations folder and re-hash.**
   `git mv server/atlas/cutover/20261107233000_text_activity_cutover.sql server/atlas/migrations/`, then
   `cd server/atlas && ../scripts/atlas.sh migrate hash --dir file://migrations` (this updates `atlas.sum`). Commit.
8. **Deploy.** Boot runs `migrate apply`, which applies the cutover in one transaction. Client member lesson pages and
   `/admin` activity pages fail from here until the member rebuild (D7).
9. **Check**: open a converted program in the iPhone editor and viewer; confirm `GET /api/programs/:id` lists its lessons.

## Undo

Restore the step 1 dump into the production database (stop the server first). There is no down migration; the drop
cannot be reversed any other way.
