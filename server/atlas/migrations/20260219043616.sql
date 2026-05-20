-- Modify "activity_read_blocks" table
ALTER TABLE "activity_read_blocks" ADD COLUMN "title" character varying NULL;
-- Set comment to column: "title" on table: "activity_read_blocks"
COMMENT ON COLUMN "activity_read_blocks"."title" IS 'Block title, e.g., ''Romans 1:1-5'' for Bible verse blocks';
