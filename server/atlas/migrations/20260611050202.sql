-- Create "verse_windows" table
CREATE TABLE "verse_windows" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "translationId" uuid NOT NULL, "bookNumber" integer NOT NULL, "chapter" integer NOT NULL, "verseStart" integer NOT NULL, "verseEnd" integer NOT NULL, "text" text NOT NULL, "embedding" vector(384) NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "verse_windows_translationId_bookNumber_chapter_verseStart_verse" UNIQUE ("translationId", "bookNumber", "chapter", "verseStart", "verseEnd"), CONSTRAINT "fk_verse_windows_translation" FOREIGN KEY ("translationId") REFERENCES "translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE);
-- Create index "idx_verse_windows_translationId_bookNumber_chapter" to table: "verse_windows"
CREATE INDEX "idx_verse_windows_translationId_bookNumber_chapter" ON "verse_windows" ("translationId", "bookNumber", "chapter");
-- Set comment to column: "text" on table: "verse_windows"
COMMENT ON COLUMN "verse_windows"."text" IS 'Concatenated verse texts for the window';
-- Set comment to column: "embedding" on table: "verse_windows"
COMMENT ON COLUMN "verse_windows"."embedding" IS 'Semantic search embedding for multi-verse concepts';
-- HNSW cosine index (hand-managed: Atlas community can't express HNSW in HCL)
CREATE INDEX "verse_windows_embedding_hnsw_idx" ON "verse_windows" USING hnsw ("embedding" vector_cosine_ops) WITH (m = 16, ef_construction = 64);
