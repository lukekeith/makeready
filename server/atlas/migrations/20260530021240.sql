-- Modify "lesson_activities" table
ALTER TABLE "lesson_activities" ADD COLUMN "placeholder" character varying NULL;
-- Set comment to column: "placeholder" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."placeholder" IS 'Custom placeholder text for USER_INPUT activities';
-- Modify "lesson_template_activities" table
ALTER TABLE "lesson_template_activities" ADD COLUMN "placeholder" character varying NULL;
-- Set comment to column: "placeholder" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."placeholder" IS 'Custom placeholder text for USER_INPUT activities';
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "placeholder" character varying NULL;
-- Set comment to column: "placeholder" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."placeholder" IS 'Custom placeholder text for USER_INPUT activities';
-- Modify "users" table
ALTER TABLE "users" ADD CONSTRAINT "users_microsoftId_key" UNIQUE USING INDEX "users_microsoftId_key";
-- Create "preview_tokens" table
CREATE TABLE "preview_tokens" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "token" character varying NOT NULL,
  "userId" uuid NOT NULL,
  "organizationId" uuid NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "preview_tokens_token_key" UNIQUE ("token"),
  CONSTRAINT "preview_tokens_userId_key" UNIQUE ("userId"),
  CONSTRAINT "fk_preview_tokens_organization" FOREIGN KEY ("organizationId") REFERENCES "organizations" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_preview_tokens_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_preview_tokens_token" to table: "preview_tokens"
CREATE INDEX "idx_preview_tokens_token" ON "preview_tokens" ("token");
-- Create index "idx_preview_tokens_userId" to table: "preview_tokens"
CREATE INDEX "idx_preview_tokens_userId" ON "preview_tokens" ("userId");
-- Set comment to column: "token" on table: "preview_tokens"
COMMENT ON COLUMN "preview_tokens"."token" IS 'The preview token string passed as ?preview_token=xxx';
-- Set comment to column: "userId" on table: "preview_tokens"
COMMENT ON COLUMN "preview_tokens"."userId" IS 'One token per user — upsert replaces the old one';
-- Set comment to column: "organizationId" on table: "preview_tokens"
COMMENT ON COLUMN "preview_tokens"."organizationId" IS 'Org scope — any leader in this org can preview any org content';
