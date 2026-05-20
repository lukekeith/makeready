-- Modify "groups" table
ALTER TABLE "groups" ADD COLUMN "memberDirectoryEnabled" boolean NOT NULL DEFAULT true;
-- Set comment to column: "memberDirectoryEnabled" on table: "groups"
COMMENT ON COLUMN "groups"."memberDirectoryEnabled" IS 'Allow members to see contact info of other members';
-- Modify "member_lesson_progress" table
ALTER TABLE "member_lesson_progress" ALTER COLUMN "lastUpdatedAt" DROP DEFAULT;
-- Create "device_tokens" table
CREATE TABLE "device_tokens" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "token" character varying NOT NULL,
  "platform" character varying NOT NULL DEFAULT 'ios',
  "environment" character varying NOT NULL DEFAULT 'production',
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "device_tokens_token_key" UNIQUE ("token"),
  CONSTRAINT "fk_device_tokens_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_device_tokens_userId" to table: "device_tokens"
CREATE INDEX "idx_device_tokens_userId" ON "device_tokens" ("userId");
-- Set comment to column: "platform" on table: "device_tokens"
COMMENT ON COLUMN "device_tokens"."platform" IS 'ios or android';
-- Set comment to column: "environment" on table: "device_tokens"
COMMENT ON COLUMN "device_tokens"."environment" IS 'sandbox or production';
