-- Create "enrollment_drafts" table
-- ui2-enrollments-browse: the id columns take the type "users"."id" actually has (the ui2-programs D12
-- precedent, 20261028080040). A database built by these migrations has uuid ids; one created by Prisma
-- before Atlas (the dev/prod schema) has text ids, and a uuid column could not reference it (42804).
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format('CREATE TABLE "enrollment_drafts" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "groupId" %1$s NOT NULL, "studyProgramId" %1$s NOT NULL, "startDate" character varying NULL, "enabledDays" jsonb NULL, "overriddenDates" jsonb NULL, "scheduleDates" jsonb NULL, "smsTime" character varying NULL, "timezone" character varying NULL, "syncMode" "EnrollmentSyncMode" NULL, "lessonAccess" "LessonAccess" NULL, "createdById" %1$s NULL, "updatedById" %1$s NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "enrollment_drafts_groupId_studyProgramId_key" UNIQUE ("groupId", "studyProgramId"), CONSTRAINT "fk_enrollment_drafts_createdBy" FOREIGN KEY ("createdById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, CONSTRAINT "fk_enrollment_drafts_group" FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, CONSTRAINT "fk_enrollment_drafts_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, CONSTRAINT "fk_enrollment_drafts_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL)', id_type);
END $$;
-- Set comment to column: "startDate" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."startDate" IS 'yyyy-MM-dd — the checklist''s first lesson date';
-- Set comment to column: "enabledDays" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."enabledDays" IS 'Weekday names as sent, e.g. [''Sun'',''Mon'']';
-- Set comment to column: "overriddenDates" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."overriddenDates" IS 'yyyy-MM-dd[] the leader toggled against the weekday walk';
-- Set comment to column: "scheduleDates" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."scheduleDates" IS 'yyyy-MM-dd[] strictly ascending — the checklist''s lesson dates';
-- Set comment to column: "smsTime" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."smsTime" IS 'HH:mm invite time';
-- Set comment to column: "timezone" on table: "enrollment_drafts"
COMMENT ON COLUMN "enrollment_drafts"."timezone" IS 'IANA zone, e.g. ''America/Chicago''';
