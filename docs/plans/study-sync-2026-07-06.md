# Study Program → Enrollment Sync (Versioning) — Design Spec

**Date:** 2026-07-06
**Status:** Phases 1–2 implemented on `feature/study-sync`; phases 3–6 pending
**Scope:** Server (schema + APIs) first; client/iPhone consume later. Dashboard notification banner + modal is in scope; the enrollment sync-settings view launched *from* a notification is a later build (the notification payload must support it now).

## Problem

Enrolled lessons (`LessonSchedule` + `ScheduledLessonActivity`) are a one-time copy of curriculum lessons (`Lesson` + `LessonActivity`) made at enrollment. Curriculum edits never reach existing enrollments. We want opt-in downstream sync that never disturbs the historical record of members who already completed lessons.

## Approved decisions

1. **Propagation trigger:** explicit **"Publish updates"** action on the study program (not auto-on-save). The publish, not the edit, is the unit of sync — 25 edits then one publish = one version = one notification.
2. **Partial work on edited activities:** **carry forward** via lineage key. A member mid-lesson keeps completion state and input even if an activity they did was edited.
3. **Lessons added/removed mid-enrollment:** **future dates only.** Past-dated/delivered schedules never move; new/reordered lessons slot into the remaining future schedule; removed lessons are soft-hidden (kept in history if any member has progress).
4. **Approval-required mode:** **all-or-nothing** — approving brings the enrollment fully to the latest published version. Every enrollment is always at one well-defined program version.

## Architecture

### Curriculum versions

New model `StudyProgramVersion`:

```
studyProgramId, versionNumber (int, unique per program), publishedAt,
publishedById, changeSummary (Claude-generated), snapshot Json,
lessonHashes Json  // { [lessonId]: contentHash }
```

- "Publish updates" computes a canonical per-lesson content hash (title + activities + read blocks + source references), diffs against the previous version's `lessonHashes` to find changed/added/removed lessons, generates `changeSummary` via the Claude API (existing server integration), stores a full JSON snapshot for auditability, and enqueues fan-out.
- Only changed lessons sync downstream.

### Enrollment sync settings

On `Enrollment`:

```
syncMode        SyncMode @default(OFF)   // OFF | AUTO | APPROVAL
syncedProgramVersionNumber Int?          // version this enrollment reflects
```

- Enrollment UI: "Sync to study" toggle with description of implications; when on, choose **Automatic** or **Approval required**.
- Drift = latest published `versionNumber` > `syncedProgramVersionNumber` (cheap indexed check).
- Migration backfill: existing enrollments get `OFF` and a baseline at the program's initial version (v1 cut at migration time). Forward drift only; pre-existing drift is not retro-detected.

### Enrolled lesson versions + member pinning

New model `LessonScheduleVersion`:

```
lessonScheduleId, versionNumber, programVersionNumber, publishedAt
```

- `ScheduledLessonActivity` gains `versionId`; `LessonSchedule` gains `currentVersionId`. Versions are **immutable** — sync creates a new version's activity rows and never mutates/deletes old ones.
- `MemberLessonProgress` gains `pinnedVersionId`, **stamped at lesson completion**.
- Render resolution per member: `pinnedVersionId ?? lessonSchedule.currentVersionId`.
  - Completed → pinned, sees exactly what they finished, forever.
  - Not started / partial → no pin, sees latest automatically. No per-member writes at publish time.

### Partial-progress carry-forward

- Lineage key = `sourceLessonActivityId` (same curriculum activity → same key across all enrolled copies/versions).
- When a member with progress on a prior version opens the current version, lazily **copy** (never move) their `MemberActivityProgress`/`MemberVideoProgress` rows to the matching new activity by lineage key. Lazy = O(returning members), not O(all members × publish).
- `StudyNote`/`NoteLink` rows are untouched and survive by construction.

### Schema integrity fixes required en route

- `MemberActivityProgress`/`MemberVideoProgress` → `scheduledActivity` is `onDelete: Cascade`: sync must **never delete** activity rows (versions supersede; removals are soft) or member progress cascades away.
- `ScheduledLessonActivity.sourceLessonActivityId` is `onDelete: SetNull`: this severs the lineage key. Make it a plain stable lineage column (no FK) or soft-delete curriculum activities.
- Schema changes go through `server/schema/*.yaml` (source of truth) → Prisma.

### Fan-out job

- Publish returns immediately; a background job iterates enrollments of the program:
  - `AUTO` → apply sync (create new `LessonScheduleVersion`s for changed lessons, create schedules for added lessons in future slots, soft-hide removed, bump `syncedProgramVersionNumber`), then notify "updates applied".
  - `APPROVAL` / `OFF` → notify only (`OFF` leaders get the "you have drift" notification so an accidental toggle-off is recoverable).
- Idempotent unit: "bring enrollment E to version N" — safe to retry. `EnrollmentSyncRun` state row per (enrollment, targetVersion) so a crashed job resumes.
- Approval acceptance calls the same routine on demand.

### Notifications

Extend existing `Notification` model + `notification.ts` service (already pairs DB + push):

- `dedupeKey` (e.g. `program-updates:{enrollmentId}`): on publish, if an **unread** notification with the key exists, update in place (regenerated summary, version range, timestamp). N publishes before reading → 1 notification.
- `actions Json`: `[{ label, view, params }]` — e.g. `{ label: "Review updates", view: "enrollment-sync", params: { enrollmentId } }`. View names are contracts clients resolve later; notification system stays generic.
- Notification body carries enough to decide without tapping: program name, group name, version range, AI change summary.

### Dashboard banner + modal (build now)

- `GET /notifications/summary` → unread count + latest `createdAt`.
- Home dashboard banner: "You have N unread notifications · last one {relative time}" → tap opens modal listing notifications.
- Tapping a notification with an action opens the specified compact view in the same modal (the enrollment sync view itself is a later build; for now the action payload must round-trip).

### API surface (server)

- `POST /study-programs/:id/publish` — cut version, enqueue fan-out
- `GET  /study-programs/:id/versions` — version history + summaries
- `GET  /enrollments/:id/sync` — sync mode, synced version, drift + pending change summary
- `PATCH /enrollments/:id/sync` — change `syncMode`
- `POST /enrollments/:id/sync/apply` — approve/apply to latest (approval mode or manual catch-up from drift)
- `GET  /notifications/summary`, existing list/read endpoints gain `dedupeKey`/`actions`

### Future-proofing

Cross-org program sharing works unchanged: an enrollment in any org tracks `syncedProgramVersionNumber` against the shared program's published versions; fan-out and notifications are org-agnostic already.

## Suggested implementation phases

1. ✅ Schema: versions, sync fields, lineage-key fix, backfill (v1 per schedule, baseline enrollments at OFF). **Done 2026-07-06.**
2. ✅ Publish endpoint: hashing, diffing, snapshot, Claude summary. **Done 2026-07-06.**
3. Sync engine: idempotent per-enrollment apply + fan-out job + `EnrollmentSyncRun`.
4. Member resolution: pinned-version rendering + lazy carry-forward in lesson-fetch paths.
5. Notifications: dedupe + actions, summary endpoint.
6. Client: enrollment "Sync to study" toggle, program "Publish updates" button, dashboard banner + modal.

## Phase 2 implementation notes (2026-07-06)

- Service: `src/services/study-program-publish.ts` (`publishProgramVersion`).
  No-op publish detection (identical lesson set + hashes + day order) returns
  `alreadyUpToDate` without cutting a version. Concurrent publishes race on the
  `(studyProgramId, versionNumber)` unique → `PublishConflictError` → 409.
- Diff categories: `added` / `changed` (hash differs) / `removed` / `moved`
  (same hash, different dayNumber). Baseline version has `changedLessonIds =
  null` and no summary.
- Endpoints: `POST /api/programs/:id/publish-updates` (mutationFilter; requires
  isPublished; same empty-READ-activity guard as first publish) and
  `GET /api/programs/:id/versions` (accessFilter).
- Baseline hook: PATCH `/programs/:id` transitioning `isPublished false→true`
  cuts v1 (`generateSummary: false`); failure there logs but never undoes the
  publish toggle.
- Claude summary: `summarizeProgramChanges` in `services/claude.ts`, model
  `claude-opus-4-8` (`CLAUDE_MODELS.opus48` — the older `sonnet`/`opus` map
  entries are deprecated model IDs; left untouched for existing callers).
  Best-effort: null on missing key/API failure; per-lesson before/after JSON
  truncated at 4k chars. Verified live 2026-07-06.
- Tests: `src/routes/__tests__/program-publish.test.ts` (6 tests, Claude
  mocked via `vi.mock` + `importOriginal`).

## Phase 1 implementation notes (2026-07-06)

- Migration `server/atlas/migrations/20260706062151.sql`. The DROP of the old
  `(lessonScheduleId, orderNumber)` unique was added by hand — Atlas is configured
  with `drop_index = true` skip (HNSW workaround), so it suppressed the drop.
- Lineage is a plain `lineageKey` column (= source `LessonActivity.id` at copy
  time, no FK). The existing `sourceLessonActivityId` FK (SetNull) is kept for
  the reload feature; `lineageKey` is the carry-forward key.
- **Cascade decision:** `MemberActivityProgress → scheduledActivity` stays
  `onDelete: Cascade`. The leader "delete enrolled activity" endpoint keeps its
  existing hard-delete semantics; the constraint the sync engine must honor is
  simply *never delete activity rows* — versions supersede. (Restrict would have
  broken the existing endpoint.)
- Leader edit endpoints (add/delete/reorder scheduled activities) are scoped to
  the schedule's `currentVersionId` so pinned historical versions are untouched.
- Copy logic extracted to `src/services/lesson-copy.ts` (used by enrollment
  creation, add-lesson, and later the sync engine). Canonical hashing lives in
  `src/services/lesson-content-hash.ts` (`v1:`-prefixed sha256; excludes derived
  fields like estimates/thumbnails; read blocks reference source refs by
  position so curriculum and copies hash identically).
- `sourceContentHash` on a v1 version = hash of the *curriculum* lesson at copy
  time (not the enrolled copy — the copy transforms scripture content, so
  hashing it would produce false drift).
- Backfill: `npm run backfill:study-sync` (idempotent; run on staging/prod after
  deploy). Local dev DB backfilled 2026-07-06 (111 schedules, 256+245 activities).
- Raw SQL in request paths must not use `::uuid` casts: the CI/test DB is
  created via `prisma db push` (String ids = `text`), while dev/prod use Atlas
  migrations (`uuid`). Column-to-column joins are fine (backfill script).
- Local test DB: `docker run -d --name makeready-test-db -p 5433:5432 -e
  POSTGRES_USER=test -e POSTGRES_PASSWORD=test -e POSTGRES_DB=makeready_test
  pgvector/pgvector:pg16` + `CREATE EXTENSION vector` + `prisma db push`
  (matches `.env.test`; the whole server suite now runs locally).
- Tests: `src/routes/__tests__/enrollment-sync.test.ts` (5 tests) verifies v1
  versions, hash round-trip, versionId/lineageKey stamping, syncMode
  create/patch — authenticated via the real API-key path.
