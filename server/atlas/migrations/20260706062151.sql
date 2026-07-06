-- Create enum type "EnrollmentSyncMode"
CREATE TYPE "EnrollmentSyncMode" AS ENUM ('OFF', 'AUTO', 'APPROVAL');
-- Create enum type "SyncRunStatus"
CREATE TYPE "SyncRunStatus" AS ENUM ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED');
-- Modify "enrollments" table
ALTER TABLE "enrollments" ADD COLUMN "syncMode" "EnrollmentSyncMode" NOT NULL DEFAULT 'OFF', ADD COLUMN "syncedProgramVersionNumber" integer NULL;
-- Create index "idx_enrollments_studyProgramId_syncMode" to table: "enrollments"
CREATE INDEX "idx_enrollments_studyProgramId_syncMode" ON "enrollments" ("studyProgramId", "syncMode");
-- Set comment to column: "syncMode" on table: "enrollments"
COMMENT ON COLUMN "enrollments"."syncMode" IS 'How this enrollment tracks curriculum updates published to its study program';
-- Set comment to column: "syncedProgramVersionNumber" on table: "enrollments"
COMMENT ON COLUMN "enrollments"."syncedProgramVersionNumber" IS 'StudyProgramVersion.versionNumber this enrollment''s lessons reflect; null = pre-versioning baseline. Drift = program.currentVersionNumber > this.';
-- Modify "lesson_schedules" table
ALTER TABLE "lesson_schedules" ADD COLUMN "currentVersionId" uuid NULL;
-- Create index "idx_lesson_schedules_currentVersionId" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_currentVersionId" ON "lesson_schedules" ("currentVersionId");
-- Set comment to column: "currentVersionId" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."currentVersionId" IS 'LessonScheduleVersion members without a pin see; null only for pre-backfill legacy rows';
-- Modify "member_lesson_progress" table
ALTER TABLE "member_lesson_progress" ADD COLUMN "pinnedVersionId" uuid NULL;
-- Create index "idx_member_lesson_progress_pinnedVersionId" to table: "member_lesson_progress"
CREATE INDEX "idx_member_lesson_progress_pinnedVersionId" ON "member_lesson_progress" ("pinnedVersionId");
-- Set comment to column: "pinnedVersionId" on table: "member_lesson_progress"
COMMENT ON COLUMN "member_lesson_progress"."pinnedVersionId" IS 'LessonScheduleVersion stamped at completion; pinned members render this version forever. Null = member floats to the schedule''s currentVersion.';
-- Modify "notifications" table
ALTER TABLE "notifications" ADD COLUMN "dedupeKey" character varying NULL, ADD COLUMN "actions" jsonb NULL;
-- Create index "idx_notifications_userId_dedupeKey" to table: "notifications"
CREATE INDEX "idx_notifications_userId_dedupeKey" ON "notifications" ("userId", "dedupeKey");
-- Set comment to column: "dedupeKey" on table: "notifications"
COMMENT ON COLUMN "notifications"."dedupeKey" IS 'Coalescing key (e.g. ''program-updates:{enrollmentId}''): while an unread notification with this key exists, new events update it in place instead of inserting';
-- Set comment to column: "actions" on table: "notifications"
COMMENT ON COLUMN "notifications"."actions" IS 'Array of {label, view, params} action descriptors; clients resolve ''view'' to a compact in-modal view (e.g. enrollment sync settings)';
-- Drop superseded unique (order is now unique per version, not per schedule — multiple versions coexist under one schedule)
ALTER TABLE "scheduled_lesson_activities" DROP CONSTRAINT "scheduled_lesson_activities_lessonScheduleId_orderNumber_key";
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "versionId" uuid NULL, ADD COLUMN "lineageKey" character varying NULL, ADD CONSTRAINT "scheduled_lesson_activities_versionId_orderNumber_key" UNIQUE ("versionId", "orderNumber");
-- Create index "idx_scheduled_lesson_activities_lessonScheduleId_lineageKey" to table: "scheduled_lesson_activities"
CREATE INDEX "idx_scheduled_lesson_activities_lessonScheduleId_lineageKey" ON "scheduled_lesson_activities" ("lessonScheduleId", "lineageKey");
-- Create index "idx_scheduled_lesson_activities_versionId" to table: "scheduled_lesson_activities"
CREATE INDEX "idx_scheduled_lesson_activities_versionId" ON "scheduled_lesson_activities" ("versionId");
-- Set comment to column: "versionId" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."versionId" IS 'LessonScheduleVersion this activity belongs to; null only for pre-backfill legacy rows';
-- Set comment to column: "lineageKey" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."lineageKey" IS 'Stable identity across versions = source LessonActivity.id at copy time (plain value, no FK, so curriculum deletes can''t sever it). Drives member progress carry-forward. Null for leader-added custom activities.';
-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD COLUMN "currentVersionNumber" integer NULL;
-- Set comment to column: "currentVersionNumber" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."currentVersionNumber" IS 'Latest published StudyProgramVersion number; null until first ''Publish updates''. Denormalized for cheap enrollment drift checks.';
-- Create "enrollment_sync_runs" table
CREATE TABLE "enrollment_sync_runs" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "enrollmentId" uuid NOT NULL, "targetProgramVersionNumber" integer NOT NULL, "status" "SyncRunStatus" NOT NULL DEFAULT 'PENDING', "error" text NULL, "triggeredById" uuid NULL, "startedAt" timestamp NULL, "completedAt" timestamp NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "enrollment_sync_runs_enrollmentId_targetProgramVersionNumber_ke" UNIQUE ("enrollmentId", "targetProgramVersionNumber"));
-- Create index "idx_enrollment_sync_runs_enrollmentId" to table: "enrollment_sync_runs"
CREATE INDEX "idx_enrollment_sync_runs_enrollmentId" ON "enrollment_sync_runs" ("enrollmentId");
-- Create index "idx_enrollment_sync_runs_status" to table: "enrollment_sync_runs"
CREATE INDEX "idx_enrollment_sync_runs_status" ON "enrollment_sync_runs" ("status");
-- Create index "idx_enrollment_sync_runs_triggeredById" to table: "enrollment_sync_runs"
CREATE INDEX "idx_enrollment_sync_runs_triggeredById" ON "enrollment_sync_runs" ("triggeredById");
-- Set comment to column: "targetProgramVersionNumber" on table: "enrollment_sync_runs"
COMMENT ON COLUMN "enrollment_sync_runs"."targetProgramVersionNumber" IS 'StudyProgramVersion.versionNumber this run applies';
-- Set comment to column: "error" on table: "enrollment_sync_runs"
COMMENT ON COLUMN "enrollment_sync_runs"."error" IS 'Last failure message when status = FAILED';
-- Set comment to column: "triggeredById" on table: "enrollment_sync_runs"
COMMENT ON COLUMN "enrollment_sync_runs"."triggeredById" IS 'User who triggered the run (approval-mode apply / manual catch-up); null for automatic fan-out';
-- Create "lesson_schedule_versions" table
CREATE TABLE "lesson_schedule_versions" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "lessonScheduleId" uuid NOT NULL, "versionNumber" integer NOT NULL, "programVersionNumber" integer NULL, "sourceContentHash" character varying NULL, "publishedAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "lesson_schedule_versions_lessonScheduleId_versionNumber_key" UNIQUE ("lessonScheduleId", "versionNumber"));
-- Create index "idx_lesson_schedule_versions_lessonScheduleId" to table: "lesson_schedule_versions"
CREATE INDEX "idx_lesson_schedule_versions_lessonScheduleId" ON "lesson_schedule_versions" ("lessonScheduleId");
-- Set comment to column: "versionNumber" on table: "lesson_schedule_versions"
COMMENT ON COLUMN "lesson_schedule_versions"."versionNumber" IS '1-based, monotonically increasing per lesson schedule';
-- Set comment to column: "programVersionNumber" on table: "lesson_schedule_versions"
COMMENT ON COLUMN "lesson_schedule_versions"."programVersionNumber" IS 'StudyProgramVersion.versionNumber this version was synced from; null for enrollment-time copies and backfilled baselines';
-- Set comment to column: "sourceContentHash" on table: "lesson_schedule_versions"
COMMENT ON COLUMN "lesson_schedule_versions"."sourceContentHash" IS 'Canonical content hash of the curriculum lesson this version was copied from; compared against StudyProgramVersion.lessonHashes for per-lesson drift';
-- Create "study_program_versions" table
CREATE TABLE "study_program_versions" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "studyProgramId" uuid NOT NULL, "versionNumber" integer NOT NULL, "publishedAt" timestamp NOT NULL DEFAULT now(), "publishedById" uuid NULL, "changeSummary" text NULL, "snapshot" jsonb NOT NULL, "lessonHashes" jsonb NOT NULL, "changedLessonIds" jsonb NULL, PRIMARY KEY ("id"), CONSTRAINT "study_program_versions_studyProgramId_versionNumber_key" UNIQUE ("studyProgramId", "versionNumber"));
-- Create index "idx_study_program_versions_publishedById" to table: "study_program_versions"
CREATE INDEX "idx_study_program_versions_publishedById" ON "study_program_versions" ("publishedById");
-- Create index "idx_study_program_versions_studyProgramId" to table: "study_program_versions"
CREATE INDEX "idx_study_program_versions_studyProgramId" ON "study_program_versions" ("studyProgramId");
-- Set comment to column: "versionNumber" on table: "study_program_versions"
COMMENT ON COLUMN "study_program_versions"."versionNumber" IS '1-based, monotonically increasing per program';
-- Set comment to column: "changeSummary" on table: "study_program_versions"
COMMENT ON COLUMN "study_program_versions"."changeSummary" IS 'Claude-generated summary of changes vs previous version; shown in leader notifications';
-- Set comment to column: "snapshot" on table: "study_program_versions"
COMMENT ON COLUMN "study_program_versions"."snapshot" IS 'Full canonical JSON of the program''s lessons/activities at publish time (audit + diff source)';
-- Set comment to column: "lessonHashes" on table: "study_program_versions"
COMMENT ON COLUMN "study_program_versions"."lessonHashes" IS 'Map of lessonId -> canonical content hash at publish time; drives per-lesson sync';
-- Set comment to column: "changedLessonIds" on table: "study_program_versions"
COMMENT ON COLUMN "study_program_versions"."changedLessonIds" IS 'Lesson IDs added/changed/removed vs previous version; null on baseline (first) publish';
-- Modify "lesson_schedules" table
ALTER TABLE "lesson_schedules" ADD CONSTRAINT "fk_lesson_schedules_currentVersion" FOREIGN KEY ("currentVersionId") REFERENCES "lesson_schedule_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "member_lesson_progress" table
ALTER TABLE "member_lesson_progress" ADD CONSTRAINT "fk_member_lesson_progress_pinnedVersion" FOREIGN KEY ("pinnedVersionId") REFERENCES "lesson_schedule_versions" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD CONSTRAINT "fk_scheduled_lesson_activities_version" FOREIGN KEY ("versionId") REFERENCES "lesson_schedule_versions" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "enrollment_sync_runs" table
ALTER TABLE "enrollment_sync_runs" ADD CONSTRAINT "fk_enrollment_sync_runs_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "fk_enrollment_sync_runs_triggeredBy" FOREIGN KEY ("triggeredById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Modify "lesson_schedule_versions" table
ALTER TABLE "lesson_schedule_versions" ADD CONSTRAINT "fk_lesson_schedule_versions_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Modify "study_program_versions" table
ALTER TABLE "study_program_versions" ADD CONSTRAINT "fk_study_program_versions_publishedBy" FOREIGN KEY ("publishedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, ADD CONSTRAINT "fk_study_program_versions_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
