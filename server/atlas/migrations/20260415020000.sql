-- Add fontSize column to activity_read_blocks.
-- T-shirt sizing key controlling the root em size on the ThemePlayer
-- container at render time. Values: xs | s | m | lg | xl. NULL means
-- use default (m = 1.4em). Clients map the key to an em value and set
-- it inline on the container so each theme's internal em-based type
-- scale (h1/h2/p) scales proportionally.

ALTER TABLE "activity_read_blocks"
  ADD COLUMN IF NOT EXISTS "fontSize" TEXT;
