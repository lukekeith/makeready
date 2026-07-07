-- Modify "lesson_schedules" table
ALTER TABLE "lesson_schedules" ADD COLUMN "removedAt" timestamp NULL;
-- Set comment to column: "removedAt" on table: "lesson_schedules"
COMMENT ON COLUMN "lesson_schedules"."removedAt" IS 'Set when sync removes this lesson from the curriculum but member progress exists (soft-hide: kept for history, excluded from upcoming lists). Schedules with no progress are hard-deleted instead.';
