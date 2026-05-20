-- Add isHelpEnabled to lesson_activities (matches existing field on scheduled_lesson_activities)
ALTER TABLE "lesson_activities"
  ADD COLUMN IF NOT EXISTS "isHelpEnabled" BOOLEAN NOT NULL DEFAULT true;
