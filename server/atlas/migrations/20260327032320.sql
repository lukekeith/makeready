-- Modify "members" table (IF NOT EXISTS for columns that may already exist in production)
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "smsConsent" boolean NOT NULL DEFAULT false;
ALTER TABLE "members" ADD COLUMN IF NOT EXISTS "smsConsentAt" timestamp NULL;
-- Set comment to column: "smsConsent" on table: "members"
COMMENT ON COLUMN "members"."smsConsent" IS 'Whether member has consented to receive SMS';
-- Set comment to column: "smsConsentAt" on table: "members"
COMMENT ON COLUMN "members"."smsConsentAt" IS 'When SMS consent was last changed';
-- Modify "users" table
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "smsConsent" boolean NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "smsConsentAt" timestamp NULL;
-- Set comment to column: "smsConsent" on table: "users"
COMMENT ON COLUMN "users"."smsConsent" IS 'Whether user has consented to receive SMS';
-- Set comment to column: "smsConsentAt" on table: "users"
COMMENT ON COLUMN "users"."smsConsentAt" IS 'When SMS consent was last changed';
