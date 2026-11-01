-- Modify "organizations" table
ALTER TABLE "organizations" ADD COLUMN "isMakeReady" boolean NOT NULL DEFAULT false;
-- Create index "idx_organizations_isMakeReady" to table: "organizations"
CREATE INDEX "idx_organizations_isMakeReady" ON "organizations" ("isMakeReady");
-- Set comment to column: "isMakeReady" on table: "organizations"
COMMENT ON COLUMN "organizations"."isMakeReady" IS 'media-library D6: the one org that owns MakeReady''s own media library';
