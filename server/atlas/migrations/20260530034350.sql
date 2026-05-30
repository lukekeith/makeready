-- Create "preview_state" table
CREATE TABLE "preview_state" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "previewTokenId" uuid NOT NULL,
  "entityType" character varying NOT NULL,
  "activityId" character varying NOT NULL,
  "data" jsonb NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_preview_state_previewToken" FOREIGN KEY ("previewTokenId") REFERENCES "preview_tokens" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_preview_state_previewTokenId_entityType_activityId" to table: "preview_state"
CREATE UNIQUE INDEX "idx_preview_state_previewTokenId_entityType_activityId" ON "preview_state" ("previewTokenId", "entityType", "activityId");
-- Set comment to column: "previewTokenId" on table: "preview_state"
COMMENT ON COLUMN "preview_state"."previewTokenId" IS 'FK to PreviewToken — cascade-deletes when token is replaced';
-- Set comment to column: "entityType" on table: "preview_state"
COMMENT ON COLUMN "preview_state"."entityType" IS 'note | video_progress | exegesis_visit';
-- Set comment to column: "activityId" on table: "preview_state"
COMMENT ON COLUMN "preview_state"."activityId" IS 'The lesson activity this state is for';
-- Set comment to column: "data" on table: "preview_state"
COMMENT ON COLUMN "preview_state"."data" IS 'Saved state (note content, video seconds, visited highlight IDs)';
