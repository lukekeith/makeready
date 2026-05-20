-- Modify "api_bible_versions" table
ALTER TABLE "api_bible_versions" ADD COLUMN "popularity" integer NOT NULL DEFAULT 0;
-- Create index "idx_api_bible_versions_popularity" to table: "api_bible_versions"
CREATE INDEX "idx_api_bible_versions_popularity" ON "api_bible_versions" ("popularity");
-- Set comment to column: "popularity" on table: "api_bible_versions"
COMMENT ON COLUMN "api_bible_versions"."popularity" IS 'Popularity score (100=most popular). Based on ECPA bestseller rankings.';
