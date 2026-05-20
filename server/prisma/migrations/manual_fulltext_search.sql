-- Manual migration: Add full-text search to verses table
-- Run this SQL against your Supabase database when you have direct access

-- Add computed tsvector column for full-text search
ALTER TABLE verses
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (to_tsvector('english', text)) STORED;

-- Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS verses_search_idx
ON verses USING GIN (search_vector);

-- Verify the index
\d verses;
