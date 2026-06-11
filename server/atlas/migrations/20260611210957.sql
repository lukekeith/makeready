-- Create index "idx_media_organizationId_createdAt_id" to table: "media"
CREATE INDEX "idx_media_organizationId_createdAt_id" ON "media" ("organizationId", "createdAt", "id");
