-- Modify "members" table
ALTER TABLE "members" ADD COLUMN "profilePictureOriginalUrl" text NULL, ADD COLUMN "profilePictureFraming" jsonb NULL;
-- Set comment to column: "profilePictureOriginalUrl" on table: "members"
COMMENT ON COLUMN "members"."profilePictureOriginalUrl" IS 'image-framing-editor SC1 (D5, D8): the full original avatar photo; null means Edit reopens profilePicture';
-- Set comment to column: "profilePictureFraming" on table: "members"
COMMENT ON COLUMN "members"."profilePictureFraming" IS 'image-framing-editor SC2 (D8): {scale, rotation, offsetX, offsetY, flipped, quarterTurns} the avatar was rendered with';
