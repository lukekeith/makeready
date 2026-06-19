-- Create enum type "MembershipEventAction"
CREATE TYPE "MembershipEventAction" AS ENUM ('INVITED', 'REQUESTED', 'APPROVED', 'REJECTED', 'ADDED', 'REJOINED', 'REMOVED_GROUP', 'REMOVED_ORG');
-- Create "membership_events" table
CREATE TABLE "membership_events" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "memberId" uuid NOT NULL, "groupId" uuid NULL, "organizationId" character varying NULL, "action" "MembershipEventAction" NOT NULL, "actorId" character varying NULL, "actorType" character varying NULL, "note" text NULL, "metadata" jsonb NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "fk_membership_events_group" FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE SET NULL, CONSTRAINT "fk_membership_events_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE);
-- Create index "idx_membership_events_action" to table: "membership_events"
CREATE INDEX "idx_membership_events_action" ON "membership_events" ("action");
-- Create index "idx_membership_events_createdAt" to table: "membership_events"
CREATE INDEX "idx_membership_events_createdAt" ON "membership_events" ("createdAt");
-- Create index "idx_membership_events_groupId_createdAt" to table: "membership_events"
CREATE INDEX "idx_membership_events_groupId_createdAt" ON "membership_events" ("groupId", "createdAt");
-- Create index "idx_membership_events_memberId_createdAt" to table: "membership_events"
CREATE INDEX "idx_membership_events_memberId_createdAt" ON "membership_events" ("memberId", "createdAt");
-- Create index "idx_membership_events_organizationId_createdAt" to table: "membership_events"
CREATE INDEX "idx_membership_events_organizationId_createdAt" ON "membership_events" ("organizationId", "createdAt");
-- Set comment to column: "memberId" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."memberId" IS 'The member this event concerns (canonical identity)';
-- Set comment to column: "groupId" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."groupId" IS 'Group context; null for org-level events';
-- Set comment to column: "organizationId" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."organizationId" IS 'Org context for org-scoped history queries';
-- Set comment to column: "actorId" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."actorId" IS 'Who performed it — User id (leader) or Member id (self). Polymorphic, no FK.';
-- Set comment to column: "actorType" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."actorType" IS 'user, member, or system — disambiguates actorId';
-- Set comment to column: "note" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."note" IS 'Optional reason/message (e.g. rejection reason, join message)';
-- Set comment to column: "metadata" on table: "membership_events"
COMMENT ON COLUMN "membership_events"."metadata" IS 'Extra context (requestId, role, source, etc.)';
