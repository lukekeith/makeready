-- Create "study_program_tags" table
CREATE TABLE "study_program_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "studyProgramId" uuid NOT NULL,
  "tag" character varying NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "study_program_tags_studyProgramId_tag_key" UNIQUE ("studyProgramId", "tag"),
  CONSTRAINT "fk_study_program_tags_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_study_program_tags_studyProgramId" to table: "study_program_tags"
CREATE INDEX "idx_study_program_tags_studyProgramId" ON "study_program_tags" ("studyProgramId");
-- Create index "idx_study_program_tags_tag" to table: "study_program_tags"
CREATE INDEX "idx_study_program_tags_tag" ON "study_program_tags" ("tag");
-- Set comment to column: "tag" on table: "study_program_tags"
COMMENT ON COLUMN "study_program_tags"."tag" IS 'Lowercase, trimmed tag string';
