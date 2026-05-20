-- Modify "lesson_template_activities" table
ALTER TABLE "lesson_template_activities" ADD COLUMN "displayName" character varying NULL;
-- Set comment to column: "displayName" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."displayName" IS 'Human-readable name for the activity type, e.g., ''Read'', ''Study'', ''Video''';
