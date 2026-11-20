-- Create "voice_memos" table
CREATE TABLE "voice_memos" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NULL,
  "memberId" character varying NULL,
  "title" character varying NOT NULL,
  "key" character varying NOT NULL,
  "mimeType" character varying NOT NULL DEFAULT 'audio/mp4',
  "fileSize" integer NULL,
  "durationMs" integer NULL,
  "waveformPeaks" jsonb NULL,
  "transcript" text NULL,
  "transcriptSegments" jsonb NULL,
  "transcriptStatus" character varying NOT NULL DEFAULT 'none',
  "transcriptSource" character varying NULL,
  "transcriptAttempts" integer NOT NULL DEFAULT 0,
  "transcriptClaimedAt" timestamp NULL,
  "uploadStatus" character varying NOT NULL DEFAULT 'pending',
  "recordedAt" timestamp NOT NULL,
  "isActive" boolean NOT NULL DEFAULT true,
  "deletedAt" timestamp NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_voice_memos_memberId_recordedAt" to table: "voice_memos"
CREATE INDEX "idx_voice_memos_memberId_recordedAt" ON "voice_memos" ("memberId", "recordedAt");
-- Create index "idx_voice_memos_uploadStatus_createdAt" to table: "voice_memos"
CREATE INDEX "idx_voice_memos_uploadStatus_createdAt" ON "voice_memos" ("uploadStatus", "createdAt");
-- Create index "idx_voice_memos_userId_recordedAt" to table: "voice_memos"
CREATE INDEX "idx_voice_memos_userId_recordedAt" ON "voice_memos" ("userId", "recordedAt");
-- Set comment to column: "transcriptStatus" on table: "voice_memos"
COMMENT ON COLUMN "voice_memos"."transcriptStatus" IS 'none, pending, ready, failed';
-- Set comment to column: "transcriptSource" on table: "voice_memos"
COMMENT ON COLUMN "voice_memos"."transcriptSource" IS 'on_device, server';
-- Set comment to column: "uploadStatus" on table: "voice_memos"
COMMENT ON COLUMN "voice_memos"."uploadStatus" IS 'pending, ready';
-- Modify "voice_memos" table
ALTER TABLE "voice_memos" ADD CONSTRAINT "fk_voice_memos_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE;
