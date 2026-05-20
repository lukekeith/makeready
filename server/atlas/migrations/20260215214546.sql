-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "isHelpEnabled" boolean NOT NULL DEFAULT true;
-- Set comment to column: "isHelpEnabled" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."isHelpEnabled" IS 'Whether help info (helpTitle/helpDescription) is shown to members';
