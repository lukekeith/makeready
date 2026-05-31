-- Modify "sms_campaigns" table
ALTER TABLE "sms_campaigns" ADD COLUMN "messagingServiceSid" character varying NULL;
-- Set comment to column: "messagingServiceSid" on table: "sms_campaigns"
COMMENT ON COLUMN "sms_campaigns"."messagingServiceSid" IS 'Twilio Messaging Service SID (MG...) override. Falls back to TWILIO_MESSAGING_SERVICE_SID env var.';
