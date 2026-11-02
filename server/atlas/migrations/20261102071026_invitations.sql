-- Create "invitations" table
CREATE TABLE "invitations" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "initiatedBy" character varying NOT NULL,
  "token" character varying NULL,
  "groupId" uuid NULL,
  "inviterId" uuid NULL,
  "memberId" uuid NULL,
  "organizationId" uuid NULL,
  "recipientPhone" character varying NULL,
  "recipientName" character varying NULL,
  "message" character varying NULL,
  "respondedById" uuid NULL,
  "status" character varying NOT NULL DEFAULT 'pending',
  "expiresAt" timestamp NULL,
  "respondedAt" timestamp NULL,
  "acceptedAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "invitations_token_key" UNIQUE ("token"),
  CONSTRAINT "fk_invitations_group" FOREIGN KEY ("groupId") REFERENCES "groups" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_invitations_inviter" FOREIGN KEY ("inviterId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_invitations_member" FOREIGN KEY ("memberId") REFERENCES "members" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_invitations_organization" FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_invitations_respondedBy" FOREIGN KEY ("respondedById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create index "idx_invitations_groupId_memberId" to table: "invitations"
CREATE INDEX "idx_invitations_groupId_memberId" ON "invitations" ("groupId", "memberId");
-- Create index "idx_invitations_groupId_status" to table: "invitations"
CREATE INDEX "idx_invitations_groupId_status" ON "invitations" ("groupId", "status");
-- Create index "idx_invitations_memberId" to table: "invitations"
CREATE INDEX "idx_invitations_memberId" ON "invitations" ("memberId");
-- Create index "idx_invitations_organizationId_createdAt" to table: "invitations"
CREATE INDEX "idx_invitations_organizationId_createdAt" ON "invitations" ("organizationId", "createdAt");
-- Create index "idx_invitations_recipientPhone" to table: "invitations"
CREATE INDEX "idx_invitations_recipientPhone" ON "invitations" ("recipientPhone");
-- Set comment to column: "initiatedBy" on table: "invitations"
COMMENT ON COLUMN "invitations"."initiatedBy" IS 'leader or member; preserves the legacy relationship kind';
-- Create "invite_events" table
CREATE TABLE "invite_events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "invitationId" uuid NOT NULL,
  "type" character varying NOT NULL,
  "at" timestamp NOT NULL DEFAULT now(),
  "actorId" character varying NULL,
  "groupId" character varying NULL,
  "metadata" jsonb NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_invite_events_invitation" FOREIGN KEY ("invitationId") REFERENCES "invitations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_invite_events_invitationId_at" to table: "invite_events"
CREATE INDEX "idx_invite_events_invitationId_at" ON "invite_events" ("invitationId", "at");
-- Preserve both legacy sources in Atlas's single-file transaction. Block source writes until copy/drop completes.
LOCK TABLE "invites", "group_join_requests" IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM "invites" i JOIN "group_join_requests" r ON r.id = i.id) THEN
    RAISE EXCEPTION 'Invitation source ID collision; migration aborted without changing source IDs';
  END IF;
END $$;

INSERT INTO "invitations" (
  "id", "initiatedBy", "token", "groupId", "inviterId", "organizationId", "recipientPhone", "recipientName",
  "status", "expiresAt", "createdAt", "acceptedAt", "updatedAt"
)
SELECT i.id, 'leader', i.token, i."groupId", i."inviterId", COALESCE(g."organizationId"::text, historical_org.id::text, sole_org.id::text)::uuid,
       i."recipientPhone", i."recipientName", i.status, i."expiresAt", i."createdAt", i."acceptedAt", i."createdAt"
FROM "invites" i
JOIN "users" u ON u.id = i."inviterId"
LEFT JOIN "groups" g ON g.id = i."groupId"
LEFT JOIN "organizations" historical_org ON historical_org.id::text = u."organizationId"::text
LEFT JOIN LATERAL (
  SELECT CASE WHEN count(*) = 1 THEN (array_agg(candidate.id))[1] END AS id
  FROM (
    SELECT o.id::text AS id FROM "organizations" o WHERE o."ownerId" = i."inviterId"
    UNION
    SELECT ur."organizationId"::text FROM "user_roles" ur WHERE ur."userId" = i."inviterId"
  ) candidate
) sole_org ON true;

INSERT INTO "invitations" (
  "id", "initiatedBy", "groupId", "memberId", "organizationId", "recipientPhone", "status", "message",
  "respondedById", "respondedAt", "createdAt", "updatedAt"
)
SELECT r.id, 'member', r."groupId", r."memberId", g."organizationId"::uuid, m."phoneNumber",
       CASE WHEN r.status = 'approved' THEN 'accepted' ELSE r.status END, r.message,
       r."reviewedById", r."reviewedAt", r."createdAt", r."updatedAt"
FROM "group_join_requests" r
JOIN "groups" g ON g.id = r."groupId"
JOIN "members" m ON m.id = r."memberId";

INSERT INTO "invite_events" ("invitationId", "type", "at", "actorId", "groupId")
SELECT id, 'sent', "createdAt", "inviterId"::text, "groupId"::text FROM "invitations" WHERE "initiatedBy" = 'leader'
UNION ALL
SELECT id, 'accepted', "acceptedAt", NULL, "groupId"::text FROM "invitations" WHERE "initiatedBy" = 'leader' AND "acceptedAt" IS NOT NULL
UNION ALL
SELECT id, 'requested', "createdAt", "memberId"::text, "groupId"::text FROM "invitations" WHERE "initiatedBy" = 'member'
UNION ALL
SELECT id, CASE WHEN status = 'accepted' THEN 'approved' ELSE 'rejected' END, "respondedAt", "respondedById"::text, "groupId"::text
FROM "invitations" WHERE "initiatedBy" = 'member' AND status IN ('accepted', 'rejected') AND "respondedAt" IS NOT NULL
UNION ALL
SELECT id, 'expired', "expiresAt", NULL, "groupId"::text FROM "invitations"
WHERE status = 'pending' AND "expiresAt" < CURRENT_TIMESTAMP;

DO $$ BEGIN
  IF (SELECT count(*) FROM "invitations") <> (SELECT count(*) FROM "invites") + (SELECT count(*) FROM "group_join_requests") THEN
    RAISE EXCEPTION 'Invitation copy count mismatch; migration aborted';
  END IF;
END $$;
-- ActivityLog.inviteId is intentionally a scalar; preserve every value, including orphan history.

-- Drop "group_join_requests" table
DROP TABLE "group_join_requests";
-- Drop "invites" table
DROP TABLE "invites";
