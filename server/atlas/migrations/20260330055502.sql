-- Modify "media" table
ALTER TABLE "media" ADD COLUMN "width" integer NULL, ADD COLUMN "height" integer NULL, ADD COLUMN "aspectRatio" character varying NULL, ADD COLUMN "dominantColor" character varying NULL, ADD COLUMN "altText" character varying NULL, ADD COLUMN "fileHash" character varying NULL, ADD COLUMN "exifData" jsonb NULL, ADD COLUMN "videoResolution" character varying NULL;
-- Set comment to column: "width" on table: "media"
COMMENT ON COLUMN "media"."width" IS 'Image/video width in pixels';
-- Set comment to column: "height" on table: "media"
COMMENT ON COLUMN "media"."height" IS 'Image/video height in pixels';
-- Set comment to column: "aspectRatio" on table: "media"
COMMENT ON COLUMN "media"."aspectRatio" IS 'Aspect ratio e.g. 16:9, 4:3, 1:1';
-- Set comment to column: "dominantColor" on table: "media"
COMMENT ON COLUMN "media"."dominantColor" IS 'Dominant color as hex e.g. #3a5f8c';
-- Set comment to column: "altText" on table: "media"
COMMENT ON COLUMN "media"."altText" IS 'Accessibility alt text';
-- Set comment to column: "fileHash" on table: "media"
COMMENT ON COLUMN "media"."fileHash" IS 'SHA-256 hash for deduplication';
-- Set comment to column: "exifData" on table: "media"
COMMENT ON COLUMN "media"."exifData" IS 'EXIF metadata: camera, GPS, date taken, etc.';
-- Set comment to column: "videoResolution" on table: "media"
COMMENT ON COLUMN "media"."videoResolution" IS 'Video resolution e.g. 720p, 1080p, 4k';
