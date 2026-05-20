-- Create enum type "ActivityAction"
CREATE TYPE "ActivityAction" AS ENUM ('CREATED', 'UPDATED', 'DELETED', 'JOINED', 'LEFT', 'PUBLISHED');
-- Create "activities" table
CREATE TABLE "activities" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "actorId" uuid NOT NULL,
  "action" "ActivityAction" NOT NULL,
  "resourceType" character varying NOT NULL,
  "resourceId" character varying NOT NULL,
  "resourceName" character varying NOT NULL,
  "organizationId" character varying NULL,
  "metadata" jsonb NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_activities_actor" FOREIGN KEY ("actorId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_activities_actorId_createdAt" to table: "activities"
CREATE INDEX "idx_activities_actorId_createdAt" ON "activities" ("actorId", "createdAt");
-- Create index "idx_activities_createdAt" to table: "activities"
CREATE INDEX "idx_activities_createdAt" ON "activities" ("createdAt");
-- Create index "idx_activities_organizationId_createdAt" to table: "activities"
CREATE INDEX "idx_activities_organizationId_createdAt" ON "activities" ("organizationId", "createdAt");
-- Create index "idx_activities_resourceType_resourceId" to table: "activities"
CREATE INDEX "idx_activities_resourceType_resourceId" ON "activities" ("resourceType", "resourceId");
-- Set comment to column: "actorId" on table: "activities"
COMMENT ON COLUMN "activities"."actorId" IS 'User who performed the action';
-- Set comment to column: "resourceType" on table: "activities"
COMMENT ON COLUMN "activities"."resourceType" IS 'GROUP, PROGRAM, LESSON, EVENT, POST, ENROLLMENT, TEMPLATE, MEMBER';
-- Set comment to column: "resourceId" on table: "activities"
COMMENT ON COLUMN "activities"."resourceId" IS 'UUID of affected resource (polymorphic, no FK)';
-- Set comment to column: "resourceName" on table: "activities"
COMMENT ON COLUMN "activities"."resourceName" IS 'Denormalized display name for feed rendering';
-- Set comment to column: "organizationId" on table: "activities"
COMMENT ON COLUMN "activities"."organizationId" IS 'For scoping feed to an org';
-- Set comment to column: "metadata" on table: "activities"
COMMENT ON COLUMN "activities"."metadata" IS 'Extra context (changed fields, etc.)';
-- Modify "enrollments" table
ALTER TABLE "enrollments" ADD COLUMN "updatedById" uuid NULL, ADD CONSTRAINT "fk_enrollments_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "updatedById" on table: "enrollments"
COMMENT ON COLUMN "enrollments"."updatedById" IS 'User who last updated this enrollment';
-- Modify "events" table
ALTER TABLE "events" ADD COLUMN "updatedById" uuid NULL, ADD CONSTRAINT "fk_events_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "updatedById" on table: "events"
COMMENT ON COLUMN "events"."updatedById" IS 'User who last updated this event';
-- Modify "groups" table
ALTER TABLE "groups" ADD COLUMN "updatedById" uuid NULL, ADD CONSTRAINT "fk_groups_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "updatedById" on table: "groups"
COMMENT ON COLUMN "groups"."updatedById" IS 'User who last updated this group';
-- Modify "lesson_templates" table
ALTER TABLE "lesson_templates" ADD COLUMN "updatedById" uuid NULL, ADD COLUMN "organizationId" character varying NULL, ADD CONSTRAINT "fk_lesson_templates_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_lesson_templates_organizationId" to table: "lesson_templates"
CREATE INDEX "idx_lesson_templates_organizationId" ON "lesson_templates" ("organizationId");
-- Set comment to column: "updatedById" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."updatedById" IS 'User who last updated this template';
-- Set comment to column: "organizationId" on table: "lesson_templates"
COMMENT ON COLUMN "lesson_templates"."organizationId" IS 'Direct org association for efficient filtering';
-- Drop index "notifications_userId_createdAt_idx" from table: "notifications"
DROP INDEX IF EXISTS "notifications_userId_createdAt_idx";
-- Drop index "notifications_userId_isRead_idx" from table: "notifications"
DROP INDEX IF EXISTS "notifications_userId_isRead_idx";
-- Modify "notifications" table
ALTER TABLE "notifications" DROP CONSTRAINT IF EXISTS "notifications_userId_fkey", ALTER COLUMN "createdAt" TYPE timestamp, ALTER COLUMN "createdAt" SET DEFAULT now();
ALTER TABLE "notifications" DROP CONSTRAINT IF EXISTS "fk_notifications_user";
ALTER TABLE "notifications" ADD CONSTRAINT "fk_notifications_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Create index "idx_notifications_userId_createdAt" to table: "notifications"
CREATE INDEX IF NOT EXISTS "idx_notifications_userId_createdAt" ON "notifications" ("userId", "createdAt");
-- Create index "idx_notifications_userId_isRead" to table: "notifications"
CREATE INDEX IF NOT EXISTS "idx_notifications_userId_isRead" ON "notifications" ("userId", "isRead");
-- Set comment to column: "type" on table: "notifications"
COMMENT ON COLUMN "notifications"."type" IS 'JOIN_REQUEST, MEMBER_JOINED';
-- Modify "posts" table
ALTER TABLE "posts" ADD COLUMN "updatedById" uuid NULL, ADD CONSTRAINT "fk_posts_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Set comment to column: "updatedById" on table: "posts"
COMMENT ON COLUMN "posts"."updatedById" IS 'User who last updated this post';
-- Modify "study_programs" table
ALTER TABLE "study_programs" ADD COLUMN "updatedById" uuid NULL, ADD COLUMN "organizationId" character varying NULL, ADD CONSTRAINT "fk_study_programs_updatedBy" FOREIGN KEY ("updatedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_study_programs_organizationId" to table: "study_programs"
CREATE INDEX "idx_study_programs_organizationId" ON "study_programs" ("organizationId");
-- Set comment to column: "updatedById" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."updatedById" IS 'User who last updated this program';
-- Set comment to column: "organizationId" on table: "study_programs"
COMMENT ON COLUMN "study_programs"."organizationId" IS 'Direct org association for efficient filtering';
-- Backfill organizationId for existing study_programs from creator's organization
UPDATE "study_programs" sp SET "organizationId" = o."id"
FROM "organizations" o WHERE o."ownerId" = sp."creatorId" AND sp."organizationId" IS NULL;
-- Backfill organizationId for existing lesson_templates from creator's organization
UPDATE "lesson_templates" lt SET "organizationId" = o."id"
FROM "organizations" o WHERE o."ownerId" = lt."creatorId" AND lt."organizationId" IS NULL AND lt."creatorId" IS NOT NULL;
