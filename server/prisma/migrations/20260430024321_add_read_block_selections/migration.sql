-- Add styled-selection metadata to read blocks.
-- Each entry: { "start": int, "end": int, "style": string } over the stripped plain-text content.
ALTER TABLE "activity_read_blocks" ADD COLUMN "selections" JSONB;
