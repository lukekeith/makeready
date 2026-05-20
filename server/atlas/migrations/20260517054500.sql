-- Support Microsoft-backed beta applicants while preserving legacy Google auth fields.
-- Existing beta migration created a googleId column before the beta auth provider was corrected.

-- Modify "users" table: allow users without Google auth and add Microsoft identity.
ALTER TABLE "users" ALTER COLUMN "googleId" DROP NOT NULL;
ALTER TABLE "users" ADD COLUMN "microsoftId" varchar NULL;
CREATE UNIQUE INDEX "users_microsoftId_key" ON "users" ("microsoftId");
COMMENT ON COLUMN "users"."microsoftId" IS 'Microsoft Entra ID object ID for Microsoft-authenticated beta/admin users';

-- Modify "beta_applications" table: rename Google applicant identity to Microsoft.
ALTER TABLE "beta_applications" RENAME COLUMN "googleId" TO "microsoftId";
ALTER TABLE "beta_applications" DROP CONSTRAINT IF EXISTS "beta_applications_googleId_key";
ALTER TABLE "beta_applications" ADD CONSTRAINT "beta_applications_microsoftId_key" UNIQUE ("microsoftId");
CREATE INDEX "idx_beta_applications_microsoftId" ON "beta_applications" ("microsoftId");
COMMENT ON COLUMN "beta_applications"."microsoftId" IS 'Microsoft Entra ID object ID or subject for the authenticated applicant';
