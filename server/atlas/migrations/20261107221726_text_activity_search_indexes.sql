-- text-activity SC12: hand-managed lesson search indexes on the version model. atlas.hcl's drop_index skip keeps them out of migrate diff.
-- Lesson text moved from `lessons.title`, `lesson_activities` and `activity_read_blocks` to `lesson_versions.title` and
-- `content_activities.document`. Each expression equals its constant in server/src/services/master-search-text.ts
-- (SEARCH_TEXT.lesson, LESSON_SEARCH_TEXT_SQL).
-- Dropped (they index old tables that still exist until the cutover drop, and would only go stale):
--   lessons_search_idx, lessons_title_lower_idx, lesson_activities_search_idx, activity_read_blocks_search_idx
DROP INDEX IF EXISTS "lessons_search_idx";
DROP INDEX IF EXISTS "lessons_title_lower_idx";
DROP INDEX IF EXISTS "lesson_activities_search_idx";
DROP INDEX IF EXISTS "activity_read_blocks_search_idx";
CREATE INDEX IF NOT EXISTS "lesson_versions_search_idx" ON "lesson_versions" USING gin (to_tsvector('english', coalesce("title",'')));
CREATE INDEX IF NOT EXISTS "content_activities_search_idx" ON "content_activities" USING gin (to_tsvector('english', jsonb_path_query_array("document", '$.content.objects[*].text') || jsonb_path_query_array("document", '$.content.prompt.text')));
