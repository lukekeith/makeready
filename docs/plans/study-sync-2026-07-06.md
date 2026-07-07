# Study Program → Enrollment Sync (Versioning) — Design Spec

**Date:** 2026-07-06
**Status:** Phases 1–6 implemented on `feature/study-sync`, web + iPhone (iPhone is the primary management surface; iPhone build verification pending)
**Scope:** Server (schema + APIs) first; client/iPhone consume later. Dashboard notification banner + modal is in scope; the enrollment sync-settings view launched *from* a notification is a later build (the notification payload must support it now).

## Problem

Enrolled lessons (`LessonSchedule` + `ScheduledLessonActivity`) are a one-time copy of curriculum lessons (`Lesson` + `LessonActivity`) made at enrollment. Curriculum edits never reach existing enrollments. We want opt-in downstream sync that never disturbs the historical record of members who already completed lessons.

## Approved decisions

1. **Propagation trigger:** explicit **"Publish updates"** action on the study program (not auto-on-save). The publish, not the edit, is the unit of sync — 25 edits then one publish = one version = one notification.
2. **Partial work on edited activities:** **carry forward** via lineage key. A member mid-lesson keeps completion state and input even if an activity they did was edited.
3. **Lessons added/removed mid-enrollment:** **future dates only.** Past-dated/delivered schedules never move; new/reordered lessons slot into the remaining future schedule; removed lessons are soft-hidden (kept in history if any member has progress).
4. **Approval-required mode:** ~~all-or-nothing~~ **SUPERSEDED 2026-07-07 (user decision): per-lesson selective approval.** The Review Changes screen shows each pending lesson change (new/updated/removed, with activity counts) with a per-lesson toggle; "Approve" applies the toggled-on subset. `syncedProgramVersionNumber` bumps only when nothing pending remains, so partial approvals leave the enrollment drifted — leaders can return later and approve more (the action-required notification stays alive). Selective applies never move existing schedules (curriculum reorders take effect only on full catch-up); approved additions fill slots freed by approved removals, overflowing past all existing dates.

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

- `GET  /programs/:id/publish-preview` — read-only diff vs latest version + last-published info (pre-publish confirmation)
- `POST /study-programs/:id/publish` — cut version, enqueue fan-out
- `GET  /study-programs/:id/versions` — version history + summaries
- `GET  /enrollments/:id/sync` — sync mode, synced version, drift + pending change summary
- `GET  /enrollments/:id/sync/changes` — per-lesson pending changes (new/updated/removed + activity counts + totals) for Review Changes; rows carry selection keys
- `POST /enrollments/:id/sync/apply` accepts optional `{ lessonKeys }` for selective approval
- `PATCH /enrollments/:id/sync` — change `syncMode`
- `POST /enrollments/:id/sync/apply` — approve/apply to latest (approval mode or manual catch-up from drift)
- `GET  /notifications/summary`, existing list/read endpoints gain `dedupeKey`/`actions`

### Future-proofing

Cross-org program sharing works unchanged: an enrollment in any org tracks `syncedProgramVersionNumber` against the shared program's published versions; fan-out and notifications are org-agnostic already.

## Suggested implementation phases

1. ✅ Schema: versions, sync fields, lineage-key fix, backfill (v1 per schedule, baseline enrollments at OFF). **Done 2026-07-06.**
2. ✅ Publish endpoint: hashing, diffing, snapshot, Claude summary. **Done 2026-07-06.**
3. ✅ Sync engine: idempotent per-enrollment apply + fan-out job + `EnrollmentSyncRun`. **Done 2026-07-06.**
4. ✅ Member resolution: pinned-version rendering + lazy carry-forward in lesson-fetch paths. **Done 2026-07-06.**
5. ✅ Notifications: dedupe + actions, summary endpoint. **Done 2026-07-06.**
6. ✅ Client: enrollment "Sync to study" toggle, program "Publish updates" button, dashboard banner + modal. **Done 2026-07-06.**

## Review Changes redesign (2026-07-07)

User-requested rework of the sync page + approval model:

- **Server:** `enrollment-sync-changes.ts` (`computePendingChanges`) diffs the
  enrollment against the latest snapshot per lesson, with activity-level
  counts computed by diffing the TARGET snapshot vs the snapshot the schedule
  currently reflects (located by matching sourceContentHash in older
  versions' lessonHashes — canonical curriculum forms only; enrolled copies
  are never compared, avoiding the scripture-transform false-drift trap).
  Falls back to `activities: null` ("Content updated") when no prior snapshot
  matches. Engine: `syncEnrollmentToLatest`/`applyVersion` take `lessonKeys`;
  in selective mode unapproved removals/updates are skipped, existing
  schedules NEVER move, approved additions fill freed slots then overflow
  past all existing dates; `fullySynced` computed post-apply via hash check;
  synced version + notification resolution only on full catch-up. Verified
  live: 2-lesson drift → approve one (still drifted, one pending) → approve
  the other (fullySynced, notification resolved). All 23 study-sync server
  tests pass.
- **Study Sync page (both apps):** AI summary + per-version list + bottom
  "Apply updates" button REMOVED. Drift now renders one summary card —
  "Lessons: 2 updated · 1 new" / "Activities: 3 updated · 1 removed" — with
  a right chevron that slides to Review Changes.
- **Review Changes screen (both apps):** grid rows — left column the lesson
  date (or DAY n for unscheduled additions) with a colored tag (NEW green /
  UPDATED yellow / DELETED red); right column the quantified per-lesson
  summary (activity counts, title changes) and a lesson-level design-system
  toggle (default ON). "Approve" lives in the PageTitle right slot (hidden
  while nothing is toggled on), applies the toggled-on keys, and stays
  re-visitable — rejected changes remain pending indefinitely.
- iPhone: new `ReviewChangesPage.swift` (pbxproj-registered), pending-changes
  cache `enrollmentPendingChangesById` (cache-first + cold-open gate).
  Web: new `review-changes-pane.vue` inside the sync pane's nested SlideStack;
  store gains `loadChanges`/`apply(lessonKeys)`.

## Phase 6 — iPhone implementation notes (2026-07-06)

The iPhone app is the primary curriculum-management surface, so all three
phase-6 features exist natively in `/iphone` (Actions + @Observable pattern):

- **Models/Actions.** `EnrollmentSyncMode`/`EnrollmentSyncStatus`/
  `ProgramPendingVersion` in EnrollmentModels.swift; `getSyncStatus` /
  `updateSyncMode` / `applySyncUpdates` in EnrollmentActions (apply also
  invalidates `enrollmentDetailsById` so schedules refetch);
  `ProgramActions.publishUpdates`. `AppNotification` gains
  `actions`/`dedupeKey`; `NotificationData` gains `enrollmentId`.
- **EnrollmentSyncPage** (new file, registered in pbxproj): sync toggle,
  Automatic/Approval segmented chooser, pending versions with AI summaries,
  Apply updates (DialogOverlay confirm). Cache-first via new
  `AppState.enrollmentSyncStatusById` (transition-review B2 contract).
  Entry points: (a) EnrollmentSchedulePage title gains a sync icon → outer
  Bool SlideStack pushes the pane; (b) overlay Route
  `.enrollmentSync(enrollmentId:)` for notification taps.
- **Publish updates.** ProgramHomePage published-badge dialog now offers
  Publish updates / Switch to Draft / Cancel; publish shows the cover
  CardSpinnerOverlay while the version cuts (Claude summary takes seconds),
  then a success ConfirmationOverlay with version + change summary, or an
  "Already up to date" alert on a no-op.
- **Notifications.** Feed rows render action buttons (BoxButton .sm);
  study-sync rows/actions route via new `DeepLink.enrollmentSync` →
  `NavDestination.enrollmentSync` → modal EnrollmentSyncPage (exhaustive
  switches preserved, /nav-route pattern). APNs taps with type
  `STUDY_SYNC_*` read `enrollmentId` from the payload. MainHome "Home" tab
  gains an unread-notifications banner (opens `.notificationFeed`); unread
  count loads with home data.
- **Enrollment-time toggle (user-requested 2026-07-06):** the Confirm
  Enrollment step (`ConfirmEnrollmentPage`) now carries a "Sync to study"
  ToggleControl below "Require response", with the Automatic/Approval
  segmented chooser when on. `EnrollmentData.syncMode` travels through both
  create paths (GroupHomePage + ProgramHomePage) into
  `EnrollmentActions.createEnrollment` → `POST /api/enrollments { syncMode }`
  (the server already accepted it, defaulting OFF). The web leader-app has
  no enrollment-creation flow yet, so enrollment-time sync is iPhone-only.
- **Pre-publish preview (user-requested 2026-07-06):** "Publish updates" now
  loads `GET /programs/:id/publish-preview` (new endpoint;
  `previewProgramPublish` in study-program-publish.ts — same snapshot+diff as
  publish, read-only, no Claude call) and shows a confirmation with when the
  program was last published (version + date) and what changed since: counts
  plus per-day detail capped at 6 lines. Up-to-date programs short-circuit to
  the "Already up to date" alert without publishing. Same flow on web
  (`runPublishFlow` in program-home-modal; DialogOverlay message got
  `white-space: pre-line`) and iPhone (`loadPublishPreview` +
  preview DialogOverlay in ProgramHomePage). Endpoint verified live: detects
  a title edit as `changed`, cuts nothing, reverts clean.
- **Baseline backfill (2026-07-06, after device testing):** programs published
  BEFORE versioning shipped had no StudyProgramVersion at all — the publish
  modal said "never been published as a version" and had nothing to diff, so
  curriculum edits showed no counts. `backfill:study-sync` gained Step 7
  (cut a v1 baseline from current curriculum for every published program with
  no versions; changeSummary/changedLessonIds/publishedById null) and Step 8
  (stamp those programs' enrollments `syncedProgramVersionNumber=1` ONLY when
  their schedule-hash content matches v1 — enrollments whose curriculum was
  edited post-enrollment stay drifted so applying v1 delivers those edits; no
  notifications either way). Ran locally (4 programs baselined; King Saul's
  enrollment correctly left drifted). **Must run on staging/prod after
  deploy** (idempotent). Caveat: edits made before the baseline are inside
  v1 — they reach groups via the drift/apply path, but the publish modal
  can't count them (no pre-edit snapshot exists); only post-baseline edits
  show in the diff. Modal copy for the no-version case softened, and the
  summary condensed to a count matrix ("2 changed · 1 added") + capped
  per-day lines with truncated titles.
- **Verification:** transition-review PASS; simulator build/run pending
  (requires explicit user go-ahead per project rules).

## Phase 6 — web implementation notes (2026-07-06)

All UI landed in the **leader app** (the live `/admin` SPA at
`client/resources/js/islands/leader-app/`), NOT the legacy PrimeVue
admin-island (parked at `/admin-legacy`). Everything goes through the shared
`/admin/api/*` Laravel proxy — no proxy changes were needed.

- **Dashboard banner + notifications modal.** `leader-notifications.store.ts`
  (summary, list, optimistic mark-read/mark-all-read, exported `relativeTime`).
  `dashboard-view.vue` shows a brand-tinted banner ("You have N unread
  notifications · Last one {rel time}") when `GET /notifications/summary`
  reports unread; tapping presents the new `notifications` overlay route →
  `notifications-modal.vue` (merged activity + Notification feed, unread dots,
  action buttons from the `actions` payload, "Mark all read"). Rows without
  actions are informational; `actions: null` on activity rows is handled.
- **Enrollment sync view.** `enrollment-sync-pane.vue` +
  `leader-enrollment-sync.store.ts`. Sync toggle (OFF ↔ AUTO; toggling on
  defaults to Automatic), Automatic/Approval chooser rows, drift section
  listing pending versions with their AI change summaries, "Apply updates"
  (confirm → `POST /enrollments/:id/sync/apply` → reload). Two entry points:
  (a) Program Home → Enrollments tab → tap an enrollment (SlideStack detail
  `sync:<enrollmentId>`); (b) a notification action with
  `view: 'enrollment-sync'` slides the pane open INSIDE the notifications
  modal. The spec deferred (b), but the phase-6 toggle needed a home and one
  pane serves both — the action payload is fully wired, not just round-tripped.
  Unknown action views remain inert.
- **Publish updates.** Tapping the "Published" badge on Program Home now
  presents Publish updates / Switch to Draft / Cancel (single dialog IS the
  confirmation for both actions; draft-side behavior unchanged). Publish uses
  the sticky-dialog pattern ("Publishing..."), calls
  `POST /programs/:id/publish-updates` via `publishUpdates` in
  leader-program.store, then reports "Version N published" + the Claude
  change summary, or "Already up to date" on a no-op.
- **Not built (intentionally):** no web UI consumes
  `GET /programs/:id/versions` yet (version history page is future work);
  the legacy admin-island got nothing.
- **Verified live 2026-07-06** against the local stack (API-key auth,
  Daily Inspiration program): baseline v1 publish → title edit → v2 publish
  with live Claude summary → APPROVAL drift + coalesced notification with
  action payload → apply (drift cleared, run COMPLETED, notification
  auto-read) → AUTO fan-out auto-applied v3 → no-op publish returned
  `alreadyUpToDate`. Client `npm run build` passes (no TS checker in client;
  esbuild is the gate).

## Phase 5 implementation notes (2026-07-06)

- `upsertNotificationByDedupeKey` / `resolveNotificationsByDedupeKey` in
  notification.ts. Coalescing: unread same-key → updated in place (title/
  body/data/actions/createdAt); push fires only on first create of a cycle.
- Fan-out now notifies EVERY drifted enrollment's `createdById`:
  AUTO → `STUDY_SYNC_APPLIED` (dedupeKey `study-sync-applied:{enrollmentId}`);
  APPROVAL/OFF → `STUDY_SYNC_UPDATES_AVAILABLE`
  (`study-sync-updates:{enrollmentId}`, action label "Review updates" vs
  "Update sync settings", view `enrollment-sync`, params {enrollmentId},
  data carries from/to version + syncMode + AI summary in body).
- Successful sync (any trigger) marks the pending-updates notification read.
- **Action-required semantics (user-requested 2026-07-06):**
  STUDY_SYNC_UPDATES_AVAILABLE carries `data.requiresAction: true` — viewing
  and mark-read (single or all) never clear it, server-enforced in the
  mark-read route (app-side filter, NOT a Prisma JSON `NOT path equals` —
  that drops rows missing the key via SQL NULL semantics). It resolves only
  when the decision happens: sync applied (engine) or syncMode changed
  (PATCH /enrollments/:id resolves the dedupeKey). Clients mirror this
  (banner persists; row taps don't mark actionable rows read; sync pane
  refreshes the feed/summary after apply/mode change). Verified live:
  publish → mark-all leaves it unread; mode change resolves it;
  informational rows still clear.
- Routes: the feed previously served ONLY Activity rows — list, unread-count,
  and mark-read now merge/cover the Notification table too (Notification
  entries carry `actions` + `dedupeKey`, `actor: null`). New
  `GET /api/notifications/summary` → { unreadCount, latestAt } for the
  dashboard banner.

## Phase 4 implementation notes (2026-07-06)

- Shared helpers in `src/services/lesson-version-resolution.ts`:
  `resolveVersionId` (pin ?? current), `filterActivitiesToVersion`,
  lineage-aware `findProgressForActivity`, and `carryForwardMemberProgress`
  (copies — never moves — activity/video progress onto the resolved version's
  rows by lineageKey; idempotent via uniques + skipDuplicates).
- `checkAndUpdateLessonCompletion` judges completion against the member's
  resolved version and PINS on completion (`pinnedVersionId = pin ?? resolved`);
  un-completing clears the pin so the member floats to current again.
- `getMemberLessonDetail` resolves per member, runs lazy carry-forward for
  unpinned members, and returns only the resolved version's activities.
  List/summary paths (getMemberLessons, getMemberEnrollments,
  getEnrollmentProgress, getGroupStudies) filter + count lineage-aware;
  removed (removedAt) schedules hidden unless the member has history.
- Leader enrollment views, next-study, lessons/code|view|today, and the
  share-invite passage ref render the CURRENT version (no member context).
- `recalculateScheduledLessonEstimate` and the enrollment-analytics SQL count
  only current-version activities (and skip removed schedules).
- Known cosmetic gap: OG meta's first-activity passage ref may read a stale
  version's row (take:1 across versions); harmless, fix later.
- Perf note: multi-version schedules load all versions' activity rows and
  filter in JS; fine at current version counts, revisit if programs reach
  very high version counts.
- Tests: `member-version-resolution.test.ts` (3) — pin on complete, pinned
  rendering after sync, lineage carry-forward (copy not move), re-pin on new
  version.

## Phase 3 implementation notes (2026-07-06)

- Engine: `src/services/enrollment-sync.ts` — `syncEnrollmentToLatest` brings
  an enrollment to the program's latest published version. Content comes from
  the **version snapshot**, never live curriculum (unpublished edits must not
  leak; derived fields like videoUrl/thumbnails are recovered from live
  curriculum only when their source fields still match the snapshot).
- Snapshot lessons now carry `activityIds` (aligned with canonical activity
  order, outside the hashed content) so materialized copies get lineageKey.
  `buildLessonRowsFromSnapshot` in lesson-copy.ts adapts snapshot shape into
  the shared copier (positional "ref:N" block↔ref linkage, scripture
  transform, dangling sourceLessonActivityId FKs nulled).
- Per-lesson idempotency: hash comparison (schedule.currentVersion.
  sourceContentHash vs snapshot hash) — a crashed run resumes and skips
  already-applied lessons. `EnrollmentSyncRun` upserted RUNNING→COMPLETED/
  FAILED per (enrollment, targetVersion).
- Completed members are pinned (pinnedVersionId = outgoing currentVersionId)
  in the same transaction that switches the schedule to the new version.
- Scheduling (decision 3): locked = smsSentAt set OR scheduledDate <= now.
  Remaining curriculum lessons are laid over surviving future slot dates in
  curriculum order; removed lessons free their slots; overflow walks the
  enrollment's enabledDays. Events follow (date/title/dayNumber); endDate
  extends when needed. New `LessonSchedule.removedAt` column: removed lessons
  hard-delete when no member progress exists, soft-hide otherwise (their
  future events are deleted either way).
- Fan-out: `launchProgramVersionFanOut` fires in the background from
  publishProgramVersion; sequential per-enrollment with error isolation.
  `drainStudySyncFanOuts()` exists for test teardown (a background fan-out
  outliving its test file races the next file's writes on the shared test DB).
- Endpoints: `GET /api/enrollments/:id/sync` (mode, drift, pending version
  summaries, recent runs) and `POST /api/enrollments/:id/sync/apply`
  (approval-mode acceptance / manual catch-up).
- Tests: `enrollment-sync-engine.test.ts` (7). Also fixed a pre-existing
  intra-file flake in invite-member-integration.test.ts (same-millisecond
  Date.now() phone collision between beforeEach and a test).

### ✅ Resolved (2026-07-06): curriculum lesson deletion decoupled

`LessonSchedule.lessonId` is now **nullable with `onDelete: SetNull`**
(was Cascade). Deleting a curriculum `Lesson` row (editor delete-lesson,
days-shrink in PATCH /programs/:id) no longer touches enrollments — the
enrolled schedule survives orphaned (it owns its content) and the removal
reaches enrollments only via publish + sync, where the standard removal
rules apply (hard-delete without progress, soft-hide with progress, future
slots refill per the updated curriculum). User-approved semantics: day-count
changes only affect future enrolled lessons, which shift to fill the
schedule based on the updated program.

Read-path fallbacks for orphaned schedules (transient until sync, persistent
on OFF enrollments): title falls back to `schedule.title`, dayNumber to 0,
member-facing program branding falls back to `enrollment.studyProgram`
(selects extended in member-progress.service), OG meta returns the generic
fallback, note links skip LESSON/PROGRAM refs, availableLessons skips
orphans. Migration `20260706185753.sql`.

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
