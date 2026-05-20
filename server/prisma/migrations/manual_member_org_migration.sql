-- Manual migration: Member Organization Many-to-Many
-- This script safely migrates existing Member.organizationId data to MemberOrganization table

-- Step 1: Create member_organizations table if it doesn't exist
CREATE TABLE IF NOT EXISTS "member_organizations" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_organizations_pkey" PRIMARY KEY ("id")
);

-- Step 2: Create indexes
CREATE UNIQUE INDEX IF NOT EXISTS "member_organizations_memberId_organizationId_key" ON "member_organizations"("memberId", "organizationId");
CREATE INDEX IF NOT EXISTS "member_organizations_memberId_idx" ON "member_organizations"("memberId");
CREATE INDEX IF NOT EXISTS "member_organizations_organizationId_idx" ON "member_organizations"("organizationId");

-- Step 3: Migrate existing data (only if organizationId column exists)
INSERT INTO "member_organizations" ("id", "memberId", "organizationId", "joinedAt", "createdAt", "updatedAt")
SELECT
    gen_random_uuid()::text,
    "id" as "memberId",
    "organizationId",
    "createdAt" as "joinedAt",
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "members"
WHERE "organizationId" IS NOT NULL
ON CONFLICT ("memberId", "organizationId") DO NOTHING;

-- Step 4: Add foreign key constraints
ALTER TABLE "member_organizations"
    DROP CONSTRAINT IF EXISTS "member_organizations_memberId_fkey";

ALTER TABLE "member_organizations"
    ADD CONSTRAINT "member_organizations_memberId_fkey"
    FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "member_organizations"
    DROP CONSTRAINT IF EXISTS "member_organizations_organizationId_fkey";

ALTER TABLE "member_organizations"
    ADD CONSTRAINT "member_organizations_organizationId_fkey"
    FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Step 5: Drop the old organizationId column from members table
ALTER TABLE "members" DROP COLUMN IF EXISTS "organizationId";

-- Verification query (uncomment to check)
-- SELECT COUNT(*) as "Total Members",
--        (SELECT COUNT(*) FROM member_organizations) as "Total Org Memberships"
-- FROM members;
