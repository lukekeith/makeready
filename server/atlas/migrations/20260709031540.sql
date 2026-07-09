-- Create "ai_lesson_summaries" table
CREATE TABLE "ai_lesson_summaries" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "memberId" uuid NOT NULL, "lessonScheduleId" uuid NOT NULL, "lessonSummary" text NOT NULL, "memberSummary" text NULL, "model" character varying NOT NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "ai_lesson_summaries_memberId_lessonScheduleId_key" UNIQUE ("memberId", "lessonScheduleId"), CONSTRAINT "fk_ai_lesson_summaries_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, CONSTRAINT "fk_ai_lesson_summaries_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE);
-- Create index "idx_ai_lesson_summaries_createdAt" to table: "ai_lesson_summaries"
CREATE INDEX "idx_ai_lesson_summaries_createdAt" ON "ai_lesson_summaries" ("createdAt");
-- Create index "idx_ai_lesson_summaries_lessonScheduleId" to table: "ai_lesson_summaries"
CREATE INDEX "idx_ai_lesson_summaries_lessonScheduleId" ON "ai_lesson_summaries" ("lessonScheduleId");
-- Create index "idx_ai_lesson_summaries_memberId" to table: "ai_lesson_summaries"
CREATE INDEX "idx_ai_lesson_summaries_memberId" ON "ai_lesson_summaries" ("memberId");
-- Set comment to column: "lessonSummary" on table: "ai_lesson_summaries"
COMMENT ON COLUMN "ai_lesson_summaries"."lessonSummary" IS 'AI-generated summary of the lesson and its contents';
-- Set comment to column: "memberSummary" on table: "ai_lesson_summaries"
COMMENT ON COLUMN "ai_lesson_summaries"."memberSummary" IS 'AI-generated summary of what the member learned from their input; null when the member entered nothing substantive (kept null for analytics)';
-- Set comment to column: "model" on table: "ai_lesson_summaries"
COMMENT ON COLUMN "ai_lesson_summaries"."model" IS 'Claude model ID that generated the summaries';
