-- Modify "members" table
ALTER TABLE "members" ADD COLUMN "address" text NULL, ADD COLUMN "emergencyContactName" text NULL, ADD COLUMN "emergencyContactPhone" text NULL;
-- Set comment to column: "address" on table: "members"
COMMENT ON COLUMN "members"."address" IS 'Postal address as entered; may span lines';
-- Set comment to column: "emergencyContactName" on table: "members"
COMMENT ON COLUMN "members"."emergencyContactName" IS 'Emergency contact''s name';
-- Set comment to column: "emergencyContactPhone" on table: "members"
COMMENT ON COLUMN "members"."emergencyContactPhone" IS 'Emergency contact''s phone, as entered';
