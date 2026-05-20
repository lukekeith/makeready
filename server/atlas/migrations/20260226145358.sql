-- Add "title" column to "lessons" table
ALTER TABLE "lessons" ADD COLUMN "title" character varying NULL;
-- Set comment to column: "title" on table: "lessons"
COMMENT ON COLUMN "lessons"."title" IS 'Optional display title for lesson card';
-- Add "title" column to "lesson_schedules" table
ALTER TABLE "lesson_schedules" ADD COLUMN "title" character varying NULL;
-- Set comment to column: "title" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."title" IS 'Display title for lesson card (copied from Lesson)';
