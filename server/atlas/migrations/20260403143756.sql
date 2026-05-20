-- Create "api_bible_versions" table
CREATE TABLE IF NOT EXISTS "api_bible_versions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "apiBibleId" character varying NOT NULL,
  "abbreviation" character varying NOT NULL,
  "name" character varying NOT NULL,
  "language" character varying NOT NULL DEFAULT 'eng',
  "description" character varying NULL,
  "copyright" text NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "cachedAt" timestamp NOT NULL DEFAULT now(),
  "expiresAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "api_bible_versions_apiBibleId_key" UNIQUE ("apiBibleId")
);
-- Create index "idx_api_bible_versions_abbreviation" to table: "api_bible_versions"
CREATE INDEX IF NOT EXISTS "idx_api_bible_versions_abbreviation" ON "api_bible_versions" ("abbreviation");
-- Create index "idx_api_bible_versions_expiresAt" to table: "api_bible_versions"
CREATE INDEX IF NOT EXISTS "idx_api_bible_versions_expiresAt" ON "api_bible_versions" ("expiresAt");
-- Create index "idx_api_bible_versions_isActive" to table: "api_bible_versions"
CREATE INDEX IF NOT EXISTS "idx_api_bible_versions_isActive" ON "api_bible_versions" ("isActive");
-- Create index "idx_api_bible_versions_language" to table: "api_bible_versions"
CREATE INDEX IF NOT EXISTS "idx_api_bible_versions_language" ON "api_bible_versions" ("language");
-- Set comment to column: "apiBibleId" on table: "api_bible_versions"
COMMENT ON COLUMN "api_bible_versions"."apiBibleId" IS 'e.g. a761ca71e0b3ddcf-01';
-- Set comment to column: "abbreviation" on table: "api_bible_versions"
COMMENT ON COLUMN "api_bible_versions"."abbreviation" IS 'e.g. NASB, KJV';
-- Set comment to column: "name" on table: "api_bible_versions"
COMMENT ON COLUMN "api_bible_versions"."name" IS 'e.g. New American Standard Bible 2020';
-- Set comment to column: "expiresAt" on table: "api_bible_versions"
COMMENT ON COLUMN "api_bible_versions"."expiresAt" IS 'cachedAt + 24h';
-- Create "bible_content_cache" table
CREATE TABLE IF NOT EXISTS "bible_content_cache" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "cacheKey" character varying NOT NULL,
  "bibleId" character varying NOT NULL,
  "contentType" character varying NOT NULL,
  "responseJson" text NOT NULL,
  "copyright" text NULL,
  "verseCount" integer NOT NULL DEFAULT 0,
  "cachedAt" timestamp NOT NULL DEFAULT now(),
  "expiresAt" timestamp NOT NULL,
  "accessCount" integer NOT NULL DEFAULT 0,
  "lastAccessed" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "bible_content_cache_cacheKey_key" UNIQUE ("cacheKey")
);
-- Create index "idx_bible_content_cache_accessCount" to table: "bible_content_cache"
CREATE INDEX IF NOT EXISTS "idx_bible_content_cache_accessCount" ON "bible_content_cache" ("accessCount");
-- Create index "idx_bible_content_cache_bibleId_contentType" to table: "bible_content_cache"
CREATE INDEX IF NOT EXISTS "idx_bible_content_cache_bibleId_contentType" ON "bible_content_cache" ("bibleId", "contentType");
-- Create index "idx_bible_content_cache_expiresAt" to table: "bible_content_cache"
CREATE INDEX IF NOT EXISTS "idx_bible_content_cache_expiresAt" ON "bible_content_cache" ("expiresAt");
-- Set comment to column: "cacheKey" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."cacheKey" IS 'chapter:{bibleId}:{chapterId}';
-- Set comment to column: "bibleId" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."bibleId" IS 'API.Bible bibleId';
-- Set comment to column: "contentType" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."contentType" IS 'chapter, verse, passage';
-- Set comment to column: "responseJson" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."responseJson" IS 'JSON string of parsed verse data';
-- Set comment to column: "expiresAt" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."expiresAt" IS 'cachedAt + 14 days';
-- Set comment to column: "accessCount" on table: "bible_content_cache"
COMMENT ON COLUMN "bible_content_cache"."accessCount" IS 'Track popularity for re-warming';
-- Create "user_preferences" table
CREATE TABLE IF NOT EXISTS "user_preferences" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NULL,
  "memberId" uuid NULL,
  "key" character varying NOT NULL,
  "value" character varying NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_preferences_memberId_key_key" UNIQUE ("memberId", "key"),
  CONSTRAINT "user_preferences_userId_key_key" UNIQUE ("userId", "key"),
  CONSTRAINT "fk_user_preferences_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_user_preferences_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_user_preferences_memberId" to table: "user_preferences"
CREATE INDEX IF NOT EXISTS "idx_user_preferences_memberId" ON "user_preferences" ("memberId");
-- Create index "idx_user_preferences_userId" to table: "user_preferences"
CREATE INDEX IF NOT EXISTS "idx_user_preferences_userId" ON "user_preferences" ("userId");
-- Set comment to column: "key" on table: "user_preferences"
COMMENT ON COLUMN "user_preferences"."key" IS 'bible_translation, theme, etc.';
-- Set comment to column: "value" on table: "user_preferences"
COMMENT ON COLUMN "user_preferences"."value" IS 'Plain string or JSON';
