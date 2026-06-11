-- Set comment to column: "url" on table: "event_attachments"
COMMENT ON COLUMN "event_attachments"."url" IS 'R2 storage URL';
-- Set comment to column: "coverImageUrl" on table: "events"
COMMENT ON COLUMN "events"."coverImageUrl" IS 'R2 storage URL';
-- Remove unused embedding column and semantic search function
-- (extension drop removed 2026-06: pgvector re-introduced for Bible concept search;
--  Atlas dev-template replay requires the extension to survive this migration)
ALTER TABLE "verses" DROP COLUMN "embedding";
DROP FUNCTION IF EXISTS semantic_search_verses;
