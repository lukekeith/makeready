-- CreateTable: organizations
CREATE TABLE "organizations" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable: members
CREATE TABLE "members" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
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

-- AlterTable: users - Add organizationId
ALTER TABLE "users" ADD COLUMN "organizationId" TEXT;

-- AlterTable: groups - Add organizationId and isActive
ALTER TABLE "groups" ADD COLUMN "organizationId" TEXT,
ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable: group_members - Add memberId and isActive
ALTER TABLE "group_members" ADD COLUMN "memberId" TEXT,
ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex: organizations
CREATE UNIQUE INDEX "organizations_ownerId_key" ON "organizations"("ownerId");
CREATE INDEX "organizations_ownerId_idx" ON "organizations"("ownerId");
CREATE INDEX "organizations_isActive_idx" ON "organizations"("isActive");

-- CreateIndex: members
CREATE UNIQUE INDEX "members_phoneNumber_key" ON "members"("phoneNumber");
CREATE INDEX "members_organizationId_idx" ON "members"("organizationId");
CREATE INDEX "members_isActive_idx" ON "members"("isActive");
CREATE INDEX "members_organizationId_isActive_idx" ON "members"("organizationId", "isActive");
CREATE INDEX "members_phoneNumber_idx" ON "members"("phoneNumber");

-- CreateIndex: users
CREATE INDEX "users_organizationId_idx" ON "users"("organizationId");

-- CreateIndex: groups
CREATE INDEX "groups_organizationId_idx" ON "groups"("organizationId");
CREATE INDEX "groups_isActive_idx" ON "groups"("isActive");
CREATE INDEX "groups_organizationId_isActive_idx" ON "groups"("organizationId", "isActive");

-- CreateIndex: group_members
CREATE UNIQUE INDEX IF NOT EXISTS "group_members_groupId_memberId_key" ON "group_members"("groupId", "memberId");
CREATE INDEX IF NOT EXISTS "group_members_groupId_idx" ON "group_members"("groupId");
CREATE INDEX IF NOT EXISTS "group_members_memberId_idx" ON "group_members"("memberId");
CREATE INDEX IF NOT EXISTS "group_members_isActive_idx" ON "group_members"("isActive");
CREATE INDEX IF NOT EXISTS "group_members_groupId_isActive_idx" ON "group_members"("groupId", "isActive");

-- AddForeignKey: users.organizationId -> organizations.id
-- Note: This will be populated by data migration before enabling constraint
-- ALTER TABLE "users" ADD CONSTRAINT "users_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey: organizations.ownerId -> users.id
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: members.organizationId -> organizations.id
ALTER TABLE "members" ADD CONSTRAINT "members_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: groups.organizationId -> organizations.id
-- Note: This will be populated by data migration before enabling constraint
-- ALTER TABLE "groups" ADD CONSTRAINT "groups_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey: group_members.memberId -> members.id
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE;
