# Metrics Catalog

The initial registry contents for the flat analytics layer (see architecture.md). Every metric is an aggregate over `analytics_events`; every filter is a column. Names here are the API contract for `/api/analytics/query`.

## Event types

| event_type | Source | Meaning |
|---|---|---|
| `ACTIVITY_COMPLETED` | member_activity_progress.completedAt | Member finished a non-video activity (READ / EXEGESIS / USER_INPUT / YOUTUBE¹) |
| `VIDEO_COMPLETED` | member_video_progress.completedAt | Member watched ≥90% of a video activity |
| `VIDEO_WATCH` | member_video_progress (snapshot) | Cumulative watch: `value` = watchedSeconds, `percent` = watchPercentage |
| `LESSON_COMPLETED` | member_lesson_progress.completedAt | All activities of a lesson complete |
| `NOTE_CREATED` | study_notes via note_links | Member wrote a note against an enrollment |
| `ENROLLMENT_CREATED` | enrollments.createdAt | A group enrolled in a program |
| `MEMBER_JOINED` | membership_events (ADDED/APPROVED/REJOINED) | Member joined a group |
| `LESSON_OPENED` | client_events (web player, instrumented) | Member opened a lesson (island mount) |
| `ACTIVITY_STARTED` | client_events (web player, instrumented) | Member first displayed an activity step — with completions, forms the started→completed funnel |

¹ Verify at build time which table YouTube completion writes to (video progress vs activity progress) and slot it accordingly; the registry hides the answer from clients either way.

**Naming convention (locked):** event types are past-tense `OBJECT_ACTION` SCREAMING_SNAKE (`LESSON_COMPLETED`, `MEMBER_JOINED`) — the Segment/Amplitude object-action idiom. Renames are breaking changes to every downstream metric; new types must follow the convention. Each event type's row above is its **grain declaration** (one row = one what) — keep this table current; it is the tracking plan. Registry entries additionally carry `label`, `description`, `format` for the `/api/analytics/meta` catalog. Planned addition: `VIDEO_WATCH_PROGRESSED` flow events from the watch-delta ledger (architecture.md), which will supersede time-series use of the `VIDEO_WATCH` snapshots.

## Dimensions (filter + group-by axes)

`day` / `week` / `month` (query-time, timezone-aware, zero-filled) · `organization_id` · `group_id` · `study_program_id` · `enrollment_id` · `member_id` · `lesson_schedule_id` · `lesson_id` · `day_number` · `scheduled_activity_id` · `activity_type` · `event_type`

## Initial metrics

Every metric declares `class` (`flow` = instant events, time-windowable; `snapshot` = cumulative state, **rejects time windows**) and `versionSemantics` (`all` = full history incl. old versions/removed schedules; `current-only` = `is_current_version AND NOT is_removed`).

| Metric name | Definition (over analytics_events) | Class / versions | Notes |
|---|---|---|---|
| `engagement_events` | `COUNT(*)` over ACTIVITY_COMPLETED + VIDEO_COMPLETED + NOTE_CREATED | flow / all | "Total activity" — matches the Home dashboard's semantics; `all` so history survives program syncs |
| `completions` | `COUNT(*)` over ACTIVITY_COMPLETED + VIDEO_COMPLETED | flow / current-only | Content completions against the current curriculum |
| `lesson_completions` | `COUNT(*)` over LESSON_COMPLETED | flow / current-only | |
| `active_members` | `COUNT(DISTINCT entity_id)` over ACTIVITY_COMPLETED + VIDEO_COMPLETED + NOTE_CREATED | flow / all | "Members reached" when unbounded; "active members" when time-filtered. Per-entity metrics ALWAYS group on `entity_id`, never member_id/user_id |
| `completion_rate` | ratio: `lesson_completions` ÷ Σ_enrollment (active members_e × active schedules_e) | ratio / current-only | First-class registry ratio metric, server-computed, divide-by-zero-safe — moved out of "derived" so every surface shares one definition |
| `notes_written` | `COUNT(*)` over NOTE_CREATED | flow / all | NOTE_CREATED `value` = char length |
| `content_chars` | `SUM(value)` over NOTE_CREATED | flow / all | Writing depth (member-evaluation.md) |
| `active_days` | `COUNT(DISTINCT tz-local date)` over engagement events | flow / all | Consistency proxy; also the time-in-app stand-in |
| `on_time_rate` | ratio: on-time ÷ all LESSON_COMPLETED (`occurred_at ≤ scheduled_date + 1d`) | ratio / current-only | Needs `scheduled_date` column |
| `video_completions` | `COUNT(*)` over VIDEO_COMPLETED | flow / current-only | Owner-requested |
| `watch_seconds` | `SUM(value)` over VIDEO_WATCH | **snapshot** / all | Owner-requested. Lifetime watch time; format h/m client-side |
| `avg_watch_percent` | `AVG(percent)` over VIDEO_WATCH | **snapshot** / all | Watch depth |
| `enrollments_created` | `COUNT(*)` over ENROLLMENT_CREATED | flow / all | Growth line |
| `members_joined` | `COUNT(*)` over MEMBER_JOINED | flow / all | |

## Derived (client- or wrapper-computed, not registry entries)

| Value | Computation |
|---|---|
| Enrollment completion % | per-enrollment `lesson_completions ÷ (active members_e × active schedules_e)` — Top-enrollments ranking. (Program-level `completion_rate` is a registry ratio metric above; the denominator MUST be summed per enrollment — `distinct members × program lesson count` is wrong and must not be used) |
| Reflection rate (future) | substantive `AiLessonSummary.memberSummary` ÷ lesson_completions — needs a new view arm |

## Example queries the registry must satisfy (acceptance)

1. Program recent activity: `engagement_events` by `day`, filter `studyProgramId`, last 30 days, tz-aware, zero-filled.
2. Program heatmap: `engagement_events` by weekday×hour (the wrapper reuses the engagement heatmap SQL shape against the view), filter `studyProgramId`, last 30 days.
3. Lesson funnel: `COUNT(DISTINCT member_id)` over **LESSON_COMPLETED only** by `day_number`, filter `studyProgramId`, current-only — the chart caption is "Members completing each day", so partial activity must not inflate a bar.
4. Content mix: `completions` by `activity_type`, filter `studyProgramId`.
5. Top members: `completions` by `member_id`, filter `studyProgramId`, orderBy completions desc, limit 10.
6. Top enrollments: `lesson_completions` by `enrollment_id`, filter `studyProgramId`.
7. Org rollup (future consumer, zero new code): any of the above with `organizationId` instead of `studyProgramId`.
