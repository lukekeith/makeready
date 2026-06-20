-- Create "twilio_callbacks" table
CREATE TABLE "twilio_callbacks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "callbackType" character varying NULL,
  "accountSid" character varying NULL,
  "resourceSid" character varying NULL,
  "eventType" character varying NULL,
  "payload" jsonb NOT NULL,
  "receivedAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id")
);

-- Create indexes for callback inspection and reconciliation
CREATE INDEX "idx_twilio_callbacks_receivedAt" ON "twilio_callbacks" ("receivedAt");
CREATE INDEX "idx_twilio_callbacks_accountSid" ON "twilio_callbacks" ("accountSid");
CREATE INDEX "idx_twilio_callbacks_resourceSid" ON "twilio_callbacks" ("resourceSid");
CREATE INDEX "idx_twilio_callbacks_eventType" ON "twilio_callbacks" ("eventType");

-- Column comments
COMMENT ON COLUMN "twilio_callbacks"."callbackType" IS 'Best-effort Twilio callback category, e.g. trust_hub, business_profile, app';
COMMENT ON COLUMN "twilio_callbacks"."accountSid" IS 'Twilio Account SID associated with the callback';
COMMENT ON COLUMN "twilio_callbacks"."resourceSid" IS 'Best-effort SID for the affected Twilio resource';
COMMENT ON COLUMN "twilio_callbacks"."eventType" IS 'Best-effort Twilio event or status value';
COMMENT ON COLUMN "twilio_callbacks"."payload" IS 'Full Twilio callback payload';
