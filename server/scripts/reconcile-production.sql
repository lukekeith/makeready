-- ============================================================================
-- MakeReady Production Reconciliation Script
-- ============================================================================
-- Purpose: Convert production database from Prisma-created schema (text IDs)
--          to Atlas-compatible schema (uuid IDs) so Atlas can manage migrations.
--
-- Run this ONCE against production, wrapped in a transaction.
-- After running, baseline Atlas with:
--   atlas migrate apply --env production --baseline 20260207201008
--
-- Safe to re-run (idempotent) — uses IF EXISTS / IF NOT EXISTS throughout.
-- ============================================================================

BEGIN;

-- ============================================================================
-- PHASE 0: Ensure extensions exist
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================================
-- PHASE 0.5: Remove test rows with non-UUID IDs
-- ============================================================================
-- Production has 3 test rows with text IDs that can't be cast to uuid:
--   study_programs: "beatitudes-program-id"
--   enrollments: "test-enrollment-id"
--   members: "test-member-id"
-- We also delete child rows that reference them via FK columns.
-- Deletion order: deepest children first, parents last.

-- Deep children first (member_activity_progress references both members and lesson_schedules)
DELETE FROM "member_activity_progress" WHERE "memberId" = 'test-member-id';
DELETE FROM "member_activity_progress" WHERE "lessonScheduleId" IN (SELECT id FROM "lesson_schedules" WHERE "enrollmentId" = 'test-enrollment-id');
DELETE FROM "member_lesson_progress" WHERE "lessonScheduleId" IN (SELECT id FROM "lesson_schedules" WHERE "enrollmentId" = 'test-enrollment-id');
DELETE FROM "member_video_progress" WHERE "lessonScheduleId" IN (SELECT id FROM "lesson_schedules" WHERE "enrollmentId" = 'test-enrollment-id');

-- study_notes and note_links referencing test member
DELETE FROM "note_links" WHERE "noteId" IN (SELECT id FROM "study_notes" WHERE "memberId" = 'test-member-id');
DELETE FROM "study_notes" WHERE "memberId" = 'test-member-id';

-- lesson_activities referencing test lessons
DELETE FROM "lesson_activities" WHERE "lessonId" IN (SELECT id FROM "lessons" WHERE "studyProgramId" = 'beatitudes-program-id');

-- lesson_schedules referencing test enrollment or test lessons
DELETE FROM "lesson_schedules" WHERE "enrollmentId" = 'test-enrollment-id';
DELETE FROM "lesson_schedules" WHERE "lessonId" IN (SELECT id FROM "lessons" WHERE "studyProgramId" = 'beatitudes-program-id');

-- events referencing test enrollment
DELETE FROM "events" WHERE "enrollmentId" = 'test-enrollment-id';

-- posts referencing test enrollment
DELETE FROM "posts" WHERE "enrollmentId" = 'test-enrollment-id';

-- group_members referencing test member
DELETE FROM "group_members" WHERE "memberId" = 'test-member-id';

-- group_join_requests referencing test member
DELETE FROM "group_join_requests" WHERE "memberId" = 'test-member-id';

-- member_organizations referencing test member
DELETE FROM "member_organizations" WHERE "memberId" = 'test-member-id';

-- lessons referencing test study program
DELETE FROM "lessons" WHERE "studyProgramId" = 'beatitudes-program-id';

-- enrollments referencing test study program (includes test-enrollment-id)
DELETE FROM "enrollments" WHERE "studyProgramId" = 'beatitudes-program-id';
DELETE FROM "enrollments" WHERE "id" = 'test-enrollment-id';

-- The root test rows
DELETE FROM "study_programs" WHERE "id" = 'beatitudes-program-id';
DELETE FROM "members" WHERE "id" = 'test-member-id';

-- ============================================================================
-- PHASE 1: Drop ALL foreign key constraints
-- ============================================================================
-- We must drop FKs before changing column types.
-- Uses a DO block to safely skip tables that don't exist yet.

DO $$
DECLARE
  _drop text;
BEGIN
  -- Helper: drop a constraint if the table and constraint both exist
  FOR _drop IN
    SELECT format('ALTER TABLE %I DROP CONSTRAINT %I', c.conrelid::regclass, c.conname)
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE n.nspname = 'public'
      AND c.contype = 'f'  -- foreign key constraints only
  LOOP
    EXECUTE _drop;
  END LOOP;
END $$;


-- ============================================================================
-- PHASE 2: Convert all id PK columns from text to uuid
-- ============================================================================
-- Only convert if currently text/varchar. Safe if already uuid.

-- Primary key columns (id) for all tables with uuid PKs
DO $$ BEGIN
  -- users
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='id' AND data_type='text') THEN
    ALTER TABLE "users" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "users" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='id' AND data_type='character varying') THEN
    ALTER TABLE "users" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "users" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='activity_type_configs' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "activity_type_configs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "activity_type_configs" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='activity_logs' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "activity_logs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "activity_logs" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookmarks' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "bookmarks" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "bookmarks" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "books" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "books" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='enrollments' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "enrollments" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "enrollments" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attachments' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attachments" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "event_attachments" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attendees' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attendees" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "event_attendees" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "events" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "events" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_join_requests' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_join_requests" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "group_join_requests" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_members' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_members" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "group_members" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='groups' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "groups" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "groups" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='highlights' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "highlights" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "highlights" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invites' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "invites" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "invites" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_activities' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_activities" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "lesson_activities" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_schedules' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_schedules" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "lesson_schedules" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lessons' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lessons" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "lessons" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='media' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "media" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "media" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_activity_progress' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_activity_progress" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "member_activity_progress" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_lesson_progress' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_lesson_progress" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "member_lesson_progress" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_organizations' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_organizations" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "member_organizations" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_video_progress' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_video_progress" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "member_video_progress" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='members' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "members" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "members" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='note_links' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "note_links" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "note_links" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "organizations" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "organizations" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='permissions' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "permissions" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "permissions" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='posts' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "posts" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "posts" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='role_permissions' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "role_permissions" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "role_permissions" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='roles' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "roles" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "roles" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='study_notes' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "study_notes" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "study_notes" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='study_programs' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "study_programs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "study_programs" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='translations' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "translations" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "translations" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_roles' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "user_roles" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "user_roles" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verse_notes' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verse_notes" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "verse_notes" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verses' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verses" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "verses" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='videos' AND column_name='id' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "videos" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "videos" ALTER COLUMN "id" TYPE uuid USING "id"::uuid;
  END IF;
END $$;


-- ============================================================================
-- PHASE 3: Convert all FK columns from text to uuid
-- ============================================================================
-- These are the columns that reference another table's uuid PK.
-- Columns intentionally kept as varchar are NOT touched here.

-- Helper: convert a column to uuid if it's currently text/varchar
-- We use individual DO blocks so each is independently idempotent.

-- api_keys.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "api_keys" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- bookmarks.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookmarks' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "bookmarks" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;
-- NOTE: bookmarks.translationId is intentionally kept as varchar (no FK constraint in Atlas)

-- books.translationId -> translations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='books' AND column_name='translationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "books" ALTER COLUMN "translationId" TYPE uuid USING "translationId"::uuid;
  END IF;
END $$;

-- enrollments.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='enrollments' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "enrollments" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- enrollments.studyProgramId -> study_programs.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='enrollments' AND column_name='studyProgramId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "enrollments" ALTER COLUMN "studyProgramId" TYPE uuid USING "studyProgramId"::uuid;
  END IF;
END $$;

-- enrollments.createdById -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='enrollments' AND column_name='createdById' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "enrollments" ALTER COLUMN "createdById" TYPE uuid USING "createdById"::uuid;
  END IF;
END $$;

-- event_attachments.eventId -> events.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attachments' AND column_name='eventId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attachments" ALTER COLUMN "eventId" TYPE uuid USING "eventId"::uuid;
  END IF;
END $$;

-- event_attachments.uploadedById -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attachments' AND column_name='uploadedById' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attachments" ALTER COLUMN "uploadedById" TYPE uuid USING "uploadedById"::uuid;
  END IF;
END $$;

-- event_attendees.eventId -> events.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attendees' AND column_name='eventId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attendees" ALTER COLUMN "eventId" TYPE uuid USING "eventId"::uuid;
  END IF;
END $$;

-- event_attendees.groupMemberId -> group_members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_attendees' AND column_name='groupMemberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "event_attendees" ALTER COLUMN "groupMemberId" TYPE uuid USING "groupMemberId"::uuid;
  END IF;
END $$;

-- events.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "events" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- events.createdById -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='createdById' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "events" ALTER COLUMN "createdById" TYPE uuid USING "createdById"::uuid;
  END IF;
END $$;

-- events.lessonScheduleId -> lesson_schedules.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='lessonScheduleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "events" ALTER COLUMN "lessonScheduleId" TYPE uuid USING "lessonScheduleId"::uuid;
  END IF;
END $$;

-- events.enrollmentId -> enrollments.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='enrollmentId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "events" ALTER COLUMN "enrollmentId" TYPE uuid USING "enrollmentId"::uuid;
  END IF;
END $$;

-- NOTE: events.recurrenceGroupId is intentionally kept as varchar

-- group_join_requests.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_join_requests' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_join_requests" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- group_join_requests.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_join_requests' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_join_requests" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- group_join_requests.reviewedById -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_join_requests' AND column_name='reviewedById' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_join_requests" ALTER COLUMN "reviewedById" TYPE uuid USING "reviewedById"::uuid;
  END IF;
END $$;

-- group_members.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_members' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_members" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- group_members.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='group_members' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "group_members" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- groups.creatorId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='groups' AND column_name='creatorId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "groups" ALTER COLUMN "creatorId" TYPE uuid USING "creatorId"::uuid;
  END IF;
END $$;

-- NOTE: groups.organizationId is intentionally kept as varchar

-- highlights.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='highlights' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "highlights" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- highlights.translationId -> translations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='highlights' AND column_name='translationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "highlights" ALTER COLUMN "translationId" TYPE uuid USING "translationId"::uuid;
  END IF;
END $$;

-- invites.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invites' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "invites" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- invites.inviterId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='invites' AND column_name='inviterId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "invites" ALTER COLUMN "inviterId" TYPE uuid USING "inviterId"::uuid;
  END IF;
END $$;

-- lesson_activities.lessonId -> lessons.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_activities' AND column_name='lessonId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_activities" ALTER COLUMN "lessonId" TYPE uuid USING "lessonId"::uuid;
  END IF;
END $$;

-- lesson_activities.videoId -> videos.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_activities' AND column_name='videoId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_activities" ALTER COLUMN "videoId" TYPE uuid USING "videoId"::uuid;
  END IF;
END $$;

-- lesson_schedules.enrollmentId -> enrollments.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_schedules' AND column_name='enrollmentId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_schedules" ALTER COLUMN "enrollmentId" TYPE uuid USING "enrollmentId"::uuid;
  END IF;
END $$;

-- lesson_schedules.lessonId -> lessons.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lesson_schedules' AND column_name='lessonId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lesson_schedules" ALTER COLUMN "lessonId" TYPE uuid USING "lessonId"::uuid;
  END IF;
END $$;

-- lessons.studyProgramId -> study_programs.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='lessons' AND column_name='studyProgramId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "lessons" ALTER COLUMN "studyProgramId" TYPE uuid USING "studyProgramId"::uuid;
  END IF;
END $$;

-- media.organizationId -> organizations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='media' AND column_name='organizationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "media" ALTER COLUMN "organizationId" TYPE uuid USING "organizationId"::uuid;
  END IF;
END $$;

-- media.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='media' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "media" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- media.uploadedBy -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='media' AND column_name='uploadedBy' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "media" ALTER COLUMN "uploadedBy" TYPE uuid USING "uploadedBy"::uuid;
  END IF;
END $$;

-- member_activity_progress.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_activity_progress' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_activity_progress" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- member_activity_progress.lessonScheduleId -> lesson_schedules.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_activity_progress' AND column_name='lessonScheduleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_activity_progress" ALTER COLUMN "lessonScheduleId" TYPE uuid USING "lessonScheduleId"::uuid;
  END IF;
END $$;

-- member_activity_progress.lessonActivityId -> lesson_activities.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_activity_progress' AND column_name='lessonActivityId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_activity_progress" ALTER COLUMN "lessonActivityId" TYPE uuid USING "lessonActivityId"::uuid;
  END IF;
END $$;

-- member_lesson_progress.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_lesson_progress' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_lesson_progress" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- member_lesson_progress.lessonScheduleId -> lesson_schedules.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_lesson_progress' AND column_name='lessonScheduleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_lesson_progress" ALTER COLUMN "lessonScheduleId" TYPE uuid USING "lessonScheduleId"::uuid;
  END IF;
END $$;

-- member_organizations.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_organizations' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_organizations" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- member_organizations.organizationId -> organizations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_organizations' AND column_name='organizationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_organizations" ALTER COLUMN "organizationId" TYPE uuid USING "organizationId"::uuid;
  END IF;
END $$;

-- member_video_progress.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_video_progress' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_video_progress" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- member_video_progress.lessonScheduleId -> lesson_schedules.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_video_progress' AND column_name='lessonScheduleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_video_progress" ALTER COLUMN "lessonScheduleId" TYPE uuid USING "lessonScheduleId"::uuid;
  END IF;
END $$;

-- member_video_progress.lessonActivityId -> lesson_activities.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='member_video_progress' AND column_name='lessonActivityId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "member_video_progress" ALTER COLUMN "lessonActivityId" TYPE uuid USING "lessonActivityId"::uuid;
  END IF;
END $$;

-- members.userId -> users.id (added in migration 20260203052425)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='members' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "members" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- note_links.noteId -> study_notes.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='note_links' AND column_name='noteId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "note_links" ALTER COLUMN "noteId" TYPE uuid USING "noteId"::uuid;
  END IF;
END $$;

-- NOTE: note_links.refId is intentionally kept as varchar (polymorphic)

-- organizations.ownerId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='ownerId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "organizations" ALTER COLUMN "ownerId" TYPE uuid USING "ownerId"::uuid;
  END IF;
END $$;

-- posts.groupId -> groups.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='posts' AND column_name='groupId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "posts" ALTER COLUMN "groupId" TYPE uuid USING "groupId"::uuid;
  END IF;
END $$;

-- posts.authorId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='posts' AND column_name='authorId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "posts" ALTER COLUMN "authorId" TYPE uuid USING "authorId"::uuid;
  END IF;
END $$;

-- posts.enrollmentId -> enrollments.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='posts' AND column_name='enrollmentId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "posts" ALTER COLUMN "enrollmentId" TYPE uuid USING "enrollmentId"::uuid;
  END IF;
END $$;

-- role_permissions.roleId -> roles.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='role_permissions' AND column_name='roleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "role_permissions" ALTER COLUMN "roleId" TYPE uuid USING "roleId"::uuid;
  END IF;
END $$;

-- role_permissions.permissionId -> permissions.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='role_permissions' AND column_name='permissionId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "role_permissions" ALTER COLUMN "permissionId" TYPE uuid USING "permissionId"::uuid;
  END IF;
END $$;

-- roles.organizationId -> organizations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='roles' AND column_name='organizationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "roles" ALTER COLUMN "organizationId" TYPE uuid USING "organizationId"::uuid;
  END IF;
END $$;

-- study_notes.memberId -> members.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='study_notes' AND column_name='memberId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "study_notes" ALTER COLUMN "memberId" TYPE uuid USING "memberId"::uuid;
  END IF;
END $$;

-- study_notes.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='study_notes' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "study_notes" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- study_programs.creatorId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='study_programs' AND column_name='creatorId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "study_programs" ALTER COLUMN "creatorId" TYPE uuid USING "creatorId"::uuid;
  END IF;
END $$;

-- user_roles.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_roles' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "user_roles" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- user_roles.roleId -> roles.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_roles' AND column_name='roleId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "user_roles" ALTER COLUMN "roleId" TYPE uuid USING "roleId"::uuid;
  END IF;
END $$;

-- user_roles.organizationId -> organizations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_roles' AND column_name='organizationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "user_roles" ALTER COLUMN "organizationId" TYPE uuid USING "organizationId"::uuid;
  END IF;
END $$;

-- NOTE: user_roles.assignedBy is intentionally kept as varchar

-- verse_notes.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verse_notes' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verse_notes" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;

-- verse_notes.translationId -> translations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verse_notes' AND column_name='translationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verse_notes" ALTER COLUMN "translationId" TYPE uuid USING "translationId"::uuid;
  END IF;
END $$;

-- verses.translationId -> translations.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verses' AND column_name='translationId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verses" ALTER COLUMN "translationId" TYPE uuid USING "translationId"::uuid;
  END IF;
END $$;

-- verses.bookId -> books.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='verses' AND column_name='bookId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "verses" ALTER COLUMN "bookId" TYPE uuid USING "bookId"::uuid;
  END IF;
END $$;

-- videos.userId -> users.id
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='videos' AND column_name='userId' AND data_type IN ('text','character varying')) THEN
    ALTER TABLE "videos" ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
  END IF;
END $$;


-- ============================================================================
-- PHASE 4: Re-create all foreign key constraints
-- ============================================================================
-- Using Atlas naming convention (fk_tablename_relation).
-- Each uses IF NOT EXISTS pattern via DO blocks.

-- api_keys.userId -> users.id (CASCADE)
-- NOTE: api_keys may not exist yet; it's created in Phase 5. FK added there.

-- bookmarks.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_bookmarks_user') THEN
    ALTER TABLE "bookmarks" ADD CONSTRAINT "fk_bookmarks_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- books.translationId -> translations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_books_translation') THEN
    ALTER TABLE "books" ADD CONSTRAINT "fk_books_translation"
      FOREIGN KEY ("translationId") REFERENCES "translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- enrollments.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_enrollments_group') THEN
    ALTER TABLE "enrollments" ADD CONSTRAINT "fk_enrollments_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- enrollments.studyProgramId -> study_programs.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_enrollments_studyProgram') THEN
    ALTER TABLE "enrollments" ADD CONSTRAINT "fk_enrollments_studyProgram"
      FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- enrollments.createdById -> users.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_enrollments_createdBy') THEN
    ALTER TABLE "enrollments" ADD CONSTRAINT "fk_enrollments_createdBy"
      FOREIGN KEY ("createdById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- event_attachments.eventId -> events.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_event_attachments_event') THEN
    ALTER TABLE "event_attachments" ADD CONSTRAINT "fk_event_attachments_event"
      FOREIGN KEY ("eventId") REFERENCES "events" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- event_attachments.uploadedById -> users.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_event_attachments_uploadedBy') THEN
    ALTER TABLE "event_attachments" ADD CONSTRAINT "fk_event_attachments_uploadedBy"
      FOREIGN KEY ("uploadedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- event_attendees.eventId -> events.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_event_attendees_event') THEN
    ALTER TABLE "event_attendees" ADD CONSTRAINT "fk_event_attendees_event"
      FOREIGN KEY ("eventId") REFERENCES "events" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- event_attendees.groupMemberId -> group_members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_event_attendees_groupMember') THEN
    ALTER TABLE "event_attendees" ADD CONSTRAINT "fk_event_attendees_groupMember"
      FOREIGN KEY ("groupMemberId") REFERENCES "group_members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- events.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_group') THEN
    ALTER TABLE "events" ADD CONSTRAINT "fk_events_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- events.createdById -> users.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_createdBy') THEN
    ALTER TABLE "events" ADD CONSTRAINT "fk_events_createdBy"
      FOREIGN KEY ("createdById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- events.lessonScheduleId -> lesson_schedules.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_lessonSchedule') THEN
    ALTER TABLE "events" ADD CONSTRAINT "fk_events_lessonSchedule"
      FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- events.enrollmentId -> enrollments.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_enrollment') THEN
    ALTER TABLE "events" ADD CONSTRAINT "fk_events_enrollment"
      FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- group_join_requests.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_join_requests_group') THEN
    ALTER TABLE "group_join_requests" ADD CONSTRAINT "fk_group_join_requests_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- group_join_requests.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_join_requests_member') THEN
    ALTER TABLE "group_join_requests" ADD CONSTRAINT "fk_group_join_requests_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- group_join_requests.reviewedById -> users.id (NO ACTION)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_join_requests_reviewedBy') THEN
    ALTER TABLE "group_join_requests" ADD CONSTRAINT "fk_group_join_requests_reviewedBy"
      FOREIGN KEY ("reviewedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION;
  END IF;
END $$;

-- group_members.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_members_group') THEN
    ALTER TABLE "group_members" ADD CONSTRAINT "fk_group_members_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- group_members.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_members_member') THEN
    ALTER TABLE "group_members" ADD CONSTRAINT "fk_group_members_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- groups.creatorId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_groups_creator') THEN
    ALTER TABLE "groups" ADD CONSTRAINT "fk_groups_creator"
      FOREIGN KEY ("creatorId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- highlights.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_highlights_user') THEN
    ALTER TABLE "highlights" ADD CONSTRAINT "fk_highlights_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- highlights.translationId -> translations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_highlights_translation') THEN
    ALTER TABLE "highlights" ADD CONSTRAINT "fk_highlights_translation"
      FOREIGN KEY ("translationId") REFERENCES "translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- invites.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invites_group') THEN
    ALTER TABLE "invites" ADD CONSTRAINT "fk_invites_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- invites.inviterId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invites_inviter') THEN
    ALTER TABLE "invites" ADD CONSTRAINT "fk_invites_inviter"
      FOREIGN KEY ("inviterId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- lesson_activities.lessonId -> lessons.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lesson_activities_lesson') THEN
    ALTER TABLE "lesson_activities" ADD CONSTRAINT "fk_lesson_activities_lesson"
      FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- lesson_activities.videoId -> videos.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lesson_activities_video') THEN
    ALTER TABLE "lesson_activities" ADD CONSTRAINT "fk_lesson_activities_video"
      FOREIGN KEY ("videoId") REFERENCES "videos" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- lesson_schedules.enrollmentId -> enrollments.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lesson_schedules_enrollment') THEN
    ALTER TABLE "lesson_schedules" ADD CONSTRAINT "fk_lesson_schedules_enrollment"
      FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- lesson_schedules.lessonId -> lessons.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lesson_schedules_lesson') THEN
    ALTER TABLE "lesson_schedules" ADD CONSTRAINT "fk_lesson_schedules_lesson"
      FOREIGN KEY ("lessonId") REFERENCES "lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- lessons.studyProgramId -> study_programs.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_lessons_studyProgram') THEN
    ALTER TABLE "lessons" ADD CONSTRAINT "fk_lessons_studyProgram"
      FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- media.organizationId -> organizations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_media_organization') THEN
    ALTER TABLE "media" ADD CONSTRAINT "fk_media_organization"
      FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- media.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_media_group') THEN
    ALTER TABLE "media" ADD CONSTRAINT "fk_media_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- media.uploadedBy -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_media_uploader') THEN
    ALTER TABLE "media" ADD CONSTRAINT "fk_media_uploader"
      FOREIGN KEY ("uploadedBy") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_activity_progress.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_activity_progress_member') THEN
    ALTER TABLE "member_activity_progress" ADD CONSTRAINT "fk_member_activity_progress_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_activity_progress.lessonScheduleId -> lesson_schedules.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_activity_progress_lessonSchedule') THEN
    ALTER TABLE "member_activity_progress" ADD CONSTRAINT "fk_member_activity_progress_lessonSchedule"
      FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_activity_progress.lessonActivityId -> lesson_activities.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_activity_progress_lessonActivity') THEN
    ALTER TABLE "member_activity_progress" ADD CONSTRAINT "fk_member_activity_progress_lessonActivity"
      FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_lesson_progress FKs — table may not exist yet; created with FKs in Phase 5/6.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='member_lesson_progress') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_lesson_progress_member') THEN
      ALTER TABLE "member_lesson_progress" ADD CONSTRAINT "fk_member_lesson_progress_member"
        FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_lesson_progress_lessonSchedule') THEN
      ALTER TABLE "member_lesson_progress" ADD CONSTRAINT "fk_member_lesson_progress_lessonSchedule"
        FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- member_organizations.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_organizations_member') THEN
    ALTER TABLE "member_organizations" ADD CONSTRAINT "fk_member_organizations_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_organizations.organizationId -> organizations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_organizations_organization') THEN
    ALTER TABLE "member_organizations" ADD CONSTRAINT "fk_member_organizations_organization"
      FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_video_progress.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_video_progress_member') THEN
    ALTER TABLE "member_video_progress" ADD CONSTRAINT "fk_member_video_progress_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_video_progress.lessonScheduleId -> lesson_schedules.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_video_progress_lessonSchedule') THEN
    ALTER TABLE "member_video_progress" ADD CONSTRAINT "fk_member_video_progress_lessonSchedule"
      FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- member_video_progress.lessonActivityId -> lesson_activities.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_member_video_progress_lessonActivity') THEN
    ALTER TABLE "member_video_progress" ADD CONSTRAINT "fk_member_video_progress_lessonActivity"
      FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- members.userId -> users.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_members_linkedUser') THEN
    ALTER TABLE "members" ADD CONSTRAINT "fk_members_linkedUser"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- note_links.noteId -> study_notes.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_note_links_note') THEN
    ALTER TABLE "note_links" ADD CONSTRAINT "fk_note_links_note"
      FOREIGN KEY ("noteId") REFERENCES "study_notes" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- organizations.ownerId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_organizations_owner') THEN
    ALTER TABLE "organizations" ADD CONSTRAINT "fk_organizations_owner"
      FOREIGN KEY ("ownerId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- posts.groupId -> groups.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_posts_group') THEN
    ALTER TABLE "posts" ADD CONSTRAINT "fk_posts_group"
      FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- posts.authorId -> users.id (SET NULL)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_posts_author') THEN
    ALTER TABLE "posts" ADD CONSTRAINT "fk_posts_author"
      FOREIGN KEY ("authorId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
  END IF;
END $$;

-- posts.enrollmentId -> enrollments.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_posts_enrollment') THEN
    ALTER TABLE "posts" ADD CONSTRAINT "fk_posts_enrollment"
      FOREIGN KEY ("enrollmentId") REFERENCES "enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- role_permissions.roleId -> roles.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_role_permissions_role') THEN
    ALTER TABLE "role_permissions" ADD CONSTRAINT "fk_role_permissions_role"
      FOREIGN KEY ("roleId") REFERENCES "roles" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- role_permissions.permissionId -> permissions.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_role_permissions_permission') THEN
    ALTER TABLE "role_permissions" ADD CONSTRAINT "fk_role_permissions_permission"
      FOREIGN KEY ("permissionId") REFERENCES "permissions" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- roles.organizationId -> organizations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_roles_organization') THEN
    ALTER TABLE "roles" ADD CONSTRAINT "fk_roles_organization"
      FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- study_notes.memberId -> members.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_study_notes_member') THEN
    ALTER TABLE "study_notes" ADD CONSTRAINT "fk_study_notes_member"
      FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- study_notes.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_study_notes_user') THEN
    ALTER TABLE "study_notes" ADD CONSTRAINT "fk_study_notes_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- study_programs.creatorId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_study_programs_creator') THEN
    ALTER TABLE "study_programs" ADD CONSTRAINT "fk_study_programs_creator"
      FOREIGN KEY ("creatorId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- user_roles.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_roles_user') THEN
    ALTER TABLE "user_roles" ADD CONSTRAINT "fk_user_roles_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- user_roles.roleId -> roles.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_roles_role') THEN
    ALTER TABLE "user_roles" ADD CONSTRAINT "fk_user_roles_role"
      FOREIGN KEY ("roleId") REFERENCES "roles" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- user_roles.organizationId -> organizations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_roles_organization') THEN
    ALTER TABLE "user_roles" ADD CONSTRAINT "fk_user_roles_organization"
      FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- verse_notes.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_verse_notes_user') THEN
    ALTER TABLE "verse_notes" ADD CONSTRAINT "fk_verse_notes_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- verse_notes.translationId -> translations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_verse_notes_translation') THEN
    ALTER TABLE "verse_notes" ADD CONSTRAINT "fk_verse_notes_translation"
      FOREIGN KEY ("translationId") REFERENCES "translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- verses.translationId -> translations.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_verses_translation') THEN
    ALTER TABLE "verses" ADD CONSTRAINT "fk_verses_translation"
      FOREIGN KEY ("translationId") REFERENCES "translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- verses.bookId -> books.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_verses_book') THEN
    ALTER TABLE "verses" ADD CONSTRAINT "fk_verses_book"
      FOREIGN KEY ("bookId") REFERENCES "books" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;

-- videos.userId -> users.id (CASCADE)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_videos_user') THEN
    ALTER TABLE "videos" ADD CONSTRAINT "fk_videos_user"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
  END IF;
END $$;


-- ============================================================================
-- PHASE 5: Create missing tables
-- ============================================================================

-- device_tokens (from migration 20260207201008)
CREATE TABLE IF NOT EXISTS "device_tokens" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "token" character varying NOT NULL,
  "platform" character varying NOT NULL DEFAULT 'ios',
  "environment" character varying NOT NULL DEFAULT 'production',
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "device_tokens_token_key" UNIQUE ("token"),
  CONSTRAINT "fk_device_tokens_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "idx_device_tokens_userId" ON "device_tokens" ("userId");
COMMENT ON COLUMN "device_tokens"."platform" IS 'ios or android';
COMMENT ON COLUMN "device_tokens"."environment" IS 'sandbox or production';

-- api_keys (from initial migration)
CREATE TABLE IF NOT EXISTS "api_keys" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "keyHash" character varying NOT NULL,
  "keyPrefix" character varying NOT NULL,
  "name" character varying NOT NULL,
  "description" character varying NULL,
  "userId" uuid NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "expiresAt" timestamp NULL,
  "lastUsedAt" timestamp NULL,
  "usageCount" integer NOT NULL DEFAULT 0,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "api_keys_keyHash_key" UNIQUE ("keyHash"),
  CONSTRAINT "fk_api_keys_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "idx_api_keys_keyPrefix" ON "api_keys" ("keyPrefix");
CREATE INDEX IF NOT EXISTS "idx_api_keys_userId" ON "api_keys" ("userId");

-- _seed_versions (from initial migration)
CREATE TABLE IF NOT EXISTS "_seed_versions" (
  "version" character varying NOT NULL,
  "applied_at" timestamp NOT NULL DEFAULT now(),
  "checksum" character varying NULL,
  PRIMARY KEY ("version")
);


-- ============================================================================
-- PHASE 6: Add missing columns from later migrations
-- ============================================================================

-- groups.memberDirectoryEnabled (from migration 20260207201008)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='groups' AND column_name='memberDirectoryEnabled') THEN
    ALTER TABLE "groups" ADD COLUMN "memberDirectoryEnabled" boolean NOT NULL DEFAULT true;
    COMMENT ON COLUMN "groups"."memberDirectoryEnabled" IS 'Allow members to see contact info of other members';
  END IF;
END $$;

-- members.userId and members.userLinkedAt (from migration 20260203052425)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='members' AND column_name='userId') THEN
    ALTER TABLE "members" ADD COLUMN "userId" uuid NULL;
    ALTER TABLE "members" ADD CONSTRAINT "members_userId_key" UNIQUE ("userId");
    ALTER TABLE "members" ADD CONSTRAINT "fk_members_linkedUser"
      FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
    CREATE INDEX "idx_members_userId" ON "members" ("userId");
    COMMENT ON COLUMN "members"."userId" IS 'Links Member to User account for bidirectional access';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='members' AND column_name='userLinkedAt') THEN
    ALTER TABLE "members" ADD COLUMN "userLinkedAt" timestamp NULL;
    COMMENT ON COLUMN "members"."userLinkedAt" IS 'When account was linked to User';
  END IF;
END $$;

-- member_lesson_progress table (from migration 20260203052525)
CREATE TABLE IF NOT EXISTS "member_lesson_progress" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NOT NULL,
  "lessonScheduleId" uuid NOT NULL,
  "startedAt" timestamp NOT NULL DEFAULT now(),
  "completedAt" timestamp NULL,
  "lastUpdatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "member_lesson_progress_memberId_lessonScheduleId_key" UNIQUE ("memberId", "lessonScheduleId"),
  CONSTRAINT "fk_member_lesson_progress_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_lesson_progress_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "idx_member_lesson_progress_lessonScheduleId" ON "member_lesson_progress" ("lessonScheduleId");
CREATE INDEX IF NOT EXISTS "idx_member_lesson_progress_memberId" ON "member_lesson_progress" ("memberId");
CREATE INDEX IF NOT EXISTS "idx_member_lesson_progress_memberId_completedAt" ON "member_lesson_progress" ("memberId", "completedAt");

-- member_lesson_progress.lastUpdatedAt should NOT have a default (migration 20260207201008 drops it)
-- If the table was just created above, it already has no default. If it existed before, remove the default.
ALTER TABLE "member_lesson_progress" ALTER COLUMN "lastUpdatedAt" DROP DEFAULT;


-- ============================================================================
-- PHASE 7: Verification queries
-- ============================================================================
-- These SELECT statements will confirm the conversion worked.
-- They are informational only — if something is wrong, the transaction can be rolled back.

DO $$
DECLARE
  bad_count integer;
BEGIN
  SELECT count(*) INTO bad_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND column_name = 'id'
    AND data_type IN ('text', 'character varying')
    AND table_name NOT IN ('session', '_seed_versions', '_prisma_migrations', 'atlas_schema_revisions')
    AND table_name NOT LIKE '\_%';

  IF bad_count > 0 THEN
    RAISE WARNING '% tables still have text/varchar id columns — review before committing', bad_count;
  ELSE
    RAISE NOTICE 'All id columns are uuid type';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- DONE! Next steps:
-- 1. Verify: SELECT pg_typeof(id) FROM users LIMIT 1;  -- should return 'uuid'
-- 2. Baseline Atlas:
--    cd atlas && atlas migrate apply --env production --baseline 20260207201008
-- 3. Verify Atlas status:
--    cd atlas && atlas migrate status --env production
-- ============================================================================
