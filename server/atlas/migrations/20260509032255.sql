-- Modify "lesson_activities" table
ALTER TABLE "lesson_activities" ADD COLUMN "estimatedSeconds" integer NULL;
-- Set comment to column: "estimatedSeconds" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."estimatedSeconds" IS 'Calculated time estimate in seconds for this activity';
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "estimatedSeconds" integer NULL;
-- Set comment to column: "estimatedSeconds" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."estimatedSeconds" IS 'Calculated time estimate in seconds for this activity';
