-- ============================================================================
-- analytics_events — recreate with the ls: arm counting EXPECTED MEMBER-LESSONS
-- Feature home-dashboard-data, SPEC D10 (corrected 2026-10-25). Supersedes the
-- ls: arm of 20261025120000.sql (never edit a committed migration): that arm
-- emitted one row per enrollment × lesson schedule, so `scheduled_lessons`
-- counted 3/day while `lesson_completions` counted member completions (10–24/day),
-- and C-026 — which draws completed INSIDE scheduled — overflowed its plot.
--   ls: one row per lesson schedule × active member of the enrollment's group
--       (group_members.isActive, memberId NOT NULL), on the schedule's stored
--       scheduledDate (D14). member_id is that member; event_id is unique per
--       (schedule, group member).
-- HAND-WRITTEN for the same reason as 20261025120000.sql (the YAML toolchain does
-- not model materialized views); everything but the ls: arm is copied verbatim.
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS "analytics_events";

CREATE MATERIALIZED VIEW "analytics_events" AS

-- ── ACTIVITY_COMPLETED (ap:) — non-video activity completions ───────────────
SELECT
  'ap:' || map.id::text                                           AS event_id,
  'ACTIVITY_COMPLETED'                                            AS event_type,
  (map."completedAt" AT TIME ZONE 'UTC')                          AS occurred_at,
  map."memberId"::text                                            AS entity_id,
  map."memberId"::text                                            AS member_id,
  NULL::text                                                      AS user_id,
  g."organizationId"::text                                        AS organization_id,
  e."groupId"::text                                               AS group_id,
  ls."enrollmentId"::text                                         AS enrollment_id,
  e."studyProgramId"::text                                        AS study_program_id,
  map."lessonScheduleId"::text                                    AS lesson_schedule_id,
  ls."lessonId"::text                                             AS lesson_id,
  l."dayNumber"                                                   AS day_number,
  map."scheduledActivityId"::text                                 AS scheduled_activity_id,
  sa.type::text                                                   AS activity_type,
  ls."scheduledDate"::date                                        AS scheduled_date,
  1::numeric                                                      AS value,
  NULL::numeric                                                   AS percent,
  (sa."versionId" IS NULL OR sa."versionId" = ls."currentVersionId") AS is_current_version,
  (ls."removedAt" IS NOT NULL)                                    AS is_removed
FROM member_activity_progress map
JOIN lesson_schedules ls ON ls.id = map."lessonScheduleId"
JOIN enrollments e       ON e.id = ls."enrollmentId"
JOIN groups g            ON g.id = e."groupId"
LEFT JOIN lessons l      ON l.id = ls."lessonId"
LEFT JOIN scheduled_lesson_activities sa ON sa.id = map."scheduledActivityId"
WHERE map."completedAt" IS NOT NULL
  AND (sa.type IS NULL OR sa.type <> 'VIDEO')

UNION ALL

-- ── VIDEO_COMPLETED (vc:) — ≥90% watched ─────────────────────────────────────
SELECT
  'vc:' || mvp.id::text,
  'VIDEO_COMPLETED',
  (mvp."completedAt" AT TIME ZONE 'UTC'),
  mvp."memberId"::text,
  mvp."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  ls."enrollmentId"::text,
  e."studyProgramId"::text,
  mvp."lessonScheduleId"::text,
  ls."lessonId"::text,
  l."dayNumber",
  mvp."scheduledActivityId"::text,
  'VIDEO'::text,
  ls."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  (sa."versionId" IS NULL OR sa."versionId" = ls."currentVersionId"),
  (ls."removedAt" IS NOT NULL)
FROM member_video_progress mvp
JOIN lesson_schedules ls ON ls.id = mvp."lessonScheduleId"
JOIN enrollments e       ON e.id = ls."enrollmentId"
JOIN groups g            ON g.id = e."groupId"
LEFT JOIN lessons l      ON l.id = ls."lessonId"
LEFT JOIN scheduled_lesson_activities sa ON sa.id = mvp."scheduledActivityId"
WHERE mvp."completedAt" IS NOT NULL

UNION ALL

-- ── VIDEO_WATCH (vw:) — cumulative watch snapshot (SNAPSHOT class) ───────────
SELECT
  'vw:' || mvp.id::text,
  'VIDEO_WATCH',
  (mvp."lastWatchedAt" AT TIME ZONE 'UTC'),
  mvp."memberId"::text,
  mvp."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  ls."enrollmentId"::text,
  e."studyProgramId"::text,
  mvp."lessonScheduleId"::text,
  ls."lessonId"::text,
  l."dayNumber",
  mvp."scheduledActivityId"::text,
  'VIDEO'::text,
  ls."scheduledDate"::date,
  mvp."watchedSeconds"::numeric,
  mvp."watchPercentage"::numeric,
  (sa."versionId" IS NULL OR sa."versionId" = ls."currentVersionId"),
  (ls."removedAt" IS NOT NULL)
FROM member_video_progress mvp
JOIN lesson_schedules ls ON ls.id = mvp."lessonScheduleId"
JOIN enrollments e       ON e.id = ls."enrollmentId"
JOIN groups g            ON g.id = e."groupId"
LEFT JOIN lessons l      ON l.id = ls."lessonId"
LEFT JOIN scheduled_lesson_activities sa ON sa.id = mvp."scheduledActivityId"
WHERE mvp."watchedSeconds" > 0

UNION ALL

-- ── LESSON_COMPLETED (lc:) — all activities of a lesson complete ─────────────
SELECT
  'lc:' || mlp.id::text,
  'LESSON_COMPLETED',
  (mlp."completedAt" AT TIME ZONE 'UTC'),
  mlp."memberId"::text,
  mlp."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  ls."enrollmentId"::text,
  e."studyProgramId"::text,
  mlp."lessonScheduleId"::text,
  ls."lessonId"::text,
  l."dayNumber",
  NULL::text,
  NULL::text,
  ls."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  (mlp."pinnedVersionId" IS NULL OR mlp."pinnedVersionId" = ls."currentVersionId"),
  (ls."removedAt" IS NOT NULL)
FROM member_lesson_progress mlp
JOIN lesson_schedules ls ON ls.id = mlp."lessonScheduleId"
JOIN enrollments e       ON e.id = ls."enrollmentId"
JOIN groups g            ON g.id = e."groupId"
LEFT JOIN lessons l      ON l.id = ls."lessonId"
WHERE mlp."completedAt" IS NOT NULL

UNION ALL

-- ── NOTE_CREATED (nt:) — study notes linked to enrollments ───────────────────
-- value = LENGTH(content): COUNT = notes written, SUM = characters written.
SELECT
  'nt:' || nl.id::text,
  'NOTE_CREATED',
  (sn."createdAt" AT TIME ZONE 'UTC'),
  COALESCE(sn."memberId", sn."userId")::text,
  sn."memberId"::text,
  sn."userId"::text,
  g."organizationId"::text,
  e."groupId"::text,
  e.id::text,
  e."studyProgramId"::text,
  NULL::text,
  NULL::text,
  NULL::int,
  NULL::text,
  NULL::text,
  NULL::date,
  LENGTH(sn.content)::numeric,
  NULL::numeric,
  TRUE,
  FALSE
FROM study_notes sn
JOIN note_links nl ON nl."noteId" = sn.id AND nl."refType" = 'ENROLLMENT'
JOIN enrollments e ON e.id::text = nl."refId"
JOIN groups g      ON g.id = e."groupId"
WHERE sn."isActive" = true
  AND COALESCE(sn."memberId", sn."userId") IS NOT NULL

UNION ALL

-- ── ENROLLMENT_CREATED (en:) — a group enrolled in a program ─────────────────
SELECT
  'en:' || e.id::text,
  'ENROLLMENT_CREATED',
  (e."createdAt" AT TIME ZONE 'UTC'),
  e."createdById"::text,
  NULL::text,
  e."createdById"::text,
  g."organizationId"::text,
  e."groupId"::text,
  e.id::text,
  e."studyProgramId"::text,
  NULL::text,
  NULL::text,
  NULL::int,
  NULL::text,
  NULL::text,
  NULL::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  FALSE
FROM enrollments e
JOIN groups g ON g.id = e."groupId"
WHERE e."createdById" IS NOT NULL

UNION ALL

-- ── MEMBER_JOINED (mj:) — ADDED / APPROVED / REJOINED membership events ──────
SELECT
  'mj:' || me.id::text,
  'MEMBER_JOINED',
  (me."createdAt" AT TIME ZONE 'UTC'),
  me."memberId"::text,
  me."memberId"::text,
  NULL::text,
  COALESCE(me."organizationId"::text, g."organizationId"::text),
  me."groupId"::text,
  NULL::text,
  NULL::text,
  NULL::text,
  NULL::text,
  NULL::int,
  NULL::text,
  NULL::text,
  NULL::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  FALSE
FROM membership_events me
LEFT JOIN groups g ON g.id = me."groupId"
WHERE me.action IN ('ADDED', 'APPROVED', 'REJOINED')

UNION ALL

-- ── client_events (ce:) — instrumented engagement (LESSON_OPENED, …) ─────────
SELECT
  'ce:' || ce.id::text,
  ce."eventType",
  (ce."occurredAt" AT TIME ZONE 'UTC'),
  COALESCE(ce."memberId", ce."userId")::text,
  ce."memberId"::text,
  ce."userId"::text,
  ce."organizationId"::text,
  ce."groupId"::text,
  ce."enrollmentId"::text,
  ce."studyProgramId"::text,
  ce."lessonScheduleId"::text,
  ce."lessonId"::text,
  ce."dayNumber",
  ce."scheduledActivityId"::text,
  ce."activityType"::text,
  ce."scheduledDate"::date,
  ce.value::numeric,
  NULL::numeric,
  TRUE,
  FALSE
FROM client_events ce
LEFT JOIN members m ON m.id::text = ce."memberId"
LEFT JOIN users u   ON u.id::text = ce."userId"
WHERE COALESCE(ce."memberId", ce."userId") IS NOT NULL
  AND (ce."memberId" IS NULL OR m.id IS NOT NULL)
  AND (ce."userId" IS NULL OR u.id IS NOT NULL)

UNION ALL

-- ── LESSON_SCHEDULED (ls:) — an expected member-lesson on its scheduled date ──
SELECT
  'ls:' || ls.id::text || ':' || gm.id::text,
  'LESSON_SCHEDULED',
  (ls."scheduledDate" AT TIME ZONE 'UTC'),
  ls."enrollmentId"::text,
  gm."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  ls."enrollmentId"::text,
  e."studyProgramId"::text,
  ls.id::text,
  ls."lessonId"::text,
  l."dayNumber",
  NULL::text,
  NULL::text,
  ls."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  (ls."removedAt" IS NOT NULL)
FROM lesson_schedules ls
JOIN enrollments e    ON e.id = ls."enrollmentId"
JOIN groups g         ON g.id = e."groupId"
JOIN group_members gm ON gm."groupId" = e."groupId" AND gm."isActive" AND gm."memberId" IS NOT NULL
LEFT JOIN lessons l   ON l.id = ls."lessonId";

-- Unique natural key — REQUIRED by REFRESH MATERIALIZED VIEW CONCURRENTLY.
-- Every arm's event_id is prefix + a NOT NULL primary key, so it is provably
-- non-NULL (NULLs would defeat CONCURRENTLY's duplicate detection).
CREATE UNIQUE INDEX "analytics_events_event_id_key" ON "analytics_events" ("event_id");

-- One composite per primary filter axis, time-ordered.
CREATE INDEX "idx_analytics_events_program_time" ON "analytics_events" ("study_program_id", "occurred_at");
CREATE INDEX "idx_analytics_events_group_time"   ON "analytics_events" ("group_id", "occurred_at");
CREATE INDEX "idx_analytics_events_org_time"     ON "analytics_events" ("organization_id", "occurred_at");
CREATE INDEX "idx_analytics_events_enroll_time"  ON "analytics_events" ("enrollment_id", "occurred_at");
CREATE INDEX "idx_analytics_events_member_time"  ON "analytics_events" ("member_id", "occurred_at");
CREATE INDEX "idx_analytics_events_type_time"    ON "analytics_events" ("event_type", "occurred_at");
