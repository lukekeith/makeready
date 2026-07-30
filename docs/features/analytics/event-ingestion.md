# Client Event Ingestion — how any engagement latches on

Owner direction (2026-07-29): the engine must let **any feature, lesson, activity type, or engagement** track analytics against itself, forever. The derived-from-state arms (architecture.md) cover everything that already persists to OLTP; this doc adds the second half — a **first-class instrumented-event path** for engagement that has no OLTP side effect (opens, starts, views, future interactions). Together they make the layer hybrid: *derive what the database already knows; instrument what it doesn't; union both into one flat view.*

**Platform reality that shapes everything here: members engage with content in the WEB app** (lesson player at `client/resources/js/components/domain/lesson-island/steps/{video,youtube,read,exegesis,input,complete}-step.vue`). The iPhone app is the leader tool — it *consumes* analytics (Program tab) and needs only the tracker scaffold, not member instrumentation.

## Server: `client_events` + `POST /api/analytics/events`

**`client_events`** — append-only real table, modeled in `schema/schema.yaml` (normal `/schema` flow, unlike the matview):

| Column | Notes |
|---|---|
| `id` uuid | **Client-generated** — natural idempotency key; retries upsert-ignore |
| `event_type` text | MUST exist in the server registry — unknown types are rejected (400), which IS the tracking-plan discipline: registering the type is how a feature "latches on" |
| `occurred_at` timestamptz | Client clock; `received_at` server clock alongside. Ingest clamps `occurred_at` into `[received_at − 48h, received_at + 5min]` (offline buffer replay allowed, clock nonsense rejected) |
| `member_id` / `user_id` | **From the session, never from the payload** — spoof-proof by construction |
| `enrollment_id`, `lesson_schedule_id`, `scheduled_activity_id` | Client sends only these narrow ids; the server **enriches** org/group/program/activity_type/day_number/scheduled_date from them at ingest (client can't mislabel dimensions) and validates the ids belong to the session's member/leader scope |
| `value` numeric default 1, `metadata` jsonb | metadata is a pressure valve for event-specific attributes; anything queried regularly gets promoted to a real column (additive) |

**Endpoint**: `POST /api/analytics/events` accepts a batch (max 50), session-auth (member phone-session on web, leader session on iPhone), zod-validated, rate-limited, always fire-and-forget from the client's perspective (a dropped batch must never break the lesson player). The matview gains one `UNION ALL` arm (`ce:` prefix) projecting `client_events` into `analytics_events` — after which every registry metric, dimension, and filter works on instrumented events with zero further plumbing.

**The extensibility recipe** (the whole point):
1. New engagement to track → register the `event_type` server-side (name per the locked convention, declare grain/value semantics in metrics-catalog.md).
2. Emit it from the client through the tracker (one call).
3. Done — it flows through ingest → view arm → registry. No migration unless it needs a genuinely new dimension column (additive when it does).

## Web client: `analytics.ts` tracker (the member side — the priority)

Small module in `client/resources/js/` used by the lesson island:
- `track(eventType, { enrollmentId, lessonScheduleId, scheduledActivityId, value?, metadata? })` — pushes to an in-memory queue with a client UUID + timestamp.
- Flush: every 10s, at queue ≥ 20, and on `visibilitychange`/`pagehide` via `navigator.sendBeacon` (keepalive-fetch fallback) — the page-close path is where naive implementations lose the last events.
- Failure policy: retry next flush with the same UUIDs (idempotent), drop after 24h; never surface errors to members.

**First instrumented events (ship with the tab, Phase B):**
- `LESSON_OPENED` — lesson island mount.
- `ACTIVITY_STARTED` — first display of each step (all six step components, one emit point in the island's step-change handler, not per-file).
These two close the "started-but-never-completed is invisible" gap flagged in the research — started→completed becomes a real funnel — and they're privacy-equivalent to the completion data leaders already see. Video watch heartbeats deliberately STAY on the existing `saveVideoProgress` path (it's already a write-path with business meaning; the delta ledger taps it server-side).

## iPhone: scaffold only

`AnalyticsActions` + a small buffered tracker service (flush on background, via APIClient per house pattern — views never call it directly). **Zero events emitted initially**: leader-side authoring is already ledgered by `trackActivity`, member engagement doesn't happen here, and APP_SESSION/time-in-app remains deferred pending privacy sign-off (README checklist 5/6 of member-evaluation.md). The scaffold exists so the first future iPhone event is a one-line emit, not an infrastructure project.

## What this does NOT change

- Derived arms stay authoritative for anything with OLTP truth (completions, notes, enrollments) — never double-instrument what the database already records; an event type lives in exactly ONE arm.
- The privacy posture: no session tracking, no dwell timers, no per-keystroke anything without explicit sign-off. The pipe existing does not authorize events flowing through it — registration is the gate, and registration of member-behavior events beyond opens/starts requires the owner's yes.
- The Phase-D roadmap epic (dwell time, drop-off funnels, cohort dashboards) — it now has its transport ready and becomes "register types + emit + build charts" instead of a pipeline project.

## Phase placement

- **Phase A** additionally builds: `client_events` table + ingest endpoint + the `ce:` view arm + registration enforcement.
- **Phase B** additionally builds: web `analytics.ts` + the two lesson-player events (server type registration included).
- **Phase C** additionally builds: iPhone tracker scaffold (no events).
