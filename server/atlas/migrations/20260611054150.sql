-- Create "bible_passages" table
CREATE TABLE "bible_passages" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "bookNumber" integer NOT NULL, "chapter" integer NOT NULL, "verseStart" integer NOT NULL, "verseEnd" integer NOT NULL, "title" character varying NOT NULL, "summary" text NOT NULL, "themes" text[] NOT NULL, "openingText" text NOT NULL, "embedding" vector(384) NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "bible_passages_bookNumber_chapter_verseStart_verseEnd_key" UNIQUE ("bookNumber", "chapter", "verseStart", "verseEnd"));
-- Create index "idx_bible_passages_bookNumber_chapter" to table: "bible_passages"
CREATE INDEX "idx_bible_passages_bookNumber_chapter" ON "bible_passages" ("bookNumber", "chapter");
-- Set comment to column: "title" on table: "bible_passages"
COMMENT ON COLUMN "bible_passages"."title" IS 'Pericope title, e.g. ''The Parable of the Prodigal Son''';
-- Set comment to column: "summary" on table: "bible_passages"
COMMENT ON COLUMN "bible_passages"."summary" IS '1-2 sentence summary of the passage';
-- Set comment to column: "themes" on table: "bible_passages"
COMMENT ON COLUMN "bible_passages"."themes" IS 'Theme keywords, e.g. repentance, fatherly love';
-- Set comment to column: "openingText" on table: "bible_passages"
COMMENT ON COLUMN "bible_passages"."openingText" IS 'First 1-2 verses (WEB) used as the result snippet';
-- Set comment to column: "embedding" on table: "bible_passages"
COMMENT ON COLUMN "bible_passages"."embedding" IS 'Embedding of the concept card (title + summary + themes)';
-- HNSW cosine index (hand-managed: Atlas community can't express HNSW in HCL)
CREATE INDEX "bible_passages_embedding_hnsw_idx" ON "bible_passages" USING hnsw ("embedding" vector_cosine_ops) WITH (m = 16, ef_construction = 64);
