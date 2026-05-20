-- Add missing columns to users table
-- These columns exist in the Prisma schema but were not in the initial migration

-- Add phoneNumber column (nullable with unique constraint)
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phoneNumber" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "users_phoneNumber_key" ON "users"("phoneNumber");

-- Add phoneVerified column (boolean with default false)
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phoneVerified" BOOLEAN NOT NULL DEFAULT false;

-- Add isSuperAdmin column (boolean with default false)
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "isSuperAdmin" BOOLEAN NOT NULL DEFAULT false;

-- Create index for isSuperAdmin
CREATE INDEX IF NOT EXISTS "users_isSuperAdmin_idx" ON "users"("isSuperAdmin");

-- Add missing columns to organizations table
ALTER TABLE "organizations" ADD COLUMN IF NOT EXISTS "twilioVerifyServiceSid" TEXT;
