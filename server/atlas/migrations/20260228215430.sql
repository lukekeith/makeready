-- Create "notifications" table
CREATE TABLE "notifications" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "userId" uuid NOT NULL,
  "type" character varying NOT NULL,
  "title" character varying NOT NULL,
  "body" character varying NOT NULL,
  "isRead" boolean NOT NULL DEFAULT false,
  "data" jsonb NULL,
  "createdAt" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"),
  CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE CASCADE ON DELETE CASCADE
);
-- Create index "notifications_userId_isRead_idx" to table: "notifications"
CREATE INDEX "notifications_userId_isRead_idx" ON "notifications" ("userId", "isRead");
-- Create index "notifications_userId_createdAt_idx" to table: "notifications"
CREATE INDEX "notifications_userId_createdAt_idx" ON "notifications" ("userId", "createdAt");
