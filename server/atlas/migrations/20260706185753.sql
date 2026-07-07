-- Modify "lesson_schedules" table
ALTER TABLE "lesson_schedules" DROP CONSTRAINT "fk_lesson_schedules_lesson", ALTER COLUMN "lessonId" DROP NOT NULL, ADD CONSTRAINT "fk_lesson_schedules_lesson" FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "lessonId" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."lessonId" IS 'Source curriculum lesson; null after that lesson is deleted from the curriculum (the schedule owns its content — deletion reaches enrollments only via publish+sync, never by cascade)';
