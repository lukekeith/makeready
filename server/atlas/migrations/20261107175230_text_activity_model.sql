-- text-activity SC1-SC6, SC10, SC11: the new model's tables and columns, atlas-generated. Every statement that
-- types an id or FK column as uuid is wrapped so the column takes "users"."id"'s real type instead (text on the
-- Prisma-era dev/prod schema, uuid on a migrations-only database; a literal uuid fails 42804 on dev).
-- Nothing here drops a table, column or row (D27, D30).
-- Create enum type "LessonVersionStatus"
CREATE TYPE "LessonVersionStatus" AS ENUM ('DRAFT', 'PUBLISHED');
-- Modify "ai_lesson_summaries" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$ALTER TABLE "ai_lesson_summaries" ALTER COLUMN "lessonScheduleId" DROP NOT NULL, ADD COLUMN "scheduledLessonId" %1$s NULL$f$, id_type);
END $$;
-- Set comment to column: "scheduledLessonId" on table: "ai_lesson_summaries"
COMMENT ON COLUMN "ai_lesson_summaries"."scheduledLessonId" IS 'text-activity SC5: the ScheduledLesson summarised (replaces lessonScheduleId)';
-- Modify "client_events" table
ALTER TABLE "client_events" ADD COLUMN "scheduledLessonId" character varying NULL, ADD COLUMN "activityKey" character varying NULL, ADD COLUMN "kind" character varying NULL;
-- Set comment to column: "scheduledLessonId" on table: "client_events"
COMMENT ON COLUMN "client_events"."scheduledLessonId" IS 'text-activity SC11: replaces lessonScheduleId (no FK, analytics rows)';
-- Set comment to column: "activityKey" on table: "client_events"
COMMENT ON COLUMN "client_events"."activityKey" IS 'text-activity SC11: replaces scheduledActivityId';
-- Set comment to column: "kind" on table: "client_events"
COMMENT ON COLUMN "client_events"."kind" IS 'text-activity SC11: replaces activityType';
-- Modify "enrollments" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$ALTER TABLE "enrollments" ADD COLUMN "programVersionId" %1$s NULL$f$, id_type);
END $$;
-- Set comment to column: "programVersionId" on table: "enrollments"
COMMENT ON COLUMN "enrollments"."programVersionId" IS 'text-activity SC3: the ProgramVersion the enrollment is synced to (replaces syncedProgramVersionNumber)';
-- Modify "events" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$ALTER TABLE "events" ADD COLUMN "scheduledLessonId" %1$s NULL, ADD CONSTRAINT "events_scheduledLessonId_key" UNIQUE ("scheduledLessonId")$f$, id_type);
END $$;
-- Set comment to column: "scheduledLessonId" on table: "events"
COMMENT ON COLUMN "events"."scheduledLessonId" IS 'text-activity SC5: the ScheduledLesson this calendar event stands for';
-- Modify "lesson_template_activities" table
ALTER TABLE "lesson_template_activities" ALTER COLUMN "type" DROP NOT NULL, ADD COLUMN "kind" character varying NULL, ADD COLUMN "document" jsonb NULL;
-- Set comment to column: "kind" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."kind" IS 'text-activity SC6: content kind (validated text, replaces type)';
-- Set comment to column: "document" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."document" IS 'text-activity SC6: starter document per 02-content-schema';
-- Modify "lessons" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$ALTER TABLE "lessons" ALTER COLUMN "studyProgramId" DROP NOT NULL, ALTER COLUMN "dayNumber" DROP NOT NULL, ADD COLUMN "programId" %1$s NULL, ADD COLUMN "position" integer NULL, ADD COLUMN "deletedAt" timestamp NULL$f$, id_type);
END $$;
-- Create index "idx_lessons_programId_position" to table: "lessons"
CREATE INDEX "idx_lessons_programId_position" ON "lessons" ("programId", "position");
-- Set comment to column: "studyProgramId" on table: "lessons"
COMMENT ON COLUMN "lessons"."studyProgramId" IS 'Old model; becomes programId at the cutover (text-activity D27)';
-- Set comment to column: "programId" on table: "lessons"
COMMENT ON COLUMN "lessons"."programId" IS 'text-activity SC2: owning program; NOT NULL after the import backfill (Data plan step 3)';
-- Set comment to column: "position" on table: "lessons"
COMMENT ON COLUMN "lessons"."position" IS 'text-activity SC2: 1-based order within the program (replaces dayNumber)';
-- Set comment to column: "deletedAt" on table: "lessons"
COMMENT ON COLUMN "lessons"."deletedAt" IS 'text-activity D36: set instead of a hard delete once any published version exists';
-- Modify "study_programs" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$ALTER TABLE "study_programs" ADD COLUMN "currentVersionId" %1$s NULL$f$, id_type);
END $$;
-- Set comment to column: "currentVersionId" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."currentVersionId" IS 'text-activity SC4: latest ProgramVersion (replaces currentVersionNumber)';
-- Create "activity_progress" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "activity_progress" ("memberId" %1$s NOT NULL, "scheduledLessonId" %1$s NOT NULL, "activityKey" character varying NOT NULL, "startedAt" timestamp NOT NULL DEFAULT now(), "completedAt" timestamp NULL, "state" jsonb NULL, PRIMARY KEY ("memberId", "scheduledLessonId", "activityKey"))$f$, id_type);
END $$;
-- Create "content_activities" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "content_activities" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "lessonVersionId" %1$s NOT NULL, "activityKey" character varying NOT NULL, "position" integer NOT NULL, "kind" character varying NOT NULL, "title" character varying NOT NULL, "document" jsonb NOT NULL, "estimatedSeconds" integer NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "content_activities_lessonVersionId_activityKey_key" UNIQUE ("lessonVersionId", "activityKey"), CONSTRAINT "content_activities_lessonVersionId_position_key" UNIQUE ("lessonVersionId", "position"))$f$, id_type);
END $$;
-- Create index "idx_content_activities_activityKey" to table: "content_activities"
CREATE INDEX "idx_content_activities_activityKey" ON "content_activities" ("activityKey");
-- Set comment to column: "activityKey" on table: "content_activities"
COMMENT ON COLUMN "content_activities"."activityKey" IS 'Stable across versions of one lesson; keeps MediaUsage and progress attached';
-- Set comment to column: "kind" on table: "content_activities"
COMMENT ON COLUMN "content_activities"."kind" IS 'Validated text (SC9): a new kind needs no migration';
-- Set comment to column: "document" on table: "content_activities"
COMMENT ON COLUMN "content_activities"."document" IS '02-content-schema s2, saved whole, max 256 KB (D3)';
-- Create "lesson_progress" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "lesson_progress" ("memberId" %1$s NOT NULL, "scheduledLessonId" %1$s NOT NULL, "startedAt" timestamp NOT NULL DEFAULT now(), "completedAt" timestamp NULL, "pinnedVersionId" %1$s NULL, PRIMARY KEY ("memberId", "scheduledLessonId"))$f$, id_type);
END $$;
-- Create "lesson_versions" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "lesson_versions" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "lessonId" %1$s NOT NULL, "enrollmentId" %1$s NULL, "number" integer NOT NULL, "status" "LessonVersionStatus" NOT NULL DEFAULT 'DRAFT', "title" character varying NULL, "contentHash" character varying NOT NULL DEFAULT '', "estimatedSeconds" integer NULL, "basedOnVersionId" %1$s NULL, "publishedAt" timestamp NULL, "publishedById" %1$s NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "fk_lesson_versions_basedOn" FOREIGN KEY ("basedOnVersionId") REFERENCES "lesson_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL)$f$, id_type);
END $$;
-- Create index "idx_lesson_versions_enrollmentId" to table: "lesson_versions"
CREATE INDEX "idx_lesson_versions_enrollmentId" ON "lesson_versions" ("enrollmentId");
-- Create index "idx_lesson_versions_lessonId" to table: "lesson_versions"
CREATE INDEX "idx_lesson_versions_lessonId" ON "lesson_versions" ("lessonId");
-- Set comment to column: "lessonId" on table: "lesson_versions"
COMMENT ON COLUMN "lesson_versions"."lessonId" IS 'Never null (D36 supersedes 05 s2)';
-- Set comment to column: "enrollmentId" on table: "lesson_versions"
COMMENT ON COLUMN "lesson_versions"."enrollmentId" IS 'Null for program versions; set for a group''s customized version';
-- Create "program_version_lessons" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "program_version_lessons" ("programVersionId" %1$s NOT NULL, "lessonId" %1$s NOT NULL, "lessonVersionId" %1$s NOT NULL, "position" integer NOT NULL, PRIMARY KEY ("programVersionId", "lessonId"))$f$, id_type);
END $$;
-- Create "program_versions" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "program_versions" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "programId" %1$s NOT NULL, "number" integer NOT NULL, "changeSummary" text NULL, "publishedAt" timestamp NOT NULL DEFAULT now(), "publishedById" %1$s NULL, PRIMARY KEY ("id"), CONSTRAINT "program_versions_programId_number_key" UNIQUE ("programId", "number"))$f$, id_type);
END $$;
-- Create "scheduled_lessons" table
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format($f$CREATE TABLE "scheduled_lessons" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "code" character varying NULL, "enrollmentId" %1$s NOT NULL, "lessonId" %1$s NULL, "scheduledDate" timestamp NOT NULL, "currentVersionId" %1$s NOT NULL, "removedAt" timestamp NULL, "smsSentAt" timestamp NULL, "templateId" %1$s NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "scheduled_lessons_code_key" UNIQUE ("code"), CONSTRAINT "scheduled_lessons_enrollmentId_lessonId_key" UNIQUE ("enrollmentId", "lessonId"))$f$, id_type);
END $$;
-- Create index "idx_scheduled_lessons_currentVersionId" to table: "scheduled_lessons"
CREATE INDEX "idx_scheduled_lessons_currentVersionId" ON "scheduled_lessons" ("currentVersionId");
-- Create index "idx_scheduled_lessons_scheduledDate" to table: "scheduled_lessons"
CREATE INDEX "idx_scheduled_lessons_scheduledDate" ON "scheduled_lessons" ("scheduledDate");
-- Set comment to column: "code" on table: "scheduled_lessons"
COMMENT ON COLUMN "scheduled_lessons"."code" IS '6-char alphanumeric for deep linking';
-- Set comment to column: "smsSentAt" on table: "scheduled_lessons"
COMMENT ON COLUMN "scheduled_lessons"."smsSentAt" IS 'SC10: still locks edits once the SMS went out';
-- Modify "ai_lesson_summaries" table
ALTER TABLE "ai_lesson_summaries" ADD CONSTRAINT "fk_ai_lesson_summaries_scheduledLesson" FOREIGN KEY ("scheduledLessonId") REFERENCES "scheduled_lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "enrollments" table
ALTER TABLE "enrollments" ADD CONSTRAINT "fk_enrollments_programVersion" FOREIGN KEY ("programVersionId") REFERENCES "program_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "events" table
ALTER TABLE "events" ADD CONSTRAINT "fk_events_scheduledLesson" FOREIGN KEY ("scheduledLessonId") REFERENCES "scheduled_lessons" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "lessons" table
ALTER TABLE "lessons" ADD CONSTRAINT "fk_lessons_program" FOREIGN KEY ("programId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD CONSTRAINT "fk_study_programs_currentVersion" FOREIGN KEY ("currentVersionId") REFERENCES "program_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "activity_progress" table
ALTER TABLE "activity_progress" ADD CONSTRAINT "fk_activity_progress_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_activity_progress_scheduledLesson" FOREIGN KEY ("scheduledLessonId") REFERENCES "scheduled_lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "content_activities" table
ALTER TABLE "content_activities" ADD CONSTRAINT "fk_content_activities_lessonVersion" FOREIGN KEY ("lessonVersionId") REFERENCES "lesson_versions" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "lesson_progress" table
ALTER TABLE "lesson_progress" ADD CONSTRAINT "fk_lesson_progress_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_lesson_progress_pinnedVersion" FOREIGN KEY ("pinnedVersionId") REFERENCES "lesson_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, ADD CONSTRAINT "fk_lesson_progress_scheduledLesson" FOREIGN KEY ("scheduledLessonId") REFERENCES "scheduled_lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "lesson_versions" table
ALTER TABLE "lesson_versions" ADD CONSTRAINT "fk_lesson_versions_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_lesson_versions_lesson" FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_lesson_versions_publishedBy" FOREIGN KEY ("publishedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "program_version_lessons" table
ALTER TABLE "program_version_lessons" ADD CONSTRAINT "fk_program_version_lessons_lesson" FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE RESTRICT, ADD CONSTRAINT "fk_program_version_lessons_lessonVersion" FOREIGN KEY ("lessonVersionId") REFERENCES "lesson_versions" ("id") ON UPDATE NO ACTION ON DELETE RESTRICT, ADD CONSTRAINT "fk_program_version_lessons_programVersion" FOREIGN KEY ("programVersionId") REFERENCES "program_versions" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "program_versions" table
ALTER TABLE "program_versions" ADD CONSTRAINT "fk_program_versions_program" FOREIGN KEY ("programId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_program_versions_publishedBy" FOREIGN KEY ("publishedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "scheduled_lessons" table
ALTER TABLE "scheduled_lessons" ADD CONSTRAINT "fk_scheduled_lessons_currentVersion" FOREIGN KEY ("currentVersionId") REFERENCES "lesson_versions" ("id") ON UPDATE NO ACTION ON DELETE RESTRICT, ADD CONSTRAINT "fk_scheduled_lessons_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_scheduled_lessons_lesson" FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, ADD CONSTRAINT "fk_scheduled_lessons_template" FOREIGN KEY ("templateId") REFERENCES "lesson_templates" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
