-- master-search SC1: userId takes the type "users"."id" actually has (text on dev/prod, uuid on a migrations-only database).
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format('CREATE TABLE "search_recent_results" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "userId" %1$s NOT NULL, "resourceType" character varying NOT NULL, "resourceId" character varying NOT NULL, "openedAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "fk_search_recent_results_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE)', id_type);
END $$;
CREATE UNIQUE INDEX "idx_search_recent_results_userId_resourceType_resourceId" ON "search_recent_results" ("userId", "resourceType", "resourceId");
CREATE INDEX "idx_search_recent_results_userId_openedAt" ON "search_recent_results" ("userId", "openedAt");
COMMENT ON COLUMN "search_recent_results"."resourceType" IS 'A SearchType (PROGRAM, TEMPLATE, MEMBER, GROUP, LESSON, EVENT, POST, VIDEO, PHOTO)';
COMMENT ON COLUMN "search_recent_results"."resourceId" IS 'Id of the opened resource; spans tables, so no FK';
