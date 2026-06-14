-- Hybrid-search lexical infra for verses (hand-managed).
--
-- The `verses.searchVector` tsvector column exists (migration 20260129053731)
-- but was never populated or indexed in a committed migration — the GIN index
-- and data existed only ad-hoc in local dev. This migration makes the lexical
-- arm of hybrid search reproducible across environments. A *generated* column
-- would fight the Atlas-tracked plain-tsvector desired state, so we keep the
-- plain column and maintain it with a trigger. Everything here is idempotent.

-- 1. Backfill existing rows.
UPDATE "verses" SET "searchVector" = to_tsvector('english', "text") WHERE "searchVector" IS NULL;

-- 2. Keep it maintained on future writes (e.g. a Bible re-import).
CREATE OR REPLACE FUNCTION verses_search_vector_update() RETURNS trigger AS $$
BEGIN
  NEW."searchVector" := to_tsvector('english', NEW."text");
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS verses_search_vector_trg ON "verses";
CREATE TRIGGER verses_search_vector_trg
  BEFORE INSERT OR UPDATE OF "text" ON "verses"
  FOR EACH ROW EXECUTE FUNCTION verses_search_vector_update();

-- 3. GIN index for @@ full-text matching (hand-managed; Atlas drop_index skip
--    keeps it from being dropped on diff).
CREATE INDEX IF NOT EXISTS "verses_search_idx" ON "verses" USING gin ("searchVector");
