-- Create enum type: "BetaApplicationStatus"
CREATE TYPE "public"."BetaApplicationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN');

-- Modify "users" table
ALTER TABLE "users" ADD COLUMN "isActive" boolean NOT NULL DEFAULT true;

-- Create index "idx_users_isActive" to table: "users"
CREATE INDEX "idx_users_isActive" ON "users" ("isActive");

-- Set comment to column: "isActive" on table: "users"
COMMENT ON COLUMN "users"."isActive" IS 'Inactive users cannot authenticate or access leader/admin app surfaces';

-- Create "faq_items" table
CREATE TABLE "faq_items" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "scope" varchar NOT NULL,
  "question" varchar NOT NULL,
  "answer" text NOT NULL,
  "sortOrder" integer NOT NULL DEFAULT 0,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "faq_items_scope_question_key" UNIQUE ("scope", "question")
);

-- Create indexes for "faq_items"
CREATE INDEX "idx_faq_items_scope" ON "faq_items" ("scope");
CREATE INDEX "idx_faq_items_scope_isActive" ON "faq_items" ("scope", "isActive");
CREATE INDEX "idx_faq_items_scope_sortOrder" ON "faq_items" ("scope", "sortOrder");

-- Set comments on "faq_items"
COMMENT ON COLUMN "faq_items"."scope" IS 'Page or surface where this FAQ is rendered (home, for-leaders, for-members, about, join-beta)';

-- Create "beta_applications" table
CREATE TABLE "beta_applications" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "googleId" varchar NOT NULL,
  "applicantEmail" varchar NOT NULL,
  "applicantName" varchar NOT NULL,
  "applicantPicture" varchar NULL,
  "phoneNumber" varchar NULL,
  "organizationName" varchar NOT NULL,
  "organizationWebsite" varchar NULL,
  "groupMemberAgeRange" varchar NOT NULL,
  "numberOfGroups" integer NOT NULL,
  "estimatedGroupMembers" integer NOT NULL,
  "groupDescription" text NOT NULL,
  "status" "public"."BetaApplicationStatus" NOT NULL DEFAULT 'PENDING',
  "userId" uuid NULL,
  "organizationId" uuid NULL,
  "reviewNotes" text NULL,
  "reviewedAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "beta_applications_googleId_key" UNIQUE ("googleId"),
  CONSTRAINT "beta_applications_applicantEmail_key" UNIQUE ("applicantEmail"),
  CONSTRAINT "fk_beta_applications_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_beta_applications_organization" FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);

-- Create indexes for "beta_applications"
CREATE INDEX "idx_beta_applications_status" ON "beta_applications" ("status");
CREATE INDEX "idx_beta_applications_createdAt" ON "beta_applications" ("createdAt");
CREATE INDEX "idx_beta_applications_userId" ON "beta_applications" ("userId");
CREATE INDEX "idx_beta_applications_organizationId" ON "beta_applications" ("organizationId");
CREATE INDEX "idx_beta_applications_applicantEmail" ON "beta_applications" ("applicantEmail");

-- Set comments on "beta_applications"
COMMENT ON COLUMN "beta_applications"."googleId" IS 'Google subject for the authenticated applicant';
