-- Modify "study_notes" table
ALTER TABLE "study_notes" ADD COLUMN "title" character varying NULL, ADD COLUMN "preview" character varying NULL;
-- Create index "idx_study_notes_userId_updatedAt" to table: "study_notes"
CREATE INDEX "idx_study_notes_userId_updatedAt" ON "study_notes" ("userId", "updatedAt");
