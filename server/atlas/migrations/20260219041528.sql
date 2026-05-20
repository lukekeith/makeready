-- Create "activity_read_blocks" table
CREATE TABLE "activity_read_blocks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "lessonActivityId" uuid NULL,
  "scheduledActivityId" uuid NULL,
  "orderNumber" integer NOT NULL DEFAULT 1,
  "content" text NULL,
  "isLocked" boolean NOT NULL DEFAULT false,
  "sourceReferenceId" uuid NULL,
  "createdAt" timestamp NOT NULL DEFAULT now(),
  "updatedAt" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "fk_activity_read_blocks_lessonActivity" FOREIGN KEY ("lessonActivityId") REFERENCES "lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_activity_read_blocks_scheduledActivity" FOREIGN KEY ("scheduledActivityId") REFERENCES "scheduled_lesson_activities" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "fk_activity_read_blocks_sourceReference" FOREIGN KEY ("sourceReferenceId") REFERENCES "activity_source_references" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_activity_read_blocks_lessonActivityId" to table: "activity_read_blocks"
CREATE INDEX "idx_activity_read_blocks_lessonActivityId" ON "activity_read_blocks" ("lessonActivityId");
-- Create index "idx_activity_read_blocks_scheduledActivityId" to table: "activity_read_blocks"
CREATE INDEX "idx_activity_read_blocks_scheduledActivityId" ON "activity_read_blocks" ("scheduledActivityId");
-- Set comment to column: "lessonActivityId" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."lessonActivityId" IS 'For program lesson activities';
-- Set comment to column: "scheduledActivityId" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."scheduledActivityId" IS 'For enrolled lesson activities';
-- Set comment to column: "orderNumber" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."orderNumber" IS 'Sort order within the activity';
-- Set comment to column: "content" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."content" IS 'Text/markdown content of this block';
-- Set comment to column: "isLocked" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."isLocked" IS 'Locked blocks cannot be edited (e.g., Bible verses)';
-- Set comment to column: "sourceReferenceId" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."sourceReferenceId" IS 'Links to ActivitySourceReference for Bible verse blocks';
