-- Add value to enum type: "TemplateActivityType"
ALTER TYPE "TemplateActivityType" ADD VALUE 'YOUTUBE';
-- Modify "lesson_activities" table
ALTER TABLE "lesson_activities" ADD COLUMN "youtubeUrl" character varying NULL, ADD COLUMN "youtubeVideoId" character varying NULL, ADD COLUMN "youtubeStartSeconds" integer NULL, ADD COLUMN "youtubeEndSeconds" integer NULL, ADD COLUMN "youtubeThumbnailUrl" character varying NULL;
-- Set comment to column: "youtubeUrl" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."youtubeUrl" IS 'YouTube video URL for YOUTUBE activities';
-- Set comment to column: "youtubeVideoId" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."youtubeVideoId" IS 'Extracted YouTube video ID';
-- Set comment to column: "youtubeStartSeconds" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."youtubeStartSeconds" IS 'Start time in seconds for YouTube clip';
-- Set comment to column: "youtubeEndSeconds" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."youtubeEndSeconds" IS 'End time in seconds for YouTube clip';
-- Set comment to column: "youtubeThumbnailUrl" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."youtubeThumbnailUrl" IS 'YouTube video thumbnail URL from oEmbed';
-- Modify "scheduled_lesson_activities" table
ALTER TABLE "scheduled_lesson_activities" ADD COLUMN "youtubeUrl" character varying NULL, ADD COLUMN "youtubeVideoId" character varying NULL, ADD COLUMN "youtubeStartSeconds" integer NULL, ADD COLUMN "youtubeEndSeconds" integer NULL, ADD COLUMN "youtubeThumbnailUrl" character varying NULL;
-- Set comment to column: "youtubeUrl" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."youtubeUrl" IS 'YouTube video URL for YOUTUBE activities';
-- Set comment to column: "youtubeVideoId" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."youtubeVideoId" IS 'Extracted YouTube video ID';
-- Set comment to column: "youtubeStartSeconds" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."youtubeStartSeconds" IS 'Start time in seconds for YouTube clip';
-- Set comment to column: "youtubeEndSeconds" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."youtubeEndSeconds" IS 'End time in seconds for YouTube clip';
-- Set comment to column: "youtubeThumbnailUrl" on table: "scheduled_lesson_activities"
COMMENT ON COLUMN "scheduled_lesson_activities"."youtubeThumbnailUrl" IS 'YouTube video thumbnail URL from oEmbed';
