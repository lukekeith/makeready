-- Add value to enum type: "ActivityAction"
ALTER TYPE "ActivityAction" ADD VALUE 'ENROLLED';
-- Add value to enum type: "ActivityAction"
ALTER TYPE "ActivityAction" ADD VALUE 'COMPLETED';
-- Add value to enum type: "ActivityAction"
ALTER TYPE "ActivityAction" ADD VALUE 'SUBMITTED';
-- Add value to enum type: "ActivityAction"
ALTER TYPE "ActivityAction" ADD VALUE 'SENT';
-- Add value to enum type: "ActivityAction"
ALTER TYPE "ActivityAction" ADD VALUE 'NOTIFIED';
-- Modify "activities" table
ALTER TABLE "activities" ADD COLUMN "groupId" uuid NULL, ADD COLUMN "targetUserId" uuid NULL, ADD COLUMN "title" character varying NULL, ADD COLUMN "body" text NULL, ADD COLUMN "isRead" boolean NOT NULL DEFAULT false, ADD CONSTRAINT "fk_activities_group" FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, ADD CONSTRAINT "fk_activities_targetUser" FOREIGN KEY ("targetUserId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
-- Create index "idx_activities_groupId_createdAt" to table: "activities"
CREATE INDEX "idx_activities_groupId_createdAt" ON "activities" ("groupId", "createdAt");
-- Create index "idx_activities_targetUserId_createdAt" to table: "activities"
CREATE INDEX "idx_activities_targetUserId_createdAt" ON "activities" ("targetUserId", "createdAt");
-- Create index "idx_activities_targetUserId_isRead" to table: "activities"
CREATE INDEX "idx_activities_targetUserId_isRead" ON "activities" ("targetUserId", "isRead");
-- Set comment to column: "groupId" on table: "activities"
COMMENT ON COLUMN "activities"."groupId" IS 'Group context for group-level feeds';
-- Set comment to column: "targetUserId" on table: "activities"
COMMENT ON COLUMN "activities"."targetUserId" IS 'Target user for directed/notification activities';
-- Set comment to column: "title" on table: "activities"
COMMENT ON COLUMN "activities"."title" IS 'Display title (for notification-style activities)';
-- Set comment to column: "body" on table: "activities"
COMMENT ON COLUMN "activities"."body" IS 'Display body (for notification-style activities)';
-- Set comment to column: "isRead" on table: "activities"
COMMENT ON COLUMN "activities"."isRead" IS 'Read status for targeted activities';
