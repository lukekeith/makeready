-- Modify "media" table
ALTER TABLE "media" ADD COLUMN "videoId" uuid NULL, ADD COLUMN "thumbnailUrl" character varying NULL, ADD COLUMN "uploadStatus" character varying NOT NULL DEFAULT 'ready', ADD COLUMN "source" character varying NULL, ADD COLUMN "duration" integer NULL, ADD CONSTRAINT "fk_media_video" FOREIGN KEY ("videoId") REFERENCES "videos" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_media_uploadStatus" to table: "media"
CREATE INDEX "idx_media_uploadStatus" ON "media" ("uploadStatus");
-- Create index "idx_media_videoId" to table: "media"
CREATE INDEX "idx_media_videoId" ON "media" ("videoId");
-- Set comment to column: "videoId" on table: "media"
COMMENT ON COLUMN "media"."videoId" IS 'FK to Video for Cloudflare Stream media';
-- Set comment to column: "thumbnailUrl" on table: "media"
COMMENT ON COLUMN "media"."thumbnailUrl" IS 'Preview thumbnail URL';
-- Set comment to column: "uploadStatus" on table: "media"
COMMENT ON COLUMN "media"."uploadStatus" IS 'pending, processing, ready, error';
-- Set comment to column: "source" on table: "media"
COMMENT ON COLUMN "media"."source" IS 'How media entered library: direct, auto_capture, import';
-- Set comment to column: "duration" on table: "media"
COMMENT ON COLUMN "media"."duration" IS 'Duration in seconds for video/audio';
-- Create "media_tags" table
CREATE TABLE "media_tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "mediaId" uuid NOT NULL,
  "tag" character varying NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "media_tags_mediaId_tag_key" UNIQUE ("mediaId", "tag"),
  CONSTRAINT "fk_media_tags_media" FOREIGN KEY ("mediaId") REFERENCES "media" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_media_tags_mediaId" to table: "media_tags"
CREATE INDEX "idx_media_tags_mediaId" ON "media_tags" ("mediaId");
-- Create index "idx_media_tags_tag" to table: "media_tags"
CREATE INDEX "idx_media_tags_tag" ON "media_tags" ("tag");
-- Set comment to column: "tag" on table: "media_tags"
COMMENT ON COLUMN "media_tags"."tag" IS 'Lowercase, trimmed tag string';
-- Create "media_usages" table
CREATE TABLE "media_usages" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "mediaId" uuid NOT NULL,
  "usageType" character varying NOT NULL,
  "resourceId" character varying NOT NULL,
  "resourceName" character varying NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "media_usages_mediaId_usageType_resourceId_key" UNIQUE ("mediaId", "usageType", "resourceId"),
  CONSTRAINT "fk_media_usages_media" FOREIGN KEY ("mediaId") REFERENCES "media" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_media_usages_mediaId" to table: "media_usages"
CREATE INDEX "idx_media_usages_mediaId" ON "media_usages" ("mediaId");
-- Create index "idx_media_usages_resourceId" to table: "media_usages"
CREATE INDEX "idx_media_usages_resourceId" ON "media_usages" ("resourceId");
-- Create index "idx_media_usages_usageType" to table: "media_usages"
CREATE INDEX "idx_media_usages_usageType" ON "media_usages" ("usageType");
-- Set comment to column: "usageType" on table: "media_usages"
COMMENT ON COLUMN "media_usages"."usageType" IS 'LESSON_ACTIVITY, PROGRAM_COVER, GROUP_COVER, POST, SCHEDULED_ACTIVITY';
-- Set comment to column: "resourceId" on table: "media_usages"
COMMENT ON COLUMN "media_usages"."resourceId" IS 'ID of the resource using this media';
-- Set comment to column: "resourceName" on table: "media_usages"
COMMENT ON COLUMN "media_usages"."resourceName" IS 'Human-readable name for display';
