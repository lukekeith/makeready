-- Backfill: assign every organization-less group to its organization so the
-- NOT NULL constraint below can be applied. All currently-orphaned groups
-- belong to the MakeReady organization. Guarded on that org existing, so this
-- is a safe no-op on environments that don't have it (e.g. a fresh/empty DB).
UPDATE "groups"
SET "organizationId" = '8622a038-0e4a-418d-996b-1039cf10806a'
WHERE "organizationId" IS NULL
  AND EXISTS (
    SELECT 1 FROM "organizations" WHERE "id" = '8622a038-0e4a-418d-996b-1039cf10806a'
  );

-- Grant Scott Stickane (the QA user) the same MakeReady role(s) the org owner
-- (Luke Keith) holds, so he can manage groups across the org — not only ones he
-- created. This copies the owner's role assignment instead of hard-coding a role
-- id, so it always matches how the owner is set up. Idempotent (NOT EXISTS) and a
-- no-op anywhere the source assignment is absent (e.g. an empty environment).
INSERT INTO "user_roles" ("id", "userId", "roleId", "organizationId", "assignedAt", "assignedBy")
SELECT gen_random_uuid(),
       'df8f4da0-8ee1-48bb-a6a3-61c0fd44206c',
       ur."roleId",
       ur."organizationId",
       now(),
       '57ed656d-acc0-4dcf-a9dd-c655f01e7b06'
FROM "user_roles" ur
WHERE ur."userId" = '57ed656d-acc0-4dcf-a9dd-c655f01e7b06'
  AND ur."organizationId" = '8622a038-0e4a-418d-996b-1039cf10806a'
  AND NOT EXISTS (
    SELECT 1 FROM "user_roles" e
    WHERE e."userId" = 'df8f4da0-8ee1-48bb-a6a3-61c0fd44206c'
      AND e."roleId" = ur."roleId"
      AND e."organizationId" = ur."organizationId"
  );

-- Enforce the invariant: every group MUST belong to an organization. Groups can
-- no longer be orphaned.
-- Modify "groups" table
ALTER TABLE "groups" ALTER COLUMN "organizationId" SET NOT NULL;
