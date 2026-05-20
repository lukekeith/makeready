-- Set comment to column: "url" on table: "event_attachments"
COMMENT ON COLUMN "event_attachments"."url" IS 'R2 storage URL';
-- Set comment to column: "coverImageUrl" on table: "events"
COMMENT ON COLUMN "events"."coverImageUrl" IS 'R2 storage URL';
-- Remove pgvector: drop embedding column, semantic search function, and extension
ALTER TABLE "verses" DROP COLUMN "embedding";
DROP FUNCTION IF EXISTS semantic_search_verses;
DROP EXTENSION IF EXISTS vector;
