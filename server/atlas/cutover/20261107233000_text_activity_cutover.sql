-- text-activity cutover. Applied ONLY by the owner's runbook (docs/features/text-activity/CUTOVER.md), after a verified pg_dump.
-- It lives outside atlas/migrations/ on purpose: boot runs `migrate apply`, so a drop in that folder would run on the next
-- deploy instead of from the runbook (SPEC D27, D30). The undo is the pg_dump restore.
BEGIN;

-- D42: rows that name old lesson, schedule or activity ids
DELETE FROM "note_links" WHERE "refType" IN ('LESSON_ACTIVITY','SCHEDULED_ACTIVITY','LESSON_SCHEDULE');
DELETE FROM "preview_state";
DELETE FROM "client_events" WHERE "lessonScheduleId" IS NOT NULL OR "scheduledActivityId" IS NOT NULL;

-- D13: derived summaries and members' enrollments are not carried
DELETE FROM "ai_lesson_summaries" WHERE "scheduledLessonId" IS NULL;
-- scheduled_lessons.currentVersionId is RESTRICT while lesson_versions.enrollmentId cascades from enrollments: the schedule goes first
DELETE FROM "scheduled_lessons";
DELETE FROM "enrollments";

-- Never imported (no program): nothing can own them
DELETE FROM "lessons" WHERE "programId" IS NULL;

-- Data plan step 3: the import backfilled these
ALTER TABLE "lessons" ALTER COLUMN "programId" SET NOT NULL, ALTER COLUMN "position" SET NOT NULL;

-- SC8: the replaced models
DROP TABLE "content_highlights" CASCADE;
DROP TABLE "activity_read_blocks" CASCADE;
DROP TABLE "activity_source_references" CASCADE;
DROP TABLE "member_activity_progress" CASCADE;
DROP TABLE "member_video_progress" CASCADE;
DROP TABLE "member_lesson_progress" CASCADE;
DROP TABLE "scheduled_lesson_activities" CASCADE;
DROP TABLE "lesson_activities" CASCADE;
DROP TABLE "lesson_schedules" CASCADE;
DROP TABLE "lesson_schedule_versions" CASCADE;
DROP TABLE "study_program_versions" CASCADE;
DROP TABLE "enrollment_sync_runs" CASCADE;
DROP TABLE "text_themes" CASCADE;

-- SC2-SC5, SC6, SC11: old columns
ALTER TABLE "lessons" DROP COLUMN "studyProgramId", DROP COLUMN "dayNumber", DROP COLUMN "title", DROP COLUMN "estimatedMinutes";
ALTER TABLE "enrollments" DROP COLUMN "syncedProgramVersionNumber";
ALTER TABLE "study_programs" DROP COLUMN "currentVersionNumber";
ALTER TABLE "events" DROP COLUMN "lessonScheduleId";
ALTER TABLE "ai_lesson_summaries" DROP COLUMN "lessonScheduleId";
ALTER TABLE "lesson_template_activities" DROP COLUMN "type";
ALTER TABLE "client_events" DROP COLUMN "lessonScheduleId", DROP COLUMN "scheduledActivityId", DROP COLUMN "activityType";

-- SC9
DROP TYPE IF EXISTS "TemplateActivityType";

COMMIT;
