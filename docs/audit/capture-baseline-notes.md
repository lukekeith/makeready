# iPhone Visual-Regression Baseline — Capture Notes (Phase 0.1)

## How the iPhone capture pipeline actually works

The working iPhone capture path is **XCTest + swift-snapshot-testing**, not Playwright and not the in-app `FixturesManager` (`iphone/MakeReady/FixturesManager.swift` is unrelated — it only loads contact/member list fixtures for pickers inside the running app). The runner `capture/runners/iphone/capture.sh` sets `CAPTURE_ROOT=capture/fixtures/iphone` and runs `xcodebuild test -only-testing:MakeReadyCaptureTests/CaptureRunner` against the iPhone 17 Pro Max simulator. `CaptureRunner.testCaptureAll()` (in `iphone/MakeReadyCaptureTests/CaptureRunner.swift`) discovers every `capture/fixtures/iphone/{workflow}/*.json` fixture (skipping folders prefixed with `_` or `.`), resets `AppState.shared` to a fresh instance, seeds it from the fixture's `state` block (`CaptureEnvironment.swift`), instantiates the SwiftUI view mapped from the fixture's `view` key (`ViewRegistry.swift`), wraps it in device chrome, and records a snapshot per entry in `devices` (`iphone-se`, `iphone-15-pro`, `iphone-16-pro-max`) into `{workflow}/screenshots/{device}/capture.{name}.png`. It always runs in **record mode** (`isRecording = true`) — there is no built-in diffing; the baseline workflow is: commit the recorded PNGs, re-run after the refactor, and use `git diff` / the capture UI (`capture/server.mjs`, frontend on :5950) to compare. The capture UI lists sets from `capture/fixtures/iphone/manifest.json`.

### Command to run the baseline (user-triggered; builds the app + boots the simulator)

```bash
cd /Users/lukekeith/www/makeready/capture
bash runners/iphone/capture.sh                 # all workflows
bash runners/iphone/capture.sh home            # one workflow
bash runners/iphone/capture.sh home 03-large-org   # one screen
```

Then commit the regenerated PNGs under `capture/fixtures/iphone/*/screenshots/` as the pre-refactor baseline. Post-refactor, re-run the same command and inspect `git diff --stat capture/fixtures/iphone` (PNG byte-changes flag visual changes; open the capture UI for side-by-side).

### Fixture JSON schema (decoded by `CaptureFixture.swift`)

```json
{
  "platform": "iphone",
  "view": "pages.<registry-key>",       // must exist in ViewRegistry.swift
  "output": "NN-name.png",
  "title": "Set: Human Title",
  "devices": ["iphone-se", "iphone-15-pro", "iphone-16-pro-max"],
  "auth": { "isAuthenticated": true, "currentUser": { "id", "name", "email", "picture" } },
  "state": { ... }                       // seeded into AppState by CaptureEnvironment.swift
}
```

`state` keys with **working seeding support today**: `programId`, `programName`, `programDays`, `programCoverImagePath` (file relative to capture root), `lessons[]` (with embedded `activities[]`), `activity` (full read-blocks/source-refs/YouTube fields), `lessonId`, `homeStats` (`totalMembers`, `totalGroups`, `totalStudies`, `totalEnrolledLessons`, `heatmap`, `weeklyActivity`). Note: `state.programs[]`, `state.groups[]`, `state.enrollments[]` are *decoded* (`CaptureState`) but **never applied** by `setupCaptureState()` — the arrays in `home/01-with-data.json` are currently inert.

### Registered views (`ViewRegistry.swift`) — the only capturable screens today

`pages.login`, `pages.home` (MainView, Home tab only), `pages.create-program`, `pages.program-home`, `pages.edit-read-activity`, `pages.edit-exegesis-activity`, `pages.edit-youtube-activity`, `pages.edit-user-input-activity`, `pages.video-activity-picker`.

## Pre-existing coverage (17 fixtures, 7 sets, 3 devices each)

| Set | Fixtures |
|---|---|
| login | 01-unauthenticated |
| home | 01-with-data, 02-empty |
| create-program | 01-empty-form, 02-program-home-empty, 03-program-home-with-lessons |
| create-read-activity | 01-with-blocks, 02-empty, 03-styled-blocks |
| create-exegesis-activity | 01–04 |
| create-video-activity | 01-picker, 02-youtube-empty, 03-youtube-loaded |
| create-user-input-activity | 01-empty, 02-title-only, 03-help-fully-configured |

## What was added in this phase

**Active fixtures (capturable on the next run, no app/test-target changes needed):**

1. `home/03-large-org.json` — `pages.home` with large KPI numbers + dense heatmap (baselines KPI formatting and the Home tab + NavBar, both touched by the nav/state refactor).
2. `create-program/04-program-home-many-lessons.json` — `pages.program-home` with 12 lessons / mixed activity types, no cover image (baselines lesson-list density on ProgramHomePage).

No `manifest.json` change was needed — both live in sets already listed.

**Pending fixtures (18, in `_`-prefixed folders so the loader skips them; schema-exact, ready to activate):**

| Pending set | Fixtures | Proposed `view` key |
|---|---|---|
| `_main-tabs/` | 01-groups-tab, 02-library-programs-tab, 03-library-media-tab, 04-calendar-tab | `pages.main` + proposed `state.mainTab` / `state.librarySubTab` |
| `_group-home/` | 01-overview, 02-manage-screen, 03-group-screen | `pages.group-home` + proposed `state.screenIndex` (3-screen slider) |
| `_program-extras/` | 01-program-home-second-screen, 02-edit-day | `pages.program-home` (+`screenIndex`), `pages.edit-day` |
| `_enrollments/` | 01-enrollments-list, 02-enrollment-schedule, 03-edit-enrollment-day, 04-select-enroll-date | `pages.enrollments-list`, `pages.enrollment-schedule`, `pages.edit-enrollment-day`, `pages.select-enroll-date` |
| `_media/` | 01-media-detail | `pages.media-detail` (grid covered by `_main-tabs/03`) |
| `_members/` | 01-group-members, 02-member-home | `pages.group-members`, `pages.member-home` |
| `_profile/` | 01-profile | `pages.profile` |
| `_notifications/` | 01-notification-feed | `pages.notification-feed` |
| `_bible/` | 01-bible-reader | `pages.bible-reader` |
| `_menus/` | 01-add-menu, 02-user-menu, 03-share-invite-sheet | `pages.add-menu`, `pages.user-menu`, `pages.share-invite-sheet` |

## Coverage vs. the Phase 0 target list

| Target | Status |
|---|---|
| Home tab + NavBar | ✅ capturable now (`home/01–03`) |
| Groups / Library (Programs, Media) / Calendar tabs | ⏸ pending — `MainView.currentTab` is `@State private`, not fixture-drivable |
| Group home + 3-screen slider | ⏸ pending — no registry case; slider index is internal state |
| Program home (screen 1) | ✅ capturable now (`create-program/02–04`) |
| Program home second screen | ⏸ pending — needs `screenIndex` support |
| EditDay | ⏸ pending — needs registry case (`EditDay(isPresented:programId:...)`) |
| EditReadActivityPage | ✅ covered (`create-read-activity/*`) |
| Enrollment flows (list, schedule, edit day, select date) | ⏸ pending — no registry cases; no enrollment/group seeding |
| Media grid + MediaDetailOverlay | ⏸ pending — no registry cases; no media seeding |
| GroupMembersPage / MemberHomePage | ⏸ pending — no registry cases; no member seeding |
| Profile / Notifications | ⏸ pending — no registry cases |
| Bible reader overlay | ⏸ pending — no registry case; needs offline Bible content path verified |
| AddMenu / UserMenu / presentModal sheet | ⏸ pending — no registry cases; overlays need an OverlayManager-hosted wrapper |

## Gaps and recommendations

The capture mechanism can only render views **registered in `ViewRegistry.swift`** with state **seeded by `CaptureEnvironment.swift`**. Both files live in the `MakeReadyCaptureTests` test target (already in the Xcode project), so closing the gaps requires *test-target Swift only* — except item 1, which needs one tiny app-side hook. Per-gap work:

1. **Main tab selection (`pages.main`)** — add an optional `initialTab: MainTab` (and a library sub-tab equivalent) init parameter to `MainView` / `MainLibrary`, defaulting to current behavior. ~5-line app change; everything else is a registry case reading `state.mainTab`.
2. **Group/enrollment/member/media/notification seeding** — extend `CaptureState` with typed `groups: [CaptureGroup]`, `enrollments`, `members`, `media`, `notifications` and apply them in `setupCaptureState()` via `state.groups.upsert(...)`, `state.enrollments.upsert(...)`, etc., plus the relationship indexes (`groupEnrollmentIndex`-style). Note the existing inert `groups`/`enrollments` loose-dict fields should be replaced by these typed versions. The pending fixtures already carry data shaped on the real models (`UserGroup` in `Pages/Manage/Group/Models/GroupModels.swift`, `EnrollmentWithProgram`, `MediaLibraryItem`, `AppNotification` in `State/Models.swift`).
3. **Registry cases** — one `case` per proposed view key. Signatures verified: `GroupHomePage(groupId:)`, `EnrollmentsListPage(groupId:)`, `EnrollmentSchedulePage(enrollment:)`, `EditEnrollmentDay(isPresented:enrollmentId:)`, `EditDay(isPresented:programId:...)`, `GroupMembersPage(groupId:)`, `MemberHomePage(pendingSubTab:)`, `ProfilePage()`, `NotificationFeedPage()`, `MediaDetailOverlay(item:sourceFrame:onDismiss:)`. Pages that fire Actions in `onAppear` will attempt network calls against `127.0.0.1:3010`; the seeded AppState still renders (same pattern ProgramHomePage already relies on), but render-before-load timing should be sanity-checked on first capture.
4. **Internal slider/screen index** (`GroupHomePage` 3-screen slider, `ProgramHomePage` second screen) — these are `@State private`; add an optional `initialScreenIndex` init parameter (app-side, default 0) or a `#if DEBUG` capture hook, then read `state.screenIndex` in the registry.
5. **Overlays/menus** (`AddMenu`, `UserMenu`, `ShareInviteSheet`, `MediaDetailOverlay`, `BibleReaderOverlay`) — snapshot them inside a host view that pre-presents them via `OverlayManager` (or render the overlay view directly over `Color.appBackground`), since `verifySnapshot` captures a single static view tree, not animated presentation.
6. **Bible reader** — `BibleReaderOverlay` depends on the Bible content service; verify chapter content is bundle-local (offline) before relying on it for deterministic snapshots, otherwise seed a fixture passage.
7. **Remote images** — `AsyncImage`/URL-loaded images render as placeholders in synchronous snapshots. Deterministic (good for diffs), but any fixture that should show imagery must use the local-file path mechanism (`programCoverImagePath` pattern) — extend the same approach for group covers and media thumbnails.
8. **No comparison mode** — `CaptureRunner` always records. Optional improvement: a `CAPTURE_COMPARE=1` env switch that sets `isRecording = false` to get true pass/fail visual regression instead of git-diffing PNGs.

**Activation checklist per pending set:** (1) add the ViewRegistry case + any CaptureState/seeding support, (2) rename the folder to drop the leading `_`, (3) add the set to `capture/fixtures/iphone/manifest.json`, (4) run `bash runners/iphone/capture.sh <folder>`.

**Recommended sequencing:** land items 2+3 first (pure test-target, unlocks 12 of 18 pending fixtures: enrollments, members, media-detail, profile, notifications, share-invite), then item 1/4 (tiny app-side init params, unlocks main-tabs + sliders), then 5/6 (overlays + Bible).
