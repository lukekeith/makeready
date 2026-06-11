-- Install required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
-- Create enum type "ActivityType"
CREATE TYPE "public"."ActivityType" AS ENUM ('SOAP', 'OIA', 'DBS', 'HEAR', 'VIDEO');
-- Create "activity_type_configs" table
CREATE TABLE "public"."activity_type_configs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "type" "public"."ActivityType" NOT NULL,
  "maxPerLesson" integer NULL,
  "category" character varying NULL,
  "categoryMax" integer NULL,
  "displayName" character varying NOT NULL,
  "description" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "activity_type_configs_type_key" UNIQUE ("type")
);
-- Create index "idx_activity_type_configs_category" to table: "activity_type_configs"
CREATE INDEX "idx_activity_type_configs_category" ON "public"."activity_type_configs" ("category");
-- Set comment to column: "maxPerLesson" on table: "activity_type_configs"
COMMENT ON COLUMN "public"."activity_type_configs"."maxPerLesson" IS 'NULL = unlimited';
-- Set comment to column: "category" on table: "activity_type_configs"
COMMENT ON COLUMN "public"."activity_type_configs"."category" IS 'For mutual exclusivity (e.g., ''STUDY'')';
-- Set comment to column: "categoryMax" on table: "activity_type_configs"
COMMENT ON COLUMN "public"."activity_type_configs"."categoryMax" IS 'Max total of this category per lesson';
-- Create enum type "ActivityStatus"
CREATE TYPE "public"."ActivityStatus" AS ENUM ('PENDING', 'COMPLETE');
-- Create enum type "LogStatus"
CREATE TYPE "public"."LogStatus" AS ENUM ('SUCCESS', 'FAILURE', 'WARNING');
-- Create enum type "LogCategory"
CREATE TYPE "public"."LogCategory" AS ENUM ('AUTH', 'JOIN', 'ACCESS');
-- Create enum type "PostType"
CREATE TYPE "public"."PostType" AS ENUM ('WELCOME', 'POLL', 'VIDEO', 'EVENT', 'ANNOUNCEMENT');
-- Create enum type "RecurrenceFrequency"
CREATE TYPE "public"."RecurrenceFrequency" AS ENUM ('NONE', 'DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'YEARLY');
-- Create enum type "RsvpStatus"
CREATE TYPE "public"."RsvpStatus" AS ENUM ('GOING', 'MAYBE', 'NOT_GOING', 'PENDING');
-- Create enum type "EventVisibility"
CREATE TYPE "public"."EventVisibility" AS ENUM ('PRIVATE', 'PUBLIC');
-- Create enum type "HighlightMode"
CREATE TYPE "public"."HighlightMode" AS ENUM ('HIGHLIGHT', 'CHAPTER', 'VERSE');
-- Create "users" table
CREATE TABLE "public"."users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "googleId" character varying NOT NULL,
  "email" character varying NOT NULL,
  "name" character varying NOT NULL,
  "picture" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  "phoneNumber" character varying NULL,
  "phoneVerified" boolean NOT NULL DEFAULT false,
  "organizationId" character varying NULL,
  "isSuperAdmin" boolean NOT NULL DEFAULT false,
  PRIMARY KEY ("id"),
  CONSTRAINT "users_email_key" UNIQUE ("email"),
  CONSTRAINT "users_googleId_key" UNIQUE ("googleId"),
  CONSTRAINT "users_phoneNumber_key" UNIQUE ("phoneNumber")
);
-- Create index "idx_users_isSuperAdmin" to table: "users"
CREATE INDEX "idx_users_isSuperAdmin" ON "public"."users" ("isSuperAdmin");
-- Create index "idx_users_organizationId" to table: "users"
CREATE INDEX "idx_users_organizationId" ON "public"."users" ("organizationId");
-- Set comment to column: "organizationId" on table: "users"
COMMENT ON COLUMN "public"."users"."organizationId" IS 'DEPRECATED: Use UserRole relation instead';
-- Set comment to column: "isSuperAdmin" on table: "users"
COMMENT ON COLUMN "public"."users"."isSuperAdmin" IS 'Platform-wide super admin';
-- Create enum type "HighlightColor"
CREATE TYPE "public"."HighlightColor" AS ENUM ('YELLOW', 'BLUE', 'GREEN', 'ORANGE', 'PURPLE', 'PINK');
-- Create enum type "Testament"
CREATE TYPE "public"."Testament" AS ENUM ('OLD_TESTAMENT', 'NEW_TESTAMENT');
-- Create "_seed_versions" table
CREATE TABLE "public"."_seed_versions" (
  "version" character varying NOT NULL,
  "applied_at" timestamp NOT NULL DEFAULT now(),
  "checksum" character varying NULL,
  PRIMARY KEY ("version")
);
-- Create "activity_logs" table
CREATE TABLE "public"."activity_logs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "category" "public"."LogCategory" NOT NULL,
  "activityType" character varying NOT NULL,
  "status" "public"."LogStatus" NOT NULL,
  "userId" character varying NULL,
  "memberId" character varying NULL,
  "actorIp" character varying NULL,
  "userAgent" character varying NULL,
  "route" character varying NOT NULL,
  "method" character varying NOT NULL,
  "groupId" character varying NULL,
  "eventId" character varying NULL,
  "enrollmentId" character varying NULL,
  "lessonId" character varying NULL,
  "organizationId" character varying NULL,
  "inviteId" character varying NULL,
  "message" character varying NOT NULL,
  "errorCode" character varying NULL,
  "errorMessage" character varying NULL,
  "warningMessage" character varying NULL,
  "metadata" jsonb NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id")
);
-- Create index "idx_activity_logs_activityType" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_activityType" ON "public"."activity_logs" ("activityType");
-- Create index "idx_activity_logs_activityType_status" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_activityType_status" ON "public"."activity_logs" ("activityType", "status");
-- Create index "idx_activity_logs_category" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_category" ON "public"."activity_logs" ("category");
-- Create index "idx_activity_logs_category_createdAt" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_category_createdAt" ON "public"."activity_logs" ("category", "createdAt");
-- Create index "idx_activity_logs_createdAt" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_createdAt" ON "public"."activity_logs" ("createdAt");
-- Create index "idx_activity_logs_groupId" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_groupId" ON "public"."activity_logs" ("groupId");
-- Create index "idx_activity_logs_memberId" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_memberId" ON "public"."activity_logs" ("memberId");
-- Create index "idx_activity_logs_status" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_status" ON "public"."activity_logs" ("status");
-- Create index "idx_activity_logs_userId" to table: "activity_logs"
CREATE INDEX "idx_activity_logs_userId" ON "public"."activity_logs" ("userId");
-- Set comment to column: "activityType" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."activityType" IS 'e.g., AUTH_GOOGLE_LOGIN, JOIN_GROUP_REQUEST';
-- Set comment to column: "userId" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."userId" IS 'User ID for User-authenticated actions';
-- Set comment to column: "memberId" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."memberId" IS 'Member ID for Member-authenticated actions';
-- Set comment to column: "actorIp" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."actorIp" IS 'IP address for rate-limiting/security';
-- Set comment to column: "userAgent" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."userAgent" IS 'For device tracking';
-- Set comment to column: "route" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."route" IS 'e.g., /auth/google/callback';
-- Set comment to column: "method" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."method" IS 'HTTP method: GET, POST, etc.';
-- Set comment to column: "message" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."message" IS 'Human-readable log message';
-- Set comment to column: "errorCode" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."errorCode" IS 'Error code if status is FAILURE';
-- Set comment to column: "errorMessage" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."errorMessage" IS 'Error message if status is FAILURE';
-- Set comment to column: "warningMessage" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."warningMessage" IS 'Warning message if status is WARNING';
-- Set comment to column: "metadata" on table: "activity_logs"
COMMENT ON COLUMN "public"."activity_logs"."metadata" IS 'Additional structured data';
-- Create enum type "EventType"
CREATE TYPE "public"."EventType" AS ENUM ('LESSON', 'MEETING', 'ONLINE', 'DEADLINE', 'SOCIAL', 'OTHER');
-- Create "session" table
CREATE TABLE "public"."session" (
  "sid" character varying NOT NULL,
  "sess" jsonb NOT NULL,
  "expire" timestamp NOT NULL,
  PRIMARY KEY ("sid")
);
-- Create index "idx_session_expire" to table: "session"
CREATE INDEX "idx_session_expire" ON "public"."session" ("expire");
-- Create "api_keys" table
CREATE TABLE "public"."api_keys" (
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
  CONSTRAINT "fk_api_keys_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_api_keys_keyPrefix" to table: "api_keys"
CREATE INDEX "idx_api_keys_keyPrefix" ON "public"."api_keys" ("keyPrefix");
-- Create index "idx_api_keys_userId" to table: "api_keys"
CREATE INDEX "idx_api_keys_userId" ON "public"."api_keys" ("userId");
-- Set comment to column: "keyHash" on table: "api_keys"
COMMENT ON COLUMN "public"."api_keys"."keyHash" IS 'SHA-256 hash of full key (irreversible)';
-- Set comment to column: "keyPrefix" on table: "api_keys"
COMMENT ON COLUMN "public"."api_keys"."keyPrefix" IS 'First 8 chars for display (e.g., mr_abc12)';
-- Set comment to column: "name" on table: "api_keys"
COMMENT ON COLUMN "public"."api_keys"."name" IS 'Friendly name (e.g., ''Claude Code'')';
-- Create "bookmarks" table
CREATE TABLE "public"."bookmarks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "translationId" character varying NOT NULL,
  "bookNumber" integer NOT NULL,
  "chapter" integer NOT NULL,
  "verseStart" integer NOT NULL,
  "verseEnd" integer NULL,
  "label" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_bookmarks_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_bookmarks_userId_createdAt" to table: "bookmarks"
CREATE INDEX "idx_bookmarks_userId_createdAt" ON "public"."bookmarks" ("userId", "createdAt");
-- Set comment to column: "label" on table: "bookmarks"
COMMENT ON COLUMN "public"."bookmarks"."label" IS 'Optional label like ''Favorite verse''';
-- Create "translations" table
CREATE TABLE "public"."translations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "code" character varying NOT NULL,
  "name" character varying NOT NULL,
  "language" character varying NOT NULL,
  "description" character varying NULL,
  "copyright" character varying NULL,
  "license" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "translations_code_key" UNIQUE ("code")
);
-- Create index "idx_translations_code" to table: "translations"
CREATE INDEX "idx_translations_code" ON "public"."translations" ("code");
-- Set comment to column: "code" on table: "translations"
COMMENT ON COLUMN "public"."translations"."code" IS 'ESV, KJV, NIV';
-- Set comment to column: "name" on table: "translations"
COMMENT ON COLUMN "public"."translations"."name" IS 'English Standard Version';
-- Set comment to column: "language" on table: "translations"
COMMENT ON COLUMN "public"."translations"."language" IS 'en, es, fr';
-- Create "books" table
CREATE TABLE "public"."books" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "translationId" uuid NOT NULL,
  "bookNumber" integer NOT NULL,
  "bookName" character varying NOT NULL,
  "bookAbbrev" character varying NOT NULL,
  "testament" "public"."Testament" NOT NULL,
  "chapters" integer NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "books_translationId_bookName_key" UNIQUE ("translationId", "bookName"),
  CONSTRAINT "books_translationId_bookNumber_key" UNIQUE ("translationId", "bookNumber"),
  CONSTRAINT "fk_books_translation" FOREIGN KEY ("translationId") REFERENCES "public"."translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_books_bookNumber" to table: "books"
CREATE INDEX "idx_books_bookNumber" ON "public"."books" ("bookNumber");
-- Create index "idx_books_translationId_testament" to table: "books"
CREATE INDEX "idx_books_translationId_testament" ON "public"."books" ("translationId", "testament");
-- Set comment to column: "bookNumber" on table: "books"
COMMENT ON COLUMN "public"."books"."bookNumber" IS '1-66 (canonical order)';
-- Set comment to column: "bookName" on table: "books"
COMMENT ON COLUMN "public"."books"."bookName" IS 'Genesis, Matthew';
-- Set comment to column: "bookAbbrev" on table: "books"
COMMENT ON COLUMN "public"."books"."bookAbbrev" IS 'Gen, Matt';
-- Set comment to column: "chapters" on table: "books"
COMMENT ON COLUMN "public"."books"."chapters" IS 'Total chapters in book';
-- Create "groups" table
CREATE TABLE "public"."groups" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "code" character varying NULL,
  "name" character varying NOT NULL,
  "description" character varying NULL,
  "coverImageUrl" character varying NULL,
  "isPrivate" boolean NOT NULL DEFAULT false,
  "allowInvites" boolean NOT NULL DEFAULT true,
  "welcomeMessage" character varying NULL,
  "ageRangeMin" integer NULL,
  "ageRangeMax" integer NULL,
  "maxMembers" integer NULL,
  "creatorId" uuid NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  "organizationId" character varying NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  PRIMARY KEY ("id"),
  CONSTRAINT "groups_code_key" UNIQUE ("code"),
  CONSTRAINT "fk_groups_creator" FOREIGN KEY ("creatorId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_groups_isActive" to table: "groups"
CREATE INDEX "idx_groups_isActive" ON "public"."groups" ("isActive");
-- Create index "idx_groups_organizationId" to table: "groups"
CREATE INDEX "idx_groups_organizationId" ON "public"."groups" ("organizationId");
-- Create index "idx_groups_organizationId_isActive" to table: "groups"
CREATE INDEX "idx_groups_organizationId_isActive" ON "public"."groups" ("organizationId", "isActive");
-- Set comment to column: "code" on table: "groups"
COMMENT ON COLUMN "public"."groups"."code" IS '6-char alphanumeric for public join';
-- Create "study_programs" table
CREATE TABLE "public"."study_programs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" character varying NOT NULL,
  "description" character varying NULL,
  "defaultActivity" "public"."ActivityType" NOT NULL DEFAULT 'SOAP',
  "days" integer NOT NULL DEFAULT 30,
  "coverImageUrl" character varying NULL,
  "requireResponse" boolean NOT NULL DEFAULT true,
  "creatorId" uuid NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_study_programs_creator" FOREIGN KEY ("creatorId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_study_programs_creatorId" to table: "study_programs"
CREATE INDEX "idx_study_programs_creatorId" ON "public"."study_programs" ("creatorId");
-- Create index "idx_study_programs_isActive" to table: "study_programs"
CREATE INDEX "idx_study_programs_isActive" ON "public"."study_programs" ("isActive");
-- Set comment to column: "requireResponse" on table: "study_programs"
COMMENT ON COLUMN "public"."study_programs"."requireResponse" IS 'Frontend flag: require user input before step completion';
-- Create "enrollments" table
CREATE TABLE "public"."enrollments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "groupId" uuid NOT NULL,
  "studyProgramId" uuid NOT NULL,
  "startDate" timestamp NOT NULL,
  "endDate" timestamp NOT NULL,
  "enabledDays" character varying NOT NULL,
  "smsTime" character varying NULL,
  "timezone" character varying NULL,
  "requireResponse" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  "createdById" uuid NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_enrollments_createdBy" FOREIGN KEY ("createdById") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_enrollments_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_enrollments_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "public"."study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_enrollments_createdById" to table: "enrollments"
CREATE INDEX "idx_enrollments_createdById" ON "public"."enrollments" ("createdById");
-- Create index "idx_enrollments_groupId" to table: "enrollments"
CREATE INDEX "idx_enrollments_groupId" ON "public"."enrollments" ("groupId");
-- Create index "idx_enrollments_startDate" to table: "enrollments"
CREATE INDEX "idx_enrollments_startDate" ON "public"."enrollments" ("startDate");
-- Create index "idx_enrollments_studyProgramId" to table: "enrollments"
CREATE INDEX "idx_enrollments_studyProgramId" ON "public"."enrollments" ("studyProgramId");
-- Set comment to column: "enabledDays" on table: "enrollments"
COMMENT ON COLUMN "public"."enrollments"."enabledDays" IS 'JSON array: [''Mon'',''Tue'',''Wed'',''Thu'',''Fri'']';
-- Set comment to column: "smsTime" on table: "enrollments"
COMMENT ON COLUMN "public"."enrollments"."smsTime" IS 'Time to send SMS, e.g. ''08:00''';
-- Set comment to column: "timezone" on table: "enrollments"
COMMENT ON COLUMN "public"."enrollments"."timezone" IS 'e.g. ''America/Chicago''';
-- Set comment to column: "requireResponse" on table: "enrollments"
COMMENT ON COLUMN "public"."enrollments"."requireResponse" IS 'Require user input before step completion';
-- Create "lessons" table
CREATE TABLE "public"."lessons" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "studyProgramId" uuid NOT NULL,
  "dayNumber" integer NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "lessons_studyProgramId_dayNumber_key" UNIQUE ("studyProgramId", "dayNumber"),
  CONSTRAINT "fk_lessons_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "public"."study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_lessons_studyProgramId" to table: "lessons"
CREATE INDEX "idx_lessons_studyProgramId" ON "public"."lessons" ("studyProgramId");
-- Set comment to column: "dayNumber" on table: "lessons"
COMMENT ON COLUMN "public"."lessons"."dayNumber" IS '1-based day number';
-- Create "lesson_schedules" table
CREATE TABLE "public"."lesson_schedules" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "code" character varying NULL,
  "enrollmentId" uuid NOT NULL,
  "lessonId" uuid NOT NULL,
  "scheduledDate" timestamp NOT NULL,
  "smsSentAt" timestamp NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "lesson_schedules_code_key" UNIQUE ("code"),
  CONSTRAINT "lesson_schedules_enrollmentId_lessonId_key" UNIQUE ("enrollmentId", "lessonId"),
  CONSTRAINT "fk_lesson_schedules_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "public"."enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_lesson_schedules_lesson" FOREIGN KEY ("lessonId") REFERENCES "public"."lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_lesson_schedules_code" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_code" ON "public"."lesson_schedules" ("code");
-- Create index "idx_lesson_schedules_enrollmentId" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_enrollmentId" ON "public"."lesson_schedules" ("enrollmentId");
-- Create index "idx_lesson_schedules_lessonId" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_lessonId" ON "public"."lesson_schedules" ("lessonId");
-- Create index "idx_lesson_schedules_scheduledDate" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_scheduledDate" ON "public"."lesson_schedules" ("scheduledDate");
-- Create index "idx_lesson_schedules_smsSentAt" to table: "lesson_schedules"
CREATE INDEX "idx_lesson_schedules_smsSentAt" ON "public"."lesson_schedules" ("smsSentAt");
-- Set comment to column: "code" on table: "lesson_schedules"
COMMENT ON COLUMN "public"."lesson_schedules"."code" IS '6-char alphanumeric for deep linking';
-- Create "events" table
CREATE TABLE "public"."events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "code" character varying NULL,
  "groupId" uuid NOT NULL,
  "type" "public"."EventType" NOT NULL,
  "title" character varying NOT NULL,
  "description" text NULL,
  "date" timestamp NOT NULL,
  "startTime" character varying NULL,
  "endTime" character varying NULL,
  "isAllDay" boolean NOT NULL DEFAULT false,
  "timezone" character varying NULL,
  "coverImageUrl" character varying NULL,
  "externalUrl" character varying NULL,
  "visibility" "public"."EventVisibility" NOT NULL DEFAULT 'PRIVATE',
  "locationName" character varying NULL,
  "locationAddress" character varying NULL,
  "locationLat" numeric(10,8) NULL,
  "locationLng" numeric(11,8) NULL,
  "googlePlaceId" character varying NULL,
  "recurrenceFrequency" "public"."RecurrenceFrequency" NOT NULL DEFAULT 'NONE',
  "recurrenceEndDate" timestamp NULL,
  "recurrenceCount" integer NULL,
  "recurrenceGroupId" character varying NULL,
  "isRecurrenceParent" boolean NOT NULL DEFAULT false,
  "alertMinutesBefore" integer NULL,
  "lessonScheduleId" uuid NULL,
  "enrollmentId" uuid NULL,
  "dayNumber" integer NULL,
  "createdById" uuid NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "events_code_key" UNIQUE ("code"),
  CONSTRAINT "events_lessonScheduleId_key" UNIQUE ("lessonScheduleId"),
  CONSTRAINT "fk_events_createdBy" FOREIGN KEY ("createdById") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_events_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "public"."enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_events_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_events_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "public"."lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_events_code" to table: "events"
CREATE INDEX "idx_events_code" ON "public"."events" ("code");
-- Create index "idx_events_date" to table: "events"
CREATE INDEX "idx_events_date" ON "public"."events" ("date");
-- Create index "idx_events_enrollmentId" to table: "events"
CREATE INDEX "idx_events_enrollmentId" ON "public"."events" ("enrollmentId");
-- Create index "idx_events_groupId" to table: "events"
CREATE INDEX "idx_events_groupId" ON "public"."events" ("groupId");
-- Create index "idx_events_groupId_date" to table: "events"
CREATE INDEX "idx_events_groupId_date" ON "public"."events" ("groupId", "date");
-- Create index "idx_events_recurrenceGroupId" to table: "events"
CREATE INDEX "idx_events_recurrenceGroupId" ON "public"."events" ("recurrenceGroupId");
-- Create index "idx_events_type" to table: "events"
CREATE INDEX "idx_events_type" ON "public"."events" ("type");
-- Create index "idx_events_visibility" to table: "events"
CREATE INDEX "idx_events_visibility" ON "public"."events" ("visibility");
-- Set comment to column: "code" on table: "events"
COMMENT ON COLUMN "public"."events"."code" IS '6-char alphanumeric';
-- Set comment to column: "date" on table: "events"
COMMENT ON COLUMN "public"."events"."date" IS 'Event date';
-- Set comment to column: "startTime" on table: "events"
COMMENT ON COLUMN "public"."events"."startTime" IS 'HH:mm format';
-- Set comment to column: "endTime" on table: "events"
COMMENT ON COLUMN "public"."events"."endTime" IS 'HH:mm format';
-- Set comment to column: "timezone" on table: "events"
COMMENT ON COLUMN "public"."events"."timezone" IS 'e.g., ''America/Chicago''';
-- Set comment to column: "coverImageUrl" on table: "events"
COMMENT ON COLUMN "public"."events"."coverImageUrl" IS 'Supabase storage URL';
-- Set comment to column: "externalUrl" on table: "events"
COMMENT ON COLUMN "public"."events"."externalUrl" IS 'External link (Zoom, website)';
-- Set comment to column: "locationName" on table: "events"
COMMENT ON COLUMN "public"."events"."locationName" IS 'Starbucks - Richardson';
-- Set comment to column: "locationAddress" on table: "events"
COMMENT ON COLUMN "public"."events"."locationAddress" IS 'Full formatted address';
-- Set comment to column: "googlePlaceId" on table: "events"
COMMENT ON COLUMN "public"."events"."googlePlaceId" IS 'Google Places ID';
-- Set comment to column: "recurrenceEndDate" on table: "events"
COMMENT ON COLUMN "public"."events"."recurrenceEndDate" IS 'When recurrence stops';
-- Set comment to column: "recurrenceCount" on table: "events"
COMMENT ON COLUMN "public"."events"."recurrenceCount" IS 'Stop after N occurrences';
-- Set comment to column: "recurrenceGroupId" on table: "events"
COMMENT ON COLUMN "public"."events"."recurrenceGroupId" IS 'UUID linking recurring instances';
-- Set comment to column: "alertMinutesBefore" on table: "events"
COMMENT ON COLUMN "public"."events"."alertMinutesBefore" IS '5, 10, 30, 60, 120, 1440, 2880, 10080';
-- Set comment to column: "enrollmentId" on table: "events"
COMMENT ON COLUMN "public"."events"."enrollmentId" IS 'Quick reference to enrollment';
-- Set comment to column: "dayNumber" on table: "events"
COMMENT ON COLUMN "public"."events"."dayNumber" IS 'Day number in study program (1-based)';
-- Create "event_attachments" table
CREATE TABLE "public"."event_attachments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "eventId" uuid NOT NULL,
  "url" character varying NOT NULL,
  "fileName" character varying NOT NULL,
  "fileType" character varying NOT NULL,
  "fileSize" integer NOT NULL,
  "uploadedById" uuid NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_event_attachments_event" FOREIGN KEY ("eventId") REFERENCES "public"."events" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_event_attachments_uploadedBy" FOREIGN KEY ("uploadedById") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_event_attachments_eventId" to table: "event_attachments"
CREATE INDEX "idx_event_attachments_eventId" ON "public"."event_attachments" ("eventId");
-- Set comment to column: "url" on table: "event_attachments"
COMMENT ON COLUMN "public"."event_attachments"."url" IS 'Supabase storage URL';
-- Set comment to column: "fileName" on table: "event_attachments"
COMMENT ON COLUMN "public"."event_attachments"."fileName" IS 'Original filename';
-- Set comment to column: "fileType" on table: "event_attachments"
COMMENT ON COLUMN "public"."event_attachments"."fileType" IS 'MIME type';
-- Set comment to column: "fileSize" on table: "event_attachments"
COMMENT ON COLUMN "public"."event_attachments"."fileSize" IS 'Size in bytes';
-- Create "members" table
CREATE TABLE "public"."members" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "phoneNumber" character varying NOT NULL,
  "phoneVerified" boolean NOT NULL DEFAULT false,
  "firstName" character varying NULL,
  "lastName" character varying NULL,
  "email" character varying NULL,
  "gender" character varying NULL,
  "birthday" timestamp NULL,
  "profilePicture" character varying NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "lastVerifiedAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  "googleId" character varying NULL,
  "googleEmail" character varying NULL,
  "googlePicture" character varying NULL,
  "googleLinkedAt" timestamp NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "members_googleId_key" UNIQUE ("googleId"),
  CONSTRAINT "members_phoneNumber_key" UNIQUE ("phoneNumber")
);
-- Create index "idx_members_googleId" to table: "members"
CREATE INDEX "idx_members_googleId" ON "public"."members" ("googleId");
-- Create index "idx_members_isActive" to table: "members"
CREATE INDEX "idx_members_isActive" ON "public"."members" ("isActive");
-- Create index "idx_members_phoneNumber" to table: "members"
CREATE INDEX "idx_members_phoneNumber" ON "public"."members" ("phoneNumber");
-- Set comment to column: "gender" on table: "members"
COMMENT ON COLUMN "public"."members"."gender" IS 'male or female';
-- Set comment to column: "googleId" on table: "members"
COMMENT ON COLUMN "public"."members"."googleId" IS 'Google ID for profile sync (not for auth)';
-- Set comment to column: "googleEmail" on table: "members"
COMMENT ON COLUMN "public"."members"."googleEmail" IS 'Email from linked Google account';
-- Set comment to column: "googlePicture" on table: "members"
COMMENT ON COLUMN "public"."members"."googlePicture" IS 'Profile picture URL from Google';
-- Set comment to column: "googleLinkedAt" on table: "members"
COMMENT ON COLUMN "public"."members"."googleLinkedAt" IS 'When Google profile was linked';
-- Create "group_members" table
CREATE TABLE "public"."group_members" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "groupId" uuid NOT NULL,
  "role" character varying NOT NULL DEFAULT 'member',
  "joinedAt" timestamp NOT NULL DEFAULT now(),
  "memberId" uuid NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  PRIMARY KEY ("id"),
  CONSTRAINT "group_members_groupId_memberId_key" UNIQUE ("groupId", "memberId"),
  CONSTRAINT "fk_group_members_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_group_members_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_group_members_groupId" to table: "group_members"
CREATE INDEX "idx_group_members_groupId" ON "public"."group_members" ("groupId");
-- Create index "idx_group_members_groupId_isActive" to table: "group_members"
CREATE INDEX "idx_group_members_groupId_isActive" ON "public"."group_members" ("groupId", "isActive");
-- Create index "idx_group_members_isActive" to table: "group_members"
CREATE INDEX "idx_group_members_isActive" ON "public"."group_members" ("isActive");
-- Create index "idx_group_members_memberId" to table: "group_members"
CREATE INDEX "idx_group_members_memberId" ON "public"."group_members" ("memberId");
-- Create "event_attendees" table
CREATE TABLE "public"."event_attendees" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "eventId" uuid NOT NULL,
  "groupMemberId" uuid NULL,
  "phoneNumber" character varying NULL,
  "firstName" character varying NULL,
  "lastName" character varying NULL,
  "gender" character varying NULL,
  "birthdate" timestamp NULL,
  "rsvpStatus" "public"."RsvpStatus" NOT NULL DEFAULT 'PENDING',
  "rsvpAt" timestamp NULL,
  "checkedIn" boolean NOT NULL DEFAULT false,
  "checkedInAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "event_attendees_eventId_groupMemberId_key" UNIQUE ("eventId", "groupMemberId"),
  CONSTRAINT "event_attendees_eventId_phoneNumber_key" UNIQUE ("eventId", "phoneNumber"),
  CONSTRAINT "fk_event_attendees_event" FOREIGN KEY ("eventId") REFERENCES "public"."events" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_event_attendees_groupMember" FOREIGN KEY ("groupMemberId") REFERENCES "public"."group_members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_event_attendees_eventId" to table: "event_attendees"
CREATE INDEX "idx_event_attendees_eventId" ON "public"."event_attendees" ("eventId");
-- Create index "idx_event_attendees_rsvpStatus" to table: "event_attendees"
CREATE INDEX "idx_event_attendees_rsvpStatus" ON "public"."event_attendees" ("rsvpStatus");
-- Set comment to column: "groupMemberId" on table: "event_attendees"
COMMENT ON COLUMN "public"."event_attendees"."groupMemberId" IS 'For PRIVATE events';
-- Set comment to column: "phoneNumber" on table: "event_attendees"
COMMENT ON COLUMN "public"."event_attendees"."phoneNumber" IS 'For PUBLIC events';
-- Set comment to column: "gender" on table: "event_attendees"
COMMENT ON COLUMN "public"."event_attendees"."gender" IS 'male, female, other';
-- Set comment to column: "birthdate" on table: "event_attendees"
COMMENT ON COLUMN "public"."event_attendees"."birthdate" IS 'Date only';
-- Create "group_join_requests" table
CREATE TABLE "public"."group_join_requests" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "groupId" uuid NOT NULL,
  "memberId" uuid NOT NULL,
  "status" character varying NOT NULL DEFAULT 'pending',
  "message" character varying NULL,
  "reviewedById" uuid NULL,
  "reviewedAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "group_join_requests_groupId_memberId_key" UNIQUE ("groupId", "memberId"),
  CONSTRAINT "fk_group_join_requests_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_group_join_requests_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_group_join_requests_reviewedBy" FOREIGN KEY ("reviewedById") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create index "idx_group_join_requests_groupId_status" to table: "group_join_requests"
CREATE INDEX "idx_group_join_requests_groupId_status" ON "public"."group_join_requests" ("groupId", "status");
-- Create index "idx_group_join_requests_memberId" to table: "group_join_requests"
CREATE INDEX "idx_group_join_requests_memberId" ON "public"."group_join_requests" ("memberId");
-- Set comment to column: "status" on table: "group_join_requests"
COMMENT ON COLUMN "public"."group_join_requests"."status" IS 'pending, approved, rejected';
-- Set comment to column: "message" on table: "group_join_requests"
COMMENT ON COLUMN "public"."group_join_requests"."message" IS 'Optional message from requester';
-- Set comment to column: "reviewedById" on table: "group_join_requests"
COMMENT ON COLUMN "public"."group_join_requests"."reviewedById" IS 'User who approved/rejected';
-- Create "highlights" table
CREATE TABLE "public"."highlights" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "translationId" uuid NOT NULL,
  "bookNumber" integer NOT NULL,
  "chapter" integer NOT NULL,
  "verseStart" integer NOT NULL,
  "verseEnd" integer NULL,
  "color" "public"."HighlightColor" NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "highlights_userId_translationId_bookNumber_chapter_verseStart_v" UNIQUE ("userId", "translationId", "bookNumber", "chapter", "verseStart", "verseEnd"),
  CONSTRAINT "fk_highlights_translation" FOREIGN KEY ("translationId") REFERENCES "public"."translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_highlights_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_highlights_userId_translationId" to table: "highlights"
CREATE INDEX "idx_highlights_userId_translationId" ON "public"."highlights" ("userId", "translationId");
-- Set comment to column: "verseEnd" on table: "highlights"
COMMENT ON COLUMN "public"."highlights"."verseEnd" IS 'For ranges, null for single verse';
-- Create "invites" table
CREATE TABLE "public"."invites" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "token" character varying NOT NULL,
  "groupId" uuid NULL,
  "inviterId" uuid NOT NULL,
  "recipientPhone" character varying NULL,
  "status" character varying NOT NULL DEFAULT 'pending',
  "expiresAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "acceptedAt" timestamp NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "invites_token_key" UNIQUE ("token"),
  CONSTRAINT "fk_invites_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_invites_inviter" FOREIGN KEY ("inviterId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "videos" table
CREATE TABLE "public"."videos" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" character varying NULL,
  "description" character varying NULL,
  "cloudflareUid" character varying NOT NULL,
  "playbackUrl" character varying NOT NULL,
  "thumbnailUrl" character varying NULL,
  "duration" integer NULL,
  "status" character varying NOT NULL DEFAULT 'pending',
  "userId" uuid NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "videos_cloudflareUid_key" UNIQUE ("cloudflareUid"),
  CONSTRAINT "fk_videos_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_videos_isActive" to table: "videos"
CREATE INDEX "idx_videos_isActive" ON "public"."videos" ("isActive");
-- Create index "idx_videos_status" to table: "videos"
CREATE INDEX "idx_videos_status" ON "public"."videos" ("status");
-- Create index "idx_videos_userId" to table: "videos"
CREATE INDEX "idx_videos_userId" ON "public"."videos" ("userId");
-- Set comment to column: "cloudflareUid" on table: "videos"
COMMENT ON COLUMN "public"."videos"."cloudflareUid" IS 'Cloudflare video UID';
-- Set comment to column: "playbackUrl" on table: "videos"
COMMENT ON COLUMN "public"."videos"."playbackUrl" IS 'HLS playback URL';
-- Set comment to column: "thumbnailUrl" on table: "videos"
COMMENT ON COLUMN "public"."videos"."thumbnailUrl" IS 'Auto-generated thumbnail';
-- Set comment to column: "duration" on table: "videos"
COMMENT ON COLUMN "public"."videos"."duration" IS 'Duration in seconds';
-- Set comment to column: "status" on table: "videos"
COMMENT ON COLUMN "public"."videos"."status" IS 'pending, ready, error';
-- Create "lesson_activities" table
CREATE TABLE "public"."lesson_activities" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "lessonId" uuid NOT NULL,
  "type" "public"."ActivityType" NOT NULL DEFAULT 'SOAP',
  "status" "public"."ActivityStatus" NOT NULL DEFAULT 'PENDING',
  "highlightMode" "public"."HighlightMode" NOT NULL DEFAULT 'HIGHLIGHT',
  "passageReference" character varying NULL,
  "bookNumber" integer NULL,
  "bookName" character varying NULL,
  "chapterStart" integer NULL,
  "chapterEnd" integer NULL,
  "verseStart" integer NULL,
  "verseEnd" integer NULL,
  "startElementId" character varying NULL,
  "startOffset" integer NULL,
  "endElementId" character varying NULL,
  "endOffset" integer NULL,
  "selectedVerses" jsonb NULL,
  "videoId" uuid NULL,
  "videoUrl" character varying NULL,
  "orderNumber" integer NOT NULL DEFAULT 1,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "lesson_activities_lessonId_orderNumber_key" UNIQUE ("lessonId", "orderNumber"),
  CONSTRAINT "fk_lesson_activities_lesson" FOREIGN KEY ("lessonId") REFERENCES "public"."lessons" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_lesson_activities_video" FOREIGN KEY ("videoId") REFERENCES "public"."videos" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_lesson_activities_lessonId" to table: "lesson_activities"
CREATE INDEX "idx_lesson_activities_lessonId" ON "public"."lesson_activities" ("lessonId");
-- Create index "idx_lesson_activities_videoId" to table: "lesson_activities"
CREATE INDEX "idx_lesson_activities_videoId" ON "public"."lesson_activities" ("videoId");
-- Set comment to column: "passageReference" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."passageReference" IS 'Human-readable: ''Romans 1:1-5''';
-- Set comment to column: "bookNumber" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."bookNumber" IS '1-66';
-- Set comment to column: "chapterEnd" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."chapterEnd" IS 'For cross-chapter selections';
-- Set comment to column: "startElementId" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."startElementId" IS '45-1-1 (bookNum-chapter-verse)';
-- Set comment to column: "startOffset" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."startOffset" IS 'Character offset within start verse';
-- Set comment to column: "endOffset" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."endOffset" IS 'Character offset within end verse (exclusive)';
-- Set comment to column: "selectedVerses" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."selectedVerses" IS 'Array of verse IDs for VERSE mode';
-- Set comment to column: "videoUrl" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."videoUrl" IS 'Cloudflare Stream playback URL';
-- Set comment to column: "orderNumber" on table: "lesson_activities"
COMMENT ON COLUMN "public"."lesson_activities"."orderNumber" IS 'For multiple activities per day';
-- Create "organizations" table
CREATE TABLE "public"."organizations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" character varying NOT NULL,
  "ownerId" uuid NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "twilioVerifyServiceSid" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "organizations_ownerId_key" UNIQUE ("ownerId"),
  CONSTRAINT "fk_organizations_owner" FOREIGN KEY ("ownerId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_organizations_isActive" to table: "organizations"
CREATE INDEX "idx_organizations_isActive" ON "public"."organizations" ("isActive");
-- Create index "idx_organizations_ownerId" to table: "organizations"
CREATE INDEX "idx_organizations_ownerId" ON "public"."organizations" ("ownerId");
-- Set comment to column: "ownerId" on table: "organizations"
COMMENT ON COLUMN "public"."organizations"."ownerId" IS 'DEPRECATED: Kept for backward compatibility';
-- Set comment to column: "twilioVerifyServiceSid" on table: "organizations"
COMMENT ON COLUMN "public"."organizations"."twilioVerifyServiceSid" IS 'Twilio Verify Service SID for org-branded SMS';
-- Create "media" table
CREATE TABLE "public"."media" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "title" character varying NOT NULL,
  "description" character varying NULL,
  "url" character varying NOT NULL,
  "type" character varying NOT NULL,
  "mimeType" character varying NULL,
  "fileSize" integer NULL,
  "organizationId" uuid NOT NULL,
  "groupId" uuid NULL,
  "uploadedBy" uuid NOT NULL,
  "visibility" character varying NOT NULL DEFAULT 'members',
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_media_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_media_organization" FOREIGN KEY ("organizationId") REFERENCES "public"."organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_media_uploader" FOREIGN KEY ("uploadedBy") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_media_groupId" to table: "media"
CREATE INDEX "idx_media_groupId" ON "public"."media" ("groupId");
-- Create index "idx_media_isActive" to table: "media"
CREATE INDEX "idx_media_isActive" ON "public"."media" ("isActive");
-- Create index "idx_media_organizationId" to table: "media"
CREATE INDEX "idx_media_organizationId" ON "public"."media" ("organizationId");
-- Create index "idx_media_type" to table: "media"
CREATE INDEX "idx_media_type" ON "public"."media" ("type");
-- Create index "idx_media_uploadedBy" to table: "media"
CREATE INDEX "idx_media_uploadedBy" ON "public"."media" ("uploadedBy");
-- Create index "idx_media_visibility" to table: "media"
CREATE INDEX "idx_media_visibility" ON "public"."media" ("visibility");
-- Set comment to column: "url" on table: "media"
COMMENT ON COLUMN "public"."media"."url" IS 'Cloud storage URL';
-- Set comment to column: "type" on table: "media"
COMMENT ON COLUMN "public"."media"."type" IS 'photo, video, document';
-- Set comment to column: "mimeType" on table: "media"
COMMENT ON COLUMN "public"."media"."mimeType" IS 'image/jpeg, video/mp4, application/pdf';
-- Set comment to column: "fileSize" on table: "media"
COMMENT ON COLUMN "public"."media"."fileSize" IS 'Size in bytes';
-- Set comment to column: "groupId" on table: "media"
COMMENT ON COLUMN "public"."media"."groupId" IS 'NULL = organization-wide media';
-- Set comment to column: "visibility" on table: "media"
COMMENT ON COLUMN "public"."media"."visibility" IS 'public | members | group';
-- Create "member_activity_progress" table
CREATE TABLE "public"."member_activity_progress" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NOT NULL,
  "lessonScheduleId" uuid NOT NULL,
  "lessonActivityId" uuid NOT NULL,
  "currentStep" character varying NOT NULL DEFAULT 'READ_SCRIPTURE',
  "completedSteps" text[] NOT NULL,
  "startedAt" timestamp NOT NULL DEFAULT now(),
  "completedAt" timestamp NULL,
  "lastUpdatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "member_activity_progress_memberId_lessonScheduleId_lessonActivi" UNIQUE ("memberId", "lessonScheduleId", "lessonActivityId"),
  CONSTRAINT "fk_member_activity_progress_lessonActivity" FOREIGN KEY ("lessonActivityId") REFERENCES "public"."lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_activity_progress_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "public"."lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_activity_progress_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_member_activity_progress_lessonActivityId" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_lessonActivityId" ON "public"."member_activity_progress" ("lessonActivityId");
-- Create index "idx_member_activity_progress_lessonScheduleId" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_lessonScheduleId" ON "public"."member_activity_progress" ("lessonScheduleId");
-- Create index "idx_member_activity_progress_memberId" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_memberId" ON "public"."member_activity_progress" ("memberId");
-- Create index "idx_member_activity_progress_memberId_completedAt" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_memberId_completedAt" ON "public"."member_activity_progress" ("memberId", "completedAt");
-- Set comment to column: "completedSteps" on table: "member_activity_progress"
COMMENT ON COLUMN "public"."member_activity_progress"."completedSteps" IS 'Array of completed step names';
-- Set comment to column: "completedAt" on table: "member_activity_progress"
COMMENT ON COLUMN "public"."member_activity_progress"."completedAt" IS 'When fully completed';
-- Create "member_organizations" table
CREATE TABLE "public"."member_organizations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NOT NULL,
  "organizationId" uuid NOT NULL,
  "joinedAt" timestamp NOT NULL DEFAULT now(),
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "member_organizations_memberId_organizationId_key" UNIQUE ("memberId", "organizationId"),
  CONSTRAINT "fk_member_organizations_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_organizations_organization" FOREIGN KEY ("organizationId") REFERENCES "public"."organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_member_organizations_memberId" to table: "member_organizations"
CREATE INDEX "idx_member_organizations_memberId" ON "public"."member_organizations" ("memberId");
-- Create index "idx_member_organizations_organizationId" to table: "member_organizations"
CREATE INDEX "idx_member_organizations_organizationId" ON "public"."member_organizations" ("organizationId");
-- Create "member_video_progress" table
CREATE TABLE "public"."member_video_progress" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NOT NULL,
  "lessonScheduleId" uuid NOT NULL,
  "lessonActivityId" uuid NOT NULL,
  "watchedSeconds" integer NOT NULL DEFAULT 0,
  "totalDuration" integer NULL,
  "watchPercentage" double precision NOT NULL DEFAULT 0,
  "startedAt" timestamp NOT NULL DEFAULT now(),
  "lastWatchedAt" timestamp NOT NULL,
  "completedAt" timestamp NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "member_video_progress_memberId_lessonScheduleId_lessonActivityI" UNIQUE ("memberId", "lessonScheduleId", "lessonActivityId"),
  CONSTRAINT "fk_member_video_progress_lessonActivity" FOREIGN KEY ("lessonActivityId") REFERENCES "public"."lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_video_progress_lessonSchedule" FOREIGN KEY ("lessonScheduleId") REFERENCES "public"."lesson_schedules" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_member_video_progress_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_member_video_progress_lessonActivityId" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_lessonActivityId" ON "public"."member_video_progress" ("lessonActivityId");
-- Create index "idx_member_video_progress_lessonScheduleId" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_lessonScheduleId" ON "public"."member_video_progress" ("lessonScheduleId");
-- Create index "idx_member_video_progress_memberId" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_memberId" ON "public"."member_video_progress" ("memberId");
-- Create index "idx_member_video_progress_memberId_completedAt" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_memberId_completedAt" ON "public"."member_video_progress" ("memberId", "completedAt");
-- Set comment to column: "totalDuration" on table: "member_video_progress"
COMMENT ON COLUMN "public"."member_video_progress"."totalDuration" IS 'Total video duration in seconds';
-- Set comment to column: "completedAt" on table: "member_video_progress"
COMMENT ON COLUMN "public"."member_video_progress"."completedAt" IS 'Set when >= 90% watched';
-- Create "study_notes" table
CREATE TABLE "public"."study_notes" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "memberId" uuid NULL,
  "userId" uuid NULL,
  "type" character varying NOT NULL,
  "content" text NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_study_notes_member" FOREIGN KEY ("memberId") REFERENCES "public"."members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_study_notes_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_study_notes_createdAt" to table: "study_notes"
CREATE INDEX "idx_study_notes_createdAt" ON "public"."study_notes" ("createdAt");
-- Create index "idx_study_notes_isActive" to table: "study_notes"
CREATE INDEX "idx_study_notes_isActive" ON "public"."study_notes" ("isActive");
-- Create index "idx_study_notes_memberId" to table: "study_notes"
CREATE INDEX "idx_study_notes_memberId" ON "public"."study_notes" ("memberId");
-- Create index "idx_study_notes_memberId_createdAt" to table: "study_notes"
CREATE INDEX "idx_study_notes_memberId_createdAt" ON "public"."study_notes" ("memberId", "createdAt");
-- Create index "idx_study_notes_memberId_type" to table: "study_notes"
CREATE INDEX "idx_study_notes_memberId_type" ON "public"."study_notes" ("memberId", "type");
-- Create index "idx_study_notes_type" to table: "study_notes"
CREATE INDEX "idx_study_notes_type" ON "public"."study_notes" ("type");
-- Create index "idx_study_notes_userId" to table: "study_notes"
CREATE INDEX "idx_study_notes_userId" ON "public"."study_notes" ("userId");
-- Create index "idx_study_notes_userId_createdAt" to table: "study_notes"
CREATE INDEX "idx_study_notes_userId_createdAt" ON "public"."study_notes" ("userId", "createdAt");
-- Create index "idx_study_notes_userId_type" to table: "study_notes"
CREATE INDEX "idx_study_notes_userId_type" ON "public"."study_notes" ("userId", "type");
-- Set comment to column: "type" on table: "study_notes"
COMMENT ON COLUMN "public"."study_notes"."type" IS 'OBSERVATION, APPLICATION, PRAYER, JOURNAL, etc.';
-- Create "note_links" table
CREATE TABLE "public"."note_links" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "noteId" uuid NOT NULL,
  "refType" character varying NOT NULL,
  "refId" character varying NOT NULL,
  "metadata" jsonb NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "note_links_noteId_refType_refId_key" UNIQUE ("noteId", "refType", "refId"),
  CONSTRAINT "fk_note_links_note" FOREIGN KEY ("noteId") REFERENCES "public"."study_notes" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_note_links_noteId" to table: "note_links"
CREATE INDEX "idx_note_links_noteId" ON "public"."note_links" ("noteId");
-- Create index "idx_note_links_refType" to table: "note_links"
CREATE INDEX "idx_note_links_refType" ON "public"."note_links" ("refType");
-- Create index "idx_note_links_refType_refId" to table: "note_links"
CREATE INDEX "idx_note_links_refType_refId" ON "public"."note_links" ("refType", "refId");
-- Set comment to column: "refType" on table: "note_links"
COMMENT ON COLUMN "public"."note_links"."refType" IS 'LESSON, LESSON_ACTIVITY, LESSON_SCHEDULE, ENROLLMENT, GROUP, VERSE, PROGRAM';
-- Set comment to column: "refId" on table: "note_links"
COMMENT ON COLUMN "public"."note_links"."refId" IS 'UUID of the referenced entity';
-- Set comment to column: "metadata" on table: "note_links"
COMMENT ON COLUMN "public"."note_links"."metadata" IS 'Additional context like verse references';
-- Create "posts" table
CREATE TABLE "public"."posts" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "groupId" uuid NOT NULL,
  "authorId" uuid NULL,
  "type" "public"."PostType" NOT NULL,
  "title" character varying NULL,
  "content" text NOT NULL,
  "imageUrl" character varying NULL,
  "pollOptions" jsonb NULL,
  "videoUrl" character varying NULL,
  "eventDate" timestamp NULL,
  "eventLocation" character varying NULL,
  "enrollmentId" uuid NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "posts_enrollmentId_key" UNIQUE ("enrollmentId"),
  CONSTRAINT "fk_posts_author" FOREIGN KEY ("authorId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_posts_enrollment" FOREIGN KEY ("enrollmentId") REFERENCES "public"."enrollments" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_posts_group" FOREIGN KEY ("groupId") REFERENCES "public"."groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_posts_authorId" to table: "posts"
CREATE INDEX "idx_posts_authorId" ON "public"."posts" ("authorId");
-- Create index "idx_posts_groupId" to table: "posts"
CREATE INDEX "idx_posts_groupId" ON "public"."posts" ("groupId");
-- Create index "idx_posts_groupId_createdAt" to table: "posts"
CREATE INDEX "idx_posts_groupId_createdAt" ON "public"."posts" ("groupId", "createdAt");
-- Create index "idx_posts_isActive" to table: "posts"
CREATE INDEX "idx_posts_isActive" ON "public"."posts" ("isActive");
-- Create index "idx_posts_type" to table: "posts"
CREATE INDEX "idx_posts_type" ON "public"."posts" ("type");
-- Set comment to column: "authorId" on table: "posts"
COMMENT ON COLUMN "public"."posts"."authorId" IS 'NULL for system-generated posts';
-- Set comment to column: "imageUrl" on table: "posts"
COMMENT ON COLUMN "public"."posts"."imageUrl" IS 'Cover image';
-- Set comment to column: "pollOptions" on table: "posts"
COMMENT ON COLUMN "public"."posts"."pollOptions" IS 'For POLL: [{id, text, voteCount}]';
-- Set comment to column: "videoUrl" on table: "posts"
COMMENT ON COLUMN "public"."posts"."videoUrl" IS 'For VIDEO: Cloudflare Stream URL';
-- Set comment to column: "eventDate" on table: "posts"
COMMENT ON COLUMN "public"."posts"."eventDate" IS 'For EVENT: date/time';
-- Set comment to column: "eventLocation" on table: "posts"
COMMENT ON COLUMN "public"."posts"."eventLocation" IS 'For EVENT: location string';
-- Set comment to column: "enrollmentId" on table: "posts"
COMMENT ON COLUMN "public"."posts"."enrollmentId" IS 'For WELCOME posts';
-- Create "permissions" table
CREATE TABLE "public"."permissions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "resource" character varying NOT NULL,
  "action" character varying NOT NULL,
  "name" character varying NOT NULL,
  "description" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "permissions_name_key" UNIQUE ("name")
);
-- Create index "idx_permissions_action" to table: "permissions"
CREATE INDEX "idx_permissions_action" ON "public"."permissions" ("action");
-- Create index "idx_permissions_resource" to table: "permissions"
CREATE INDEX "idx_permissions_resource" ON "public"."permissions" ("resource");
-- Set comment to column: "resource" on table: "permissions"
COMMENT ON COLUMN "public"."permissions"."resource" IS 'organization, group, member, event, announcement, media, form';
-- Set comment to column: "action" on table: "permissions"
COMMENT ON COLUMN "public"."permissions"."action" IS 'create, read, update, delete, invite, publish';
-- Set comment to column: "name" on table: "permissions"
COMMENT ON COLUMN "public"."permissions"."name" IS 'organization.update, event.create';
-- Create "roles" table
CREATE TABLE "public"."roles" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" character varying NOT NULL,
  "description" character varying NULL,
  "organizationId" uuid NULL,
  "isSystem" boolean NOT NULL DEFAULT false,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "roles_name_organizationId_key" UNIQUE ("name", "organizationId"),
  CONSTRAINT "fk_roles_organization" FOREIGN KEY ("organizationId") REFERENCES "public"."organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_roles_isSystem" to table: "roles"
CREATE INDEX "idx_roles_isSystem" ON "public"."roles" ("isSystem");
-- Create index "idx_roles_organizationId" to table: "roles"
CREATE INDEX "idx_roles_organizationId" ON "public"."roles" ("organizationId");
-- Set comment to column: "name" on table: "roles"
COMMENT ON COLUMN "public"."roles"."name" IS 'Super Admin, Owner, Admin, Group Leader, Contributor';
-- Set comment to column: "organizationId" on table: "roles"
COMMENT ON COLUMN "public"."roles"."organizationId" IS 'NULL for system roles';
-- Set comment to column: "isSystem" on table: "roles"
COMMENT ON COLUMN "public"."roles"."isSystem" IS 'true for predefined roles';
-- Create "role_permissions" table
CREATE TABLE "public"."role_permissions" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "roleId" uuid NOT NULL,
  "permissionId" uuid NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "role_permissions_roleId_permissionId_key" UNIQUE ("roleId", "permissionId"),
  CONSTRAINT "fk_role_permissions_permission" FOREIGN KEY ("permissionId") REFERENCES "public"."permissions" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_role_permissions_role" FOREIGN KEY ("roleId") REFERENCES "public"."roles" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_role_permissions_permissionId" to table: "role_permissions"
CREATE INDEX "idx_role_permissions_permissionId" ON "public"."role_permissions" ("permissionId");
-- Create index "idx_role_permissions_roleId" to table: "role_permissions"
CREATE INDEX "idx_role_permissions_roleId" ON "public"."role_permissions" ("roleId");
-- Create "user_roles" table
CREATE TABLE "public"."user_roles" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "roleId" uuid NOT NULL,
  "organizationId" uuid NOT NULL,
  "assignedAt" timestamp NOT NULL DEFAULT now(),
  "assignedBy" character varying NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_roles_userId_roleId_organizationId_key" UNIQUE ("userId", "roleId", "organizationId"),
  CONSTRAINT "fk_user_roles_organization" FOREIGN KEY ("organizationId") REFERENCES "public"."organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_user_roles_role" FOREIGN KEY ("roleId") REFERENCES "public"."roles" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_user_roles_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_user_roles_organizationId" to table: "user_roles"
CREATE INDEX "idx_user_roles_organizationId" ON "public"."user_roles" ("organizationId");
-- Create index "idx_user_roles_roleId" to table: "user_roles"
CREATE INDEX "idx_user_roles_roleId" ON "public"."user_roles" ("roleId");
-- Create index "idx_user_roles_userId" to table: "user_roles"
CREATE INDEX "idx_user_roles_userId" ON "public"."user_roles" ("userId");
-- Set comment to column: "organizationId" on table: "user_roles"
COMMENT ON COLUMN "public"."user_roles"."organizationId" IS 'Scope of this role assignment';
-- Set comment to column: "assignedBy" on table: "user_roles"
COMMENT ON COLUMN "public"."user_roles"."assignedBy" IS 'User ID who assigned this role';
-- Create "verse_notes" table
CREATE TABLE "public"."verse_notes" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "translationId" uuid NOT NULL,
  "bookNumber" integer NOT NULL,
  "chapter" integer NOT NULL,
  "verseStart" integer NOT NULL,
  "verseEnd" integer NULL,
  "content" text NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_verse_notes_translation" FOREIGN KEY ("translationId") REFERENCES "public"."translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_verse_notes_user" FOREIGN KEY ("userId") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_verse_notes_userId_translationId" to table: "verse_notes"
CREATE INDEX "idx_verse_notes_userId_translationId" ON "public"."verse_notes" ("userId", "translationId");
-- Set comment to column: "verseEnd" on table: "verse_notes"
COMMENT ON COLUMN "public"."verse_notes"."verseEnd" IS 'For passage notes';
-- Create "verses" table
CREATE TABLE "public"."verses" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "translationId" uuid NOT NULL,
  "bookId" uuid NOT NULL,
  "bookNumber" integer NOT NULL,
  "chapter" integer NOT NULL,
  "verse" integer NOT NULL,
  "text" text NOT NULL,
  "searchVector" tsvector NULL,
  "embedding" vector(384) NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "verses_translationId_bookNumber_chapter_verse_key" UNIQUE ("translationId", "bookNumber", "chapter", "verse"),
  CONSTRAINT "fk_verses_book" FOREIGN KEY ("bookId") REFERENCES "public"."books" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_verses_translation" FOREIGN KEY ("translationId") REFERENCES "public"."translations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_verses_bookId_chapter_verse" to table: "verses"
CREATE INDEX "idx_verses_bookId_chapter_verse" ON "public"."verses" ("bookId", "chapter", "verse");
-- Create index "idx_verses_translationId_bookNumber_chapter_verse" to table: "verses"
CREATE INDEX "idx_verses_translationId_bookNumber_chapter_verse" ON "public"."verses" ("translationId", "bookNumber", "chapter", "verse");
-- Set comment to column: "bookNumber" on table: "verses"
COMMENT ON COLUMN "public"."verses"."bookNumber" IS 'Denormalized for faster queries';
-- Set comment to column: "searchVector" on table: "verses"
COMMENT ON COLUMN "public"."verses"."searchVector" IS 'Full-text search';
-- Set comment to column: "embedding" on table: "verses"
COMMENT ON COLUMN "public"."verses"."embedding" IS 'Semantic search embedding (gte-small model)';
