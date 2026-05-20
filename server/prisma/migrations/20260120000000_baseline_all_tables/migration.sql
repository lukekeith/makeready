-- Baseline Migration: Captures all tables that were created via db push
-- This migration uses IF NOT EXISTS and exception handling to be safe to run
-- on an existing database without losing data.
--
-- Generated: 2026-01-20
-- Purpose: Bring migrations up to parity with production schema
--
-- IMPORTANT: This migration is idempotent - safe to run multiple times

-- ============================================================================
-- EXTENSIONS (required before creating tables that use these types)
-- ============================================================================

-- pgvector extension for embedding columns
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- ENUMS (with exception handling for existing types)
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE "Testament" AS ENUM ('OLD_TESTAMENT', 'NEW_TESTAMENT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "HighlightColor" AS ENUM ('YELLOW', 'BLUE', 'GREEN', 'ORANGE', 'PURPLE', 'PINK');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ActivityType" AS ENUM ('SOAP', 'OIA', 'DBS', 'HEAR', 'VIDEO');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ActivityStatus" AS ENUM ('PENDING', 'COMPLETE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "HighlightMode" AS ENUM ('HIGHLIGHT', 'CHAPTER', 'VERSE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "EventType" AS ENUM ('LESSON', 'MEETING', 'ONLINE', 'DEADLINE', 'SOCIAL', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "EventVisibility" AS ENUM ('PRIVATE', 'PUBLIC');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "RsvpStatus" AS ENUM ('GOING', 'MAYBE', 'NOT_GOING', 'PENDING');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "RecurrenceFrequency" AS ENUM ('NONE', 'DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'YEARLY');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "PostType" AS ENUM ('WELCOME', 'POLL', 'VIDEO', 'EVENT', 'ANNOUNCEMENT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "LogCategory" AS ENUM ('AUTH', 'JOIN', 'ACCESS');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "LogStatus" AS ENUM ('SUCCESS', 'FAILURE', 'WARNING');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- TABLES (using IF NOT EXISTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS "users" (
    "id" TEXT NOT NULL,
    "googleId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "picture" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "phoneNumber" TEXT,
    "phoneVerified" BOOLEAN NOT NULL DEFAULT false,
    "organizationId" TEXT,
    "isSuperAdmin" BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "groups" (
    "id" TEXT NOT NULL,
    "code" TEXT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "coverImageUrl" TEXT,
    "isPrivate" BOOLEAN NOT NULL DEFAULT false,
    "allowInvites" BOOLEAN NOT NULL DEFAULT true,
    "welcomeMessage" TEXT,
    "ageRangeMin" INTEGER,
    "ageRangeMax" INTEGER,
    "maxMembers" INTEGER,
    "creatorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "organizationId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "group_members" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'member',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "memberId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT "group_members_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "invites" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "groupId" TEXT,
    "inviterId" TEXT NOT NULL,
    "recipientPhone" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acceptedAt" TIMESTAMP(3),
    CONSTRAINT "invites_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "organizations" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "twilioVerifyServiceSid" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "members" (
    "id" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "phoneVerified" BOOLEAN NOT NULL DEFAULT false,
    "firstName" TEXT,
    "lastName" TEXT,
    "email" TEXT,
    "birthday" TIMESTAMP(3),
    "profilePicture" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastVerifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "members_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "member_organizations" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "member_organizations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "roles" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "organizationId" TEXT,
    "isSystem" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "permissions" (
    "id" TEXT NOT NULL,
    "resource" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "role_permissions" (
    "id" TEXT NOT NULL,
    "roleId" TEXT NOT NULL,
    "permissionId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "user_roles" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "roleId" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "assignedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "assignedBy" TEXT,
    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "media" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "url" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "mimeType" TEXT,
    "fileSize" INTEGER,
    "organizationId" TEXT NOT NULL,
    "groupId" TEXT,
    "uploadedBy" TEXT NOT NULL,
    "visibility" TEXT NOT NULL DEFAULT 'members',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "media_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "videos" (
    "id" TEXT NOT NULL,
    "title" TEXT,
    "description" TEXT,
    "cloudflareUid" TEXT NOT NULL,
    "playbackUrl" TEXT NOT NULL,
    "thumbnailUrl" TEXT,
    "duration" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "userId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "videos_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "translations" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "language" TEXT NOT NULL,
    "description" TEXT,
    "copyright" TEXT,
    "license" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "translations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "books" (
    "id" TEXT NOT NULL,
    "translationId" TEXT NOT NULL,
    "bookNumber" INTEGER NOT NULL,
    "bookName" TEXT NOT NULL,
    "bookAbbrev" TEXT NOT NULL,
    "testament" "Testament" NOT NULL,
    "chapters" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "books_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "verses" (
    "id" TEXT NOT NULL,
    "translationId" TEXT NOT NULL,
    "bookId" TEXT NOT NULL,
    "bookNumber" INTEGER NOT NULL,
    "chapter" INTEGER NOT NULL,
    "verse" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    "searchVector" tsvector,
    "embedding" vector(384),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "verses_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "highlights" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "translationId" TEXT NOT NULL,
    "bookNumber" INTEGER NOT NULL,
    "chapter" INTEGER NOT NULL,
    "verseStart" INTEGER NOT NULL,
    "verseEnd" INTEGER,
    "color" "HighlightColor" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "highlights_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "verse_notes" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "translationId" TEXT NOT NULL,
    "bookNumber" INTEGER NOT NULL,
    "chapter" INTEGER NOT NULL,
    "verseStart" INTEGER NOT NULL,
    "verseEnd" INTEGER,
    "content" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "verse_notes_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "bookmarks" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "translationId" TEXT NOT NULL,
    "bookNumber" INTEGER NOT NULL,
    "chapter" INTEGER NOT NULL,
    "verseStart" INTEGER NOT NULL,
    "verseEnd" INTEGER,
    "label" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bookmarks_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "activity_type_configs" (
    "id" TEXT NOT NULL,
    "type" "ActivityType" NOT NULL,
    "maxPerLesson" INTEGER,
    "category" TEXT,
    "categoryMax" INTEGER,
    "displayName" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "activity_type_configs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "study_programs" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "defaultActivity" "ActivityType" NOT NULL DEFAULT 'SOAP',
    "days" INTEGER NOT NULL DEFAULT 30,
    "coverImageUrl" TEXT,
    "requireResponse" BOOLEAN NOT NULL DEFAULT true,
    "creatorId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "study_programs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "lessons" (
    "id" TEXT NOT NULL,
    "studyProgramId" TEXT NOT NULL,
    "dayNumber" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "lessons_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "lesson_activities" (
    "id" TEXT NOT NULL,
    "lessonId" TEXT NOT NULL,
    "type" "ActivityType" NOT NULL DEFAULT 'SOAP',
    "status" "ActivityStatus" NOT NULL DEFAULT 'PENDING',
    "highlightMode" "HighlightMode" NOT NULL DEFAULT 'HIGHLIGHT',
    "passageReference" TEXT,
    "bookNumber" INTEGER,
    "bookName" TEXT,
    "chapterStart" INTEGER,
    "chapterEnd" INTEGER,
    "verseStart" INTEGER,
    "verseEnd" INTEGER,
    "startElementId" TEXT,
    "startOffset" INTEGER,
    "endElementId" TEXT,
    "endOffset" INTEGER,
    "selectedVerses" JSONB,
    "videoId" TEXT,
    "videoUrl" TEXT,
    "orderNumber" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "lesson_activities_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "enrollments" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "studyProgramId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "enabledDays" TEXT NOT NULL,
    "smsTime" TEXT,
    "timezone" TEXT,
    "requireResponse" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdById" TEXT,
    CONSTRAINT "enrollments_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "lesson_schedules" (
    "id" TEXT NOT NULL,
    "code" TEXT,
    "enrollmentId" TEXT NOT NULL,
    "lessonId" TEXT NOT NULL,
    "scheduledDate" TIMESTAMP(3) NOT NULL,
    "smsSentAt" TIMESTAMP(3),
    CONSTRAINT "lesson_schedules_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "events" (
    "id" TEXT NOT NULL,
    "code" TEXT,
    "groupId" TEXT NOT NULL,
    "type" "EventType" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "date" TIMESTAMP(3) NOT NULL,
    "startTime" TEXT,
    "endTime" TEXT,
    "isAllDay" BOOLEAN NOT NULL DEFAULT false,
    "timezone" TEXT,
    "coverImageUrl" TEXT,
    "externalUrl" TEXT,
    "visibility" "EventVisibility" NOT NULL DEFAULT 'PRIVATE',
    "locationName" TEXT,
    "locationAddress" TEXT,
    "locationLat" DECIMAL(10,8),
    "locationLng" DECIMAL(11,8),
    "googlePlaceId" TEXT,
    "recurrenceFrequency" "RecurrenceFrequency" NOT NULL DEFAULT 'NONE',
    "recurrenceEndDate" TIMESTAMP(3),
    "recurrenceCount" INTEGER,
    "recurrenceGroupId" TEXT,
    "isRecurrenceParent" BOOLEAN NOT NULL DEFAULT false,
    "alertMinutesBefore" INTEGER,
    "lessonScheduleId" TEXT,
    "enrollmentId" TEXT,
    "dayNumber" INTEGER,
    "createdById" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "event_attendees" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "groupMemberId" TEXT,
    "phoneNumber" TEXT,
    "firstName" TEXT,
    "lastName" TEXT,
    "gender" TEXT,
    "birthdate" TIMESTAMP(3),
    "rsvpStatus" "RsvpStatus" NOT NULL DEFAULT 'PENDING',
    "rsvpAt" TIMESTAMP(3),
    "checkedIn" BOOLEAN NOT NULL DEFAULT false,
    "checkedInAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "event_attendees_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "event_attachments" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileType" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "uploadedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "event_attachments_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "posts" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "authorId" TEXT,
    "type" "PostType" NOT NULL,
    "title" TEXT,
    "content" TEXT NOT NULL,
    "imageUrl" TEXT,
    "pollOptions" JSONB,
    "videoUrl" TEXT,
    "eventDate" TIMESTAMP(3),
    "eventLocation" TEXT,
    "enrollmentId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "posts_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "group_join_requests" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "message" TEXT,
    "reviewedById" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "group_join_requests_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "study_notes" (
    "id" TEXT NOT NULL,
    "memberId" TEXT,
    "userId" TEXT,
    "type" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "study_notes_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "note_links" (
    "id" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "refType" TEXT NOT NULL,
    "refId" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "note_links_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "member_activity_progress" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "lessonScheduleId" TEXT NOT NULL,
    "lessonActivityId" TEXT NOT NULL,
    "currentStep" TEXT NOT NULL DEFAULT 'READ_SCRIPTURE',
    "completedSteps" TEXT[],
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),
    "lastUpdatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "member_activity_progress_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "member_video_progress" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "lessonScheduleId" TEXT NOT NULL,
    "lessonActivityId" TEXT NOT NULL,
    "watchedSeconds" INTEGER NOT NULL DEFAULT 0,
    "totalDuration" INTEGER,
    "watchPercentage" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastWatchedAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3),
    CONSTRAINT "member_video_progress_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "activity_logs" (
    "id" TEXT NOT NULL,
    "category" "LogCategory" NOT NULL,
    "activityType" TEXT NOT NULL,
    "status" "LogStatus" NOT NULL,
    "userId" TEXT,
    "memberId" TEXT,
    "actorIp" TEXT,
    "userAgent" TEXT,
    "route" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "groupId" TEXT,
    "eventId" TEXT,
    "enrollmentId" TEXT,
    "lessonId" TEXT,
    "organizationId" TEXT,
    "inviteId" TEXT,
    "message" TEXT NOT NULL,
    "errorCode" TEXT,
    "errorMessage" TEXT,
    "warningMessage" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id")
);

-- ============================================================================
-- INDEXES (using IF NOT EXISTS)
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS "users_googleId_key" ON "users"("googleId");
CREATE UNIQUE INDEX IF NOT EXISTS "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX IF NOT EXISTS "users_phoneNumber_key" ON "users"("phoneNumber");
CREATE INDEX IF NOT EXISTS "users_organizationId_idx" ON "users"("organizationId");
CREATE INDEX IF NOT EXISTS "users_isSuperAdmin_idx" ON "users"("isSuperAdmin");

CREATE UNIQUE INDEX IF NOT EXISTS "groups_code_key" ON "groups"("code");
CREATE INDEX IF NOT EXISTS "groups_organizationId_idx" ON "groups"("organizationId");
CREATE INDEX IF NOT EXISTS "groups_isActive_idx" ON "groups"("isActive");
CREATE INDEX IF NOT EXISTS "groups_organizationId_isActive_idx" ON "groups"("organizationId", "isActive");

CREATE INDEX IF NOT EXISTS "group_members_groupId_idx" ON "group_members"("groupId");
CREATE INDEX IF NOT EXISTS "group_members_memberId_idx" ON "group_members"("memberId");
CREATE INDEX IF NOT EXISTS "group_members_isActive_idx" ON "group_members"("isActive");
CREATE INDEX IF NOT EXISTS "group_members_groupId_isActive_idx" ON "group_members"("groupId", "isActive");
CREATE UNIQUE INDEX IF NOT EXISTS "group_members_groupId_memberId_key" ON "group_members"("groupId", "memberId");

CREATE UNIQUE INDEX IF NOT EXISTS "invites_token_key" ON "invites"("token");

CREATE UNIQUE INDEX IF NOT EXISTS "organizations_ownerId_key" ON "organizations"("ownerId");
CREATE INDEX IF NOT EXISTS "organizations_ownerId_idx" ON "organizations"("ownerId");
CREATE INDEX IF NOT EXISTS "organizations_isActive_idx" ON "organizations"("isActive");

CREATE UNIQUE INDEX IF NOT EXISTS "members_phoneNumber_key" ON "members"("phoneNumber");
CREATE INDEX IF NOT EXISTS "members_isActive_idx" ON "members"("isActive");
CREATE INDEX IF NOT EXISTS "members_phoneNumber_idx" ON "members"("phoneNumber");

CREATE INDEX IF NOT EXISTS "member_organizations_memberId_idx" ON "member_organizations"("memberId");
CREATE INDEX IF NOT EXISTS "member_organizations_organizationId_idx" ON "member_organizations"("organizationId");
CREATE UNIQUE INDEX IF NOT EXISTS "member_organizations_memberId_organizationId_key" ON "member_organizations"("memberId", "organizationId");

CREATE INDEX IF NOT EXISTS "roles_organizationId_idx" ON "roles"("organizationId");
CREATE INDEX IF NOT EXISTS "roles_isSystem_idx" ON "roles"("isSystem");
CREATE UNIQUE INDEX IF NOT EXISTS "roles_name_organizationId_key" ON "roles"("name", "organizationId");

CREATE UNIQUE INDEX IF NOT EXISTS "permissions_name_key" ON "permissions"("name");
CREATE INDEX IF NOT EXISTS "permissions_resource_idx" ON "permissions"("resource");
CREATE INDEX IF NOT EXISTS "permissions_action_idx" ON "permissions"("action");

CREATE INDEX IF NOT EXISTS "role_permissions_roleId_idx" ON "role_permissions"("roleId");
CREATE INDEX IF NOT EXISTS "role_permissions_permissionId_idx" ON "role_permissions"("permissionId");
CREATE UNIQUE INDEX IF NOT EXISTS "role_permissions_roleId_permissionId_key" ON "role_permissions"("roleId", "permissionId");

CREATE INDEX IF NOT EXISTS "user_roles_userId_idx" ON "user_roles"("userId");
CREATE INDEX IF NOT EXISTS "user_roles_roleId_idx" ON "user_roles"("roleId");
CREATE INDEX IF NOT EXISTS "user_roles_organizationId_idx" ON "user_roles"("organizationId");
CREATE UNIQUE INDEX IF NOT EXISTS "user_roles_userId_roleId_organizationId_key" ON "user_roles"("userId", "roleId", "organizationId");

CREATE INDEX IF NOT EXISTS "media_organizationId_idx" ON "media"("organizationId");
CREATE INDEX IF NOT EXISTS "media_groupId_idx" ON "media"("groupId");
CREATE INDEX IF NOT EXISTS "media_uploadedBy_idx" ON "media"("uploadedBy");
CREATE INDEX IF NOT EXISTS "media_visibility_idx" ON "media"("visibility");
CREATE INDEX IF NOT EXISTS "media_isActive_idx" ON "media"("isActive");
CREATE INDEX IF NOT EXISTS "media_type_idx" ON "media"("type");

CREATE UNIQUE INDEX IF NOT EXISTS "videos_cloudflareUid_key" ON "videos"("cloudflareUid");
CREATE INDEX IF NOT EXISTS "videos_userId_idx" ON "videos"("userId");
CREATE INDEX IF NOT EXISTS "videos_status_idx" ON "videos"("status");
CREATE INDEX IF NOT EXISTS "videos_isActive_idx" ON "videos"("isActive");

CREATE UNIQUE INDEX IF NOT EXISTS "translations_code_key" ON "translations"("code");
CREATE INDEX IF NOT EXISTS "translations_code_idx" ON "translations"("code");

CREATE INDEX IF NOT EXISTS "books_translationId_testament_idx" ON "books"("translationId", "testament");
CREATE INDEX IF NOT EXISTS "books_bookNumber_idx" ON "books"("bookNumber");
CREATE UNIQUE INDEX IF NOT EXISTS "books_translationId_bookNumber_key" ON "books"("translationId", "bookNumber");
CREATE UNIQUE INDEX IF NOT EXISTS "books_translationId_bookName_key" ON "books"("translationId", "bookName");

CREATE INDEX IF NOT EXISTS "verses_bookId_chapter_verse_idx" ON "verses"("bookId", "chapter", "verse");
CREATE INDEX IF NOT EXISTS "verses_translationId_bookNumber_chapter_verse_idx" ON "verses"("translationId", "bookNumber", "chapter", "verse");
CREATE UNIQUE INDEX IF NOT EXISTS "verses_translationId_bookNumber_chapter_verse_key" ON "verses"("translationId", "bookNumber", "chapter", "verse");

CREATE INDEX IF NOT EXISTS "highlights_userId_translationId_idx" ON "highlights"("userId", "translationId");

CREATE INDEX IF NOT EXISTS "verse_notes_userId_translationId_idx" ON "verse_notes"("userId", "translationId");

CREATE INDEX IF NOT EXISTS "bookmarks_userId_createdAt_idx" ON "bookmarks"("userId", "createdAt");

CREATE UNIQUE INDEX IF NOT EXISTS "activity_type_configs_type_key" ON "activity_type_configs"("type");
CREATE INDEX IF NOT EXISTS "activity_type_configs_category_idx" ON "activity_type_configs"("category");

CREATE INDEX IF NOT EXISTS "study_programs_creatorId_idx" ON "study_programs"("creatorId");
CREATE INDEX IF NOT EXISTS "study_programs_isActive_idx" ON "study_programs"("isActive");

CREATE INDEX IF NOT EXISTS "lessons_studyProgramId_idx" ON "lessons"("studyProgramId");
CREATE UNIQUE INDEX IF NOT EXISTS "lessons_studyProgramId_dayNumber_key" ON "lessons"("studyProgramId", "dayNumber");

CREATE INDEX IF NOT EXISTS "lesson_activities_lessonId_idx" ON "lesson_activities"("lessonId");
CREATE INDEX IF NOT EXISTS "lesson_activities_videoId_idx" ON "lesson_activities"("videoId");
CREATE UNIQUE INDEX IF NOT EXISTS "lesson_activities_lessonId_orderNumber_key" ON "lesson_activities"("lessonId", "orderNumber");

CREATE INDEX IF NOT EXISTS "enrollments_groupId_idx" ON "enrollments"("groupId");
CREATE INDEX IF NOT EXISTS "enrollments_studyProgramId_idx" ON "enrollments"("studyProgramId");
CREATE INDEX IF NOT EXISTS "enrollments_createdById_idx" ON "enrollments"("createdById");
CREATE INDEX IF NOT EXISTS "enrollments_startDate_idx" ON "enrollments"("startDate");

CREATE UNIQUE INDEX IF NOT EXISTS "lesson_schedules_code_key" ON "lesson_schedules"("code");
CREATE INDEX IF NOT EXISTS "lesson_schedules_enrollmentId_idx" ON "lesson_schedules"("enrollmentId");
CREATE INDEX IF NOT EXISTS "lesson_schedules_lessonId_idx" ON "lesson_schedules"("lessonId");
CREATE INDEX IF NOT EXISTS "lesson_schedules_scheduledDate_idx" ON "lesson_schedules"("scheduledDate");
CREATE INDEX IF NOT EXISTS "lesson_schedules_smsSentAt_idx" ON "lesson_schedules"("smsSentAt");
CREATE INDEX IF NOT EXISTS "lesson_schedules_code_idx" ON "lesson_schedules"("code");
CREATE UNIQUE INDEX IF NOT EXISTS "lesson_schedules_enrollmentId_lessonId_key" ON "lesson_schedules"("enrollmentId", "lessonId");

CREATE UNIQUE INDEX IF NOT EXISTS "events_code_key" ON "events"("code");
CREATE UNIQUE INDEX IF NOT EXISTS "events_lessonScheduleId_key" ON "events"("lessonScheduleId");
CREATE INDEX IF NOT EXISTS "events_groupId_idx" ON "events"("groupId");
CREATE INDEX IF NOT EXISTS "events_date_idx" ON "events"("date");
CREATE INDEX IF NOT EXISTS "events_groupId_date_idx" ON "events"("groupId", "date");
CREATE INDEX IF NOT EXISTS "events_type_idx" ON "events"("type");
CREATE INDEX IF NOT EXISTS "events_visibility_idx" ON "events"("visibility");
CREATE INDEX IF NOT EXISTS "events_code_idx" ON "events"("code");
CREATE INDEX IF NOT EXISTS "events_recurrenceGroupId_idx" ON "events"("recurrenceGroupId");
CREATE INDEX IF NOT EXISTS "events_enrollmentId_idx" ON "events"("enrollmentId");

CREATE INDEX IF NOT EXISTS "event_attendees_eventId_idx" ON "event_attendees"("eventId");
CREATE INDEX IF NOT EXISTS "event_attendees_rsvpStatus_idx" ON "event_attendees"("rsvpStatus");
CREATE UNIQUE INDEX IF NOT EXISTS "event_attendees_eventId_groupMemberId_key" ON "event_attendees"("eventId", "groupMemberId");
CREATE UNIQUE INDEX IF NOT EXISTS "event_attendees_eventId_phoneNumber_key" ON "event_attendees"("eventId", "phoneNumber");

CREATE INDEX IF NOT EXISTS "event_attachments_eventId_idx" ON "event_attachments"("eventId");

CREATE UNIQUE INDEX IF NOT EXISTS "posts_enrollmentId_key" ON "posts"("enrollmentId");
CREATE INDEX IF NOT EXISTS "posts_groupId_idx" ON "posts"("groupId");
CREATE INDEX IF NOT EXISTS "posts_groupId_createdAt_idx" ON "posts"("groupId", "createdAt");
CREATE INDEX IF NOT EXISTS "posts_authorId_idx" ON "posts"("authorId");
CREATE INDEX IF NOT EXISTS "posts_type_idx" ON "posts"("type");
CREATE INDEX IF NOT EXISTS "posts_isActive_idx" ON "posts"("isActive");

CREATE INDEX IF NOT EXISTS "group_join_requests_groupId_status_idx" ON "group_join_requests"("groupId", "status");
CREATE INDEX IF NOT EXISTS "group_join_requests_memberId_idx" ON "group_join_requests"("memberId");
CREATE UNIQUE INDEX IF NOT EXISTS "group_join_requests_groupId_memberId_key" ON "group_join_requests"("groupId", "memberId");

CREATE INDEX IF NOT EXISTS "study_notes_memberId_idx" ON "study_notes"("memberId");
CREATE INDEX IF NOT EXISTS "study_notes_userId_idx" ON "study_notes"("userId");
CREATE INDEX IF NOT EXISTS "study_notes_memberId_type_idx" ON "study_notes"("memberId", "type");
CREATE INDEX IF NOT EXISTS "study_notes_userId_type_idx" ON "study_notes"("userId", "type");
CREATE INDEX IF NOT EXISTS "study_notes_memberId_createdAt_idx" ON "study_notes"("memberId", "createdAt");
CREATE INDEX IF NOT EXISTS "study_notes_userId_createdAt_idx" ON "study_notes"("userId", "createdAt");
CREATE INDEX IF NOT EXISTS "study_notes_type_idx" ON "study_notes"("type");
CREATE INDEX IF NOT EXISTS "study_notes_createdAt_idx" ON "study_notes"("createdAt");
CREATE INDEX IF NOT EXISTS "study_notes_isActive_idx" ON "study_notes"("isActive");

CREATE INDEX IF NOT EXISTS "note_links_refType_refId_idx" ON "note_links"("refType", "refId");
CREATE INDEX IF NOT EXISTS "note_links_noteId_idx" ON "note_links"("noteId");
CREATE INDEX IF NOT EXISTS "note_links_refType_idx" ON "note_links"("refType");
CREATE UNIQUE INDEX IF NOT EXISTS "note_links_noteId_refType_refId_key" ON "note_links"("noteId", "refType", "refId");

CREATE INDEX IF NOT EXISTS "member_activity_progress_memberId_idx" ON "member_activity_progress"("memberId");
CREATE INDEX IF NOT EXISTS "member_activity_progress_lessonScheduleId_idx" ON "member_activity_progress"("lessonScheduleId");
CREATE INDEX IF NOT EXISTS "member_activity_progress_lessonActivityId_idx" ON "member_activity_progress"("lessonActivityId");
CREATE INDEX IF NOT EXISTS "member_activity_progress_memberId_completedAt_idx" ON "member_activity_progress"("memberId", "completedAt");
CREATE UNIQUE INDEX IF NOT EXISTS "member_activity_progress_memberId_lessonScheduleId_lessonAc_key" ON "member_activity_progress"("memberId", "lessonScheduleId", "lessonActivityId");

CREATE INDEX IF NOT EXISTS "member_video_progress_memberId_idx" ON "member_video_progress"("memberId");
CREATE INDEX IF NOT EXISTS "member_video_progress_lessonScheduleId_idx" ON "member_video_progress"("lessonScheduleId");
CREATE INDEX IF NOT EXISTS "member_video_progress_lessonActivityId_idx" ON "member_video_progress"("lessonActivityId");
CREATE INDEX IF NOT EXISTS "member_video_progress_memberId_completedAt_idx" ON "member_video_progress"("memberId", "completedAt");
CREATE UNIQUE INDEX IF NOT EXISTS "member_video_progress_memberId_lessonScheduleId_lessonActiv_key" ON "member_video_progress"("memberId", "lessonScheduleId", "lessonActivityId");

CREATE INDEX IF NOT EXISTS "activity_logs_category_idx" ON "activity_logs"("category");
CREATE INDEX IF NOT EXISTS "activity_logs_activityType_idx" ON "activity_logs"("activityType");
CREATE INDEX IF NOT EXISTS "activity_logs_status_idx" ON "activity_logs"("status");
CREATE INDEX IF NOT EXISTS "activity_logs_userId_idx" ON "activity_logs"("userId");
CREATE INDEX IF NOT EXISTS "activity_logs_memberId_idx" ON "activity_logs"("memberId");
CREATE INDEX IF NOT EXISTS "activity_logs_groupId_idx" ON "activity_logs"("groupId");
CREATE INDEX IF NOT EXISTS "activity_logs_createdAt_idx" ON "activity_logs"("createdAt");
CREATE INDEX IF NOT EXISTS "activity_logs_category_createdAt_idx" ON "activity_logs"("category", "createdAt");
CREATE INDEX IF NOT EXISTS "activity_logs_activityType_status_idx" ON "activity_logs"("activityType", "status");

-- ============================================================================
-- FOREIGN KEYS (with exception handling for existing constraints)
-- ============================================================================

DO $$ BEGIN ALTER TABLE "groups" ADD CONSTRAINT "groups_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "group_members" ADD CONSTRAINT "group_members_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "group_members" ADD CONSTRAINT "group_members_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "invites" ADD CONSTRAINT "invites_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "invites" ADD CONSTRAINT "invites_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "organizations" ADD CONSTRAINT "organizations_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_organizations" ADD CONSTRAINT "member_organizations_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_organizations" ADD CONSTRAINT "member_organizations_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "roles" ADD CONSTRAINT "roles_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permissionId_fkey" FOREIGN KEY ("permissionId") REFERENCES "permissions"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "media" ADD CONSTRAINT "media_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "media" ADD CONSTRAINT "media_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "media" ADD CONSTRAINT "media_uploadedBy_fkey" FOREIGN KEY ("uploadedBy") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "videos" ADD CONSTRAINT "videos_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "books" ADD CONSTRAINT "books_translationId_fkey" FOREIGN KEY ("translationId") REFERENCES "translations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "verses" ADD CONSTRAINT "verses_translationId_fkey" FOREIGN KEY ("translationId") REFERENCES "translations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "verses" ADD CONSTRAINT "verses_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "books"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "highlights" ADD CONSTRAINT "highlights_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "highlights" ADD CONSTRAINT "highlights_translationId_fkey" FOREIGN KEY ("translationId") REFERENCES "translations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "verse_notes" ADD CONSTRAINT "verse_notes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "verse_notes" ADD CONSTRAINT "verse_notes_translationId_fkey" FOREIGN KEY ("translationId") REFERENCES "translations"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "bookmarks" ADD CONSTRAINT "bookmarks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "study_programs" ADD CONSTRAINT "study_programs_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "lessons" ADD CONSTRAINT "lessons_studyProgramId_fkey" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "lesson_activities" ADD CONSTRAINT "lesson_activities_lessonId_fkey" FOREIGN KEY ("lessonId") REFERENCES "lessons"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "lesson_activities" ADD CONSTRAINT "lesson_activities_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "videos"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_studyProgramId_fkey" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "lesson_schedules" ADD CONSTRAINT "lesson_schedules_enrollmentId_fkey" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "lesson_schedules" ADD CONSTRAINT "lesson_schedules_lessonId_fkey" FOREIGN KEY ("lessonId") REFERENCES "lessons"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "events" ADD CONSTRAINT "events_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "events" ADD CONSTRAINT "events_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "events" ADD CONSTRAINT "events_lessonScheduleId_fkey" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "events" ADD CONSTRAINT "events_enrollmentId_fkey" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "event_attendees" ADD CONSTRAINT "event_attendees_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "event_attendees" ADD CONSTRAINT "event_attendees_groupMemberId_fkey" FOREIGN KEY ("groupMemberId") REFERENCES "group_members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "event_attachments" ADD CONSTRAINT "event_attachments_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "event_attachments" ADD CONSTRAINT "event_attachments_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "posts" ADD CONSTRAINT "posts_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "posts" ADD CONSTRAINT "posts_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "posts" ADD CONSTRAINT "posts_enrollmentId_fkey" FOREIGN KEY ("enrollmentId") REFERENCES "enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "group_join_requests" ADD CONSTRAINT "group_join_requests_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "group_join_requests" ADD CONSTRAINT "group_join_requests_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "group_join_requests" ADD CONSTRAINT "group_join_requests_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "study_notes" ADD CONSTRAINT "study_notes_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "study_notes" ADD CONSTRAINT "study_notes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "note_links" ADD CONSTRAINT "note_links_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "study_notes"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_activity_progress" ADD CONSTRAINT "member_activity_progress_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_activity_progress" ADD CONSTRAINT "member_activity_progress_lessonScheduleId_fkey" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_activity_progress" ADD CONSTRAINT "member_activity_progress_lessonActivityId_fkey" FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_video_progress" ADD CONSTRAINT "member_video_progress_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_video_progress" ADD CONSTRAINT "member_video_progress_lessonScheduleId_fkey" FOREIGN KEY ("lessonScheduleId") REFERENCES "lesson_schedules"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE "member_video_progress" ADD CONSTRAINT "member_video_progress_lessonActivityId_fkey" FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
