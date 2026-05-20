-- CreateTable: groups
CREATE TABLE IF NOT EXISTS "groups" (
    "id" TEXT NOT NULL,
    "code" TEXT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "coverImageUrl" TEXT,
    "isPrivate" BOOLEAN NOT NULL DEFAULT false,
    "allowInvites" BOOLEAN NOT NULL DEFAULT true,
    "welcomeMessage" TEXT,
    "ageRangeMin" INTEGER,
    "ageRangeMax" INTEGER,
    "maxMembers" INTEGER,
    "creatorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable: group_members
CREATE TABLE IF NOT EXISTS "group_members" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'member',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable: invites
CREATE TABLE IF NOT EXISTS "invites" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "groupId" TEXT,
    "inviterId" TEXT NOT NULL,
    "recipientPhone" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acceptedAt" TIMESTAMP(3),

    CONSTRAINT "invites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: groups
CREATE UNIQUE INDEX IF NOT EXISTS "groups_code_key" ON "groups"("code");
CREATE INDEX IF NOT EXISTS "groups_creatorId_idx" ON "groups"("creatorId");

-- CreateIndex: group_members
CREATE INDEX IF NOT EXISTS "group_members_groupId_idx" ON "group_members"("groupId");

-- CreateIndex: invites
CREATE UNIQUE INDEX IF NOT EXISTS "invites_token_key" ON "invites"("token");

-- AddForeignKey: groups.creatorId -> users.id
DO $$ BEGIN
    ALTER TABLE "groups" ADD CONSTRAINT "groups_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- AddForeignKey: group_members.groupId -> groups.id
DO $$ BEGIN
    ALTER TABLE "group_members" ADD CONSTRAINT "group_members_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- AddForeignKey: invites.groupId -> groups.id
DO $$ BEGIN
    ALTER TABLE "invites" ADD CONSTRAINT "invites_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- AddForeignKey: invites.inviterId -> users.id
DO $$ BEGIN
    ALTER TABLE "invites" ADD CONSTRAINT "invites_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
