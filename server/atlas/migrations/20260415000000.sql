-- Add backgroundImageUrl + backgroundColor columns to activity_read_blocks.
-- Feeds the per-read-block background picker (image OR solid hex color)
-- surfaced in the iPhone theme editor.

ALTER TABLE "activity_read_blocks"
  ADD COLUMN IF NOT EXISTS "backgroundImageUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "backgroundColor"    TEXT;
