-- Modify "media" table
ALTER TABLE "media" ADD COLUMN "takenAt" timestamp NULL;
-- Set comment to column: "takenAt" on table: "media"
COMMENT ON COLUMN "media"."takenAt" IS 'When the photo was taken (media-page D4): the request''s takenAt, else EXIF DateTimeOriginal, else null';
-- media-page D4: backfill the date taken from the EXIF the upload already stored; a malformed value stays null.
UPDATE "media" SET "takenAt" = CASE WHEN "exifData"->>'dateTaken' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' THEN ("exifData"->>'dateTaken')::timestamptz END WHERE "takenAt" IS NULL AND "exifData" ? 'dateTaken';
-- media-page D4: the same bounds parseTakenAt applies to new rows.
UPDATE "media" SET "takenAt" = NULL WHERE "takenAt" < '1990-01-01' OR "takenAt" > now() + interval '24 hours';
