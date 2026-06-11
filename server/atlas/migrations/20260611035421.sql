-- Re-enable pgvector (extension was previously dropped in 20260217233435)
CREATE EXTENSION IF NOT EXISTS "vector";
-- Modify "verses" table
ALTER TABLE "verses" ADD COLUMN "embedding" vector(384) NULL;
-- Set comment to column: "embedding" on table: "verses"
COMMENT ON COLUMN "verses"."embedding" IS 'Semantic search embedding (bge-small-en-v1.5, WEB translation only)';
-- Build HNSW in-process: parallel builds need a ~64MB dynamic shared memory
-- segment, which exceeds Railway Postgres containers' /dev/shm.
SET max_parallel_maintenance_workers = 0;
-- HNSW cosine index; rows with NULL embedding (non-WEB translations) are excluded automatically
CREATE INDEX "verses_embedding_hnsw_idx" ON "verses" USING hnsw ("embedding" vector_cosine_ops) WITH (m = 16, ef_construction = 64);
