-- =============================================================================
-- Template-Based Lesson Architecture Migration
-- =============================================================================
-- This migration:
-- 1. Clears existing study program data (mostly test/seed data)
-- 2. Drops deprecated columns and enums
-- 3. Creates new template system tables and columns
-- 4. Seeds system templates (SOAP, OIA, DBS, HEAR, Video Study)
-- =============================================================================

-- Step 1: Clear existing study data (CASCADE handles FK dependencies)
TRUNCATE member_activity_progress, member_video_progress, member_lesson_progress,
         lesson_schedules, enrollments, lesson_activities, lessons, study_programs,
         activity_type_configs CASCADE;

-- Step 2: Drop old columns that reference enums about to be dropped

-- lesson_activities: drop old enum-typed and scripture columns
ALTER TABLE "lesson_activities"
  DROP COLUMN "type",
  DROP COLUMN "status",
  DROP COLUMN "highlightMode",
  DROP COLUMN "passageReference",
  DROP COLUMN "bookNumber",
  DROP COLUMN "bookName",
  DROP COLUMN "chapterStart",
  DROP COLUMN "chapterEnd",
  DROP COLUMN "verseStart",
  DROP COLUMN "verseEnd",
  DROP COLUMN "startElementId",
  DROP COLUMN "startOffset",
  DROP COLUMN "endElementId",
  DROP COLUMN "endOffset",
  DROP COLUMN "selectedVerses";

-- study_programs: drop old defaultActivity column
ALTER TABLE "study_programs" DROP COLUMN "defaultActivity";

-- member_activity_progress: drop old step tracking columns
ALTER TABLE "member_activity_progress"
  DROP COLUMN "currentStep",
  DROP COLUMN "completedSteps";

-- Step 3: Drop old enum types
DROP TYPE "ActivityStatus";
DROP TYPE "HighlightMode";

-- Drop activity_type_configs table (must be before dropping ActivityType enum)
DROP TABLE "activity_type_configs";

DROP TYPE "ActivityType";

-- Step 4: Create new enum type
CREATE TYPE "TemplateActivityType" AS ENUM ('USER_INPUT', 'READ', 'VIDEO');

-- Step 5: Add new columns to lesson_activities
ALTER TABLE "lesson_activities"
  ADD COLUMN "activityType" "TemplateActivityType" NOT NULL,
  ADD COLUMN "title" character varying NOT NULL,
  ADD COLUMN "helpTitle" character varying NULL,
  ADD COLUMN "helpDescription" text NULL,
  ADD COLUMN "helpAlwaysVisible" boolean NOT NULL DEFAULT false,
  ADD COLUMN "helpIcon" character varying NULL,
  ADD COLUMN "readContent" text NULL;
-- Set comment to column: "activityType" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."activityType" IS 'USER_INPUT, READ, VIDEO';
-- Set comment to column: "title" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."title" IS 'Activity title';
-- Set comment to column: "readContent" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."readContent" IS 'Markdown for READ activities';

-- Step 6: Create lesson_templates table
CREATE TABLE "lesson_templates" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" character varying NOT NULL,
  "description" text NULL,
  "isSystem" boolean NOT NULL DEFAULT false,
  "creatorId" uuid NULL,
  "sourceTemplateId" uuid NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_lesson_templates_creator" FOREIGN KEY ("creatorId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_lesson_templates_sourceTemplate" FOREIGN KEY ("sourceTemplateId") REFERENCES "lesson_templates" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_lesson_templates_creatorId" to table: "lesson_templates"
CREATE INDEX "idx_lesson_templates_creatorId" ON "lesson_templates" ("creatorId");
-- Create index "idx_lesson_templates_isSystem" to table: "lesson_templates"
CREATE INDEX "idx_lesson_templates_isSystem" ON "lesson_templates" ("isSystem");
-- Set comment to column: "name" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."name" IS 'e.g., ''SOAP'', ''Read & Discuss''';
-- Set comment to column: "isSystem" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."isSystem" IS 'System templates available to all';
-- Set comment to column: "creatorId" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."creatorId" IS 'NULL for system templates';
-- Set comment to column: "sourceTemplateId" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."sourceTemplateId" IS 'If duplicated from another template';

-- Step 7: Create lesson_template_activities table
CREATE TABLE "lesson_template_activities" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "templateId" uuid NOT NULL,
  "type" "TemplateActivityType" NOT NULL,
  "orderNumber" integer NOT NULL,
  "title" character varying NOT NULL,
  "helpTitle" character varying NULL,
  "helpDescription" text NULL,
  "helpAlwaysVisible" boolean NOT NULL DEFAULT false,
  "helpIcon" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "lesson_template_activities_templateId_orderNumber_key" UNIQUE ("templateId", "orderNumber"),
  CONSTRAINT "fk_lesson_template_activities_template" FOREIGN KEY ("templateId") REFERENCES "lesson_templates" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_lesson_template_activities_templateId" to table: "lesson_template_activities"
CREATE INDEX "idx_lesson_template_activities_templateId" ON "lesson_template_activities" ("templateId");
-- Set comment to column: "orderNumber" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."orderNumber" IS '1-based position';
-- Set comment to column: "title" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."title" IS 'e.g., ''Scripture'', ''Observation''';
-- Set comment to column: "helpTitle" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."helpTitle" IS 'Helper title for USER_INPUT';
-- Set comment to column: "helpDescription" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."helpDescription" IS 'Helper body for USER_INPUT';
-- Set comment to column: "helpAlwaysVisible" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."helpAlwaysVisible" IS 'Show expanded or collapsed';
-- Set comment to column: "helpIcon" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."helpIcon" IS 'Icon identifier';

-- Step 8: Modify lesson_schedules table
ALTER TABLE "lesson_schedules" ADD COLUMN "templateId" uuid NULL, ADD COLUMN "templateName" character varying NULL, ADD CONSTRAINT "fk_lesson_schedules_template" FOREIGN KEY ("templateId") REFERENCES "lesson_templates" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "templateId" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."templateId" IS 'FK to LessonTemplate for display';
-- Set comment to column: "templateName" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."templateName" IS 'Denormalized for fast card rendering';

-- Step 9: Create scheduled_lesson_activities table
CREATE TABLE "scheduled_lesson_activities" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "lessonScheduleId" uuid NOT NULL,
  "type" "TemplateActivityType" NOT NULL,
  "orderNumber" integer NOT NULL,
  "title" character varying NOT NULL,
  "helpTitle" character varying NULL,
  "helpDescription" text NULL,
  "helpAlwaysVisible" boolean NOT NULL DEFAULT false,
  "helpIcon" character varying NULL,
  "readContent" text NULL,
  "videoId" uuid NULL,
  "videoUrl" character varying NULL,
  "sourceLessonActivityId" uuid NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "scheduled_lesson_activities_lessonScheduleId_orderNumber_key" UNIQUE ("lessonScheduleId", "orderNumber"),
  CONSTRAINT "fk_scheduled_lesson_activities_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_scheduled_lesson_activities_sourceLessonActivity" FOREIGN KEY ("sourceLessonActivityId") REFERENCES "lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_scheduled_lesson_activities_video" FOREIGN KEY ("videoId") REFERENCES "videos" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_scheduled_lesson_activities_lessonScheduleId" to table: "scheduled_lesson_activities"
CREATE INDEX "idx_scheduled_lesson_activities_lessonScheduleId" ON "scheduled_lesson_activities" ("lessonScheduleId");
-- Create index "idx_scheduled_lesson_activities_sourceLessonActivityId" to table: "scheduled_lesson_activities"
CREATE INDEX "idx_scheduled_lesson_activities_sourceLessonActivityId" ON "scheduled_lesson_activities" ("sourceLessonActivityId");
-- Set comment to column: "readContent" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."readContent" IS 'Markdown for READ activities';
-- Set comment to column: "sourceLessonActivityId" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."sourceLessonActivityId" IS 'Link back to source LessonActivity for reload';

-- Step 10: Create activity_source_references table
CREATE TABLE "activity_source_references" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "lessonActivityId" uuid NULL,
  "scheduledActivityId" uuid NULL,
  "sourceType" character varying NOT NULL,
  "passageReference" character varying NULL,
  "bookNumber" integer NULL,
  "bookName" character varying NULL,
  "chapterStart" integer NULL,
  "chapterEnd" integer NULL,
  "verseStart" integer NULL,
  "verseEnd" integer NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_activity_source_references_lessonActivity" FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_activity_source_references_scheduledActivity" FOREIGN KEY ("scheduledActivityId") REFERENCES "scheduled_lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_activity_source_references_lessonActivityId" to table: "activity_source_references"
CREATE INDEX "idx_activity_source_references_lessonActivityId" ON "activity_source_references" ("lessonActivityId");
-- Create index "idx_activity_source_references_scheduledActivityId" to table: "activity_source_references"
CREATE INDEX "idx_activity_source_references_scheduledActivityId" ON "activity_source_references" ("scheduledActivityId");
-- Create index "idx_activity_source_references_sourceType" to table: "activity_source_references"
CREATE INDEX "idx_activity_source_references_sourceType" ON "activity_source_references" ("sourceType");
-- Set comment to column: "lessonActivityId" on table: "activity_source_references"
COMMENT ON COLUMN "activity_source_references"."lessonActivityId" IS 'For program lesson activities';
-- Set comment to column: "scheduledActivityId" on table: "activity_source_references"
COMMENT ON COLUMN "activity_source_references"."scheduledActivityId" IS 'For enrolled lesson activities';
-- Set comment to column: "sourceType" on table: "activity_source_references"
COMMENT ON COLUMN "activity_source_references"."sourceType" IS 'SCRIPTURE (future: URL, BOOK)';
-- Set comment to column: "passageReference" on table: "activity_source_references"
COMMENT ON COLUMN "activity_source_references"."passageReference" IS 'Romans 1:1-5';
-- Set comment to column: "bookNumber" on table: "activity_source_references"
COMMENT ON COLUMN "activity_source_references"."bookNumber" IS '1-66';

-- Step 11: Modify member_activity_progress table
DROP INDEX IF EXISTS "idx_member_activity_progress_lessonActivityId";
DROP INDEX IF EXISTS "member_activity_progress_lessonActivityId_idx";
ALTER TABLE "member_activity_progress" DROP CONSTRAINT IF EXISTS "member_activity_progress_memberId_lessonScheduleId_lessonActivi", DROP CONSTRAINT IF EXISTS "member_activity_progress_memberId_lessonScheduleId_lessonAc_key", ALTER COLUMN "lessonActivityId" DROP NOT NULL, ADD COLUMN "scheduledActivityId" uuid NULL, ADD CONSTRAINT "member_activity_progress_memberId_lessonScheduleId_scheduledAct" UNIQUE ("memberId", "lessonScheduleId", "scheduledActivityId"), ADD CONSTRAINT "fk_member_activity_progress_scheduledActivity" FOREIGN KEY ("scheduledActivityId") REFERENCES "scheduled_lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Create index "idx_member_activity_progress_scheduledActivityId" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_scheduledActivityId" ON "member_activity_progress" ("scheduledActivityId");
-- Set comment to column: "lessonActivityId" on table: "member_activity_progress"
COMMENT ON COLUMN "member_activity_progress"."lessonActivityId" IS 'Legacy FK, nullable for new records';
-- Set comment to column: "scheduledActivityId" on table: "member_activity_progress"
COMMENT ON COLUMN "member_activity_progress"."scheduledActivityId" IS 'FK to ScheduledLessonActivity';

-- Step 12: Modify member_video_progress table
DROP INDEX IF EXISTS "idx_member_video_progress_lessonActivityId";
DROP INDEX IF EXISTS "member_video_progress_lessonActivityId_idx";
ALTER TABLE "member_video_progress" DROP CONSTRAINT IF EXISTS "member_video_progress_memberId_lessonScheduleId_lessonActivityI", DROP CONSTRAINT IF EXISTS "member_video_progress_memberId_lessonScheduleId_lessonActiv_key", ALTER COLUMN "lessonActivityId" DROP NOT NULL, ADD COLUMN "scheduledActivityId" uuid NULL, ADD CONSTRAINT "member_video_progress_memberId_lessonScheduleId_scheduledActivi" UNIQUE ("memberId", "lessonScheduleId", "scheduledActivityId"), ADD CONSTRAINT "fk_member_video_progress_scheduledActivity" FOREIGN KEY ("scheduledActivityId") REFERENCES "scheduled_lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Create index "idx_member_video_progress_scheduledActivityId" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_scheduledActivityId" ON "member_video_progress" ("scheduledActivityId");
-- Set comment to column: "lessonActivityId" on table: "member_video_progress"
COMMENT ON COLUMN "member_video_progress"."lessonActivityId" IS 'Legacy FK, nullable for new records';
-- Set comment to column: "scheduledActivityId" on table: "member_video_progress"
COMMENT ON COLUMN "member_video_progress"."scheduledActivityId" IS 'FK to ScheduledLessonActivity';

-- Step 13: Modify study_programs table
ALTER TABLE "study_programs" ADD COLUMN "templateId" uuid NULL, ADD CONSTRAINT "fk_study_programs_template" FOREIGN KEY ("templateId") REFERENCES "lesson_templates" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_study_programs_templateId" to table: "study_programs"
CREATE INDEX "idx_study_programs_templateId" ON "study_programs" ("templateId");
-- Set comment to column: "templateId" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."templateId" IS 'FK to LessonTemplate';

-- =============================================================================
-- Step 14: Seed system templates
-- =============================================================================

-- SOAP Template
INSERT INTO "lesson_templates" ("id", "name", "description", "isSystem", "isActive", "updatedAt")
VALUES ('a0000000-0000-0000-0000-000000000001', 'SOAP', 'Scripture, Observation, Application, Prayer - A classic Bible study method for personal devotion.', true, true, now());

INSERT INTO "lesson_template_activities" ("templateId", "type", "orderNumber", "title", "helpTitle", "helpDescription", "helpAlwaysVisible", "helpIcon", "updatedAt")
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'READ', 1, 'Scripture', NULL, NULL, false, NULL, now()),
  ('a0000000-0000-0000-0000-000000000001', 'USER_INPUT', 2, 'Observation', 'What do you see?', 'Write down what stands out to you. Look for repeated words, commands, promises, or warnings.', false, 'eye', now()),
  ('a0000000-0000-0000-0000-000000000001', 'USER_INPUT', 3, 'Application', 'How does this apply?', 'How can you apply what you''ve read to your life today? What changes might God be asking you to make?', false, 'lightbulb', now()),
  ('a0000000-0000-0000-0000-000000000001', 'USER_INPUT', 4, 'Prayer', 'Respond in prayer', 'Write a prayer response to God based on what you''ve read and observed.', false, 'hands-praying', now());

-- OIA Template
INSERT INTO "lesson_templates" ("id", "name", "description", "isSystem", "isActive", "updatedAt")
VALUES ('a0000000-0000-0000-0000-000000000002', 'OIA', 'Observe, Interpret, Apply - A structured approach to understanding and applying Scripture.', true, true, now());

INSERT INTO "lesson_template_activities" ("templateId", "type", "orderNumber", "title", "helpTitle", "helpDescription", "helpAlwaysVisible", "helpIcon", "updatedAt")
VALUES
  ('a0000000-0000-0000-0000-000000000002', 'READ', 1, 'Scripture', NULL, NULL, false, NULL, now()),
  ('a0000000-0000-0000-0000-000000000002', 'USER_INPUT', 2, 'Observe', 'What does it say?', 'Read carefully and write down what the text actually says. Note key words, phrases, and structure.', false, 'eye', now()),
  ('a0000000-0000-0000-0000-000000000002', 'USER_INPUT', 3, 'Interpret', 'What does it mean?', 'What did this passage mean to the original audience? What is the main idea or teaching?', false, 'book-open', now()),
  ('a0000000-0000-0000-0000-000000000002', 'USER_INPUT', 4, 'Apply', 'How should I respond?', 'Based on your observations and interpretation, how should you respond? What specific action will you take?', false, 'lightbulb', now());

-- DBS Template
INSERT INTO "lesson_templates" ("id", "name", "description", "isSystem", "isActive", "updatedAt")
VALUES ('a0000000-0000-0000-0000-000000000003', 'DBS', 'Discovery Bible Study - A group-oriented method focused on retelling, discovery, obedience, and sharing.', true, true, now());

INSERT INTO "lesson_template_activities" ("templateId", "type", "orderNumber", "title", "helpTitle", "helpDescription", "helpAlwaysVisible", "helpIcon", "updatedAt")
VALUES
  ('a0000000-0000-0000-0000-000000000003', 'READ', 1, 'Scripture', NULL, NULL, false, NULL, now()),
  ('a0000000-0000-0000-0000-000000000003', 'USER_INPUT', 2, 'Retell', 'Retell the story', 'In your own words, retell what you just read. Try to include all the key details.', false, 'refresh', now()),
  ('a0000000-0000-0000-0000-000000000003', 'USER_INPUT', 3, 'Discover', 'What do you discover?', 'What do you learn about God? About people? What stands out or surprises you?', false, 'search', now()),
  ('a0000000-0000-0000-0000-000000000003', 'USER_INPUT', 4, 'Obey', 'How will you obey?', 'Based on what you discovered, what will you do differently this week? Be specific.', false, 'check-circle', now()),
  ('a0000000-0000-0000-0000-000000000003', 'USER_INPUT', 5, 'Share', 'Who will you tell?', 'Who will you share this with? How will you tell them what you learned?', false, 'share', now());

-- HEAR Template
INSERT INTO "lesson_templates" ("id", "name", "description", "isSystem", "isActive", "updatedAt")
VALUES ('a0000000-0000-0000-0000-000000000004', 'HEAR', 'Highlight, Explain, Apply, Respond - A journaling method for engaging deeply with Scripture.', true, true, now());

INSERT INTO "lesson_template_activities" ("templateId", "type", "orderNumber", "title", "helpTitle", "helpDescription", "helpAlwaysVisible", "helpIcon", "updatedAt")
VALUES
  ('a0000000-0000-0000-0000-000000000004', 'READ', 1, 'Scripture', NULL, NULL, false, NULL, now()),
  ('a0000000-0000-0000-0000-000000000004', 'USER_INPUT', 2, 'Highlight', 'What stands out?', 'Which verse or phrase catches your attention? Write it down and note why it stands out.', false, 'highlighter', now()),
  ('a0000000-0000-0000-0000-000000000004', 'USER_INPUT', 3, 'Explain', 'What does it mean?', 'What is the context? What was the author communicating? How does this fit in the larger story?', false, 'message-circle', now()),
  ('a0000000-0000-0000-0000-000000000004', 'USER_INPUT', 4, 'Apply', 'How does this apply?', 'How does this truth apply to your life right now? What area of your life does it speak to?', false, 'lightbulb', now()),
  ('a0000000-0000-0000-0000-000000000004', 'USER_INPUT', 5, 'Respond', 'Your response', 'Write a personal response — a prayer, a commitment, or a reflection on what you''ve learned.', false, 'pen', now());

-- Video Study Template
INSERT INTO "lesson_templates" ("id", "name", "description", "isSystem", "isActive", "updatedAt")
VALUES ('a0000000-0000-0000-0000-000000000005', 'Video Study', 'Watch a video and reflect - A simple template for video-based lessons with a reflection prompt.', true, true, now());

INSERT INTO "lesson_template_activities" ("templateId", "type", "orderNumber", "title", "helpTitle", "helpDescription", "helpAlwaysVisible", "helpIcon", "updatedAt")
VALUES
  ('a0000000-0000-0000-0000-000000000005', 'VIDEO', 1, 'Watch', NULL, NULL, false, NULL, now()),
  ('a0000000-0000-0000-0000-000000000005', 'USER_INPUT', 2, 'Reflection', 'What stood out?', 'Write down your thoughts and reflections from the video. What key ideas resonated with you?', false, 'pen', now());
