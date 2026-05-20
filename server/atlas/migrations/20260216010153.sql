-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD COLUMN "publishedAt" timestamp NULL;
-- Set comment to column: "publishedAt" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."publishedAt" IS 'When the program was first published';
