-- Modify "text_themes" table
ALTER TABLE "text_themes" ADD COLUMN "fontScale" double precision NULL, ADD COLUMN "maxCharacters" integer NULL;
-- Set comment to column: "fontScale" on table: "text_themes"
COMMENT ON COLUMN "text_themes"."fontScale" IS 'Font size as a fraction of container width (e.g. 0.06 = 6cqw). Drives width-scaled type so a block wraps identically on every screen.';
-- Set comment to column: "maxCharacters" on table: "text_themes"
COMMENT ON COLUMN "text_themes"."maxCharacters" IS 'Max content characters a read block may contain to use this theme. Editors mute the theme when block.content length exceeds this. Null = unlimited.';
