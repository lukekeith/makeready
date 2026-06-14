-- Create "passage_queries" table
CREATE TABLE "passage_queries" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "biblePassageId" uuid NOT NULL, "text" text NOT NULL, "embedding" vector(384) NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "passage_queries_biblePassageId_text_key" UNIQUE ("biblePassageId", "text"), CONSTRAINT "fk_passage_queries_biblePassage" FOREIGN KEY ("biblePassageId") REFERENCES "bible_passages" ("id") ON UPDATE NO ACTION ON DELETE CASCADE);
-- Create index "idx_passage_queries_biblePassageId" to table: "passage_queries"
CREATE INDEX "idx_passage_queries_biblePassageId" ON "passage_queries" ("biblePassageId");
-- Set comment to column: "text" on table: "passage_queries"
COMMENT ON COLUMN "passage_queries"."text" IS 'LLM-generated question the passage answers (doc2query)';
-- Set comment to column: "embedding" on table: "passage_queries"
COMMENT ON COLUMN "passage_queries"."embedding" IS 'Embedding of the generated question (bge-small-en-v1.5)';
-- Build HNSW in-process: parallel builds need a ~64MB dynamic shared memory
-- segment, which exceeds Railway Postgres containers' /dev/shm.
SET max_parallel_maintenance_workers = 0;
-- HNSW cosine index (hand-managed: Atlas community can't express HNSW in HCL)
CREATE INDEX "passage_queries_embedding_hnsw_idx" ON "passage_queries" USING hnsw ("embedding" vector_cosine_ops) WITH (m = 16, ef_construction = 64);
