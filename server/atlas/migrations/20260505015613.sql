-- Modify "activity_read_blocks" table
ALTER TABLE "activity_read_blocks" ALTER COLUMN "contentFormat" SET DEFAULT 'markdown', ALTER COLUMN "backgroundImageUrl" TYPE character varying, ALTER COLUMN "backgroundColor" TYPE character varying, ALTER COLUMN "fontSize" TYPE character varying;
-- Set comment to column: "backgroundColor" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."backgroundColor" IS 'Hex color for block background';
-- Set comment to column: "backgroundOverlayOpacity" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."backgroundOverlayOpacity" IS '0-1 opacity for background overlay';
-- Set comment to column: "fontSize" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."fontSize" IS 'Font size: xs, s, m, lg, xl';
-- Set comment to column: "selections" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."selections" IS 'Array of styled text spans with start, end, style';
-- Set comment to column: "themeId" on table: "lesson_activities"
COMMENT ON COLUMN "lesson_activities"."themeId" IS 'Optional theme for animated rendering';
-- Set comment to column: "definition" on table: "text_themes"
COMMENT ON COLUMN "text_themes"."definition" IS 'Theme definition (colors, animations, styles)';
