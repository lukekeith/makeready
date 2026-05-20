-- Create "member_lesson_progress" table
CREATE TABLE "member_lesson_progress" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NOT NULL,
  "lessonScheduleId" uuid NOT NULL,
  "startedAt" timestamp NOT NULL DEFAULT now(),
  "completedAt" timestamp NULL,
  "lastUpdatedAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "member_lesson_progress_memberId_lessonScheduleId_key" UNIQUE ("memberId", "lessonScheduleId"),
  CONSTRAINT "fk_member_lesson_progress_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_lesson_progress_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_member_lesson_progress_lessonScheduleId" to table: "member_lesson_progress"
CREATE INDEX "idx_member_lesson_progress_lessonScheduleId" ON "member_lesson_progress" ("lessonScheduleId");
-- Create index "idx_member_lesson_progress_memberId" to table: "member_lesson_progress"
CREATE INDEX "idx_member_lesson_progress_memberId" ON "member_lesson_progress" ("memberId");
-- Create index "idx_member_lesson_progress_memberId_completedAt" to table: "member_lesson_progress"
CREATE INDEX "idx_member_lesson_progress_memberId_completedAt" ON "member_lesson_progress" ("memberId", "completedAt");
-- Set comment to column: "completedAt" on table: "member_lesson_progress"
COMMENT ON COLUMN "member_lesson_progress"."completedAt" IS 'Set when all activities in the lesson are complete';
