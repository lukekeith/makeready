-- Create "search_history" table
CREATE TABLE IF NOT EXISTS "search_history" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NULL,
  "memberId" uuid NULL,
  "query" character varying NOT NULL,
  "searchType" character varying NOT NULL DEFAULT 'bible',
  "resultCount" integer NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_search_history_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_search_history_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_search_history_memberId_createdAt" to table: "search_history"
CREATE INDEX IF NOT EXISTS "idx_search_history_memberId_createdAt" ON "search_history" ("memberId", "createdAt");
-- Create index "idx_search_history_searchType" to table: "search_history"
CREATE INDEX IF NOT EXISTS "idx_search_history_searchType" ON "search_history" ("searchType");
-- Create index "idx_search_history_userId_createdAt" to table: "search_history"
CREATE INDEX IF NOT EXISTS "idx_search_history_userId_createdAt" ON "search_history" ("userId", "createdAt");
-- Set comment to column: "query" on table: "search_history"
COMMENT ON COLUMN "search_history"."query" IS 'The search query text';
-- Set comment to column: "searchType" on table: "search_history"
COMMENT ON COLUMN "search_history"."searchType" IS 'bible, media, program, etc.';
-- Set comment to column: "resultCount" on table: "search_history"
COMMENT ON COLUMN "search_history"."resultCount" IS 'Number of results returned';
