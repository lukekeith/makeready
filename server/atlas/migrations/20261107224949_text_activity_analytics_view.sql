-- ============================================================================
-- analytics_events — recreate on the text-activity model (SPEC SC12, D8, D42).
-- Supersedes 20261025200000.sql (never edit a committed migration). HAND-WRITTEN
-- for the same reason: the YAML toolchain does not model materialized views.
-- Output columns, their order and types are IDENTICAL to 20261025200000.sql;
-- the lesson_schedule_id / scheduled_activity_id / activity_type columns now hold
-- the ScheduledLesson id, the activityKey and the activity kind.
--   ap/vc/vw  activity_progress (kind from the scheduled lesson's current-version
--             content_activities row, matched by activityKey). A 'video' activity
--             is vc (completed) and vw (state.watchedSeconds > 0), never ap.
--   lc        lesson_progress
--   ls        scheduled_lessons x active group member
--   ce        client_events on scheduledLessonId / activityKey / kind
--   nt/en/mj  unchanged (the nt arm only ever read ENROLLMENT links; D42's removed
--             ref types never reached the view)
-- Progress tables are empty until a member rebuild writes them (D8); the view
-- then simply has no ap/vc/vw/lc rows.
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS "analytics_events";

CREATE MATERIALIZED VIEW "analytics_events" AS

-- ── ACTIVITY_COMPLETED (ap:) — non-video activity completions ───────────────
SELECT
  'ap:' || ap."memberId"::text || ':' || ap."scheduledLessonId"::text || ':' || ap."activityKey" AS event_id,
  'ACTIVITY_COMPLETED'                                            AS event_type,
  (ap."completedAt" AT TIME ZONE 'UTC')                           AS occurred_at,
  ap."memberId"::text                                             AS entity_id,
  ap."memberId"::text                                             AS member_id,
  NULL::text                                                      AS user_id,
  g."organizationId"::text                                        AS organization_id,
  e."groupId"::text                                               AS group_id,
  sl."enrollmentId"::text                                         AS enrollment_id,
  e."studyProgramId"::text                                        AS study_program_id,
  ap."scheduledLessonId"::text                                    AS lesson_schedule_id,
  sl."lessonId"::text                                             AS lesson_id,
  l."position"                                                    AS day_number,
  ap."activityKey"::text                                          AS scheduled_activity_id,
  ca.kind::text                                                   AS activity_type,
  sl."scheduledDate"::date                                        AS scheduled_date,
  1::numeric                                                      AS value,
  NULL::numeric                                                   AS percent,
  (ca.id IS NOT NULL)                                             AS is_current_version,
  (sl."removedAt" IS NOT NULL)                                    AS is_removed
FROM activity_progress ap
JOIN scheduled_lessons sl ON sl.id = ap."scheduledLessonId"
JOIN enrollments e        ON e.id = sl."enrollmentId"
JOIN groups g             ON g.id = e."groupId"
LEFT JOIN lessons l       ON l.id = sl."lessonId"
LEFT JOIN content_activities ca ON ca."lessonVersionId" = sl."currentVersionId" AND ca."activityKey" = ap."activityKey"
WHERE ap."completedAt" IS NOT NULL
  AND (ca.kind IS NULL OR ca.kind <> 'video')

UNION ALL

-- ── VIDEO_COMPLETED (vc:) — a video activity completed ───────────────────────
SELECT
  'vc:' || ap."memberId"::text || ':' || ap."scheduledLessonId"::text || ':' || ap."activityKey",
  'VIDEO_COMPLETED',
  (ap."completedAt" AT TIME ZONE 'UTC'),
  ap."memberId"::text,
  ap."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  sl."enrollmentId"::text,
  e."studyProgramId"::text,
  ap."scheduledLessonId"::text,
  sl."lessonId"::text,
  l."position",
  ap."activityKey"::text,
  'video'::text,
  sl."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  (sl."removedAt" IS NOT NULL)
FROM activity_progress ap
JOIN scheduled_lessons sl ON sl.id = ap."scheduledLessonId"
JOIN enrollments e        ON e.id = sl."enrollmentId"
JOIN groups g             ON g.id = e."groupId"
LEFT JOIN lessons l       ON l.id = sl."lessonId"
JOIN content_activities ca ON ca."lessonVersionId" = sl."currentVersionId" AND ca."activityKey" = ap."activityKey" AND ca.kind = 'video'
WHERE ap."completedAt" IS NOT NULL

UNION ALL

-- ── VIDEO_WATCH (vw:) — cumulative watch snapshot (SNAPSHOT class) ───────────
-- value = state.watchedSeconds, percent = state.watchPercentage (0-100), both only when numeric.
SELECT
  'vw:' || ap."memberId"::text || ':' || ap."scheduledLessonId"::text || ':' || ap."activityKey",
  'VIDEO_WATCH',
  (COALESCE(ap."completedAt", ap."startedAt") AT TIME ZONE 'UTC'),
  ap."memberId"::text,
  ap."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  sl."enrollmentId"::text,
  e."studyProgramId"::text,
  ap."scheduledLessonId"::text,
  sl."lessonId"::text,
  l."position",
  ap."activityKey"::text,
  'video'::text,
  sl."scheduledDate"::date,
  (ap.state->>'watchedSeconds')::numeric,
  CASE WHEN jsonb_typeof(ap.state->'watchPercentage') = 'number' THEN (ap.state->>'watchPercentage')::numeric END,
  TRUE,
  (sl."removedAt" IS NOT NULL)
FROM activity_progress ap
JOIN scheduled_lessons sl ON sl.id = ap."scheduledLessonId"
JOIN enrollments e        ON e.id = sl."enrollmentId"
JOIN groups g             ON g.id = e."groupId"
LEFT JOIN lessons l       ON l.id = sl."lessonId"
JOIN content_activities ca ON ca."lessonVersionId" = sl."currentVersionId" AND ca."activityKey" = ap."activityKey" AND ca.kind = 'video'
WHERE CASE WHEN jsonb_typeof(ap.state->'watchedSeconds') = 'number' THEN (ap.state->>'watchedSeconds')::numeric > 0 ELSE FALSE END

UNION ALL

-- ── LESSON_COMPLETED (lc:) — all activities of a lesson complete ─────────────
SELECT
  'lc:' || lp."memberId"::text || ':' || lp."scheduledLessonId"::text,
  'LESSON_COMPLETED',
  (lp."completedAt" AT TIME ZONE 'UTC'),
  lp."memberId"::text,
  lp."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  sl."enrollmentId"::text,
  e."studyProgramId"::text,
  lp."scheduledLessonId"::text,
  sl."lessonId"::text,
  l."position",
  NULL::text,
  NULL::text,
  sl."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  (lp."pinnedVersionId" IS NULL OR lp."pinnedVersionId" = sl."currentVersionId"),
  (sl."removedAt" IS NOT NULL)
FROM lesson_progress lp
JOIN scheduled_lessons sl ON sl.id = lp."scheduledLessonId"
JOIN enrollments e        ON e.id = sl."enrollmentId"
JOIN groups g             ON g.id = e."groupId"
LEFT JOIN lessons l       ON l.id = sl."lessonId"
WHERE lp."completedAt" IS NOT NULL

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
  ce."scheduledLessonId"::text,
  ce."lessonId"::text,
  ce."dayNumber",
  ce."activityKey"::text,
  ce."kind"::text,
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
  'ls:' || sl.id::text || ':' || gm.id::text,
  'LESSON_SCHEDULED',
  (sl."scheduledDate" AT TIME ZONE 'UTC'),
  sl."enrollmentId"::text,
  gm."memberId"::text,
  NULL::text,
  g."organizationId"::text,
  e."groupId"::text,
  sl."enrollmentId"::text,
  e."studyProgramId"::text,
  sl.id::text,
  sl."lessonId"::text,
  l."position",
  NULL::text,
  NULL::text,
  sl."scheduledDate"::date,
  1::numeric,
  NULL::numeric,
  TRUE,
  (sl."removedAt" IS NOT NULL)
FROM scheduled_lessons sl
JOIN enrollments e    ON e.id = sl."enrollmentId"
JOIN groups g         ON g.id = e."groupId"
JOIN group_members gm ON gm."groupId" = e."groupId" AND gm."isActive" AND gm."memberId" IS NOT NULL
LEFT JOIN lessons l   ON l.id = sl."lessonId";

-- Unique natural key — REQUIRED by REFRESH MATERIALIZED VIEW CONCURRENTLY.
-- Every arm's event_id is prefix + NOT NULL key columns, so it is provably non-NULL.
CREATE UNIQUE INDEX "analytics_events_event_id_key" ON "analytics_events" ("event_id");

-- One composite per primary filter axis, time-ordered.
CREATE INDEX "idx_analytics_events_program_time" ON "analytics_events" ("study_program_id", "occurred_at");
CREATE INDEX "idx_analytics_events_group_time"   ON "analytics_events" ("group_id", "occurred_at");
CREATE INDEX "idx_analytics_events_org_time"     ON "analytics_events" ("organization_id", "occurred_at");
CREATE INDEX "idx_analytics_events_enroll_time"  ON "analytics_events" ("enrollment_id", "occurred_at");
CREATE INDEX "idx_analytics_events_member_time"  ON "analytics_events" ("member_id", "occurred_at");
CREATE INDEX "idx_analytics_events_type_time"    ON "analytics_events" ("event_type", "occurred_at");
