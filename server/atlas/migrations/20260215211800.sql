-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD COLUMN "isPublished" boolean NOT NULL DEFAULT false;
-- Set comment to column: "isPublished" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."isPublished" IS 'Only published programs can be enrolled';
-- Data migration: existing active programs should be published (they were already enrollable)
UPDATE "study_programs" SET "isPublished" = true WHERE "isActive" = true;
