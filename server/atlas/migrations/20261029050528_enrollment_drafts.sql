-- Create "enrollment_drafts" table
CREATE TABLE "enrollment_drafts" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "groupId" uuid NOT NULL, "studyProgramId" uuid NOT NULL, "startDate" character varying NULL, "enabledDays" jsonb NULL, "overriddenDates" jsonb NULL, "scheduleDates" jsonb NULL, "smsTime" character varying NULL, "timezone" character varying NULL, "syncMode" "EnrollmentSyncMode" NULL, "lessonAccess" "LessonAccess" NULL, "createdById" uuid NULL, "updatedById" uuid NULL, "createdAt" timestamp NOT NULL DEFAULT now(), "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"), CONSTRAINT "enrollment_drafts_groupId_studyProgramId_key" UNIQUE ("groupId", "studyProgramId"), CONSTRAINT "fk_enrollment_drafts_createdBy" FOREIGN KEY ("createdById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, CONSTRAINT "fk_enrollment_drafts_group" FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, CONSTRAINT "fk_enrollment_drafts_studyProgram" FOREIGN KEY ("studyProgramId") REFERENCES "study_programs" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, CONSTRAINT "fk_enrollment_drafts_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL);
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
