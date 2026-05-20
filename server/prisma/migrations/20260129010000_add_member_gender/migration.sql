-- AlterTable: Add gender field to Member
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "gender" TEXT;
