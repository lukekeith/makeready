-- Add value to enum type: "TemplateActivityType"
ALTER TYPE "TemplateActivityType" ADD VALUE 'EXEGESIS';
-- Modify "member_activity_progress" table
ALTER TABLE "member_activity_progress" ADD COLUMN "exegesisVisitedHighlightIds" jsonb NULL;
-- Set comment to column: "exegesisVisitedHighlightIds" on table: "member_activity_progress"
COMMENT ON COLUMN "member_activity_progress"."exegesisVisitedHighlightIds" IS 'JSON array of visited ExegesisHighlight IDs for EXEGESIS activities';
-- Create "exegesis_highlights" table
CREATE TABLE "exegesis_highlights" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "readBlockId" uuid NOT NULL,
  "orderNumber" integer NOT NULL,
  "start" integer NOT NULL,
  "end" integer NOT NULL,
  "noteMarkdown" text NOT NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "exegesis_highlights_readBlockId_orderNumber_key" UNIQUE ("readBlockId", "orderNumber"),
  CONSTRAINT "exegesis_highlights_readBlockId_start_end_key" UNIQUE ("readBlockId", "start", "end"),
  CONSTRAINT "fk_exegesis_highlights_readBlock" FOREIGN KEY ("readBlockId") REFERENCES "activity_read_blocks" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_exegesis_highlights_readBlockId" to table: "exegesis_highlights"
CREATE INDEX "idx_exegesis_highlights_readBlockId" ON "exegesis_highlights" ("readBlockId");
-- Create index "idx_exegesis_highlights_readBlockId_orderNumber" to table: "exegesis_highlights"
CREATE INDEX "idx_exegesis_highlights_readBlockId_orderNumber" ON "exegesis_highlights" ("readBlockId", "orderNumber");
-- Set comment to column: "readBlockId" on table: "exegesis_highlights"
COMMENT ON COLUMN "exegesis_highlights"."readBlockId" IS 'FK to ActivityReadBlock (locked scripture block) that this highlight applies to';
-- Set comment to column: "orderNumber" on table: "exegesis_highlights"
COMMENT ON COLUMN "exegesis_highlights"."orderNumber" IS 'Stable ordering for highlight navigation';
-- Set comment to column: "start" on table: "exegesis_highlights"
COMMENT ON COLUMN "exegesis_highlights"."start" IS 'Start character offset (plain-text) into the block content';
-- Set comment to column: "end" on table: "exegesis_highlights"
COMMENT ON COLUMN "exegesis_highlights"."end" IS 'End character offset (exclusive)';
-- Set comment to column: "noteMarkdown" on table: "exegesis_highlights"
COMMENT ON COLUMN "exegesis_highlights"."noteMarkdown" IS 'Leader-authored markdown shown to members when they open the highlight';
