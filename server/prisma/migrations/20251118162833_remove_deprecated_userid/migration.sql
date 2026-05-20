-- DropForeignKey (only if exists)
DO $$ BEGIN
    ALTER TABLE "group_members" DROP CONSTRAINT IF EXISTS "group_members_userId_fkey";
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- DropIndex (only if exists)
DROP INDEX IF EXISTS "group_members_groupId_userId_key";

-- AlterTable (only if column exists)
DO $$ BEGIN
    ALTER TABLE "group_members" DROP COLUMN IF EXISTS "userId";
EXCEPTION WHEN undefined_column THEN NULL;
END $$;
