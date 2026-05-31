-- Create enum type "SmsDeliveryStatus"
CREATE TYPE "SmsDeliveryStatus" AS ENUM ('QUEUED', 'SENT', 'DELIVERED', 'UNDELIVERED', 'FAILED');
-- Create "sms_campaigns" table
CREATE TABLE "sms_campaigns" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "slug" character varying NOT NULL,
  "name" character varying NOT NULL,
  "description" text NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "sms_campaigns_slug_key" UNIQUE ("slug")
);
-- Set comment to column: "slug" on table: "sms_campaigns"
COMMENT ON COLUMN "sms_campaigns"."slug" IS 'Lookup key, e.g. group-invite, study-invite';
-- Set comment to column: "name" on table: "sms_campaigns"
COMMENT ON COLUMN "sms_campaigns"."name" IS 'Human-readable campaign name';
-- Create "sms_templates" table
CREATE TABLE "sms_templates" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "campaignId" uuid NOT NULL,
  "slug" character varying NOT NULL,
  "body" text NOT NULL,
  "requiredProps" jsonb NOT NULL,
  "minIntervalMinutes" integer NOT NULL DEFAULT 1200,
  "isActive" boolean NOT NULL DEFAULT true,
  "version" integer NOT NULL DEFAULT 1,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "sms_templates_slug_key" UNIQUE ("slug"),
  CONSTRAINT "fk_sms_templates_campaign" FOREIGN KEY ("campaignId") REFERENCES "sms_campaigns" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_sms_templates_campaignId" to table: "sms_templates"
CREATE INDEX "idx_sms_templates_campaignId" ON "sms_templates" ("campaignId");
-- Set comment to column: "slug" on table: "sms_templates"
COMMENT ON COLUMN "sms_templates"."slug" IS 'Lookup key, e.g. group-invite-v1';
-- Set comment to column: "body" on table: "sms_templates"
COMMENT ON COLUMN "sms_templates"."body" IS 'Template with {variable} placeholders';
-- Set comment to column: "requiredProps" on table: "sms_templates"
COMMENT ON COLUMN "sms_templates"."requiredProps" IS 'JSON array of required context keys for rendering';
-- Set comment to column: "minIntervalMinutes" on table: "sms_templates"
COMMENT ON COLUMN "sms_templates"."minIntervalMinutes" IS 'Min minutes between re-sends to the same phone (default 20hrs)';
-- Create "sms_logs" table
CREATE TABLE "sms_logs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "templateId" uuid NOT NULL,
  "recipientPhone" character varying NOT NULL,
  "messageBody" text NOT NULL,
  "twilioMessageSid" character varying NULL,
  "status" "SmsDeliveryStatus" NOT NULL DEFAULT 'QUEUED',
  "statusUpdatedAt" timestamp NULL,
  "sentById" uuid NULL,
  "metadata" jsonb NULL,
  "isDevSend" boolean NOT NULL DEFAULT false,
  "errorMessage" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_sms_logs_sentBy" FOREIGN KEY ("sentById") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "fk_sms_logs_template" FOREIGN KEY ("templateId") REFERENCES "sms_templates" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_sms_logs_recipientPhone" to table: "sms_logs"
CREATE INDEX "idx_sms_logs_recipientPhone" ON "sms_logs" ("recipientPhone");
-- Create index "idx_sms_logs_status" to table: "sms_logs"
CREATE INDEX "idx_sms_logs_status" ON "sms_logs" ("status");
-- Create index "idx_sms_logs_templateId_recipientPhone_createdAt" to table: "sms_logs"
CREATE INDEX "idx_sms_logs_templateId_recipientPhone_createdAt" ON "sms_logs" ("templateId", "recipientPhone", "createdAt");
-- Create index "idx_sms_logs_twilioMessageSid" to table: "sms_logs"
CREATE INDEX "idx_sms_logs_twilioMessageSid" ON "sms_logs" ("twilioMessageSid");
-- Set comment to column: "recipientPhone" on table: "sms_logs"
COMMENT ON COLUMN "sms_logs"."recipientPhone" IS 'E.164 phone number';
-- Set comment to column: "messageBody" on table: "sms_logs"
COMMENT ON COLUMN "sms_logs"."messageBody" IS 'The actual rendered message that was sent';
-- Set comment to column: "metadata" on table: "sms_logs"
COMMENT ON COLUMN "sms_logs"."metadata" IS 'Context data like groupId, enrollmentId';
