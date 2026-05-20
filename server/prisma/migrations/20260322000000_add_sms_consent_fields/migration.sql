-- AlterTable: User
ALTER TABLE "users" ADD COLUMN "smsConsent" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "smsConsentAt" TIMESTAMP(3);

-- AlterTable: Member
ALTER TABLE "members" ADD COLUMN "smsConsent" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "members" ADD COLUMN "smsConsentAt" TIMESTAMP(3);
