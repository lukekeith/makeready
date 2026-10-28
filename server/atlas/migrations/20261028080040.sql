-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD COLUMN "isPrivate" boolean NOT NULL DEFAULT false, ADD COLUMN "ageRangeMin" integer NULL, ADD COLUMN "ageRangeMax" integer NULL, ADD COLUMN "maxMembers" integer NULL, ADD COLUMN "memberDirectoryAccess" "DirectoryAccess" NOT NULL DEFAULT 'ALLOWED', ADD COLUMN "coverOriginalUrl" text NULL, ADD COLUMN "coverFraming" jsonb NULL;
-- ui2-programs D12: "leaderId" takes the type "users"."id" actually has. A database built by these
-- migrations has uuid ids; one created by Prisma before Atlas (the Prisma-era dev/prod schema) has
-- text ids, and a uuid column could not reference it (42804). Same column either way.
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format('ALTER TABLE "study_programs" ADD COLUMN "leaderId" %s NULL', id_type);
END $$;
ALTER TABLE "study_programs" ADD CONSTRAINT "fk_study_programs_leader" FOREIGN KEY ("leaderId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_study_programs_leaderId" to table: "study_programs"
CREATE INDEX "idx_study_programs_leaderId" ON "study_programs" ("leaderId");
-- Set comment to column: "isPrivate" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."isPrivate" IS 'ui2-programs D12/D13: hidden from other leaders'' program lists (discovery only)';
-- Set comment to column: "ageRangeMin" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."ageRangeMin" IS 'ui2-programs D12: advisory';
-- Set comment to column: "ageRangeMax" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."ageRangeMax" IS 'ui2-programs D12: advisory';
-- Set comment to column: "maxMembers" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."maxMembers" IS 'ui2-programs D12: advisory';
-- Set comment to column: "memberDirectoryAccess" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."memberDirectoryAccess" IS 'ui2-programs D12: stored and returned, not enforced';
-- Set comment to column: "leaderId" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."leaderId" IS 'ui2-programs D12: one assignable leader, defaults to the creator';
-- Set comment to column: "coverOriginalUrl" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."coverOriginalUrl" IS 'ui2-programs D11: the full original cover photo; null means Edit reopens coverImageUrl';
-- Set comment to column: "coverFraming" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."coverFraming" IS 'ui2-programs D11: {scale, rotation, offsetX, offsetY} the cover was rendered with';
-- ui2-programs D12: every existing program is led by its creator.
UPDATE "study_programs" SET "leaderId" = "creatorId" WHERE "leaderId" IS NULL;
