-- Add backgroundOverlayOpacity column to activity_read_blocks.
-- When both backgroundImageUrl and backgroundColor are set, the color is
-- rendered as a translucent overlay on top of the image at this opacity
-- (0–1). NULL means "use default" (0.8). Only meaningful when both
-- backgroundImageUrl and backgroundColor are present.

ALTER TABLE "activity_read_blocks"
  ADD COLUMN IF NOT EXISTS "backgroundOverlayOpacity" DOUBLE PRECISION;
