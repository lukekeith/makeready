-- master-search SC1: userId takes the type "users"."id" actually has (text on dev/prod, uuid on a migrations-only database).
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format('CREATE TABLE "search_recent_results" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "userId" %1$s NOT NULL, "resourceType" character varying NOT NULL, "resourceId" character varying NOT NULL, "openedAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "fk_search_recent_results_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE)', id_type);
END $$;
CREATE UNIQUE INDEX "search_recent_results_userId_resourceType_resourceId_key" ON "search_recent_results" ("userId", "resourceType", "resourceId");
CREATE INDEX "search_recent_results_userId_openedAt_idx" ON "search_recent_results" ("userId", "openedAt");
