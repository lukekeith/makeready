-- Add User linking fields to Member table
-- Enables bidirectional User <-> Member account linking

-- Add userId column (unique, nullable)
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "userId" VARCHAR;

-- Add userLinkedAt column (nullable)
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "userLinkedAt" TIMESTAMP;

-- Add unique constraint on userId
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'members_userId_key'
  ) THEN
    ALTER TABLE "members" ADD CONSTRAINT "members_userId_key" UNIQUE ("userId");
  END IF;
END $$;

-- Add index on userId for faster lookups
CREATE INDEX IF NOT EXISTS "idx_members_userId" ON "members" ("userId");

-- Add foreign key constraint to users table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'members_userId_fkey'
  ) THEN
    ALTER TABLE "members" ADD CONSTRAINT "members_userId_fkey"
      FOREIGN KEY ("userId") REFERENCES "users"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

-- Add comment for documentation
COMMENT ON COLUMN "members"."userId" IS 'Links Member to User account for bidirectional access';
COMMENT ON COLUMN "members"."userLinkedAt" IS 'When account was linked to User';
