-- Modify "members" table
ALTER TABLE "members" ADD COLUMN "userId" uuid NULL, ADD COLUMN "userLinkedAt" timestamp NULL, ADD CONSTRAINT "members_userId_key" UNIQUE ("userId"), ADD CONSTRAINT "fk_members_linkedUser" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL;
-- Create index "idx_members_userId" to table: "members"
CREATE INDEX "idx_members_userId" ON "members" ("userId");
-- Set comment to column: "userId" on table: "members"
COMMENT ON COLUMN "members"."userId" IS 'Links Member to User account for bidirectional access';
-- Set comment to column: "userLinkedAt" on table: "members"
COMMENT ON COLUMN "members"."userLinkedAt" IS 'When account was linked to User';
