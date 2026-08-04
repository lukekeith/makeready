-- HAND-AUTHORED, replacing Atlas's generated version. Feature `highlighting`, phase 2, task 2.2.
--
-- WHY THIS FILE WAS REWRITTEN (2026-08-04):
-- `atlas migrate diff` does not detect table renames. It emitted
--     CREATE TABLE "content_highlights" (...);
--     DROP TABLE "exegesis_highlights";
-- which would have destroyed every existing leader-authored highlight and note in the database.
-- That directly violates governing rule 1 of docs/features/highlighting/ ("no existing highlight
-- may be lost or altered") and is the exact hazard 03-data-and-api.md §1.3 flags for M1.
-- The generated statements are replaced below with in-place ALTERs that preserve every row.
--
-- This is M1 (rename) + M2 (add `style`) from 03 §1.3. It moves NO data — the Read backfill is
-- M3, in phase 3.
--
-- Column types are deliberately NOT changed. The live table stores `id`/`readBlockId` as `text`
-- and timestamps as `timestamp(3)` (Prisma-era), whereas the generated HCL describes `uuid` and
-- `timestamp`. That drift pre-dates this feature and is not this migration's business to resolve;
-- reconciling it would rewrite every row. Recorded at docs/features/highlighting/09 §G-g.

-- WHY EVERY STATEMENT IS CONDITIONAL:
-- The constraint and index identifiers on this table differ between environments. The LIVE
-- databases were created by the Prisma era and carry Prisma's names
-- (`exegesis_highlights_readBlockId_fkey`, `..._readBlockId_idx`), whereas replaying this
-- migration directory from scratch produces Atlas's names (`fk_exegesis_highlights_readBlock`,
-- `idx_exegesis_highlights_readBlockId`) — see 20260510032114.sql. A first attempt hardcoded the
-- live names; it applied fine but broke `atlas migrate diff`, which replays the directory into a
-- scratch database and therefore hit the Atlas-named variants. Each rename below accepts EITHER
-- ancestor and is a no-op once already applied, so this file is safe against a live database, a
-- from-scratch replay, and a re-run. Recorded at docs/features/highlighting/09 §G-h.

-- M1 ── rename the table in place. Every row, index and constraint survives.
DO $$
BEGIN
  IF to_regclass('public.exegesis_highlights') IS NOT NULL THEN
    ALTER TABLE "exegesis_highlights" RENAME TO "content_highlights";
  END IF;
END $$;

-- M1 ── Postgres keeps the old identifiers through a table rename, so bring them in line with the
-- names the generated schema expects. Renames only; nothing is dropped or recreated.
DO $$
DECLARE
  target  text;
  found   text;
  pair    text[];
BEGIN
  FOREACH pair SLICE 1 IN ARRAY ARRAY[
    ['content_highlights_readBlockId_orderNumber_key', 'exegesis_highlights_readBlockId_orderNumber_key'],
    ['content_highlights_readBlockId_start_end_key',   'exegesis_highlights_readBlockId_start_end_key'],
    ['fk_content_highlights_readBlock',                'exegesis_highlights_readBlockId_fkey'],
    ['fk_content_highlights_readBlock',                'fk_exegesis_highlights_readBlock']
  ]
  LOOP
    target := pair[1];
    SELECT conname INTO found
      FROM pg_constraint
     WHERE conrelid = 'public.content_highlights'::regclass
       AND conname  = pair[2];
    IF found IS NOT NULL THEN
      EXECUTE format('ALTER TABLE "content_highlights" RENAME CONSTRAINT %I TO %I', found, target);
    END IF;
  END LOOP;
END $$;

DO $$
DECLARE
  target text;
  pair   text[];
BEGIN
  FOREACH pair SLICE 1 IN ARRAY ARRAY[
    ['content_highlights_pkey',                        'exegesis_highlights_pkey'],
    ['idx_content_highlights_readBlockId',             'exegesis_highlights_readBlockId_idx'],
    ['idx_content_highlights_readBlockId',             'idx_exegesis_highlights_readBlockId'],
    ['idx_content_highlights_readBlockId_orderNumber', 'exegesis_highlights_readBlockId_orderNumber_idx'],
    ['idx_content_highlights_readBlockId_orderNumber', 'idx_exegesis_highlights_readBlockId_orderNumber']
  ]
  LOOP
    target := pair[1];
    IF to_regclass('public.' || quote_ident(pair[2])) IS NOT NULL THEN
      EXECUTE format('ALTER INDEX %I RENAME TO %I', pair[2], target);
    END IF;
  END LOOP;
END $$;

-- M2 ── add `style`. NOT NULL with a default, so Postgres backfills every pre-existing row to
-- 'highlight' and each one keeps exactly today's appearance.
-- `character varying` (not `text`) because the YAML says `type: string`, which the generator maps
-- to varchar; using `text` here left a permanent one-line drift that `schema:diff` re-proposed on
-- every run. The ALTER below is a no-op once aligned and keeps a re-run honest.
ALTER TABLE "content_highlights" ADD COLUMN IF NOT EXISTS "style" character varying NOT NULL DEFAULT 'highlight';
ALTER TABLE "content_highlights" ALTER COLUMN "style" TYPE character varying;

-- Column documentation.
COMMENT ON COLUMN "content_highlights"."readBlockId" IS 'FK to ActivityReadBlock (locked scripture block) that this highlight applies to';
COMMENT ON COLUMN "content_highlights"."orderNumber" IS 'Stable ordering for highlight navigation';
COMMENT ON COLUMN "content_highlights"."start" IS 'Start character offset (plain-text) into the block content';
COMMENT ON COLUMN "content_highlights"."end" IS 'End character offset (exclusive)';
COMMENT ON COLUMN "content_highlights"."noteMarkdown" IS 'Leader-authored markdown shown to members when they open the highlight';
COMMENT ON COLUMN "content_highlights"."style" IS 'How the span renders: ''highlight'' (background wash) or ''bold'' (font weight only, no wash). Defaults to ''highlight'' so every pre-existing row keeps today''s appearance.';

-- `ActivityReadBlock.selections` becomes a derived projection. Column unchanged — comment only.
COMMENT ON COLUMN "activity_read_blocks"."selections" IS 'DERIVED / READ-ONLY. Array of styled text spans {start, end, style}, regenerated from the ContentHighlight rows for this block by syncSelectionsForBlock — which is the ONLY writer. Do not write it from a route, a service or a client; write ContentHighlight rows instead. Retained because shipped iPhone builds and the web lesson player still read it, and because lesson-content-hash.ts hashes it (changing its serialisation restales every enrolled group''s lessons). See docs/features/highlighting/03-data-and-api.md §3.';
