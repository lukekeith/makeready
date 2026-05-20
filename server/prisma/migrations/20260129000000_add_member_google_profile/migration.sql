-- AlterTable: Add Google profile fields to Member
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "googleId" TEXT;
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "googleEmail" TEXT;
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "googlePicture" TEXT;
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "googleLinkedAt" TIMESTAMP(3);

-- CreateIndex: Unique constraint on googleId
CREATE UNIQUE INDEX IF NOT EXISTS "members_googleId_key" ON "members"("googleId");

-- CreateIndex: Index for faster lookups
CREATE INDEX IF NOT EXISTS "members_googleId_idx" ON "members"("googleId");
