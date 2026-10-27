-- Modify "groups" table
ALTER TABLE "groups" ADD COLUMN "coverOriginalUrl" text NULL, ADD COLUMN "coverFraming" jsonb NULL;
-- Set comment to column: "coverOriginalUrl" on table: "groups"
COMMENT ON COLUMN "groups"."coverOriginalUrl" IS 'group-cover-image SC1 (D10): the full original cover photo; null means Edit reopens coverImageUrl (D7)';
-- Set comment to column: "coverFraming" on table: "groups"
COMMENT ON COLUMN "groups"."coverFraming" IS 'group-cover-image SC2 (D11): {scale, rotation, offsetX, offsetY} the cover was rendered with';
