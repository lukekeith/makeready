-- Modify "lesson_activities" table
ALTER TABLE "lesson_activities" ADD COLUMN "referenceTitle" character varying NULL;
-- Set comment to column: "referenceTitle" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."referenceTitle" IS 'Display reference for READ activities, e.g., ''Romans 1:1-5''';
-- Modify "lesson_template_activities" table
ALTER TABLE "lesson_template_activities" ADD COLUMN "referenceTitle" character varying NULL;
-- Set comment to column: "referenceTitle" on table: "lesson_template_activities"
COMMENT ON COLUMN "lesson_template_activities"."referenceTitle" IS 'Display reference for READ activities, e.g., ''Romans 1:1-5''';
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "referenceTitle" character varying NULL;
-- Set comment to column: "referenceTitle" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."referenceTitle" IS 'Display reference for READ activities, e.g., ''Romans 1:1-5''';
