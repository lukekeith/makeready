-- Add isPublished column to study_programs table
ALTER TABLE "study_programs" ADD COLUMN IF NOT EXISTS "isPublished" BOOLEAN NOT NULL DEFAULT false;
