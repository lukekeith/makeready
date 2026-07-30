# Member Evaluation — multi-axis engagement model

Owner direction (2026-07-29): evaluate members multiple ways, not one ranked list — total activity, content written, lessons completed, video watch time, consistency, time in app, plus other ideas. This doc defines each axis against the flat layer, what layer changes they need, and how they surface. It resolves the README checklist item 2: **ranked presentation is accepted**; the richer answer is that ranking happens per-axis, so no single number labels a member.

## The axes

| Axis | Metric(s) | Data reality | Feasibility |
|---|---|---|---|
| **1. Total activity** | `engagement_events` grouped by `entity_id` | Already specced | ✅ ready |
| **2. Content written** | `notes_written` = COUNT over NOTE_CREATED; `content_chars` = SUM(value) over NOTE_CREATED | Member writing (SOAP input + notes) is stored as `study_notes` rows (`content @db.Text`) via the activity submit endpoint — so NOTE_CREATED events set **`value` = LENGTH(content)** and both count and depth come from the same rows. Verify at build which note `type`s are member writing vs system rows | ✅ layer tweak |
| **3. Lessons completed** | `lesson_completions` by `entity_id` | Already specced | ✅ ready |
| **4. Video watch time** | `watch_seconds` by `entity_id` (lifetime, snapshot); time-windowed once the watch-delta ledger ships | Already specced; prod currently has zero video-progress rows, so this axis lights up as video content is used | ✅ ready |
| **5. Consistency** | see below — `active_days`, `weekly_consistency`, `on_time_rate`, streaks | Needs one new view column: **`scheduled_date`** (from lesson_schedule) so punctuality is computable flat | ✅ layer tweak |
| **6. Time in app** | — | **Not trackable today.** No session/heartbeat instrumentation exists anywhere (activity_logs is web auth/route ingest only). Requires new client instrumentation (APP_SESSION events from iPhone + web member player), with privacy/consent review — surveillance-adjacent in a discipleship product | ⏳ deferred; use `active_days` as the proxy |

### Consistency, concretely (axis 5)
Four registry metrics, all flat once `scheduled_date` is a column:
- `active_days` — COUNT(DISTINCT event date) per entity. The simplest, most robust consistency signal and the recommended proxy for time-in-app.
- `weekly_consistency` — distinct active weeks ÷ weeks since the member's first event (or enrollment start), 0–1. Answers "do they show up steadily or in bursts".
- `on_time_rate` — LESSON_COMPLETED where `occurred_at ≤ scheduled_date + 1 day grace` ÷ all LESSON_COMPLETED. Punctuality against the group's schedule, across every group they're in.
- `current_streak` / `longest_streak` — consecutive scheduled lessons completed. Window-function SQL, exposed as computed registry metrics (registry gains a `computed` type whose SQL is a full statement, not a plain aggregate — the one registry extension this doc requires).

## Additional ideas (adopted / offered)

| Idea | Metric | Cost |
|---|---|---|
| **Breadth** — engages across formats, not just one | COUNT(DISTINCT activity_type) over completions | free |
| **Reflection depth** — avg chars per written note | `content_chars ÷ notes_written` (registry ratio) | free |
| **Recency** — last active | MAX(occurred_at) per entity | free |
| **Personal completion rate** — their completions ÷ what they were assigned | per-member variant of the enrollment denominator | wrapper-level |
| **Group participation** — feed posts authored | POST_CREATED view arm from `posts` (authorId nullable — verify member attribution at build) | one view arm |
| Responsiveness to SMS prompts | — | skip: no reliable response tracking |

## Presentation principle

Per-axis rankings are honest; a single composite "engagement score" is opaque and, in a discipleship context, easy to read as a spiritual scoreboard — **no composite score in v1**. Surfaces:
- **Program Analytics tab (Phase C)**: "Top members" ranks by `engagement_events` (total activity), labeled "Most active". Unchanged scope.
- **Member engagement profile (new, later phase)**: per-member panel showing the axes side by side — each as raw value + percentile within the group/org cohort (percentiles normalize small cohorts better than absolute bars). Natural homes: MemberProfilePage (iPhone) and group analytics.
- Leaders only, same org-content scoping as everything else; members never see each other's numbers.

## Layer changes this doc adds (fold into Phase A build)

1. `scheduled_date date null` column on `analytics_events` (from lesson_schedule; null for non-schedule events).
2. NOTE_CREATED `value` = `LENGTH(content)` (metrics: COUNT for notes_written, SUM for content_chars) — value=1 convention holds for every other flow event.
3. Registry `computed` metric type (full-statement SQL) for streaks.
4. Optional POST_CREATED arm after authorId verification.
5. APP_SESSION instrumentation: deferred, requires product/privacy sign-off before any client work.
