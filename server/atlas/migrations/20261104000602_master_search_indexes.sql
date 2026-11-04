-- master-search D23/D40: hand-managed search indexes. Atlas's drop_index skip (atlas/atlas.hcl) keeps them from migrate diff.
-- Each expression equals its constant in server/src/services/master-search-text.ts.
CREATE INDEX IF NOT EXISTS "groups_search_idx" ON "groups" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'') || ' ' || coalesce("code",'')));
CREATE INDEX IF NOT EXISTS "study_programs_search_idx" ON "study_programs" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'')));
CREATE INDEX IF NOT EXISTS "lesson_templates_search_idx" ON "lesson_templates" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'')));
CREATE INDEX IF NOT EXISTS "lessons_search_idx" ON "lessons" USING gin (to_tsvector('english', coalesce("title",'')));
CREATE INDEX IF NOT EXISTS "lesson_activities_search_idx" ON "lesson_activities" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("readContent",'') || ' ' || coalesce("helpTitle",'') || ' ' || coalesce("helpDescription",'')));
CREATE INDEX IF NOT EXISTS "activity_read_blocks_search_idx" ON "activity_read_blocks" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("content",''))) WHERE "lessonActivityId" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "events_search_idx" ON "events" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("description",'') || ' ' || coalesce("locationName",'')));
CREATE INDEX IF NOT EXISTS "posts_search_idx" ON "posts" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("content",'')));
CREATE INDEX IF NOT EXISTS "members_search_idx" ON "members" USING gin (to_tsvector('simple', coalesce("firstName",'') || ' ' || coalesce("lastName",'') || ' ' || coalesce("email",'') || ' ' || coalesce("phoneNumber",'')));
CREATE INDEX IF NOT EXISTS "media_search_idx" ON "media" USING gin (to_tsvector('english', coalesce("title",'')));
CREATE INDEX IF NOT EXISTS "media_tags_search_idx" ON "media_tags" USING gin (to_tsvector('english', "tag"));
CREATE INDEX IF NOT EXISTS "groups_title_lower_idx" ON "groups" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "study_programs_title_lower_idx" ON "study_programs" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "lesson_templates_title_lower_idx" ON "lesson_templates" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "lessons_title_lower_idx" ON "lessons" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "events_title_lower_idx" ON "events" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "posts_title_lower_idx" ON "posts" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "members_title_lower_idx" ON "members" (lower(btrim(coalesce("firstName",'') || ' ' || coalesce("lastName",''))) text_pattern_ops);
CREATE INDEX IF NOT EXISTS "media_title_lower_idx" ON "media" (lower("title") text_pattern_ops);
