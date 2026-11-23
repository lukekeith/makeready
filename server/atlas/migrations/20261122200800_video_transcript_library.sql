-- Modify "videos" table
ALTER TABLE "videos" ADD COLUMN "transcript" text NULL, ADD COLUMN "transcriptSegments" jsonb NULL, ADD COLUMN "transcriptStatus" character varying NOT NULL DEFAULT 'none', ADD COLUMN "transcriptSource" character varying NULL, ADD COLUMN "transcriptAttempts" integer NOT NULL DEFAULT 0, ADD COLUMN "transcriptClaimedAt" timestamp NULL, ADD COLUMN "libraryRemovedAt" timestamp NULL;
-- Create index "idx_videos_status_createdAt" to table: "videos"
CREATE INDEX "idx_videos_status_createdAt" ON "videos" ("status", "createdAt");
-- Create index "idx_videos_userId_createdAt_id" to table: "videos"
CREATE INDEX "idx_videos_userId_createdAt_id" ON "videos" ("userId", "createdAt", "id");
-- Set comment to column: "transcriptStatus" on table: "videos"
COMMENT ON COLUMN "videos"."transcriptStatus" IS 'none, pending, ready, failed';
-- Set comment to column: "transcriptSource" on table: "videos"
COMMENT ON COLUMN "videos"."transcriptSource" IS 'on_device, server';
