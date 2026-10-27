-- Create enum type "DirectoryAccess"
CREATE TYPE "DirectoryAccess" AS ENUM ('ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED');
-- Modify "groups" table
ALTER TABLE "groups" ADD COLUMN "memberDirectoryAccess" "DirectoryAccess" NOT NULL DEFAULT 'ALLOWED';
-- Set comment to column: "memberDirectoryAccess" on table: "groups"
COMMENT ON COLUMN "groups"."memberDirectoryAccess" IS 'Three-state member directory access (ui2-groups-browse D11); memberDirectoryEnabled is kept in sync';
-- ui2-groups-browse D11: a group whose Boolean directory flag is off reads NOT_ALLOWED.
UPDATE "groups" SET "memberDirectoryAccess" = 'NOT_ALLOWED' WHERE "memberDirectoryEnabled" = false;
