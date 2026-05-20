-- Data migration: Convert existing readContent into activity_read_blocks
-- Run this ONCE after the schema migration is applied
-- Safe to run multiple times (uses NOT EXISTS guard)

-- 1. Migrate lesson_activities.readContent -> activity_read_blocks
INSERT INTO activity_read_blocks (id, "lessonActivityId", "orderNumber", title, content, "isLocked", "createdAt", "updatedAt")
SELECT gen_random_uuid(), id, 1, NULL, "readContent", false, NOW(), NOW()
FROM lesson_activities
WHERE "readContent" IS NOT NULL AND "readContent" != ''
  AND NOT EXISTS (
    SELECT 1 FROM activity_read_blocks arb WHERE arb."lessonActivityId" = lesson_activities.id
  );

-- 2. Migrate scheduled_lesson_activities.readContent -> activity_read_blocks
INSERT INTO activity_read_blocks (id, "scheduledActivityId", "orderNumber", title, content, "isLocked", "createdAt", "updatedAt")
SELECT gen_random_uuid(), id, 1, NULL, "readContent", false, NOW(), NOW()
FROM scheduled_lesson_activities
WHERE "readContent" IS NOT NULL AND "readContent" != ''
  AND NOT EXISTS (
    SELECT 1 FROM activity_read_blocks arb WHERE arb."scheduledActivityId" = scheduled_lesson_activities.id
  );

-- Verify counts
SELECT 'lesson_activity read blocks' as type, count(*) FROM activity_read_blocks WHERE "lessonActivityId" IS NOT NULL
UNION ALL
SELECT 'scheduled_activity read blocks' as type, count(*) FROM activity_read_blocks WHERE "scheduledActivityId" IS NOT NULL;
