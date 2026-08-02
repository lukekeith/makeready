-- Create "analytics_refresh_state" table
CREATE TABLE "analytics_refresh_state" ("id" character varying NOT NULL, "lastRefreshedAt" timestamp NULL, "lastDurationMs" integer NULL, "lastError" text NULL, "consecutiveFailures" integer NOT NULL DEFAULT 0, "updatedAt" timestamp NOT NULL, PRIMARY KEY ("id"));
-- Set comment to column: "id" on table: "analytics_refresh_state"
COMMENT ON COLUMN "analytics_refresh_state"."id" IS 'Always ''singleton'' — one row of refresh freshness/telemetry';
-- Set comment to column: "lastRefreshedAt" on table: "analytics_refresh_state"
COMMENT ON COLUMN "analytics_refresh_state"."lastRefreshedAt" IS 'Completion instant of the last successful analytics_events refresh';
-- Set comment to column: "lastDurationMs" on table: "analytics_refresh_state"
COMMENT ON COLUMN "analytics_refresh_state"."lastDurationMs" IS 'Duration of the last successful refresh';
-- Set comment to column: "lastError" on table: "analytics_refresh_state"
COMMENT ON COLUMN "analytics_refresh_state"."lastError" IS 'Message of the most recent refresh failure; cleared on success';
-- Create "client_events" table
CREATE TABLE "client_events" ("id" character varying NOT NULL, "eventType" character varying NOT NULL, "occurredAt" timestamp NOT NULL, "receivedAt" timestamp NOT NULL DEFAULT now(), "memberId" character varying NULL, "userId" character varying NULL, "organizationId" character varying NULL, "groupId" character varying NULL, "enrollmentId" character varying NULL, "studyProgramId" character varying NULL, "lessonScheduleId" character varying NULL, "lessonId" character varying NULL, "dayNumber" integer NULL, "scheduledActivityId" character varying NULL, "activityType" character varying NULL, "scheduledDate" timestamp NULL, "value" double precision NOT NULL DEFAULT 1, "metadata" jsonb NULL, PRIMARY KEY ("id"));
-- Create index "idx_client_events_enrollmentId" to table: "client_events"
CREATE INDEX "idx_client_events_enrollmentId" ON "client_events" ("enrollmentId");
-- Create index "idx_client_events_eventType_occurredAt" to table: "client_events"
CREATE INDEX "idx_client_events_eventType_occurredAt" ON "client_events" ("eventType", "occurredAt");
-- Create index "idx_client_events_memberId" to table: "client_events"
CREATE INDEX "idx_client_events_memberId" ON "client_events" ("memberId");
-- Create index "idx_client_events_occurredAt" to table: "client_events"
CREATE INDEX "idx_client_events_occurredAt" ON "client_events" ("occurredAt");
-- Create index "idx_client_events_studyProgramId_occurredAt" to table: "client_events"
CREATE INDEX "idx_client_events_studyProgramId_occurredAt" ON "client_events" ("studyProgramId", "occurredAt");
-- Set comment to column: "id" on table: "client_events"
COMMENT ON COLUMN "client_events"."id" IS 'Client-generated UUID — natural idempotency key; retried batches insert-ignore on conflict';
-- Set comment to column: "eventType" on table: "client_events"
COMMENT ON COLUMN "client_events"."eventType" IS 'Must be a registered client-instrumented analytics event type (e.g. LESSON_OPENED); unknown types are rejected at ingest';
-- Set comment to column: "occurredAt" on table: "client_events"
COMMENT ON COLUMN "client_events"."occurredAt" IS 'Client clock (UTC), clamped at ingest into [receivedAt - 48h, receivedAt + 5min]';
-- Set comment to column: "receivedAt" on table: "client_events"
COMMENT ON COLUMN "client_events"."receivedAt" IS 'Server clock at ingest';
-- Set comment to column: "memberId" on table: "client_events"
COMMENT ON COLUMN "client_events"."memberId" IS 'Acting member — set from the session, never from the payload. Intentionally NO FK (append-only analytics table); the analytics_events ce: view arm joins members for existence, so member deletion still erases these events from analytics';
-- Set comment to column: "userId" on table: "client_events"
COMMENT ON COLUMN "client_events"."userId" IS 'Acting user (leader-side) — set from the session, never from the payload. Intentionally NO FK; see memberId';
-- Set comment to column: "organizationId" on table: "client_events"
COMMENT ON COLUMN "client_events"."organizationId" IS 'Enriched server-side from the enrollment''s group at ingest';
-- Set comment to column: "groupId" on table: "client_events"
COMMENT ON COLUMN "client_events"."groupId" IS 'Enriched server-side at ingest';
-- Set comment to column: "studyProgramId" on table: "client_events"
COMMENT ON COLUMN "client_events"."studyProgramId" IS 'Enriched server-side from the enrollment at ingest';
-- Set comment to column: "lessonId" on table: "client_events"
COMMENT ON COLUMN "client_events"."lessonId" IS 'Enriched server-side from the lesson schedule at ingest';
-- Set comment to column: "dayNumber" on table: "client_events"
COMMENT ON COLUMN "client_events"."dayNumber" IS 'Enriched server-side from the source curriculum lesson at ingest';
-- Set comment to column: "activityType" on table: "client_events"
COMMENT ON COLUMN "client_events"."activityType" IS 'Enriched server-side from the scheduled activity at ingest (USER_INPUT/READ/VIDEO/YOUTUBE/EXEGESIS)';
-- Set comment to column: "scheduledDate" on table: "client_events"
COMMENT ON COLUMN "client_events"."scheduledDate" IS 'Enriched server-side from the lesson schedule''s planned date at ingest';
-- Set comment to column: "metadata" on table: "client_events"
COMMENT ON COLUMN "client_events"."metadata" IS 'Event-specific attributes; anything queried regularly gets promoted to a real column (additive)';
