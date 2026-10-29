-- Create enum type "LessonAccess"
CREATE TYPE "LessonAccess" AS ENUM ('ONE_AT_A_TIME', 'ALL_AT_ONCE');
-- Modify "enrollments" table
ALTER TABLE "enrollments" ADD COLUMN "lessonAccess" "LessonAccess" NOT NULL DEFAULT 'ALL_AT_ONCE';
-- Set comment to column: "lessonAccess" on table: "enrollments"
COMMENT ON COLUMN "enrollments"."lessonAccess" IS 'When lessons open to members: ONE_AT_A_TIME on each lesson''s day, ALL_AT_ONCE from the start (ui2-enrollment-create D4)';
