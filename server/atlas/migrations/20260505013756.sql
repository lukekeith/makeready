-- Modify "lesson_schedules" table
ALTER TABLE "lesson_schedules" ADD COLUMN "estimatedMinutes" integer NULL;
-- Set comment to column: "estimatedMinutes" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."estimatedMinutes" IS 'Snapshot of time estimate at enrollment time';
-- Modify "lessons" table
ALTER TABLE "lessons" ADD COLUMN "estimatedMinutes" integer NULL;
-- Set comment to column: "estimatedMinutes" on table: "lessons"
COMMENT ON COLUMN "lessons"."estimatedMinutes" IS 'Calculated time estimate in minutes for all activities';
