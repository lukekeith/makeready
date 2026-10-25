# ui2-shell — spec
> lg · ticket none

## Idea

**Why.** MakeReady 2.0 replaces the iPhone app's entire UI. The design program (d2m, era 2.0) has
specced and built ~100 components and 33 screens as previews, but none of it runs in the app. This
feature makes 2.0 *the* app: from the next TestFlight build on, a leader opens MakeReady and gets the
2.0 Login, then the 2.0 Home dashboard inside the 2.0 navigation — and nothing of the legacy UI.

**What success looks like.** A TestFlight build (same bundle id, no new Apple approval) boots into
the 2.0 Login screen; Google sign-in lands on Home (TabBar MakeReady tab → TopNav "Home" section)
with live Overview and Activity data; the TopNav swipes and morphs across its 8 sections; the TabBar
switches between Home, Calendar, Search and Profile; Profile signs out. The legacy UI is not in the
binary, and every d2m component still captures pixel-identical after the module rename.

**In your words.**
- "treat it like a new 2.0 app, but without changing the bundle id … a clean break … We will never
  use the legacy app ever again, the only reason I'm not deleting it is so we can use it as a
  functional reference. So there's no need to toggle anything" → D3, D5
- "start releasing the new app as quickly as possible, even if all we have is a login screen" → D4
- "the new makeready app will have zero components from the current app" → D1, D2
- "this nav is only available on the main MakeReady page (first bottom left tab on the bottom nav).
  calendar, search, and profile do not use the topnav." → D12
- "The home dashboard screen is the 'Home' link on the top nav. This is the first page a user will
  see if they tap the MakeReady tab on the bottom nav." → D13

**The concept.** The d2m-owned module (today `UI2Preview`) is renamed `MakeReadyUI`, d2m is
repointed at it, and the app links it. A thin hand-written wiring layer in the app target turns it
into an app: a root that gates on auth, a shell that draws the two navigation levels once, and one
*container* per screen that reads `AppState`, builds the d2m screen's props, and maps its `on…`
callbacks to Actions or shell routes. d2m keeps rebuilding the pure views; containers are never
touched by a rebuild.

```mermaid
flowchart TB
  App[MakeReadyApp] --> Root[UI2Root]
  Root -- signed out --> LoginC[LoginContainer] --> LoginS[MakeReadyUI.LoginScreen]
  Root -- signed in --> Shell[UI2Shell]
  Shell --> TB[TabBar C-084 · always]
  Shell -- tab home --> TN[TopNav C-019 · Home tab only]
  TN -- section Home --> HomeC[HomeDashboardContainer] --> HomeS[MakeReadyUI.HomeDashboardScreen]
  TN -- other 7 sections --> Empty1[empty page]
  Shell -- calendar / search --> Empty2[empty page]
  Shell -- profile --> ProfC[ProfileStopgapContainer · Sign out + DEV env switcher]
  HomeC & LoginC & ProfC --> State[(AppState + Actions + AuthManager — shared foundations)]
  State --> API[server :3010 — existing endpoints]
```

**How it fits today.** The app root (`MakeReadyApp.swift:28`) shows legacy `MainView` or `LoginView`
on `AuthManager.isAuthenticated`¹. `AuthManager` already does Google OAuth via
`ASWebAuthenticationSession` → `/auth/exchange` → `/auth/me`, keeps `connect.sid` in the Keychain per
environment, and has a Local `/auth/dev-login` path²; `signOut()` posts `/auth/logout` and clears
`AppState`³. `AppState.loadInitialData()` loads programs, templates, unread count, the one org, Bible
translations and themes⁴. There is no feature-flag mechanism and no multi-org. The `UI2Preview`
framework target is linked only by the capture app and capture tests⁵; its screens draw their own
navigation (six render `TopNav`, Calendar and Search render `TabBar`)⁶. The dev environment switcher
lives on legacy `ProfilePage`⁷. `/auth/leader-access` and `/api/analytics/*` exist on the server but
the iPhone has never called them⁸.

**Approaches considered.** Chosen: rename the module, repoint d2m, wire through app-side containers
(one source of truth; Figma diffs keep verifying what ships). Rejected: building from `UI2Preview`
under its preview name (every rule and doc would describe a fiction); copying components into a new
app folder (forks the code — d2m rebuilds land in the copy nobody ships); wiring inside the d2m
screen files (a rebuild overwrites the wiring).

¹ `iphone/MakeReady/MakeReadyApp.swift:28-35` · ² `AuthManager.swift:101,137,249,287,406` ·
³ `AuthManager.swift:362` · ⁴ `State/AppState.swift:847` · ⁵ `project.pbxproj:1314,1346` ·
⁶ `UI2Preview/Screens/**` grep `TopNav(`/`TabBar(` · ⁷ `Pages/Profile/ProfilePage.swift:13` ·
⁸ `server/src/routes/auth.ts:571`, `server/src/routes/analytics.ts:188`

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ⬜ | Nothing (D25 ruled no server metrics). Every endpoint release 1 calls exists (§Contract, verified at audit); no route, schema or zod change | — |
| client | ⬜ | Nothing. The web app shares no code with the iPhone app; members stay on web (UI 2.0 D1) | — |
| iphone | ✅ | Module rename + link, legacy UI out of the target, new root/shell/containers, Home + Login + Profile wiring | §iphone |
| capture | ✅ | Path/import references follow the rename; re-capture proves the rename is pixel-neutral; Home/Login screen captures | §capture |

**Sequencing:** no producer change, so no freeze. Phase 1 (rename) touches iphone + capture
references in ONE mechanical commit set and is verified by capture before anything else moves; every
later phase is iphone-only. d2m prerequisites (F1–F5) gate Phase 3 only.

**Backward compatibility:** the iPhone app is a released artifact. Builds already installed keep the
legacy UI until updated — they call the same unchanged endpoints, so nothing they read moves. This
feature ships a binary in which the legacy UI no longer exists: a legacy fix after this lands ships
only from the `legacy-final` tag (D5).

**Blast radius:** d2m's project settings (`previewDir`, `tokensOutPath`, `targetSyncCmd`), every
`/ui2-*` and `/d2m-*` command and doc that names `UI2Preview`, the capture app/tests, SwiftLint
`included:` paths, and push-notification deep links (D17).

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Where 2.0 code lives | Rename `iphone/MakeReady/UI2Preview/` → `iphone/MakeReadyUI/` and the framework target `UI2Preview` → `MakeReadyUI`; no type is renamed. Repoint d2m settings `previewDir` → `iphone/MakeReadyUI`, `tokensOutPath` → `iphone/MakeReadyUI/Tokens.swift`, `targetSyncCmd` → the renamed sync script. Link + embed `MakeReadyUI.framework` in the `MakeReady` app target. The module stays d2m-owned and never imports `MakeReady`. Why: one source of truth — d2m rebuilds and Figma diffs reach what ships, and the module boundary makes legacy UI unreferenceable. Rejected: keep the `UI2Preview` name (preview-only framing contradicts its use); copy into a new component tree (forks the code, diffs verify a copy that doesn't ship) | user 2026-10-24 |
| D2 | Where wiring lives | Hand-written code in the app target under `iphone/MakeReady/UI2/`: `UI2Root.swift`, `Shell/` (shell view, `UI2Tab`/`UI2Section` enums, `UI2Route`), `Containers/<Namespace>/<Id>Container.swift`. A container reads `AppState`/`AuthManager`, builds the screen's `State`, maps each `on…` callback to an Action, a shell route or a no-op, and renders the `MakeReadyUI` screen. No file under `iphone/MakeReadyUI/` is hand-edited for wiring. Why: d2m regenerates screen files; views stay pure (UI 2.0 D12–D15, D30, D37). Rejected: wiring inside d2m screen files (overwritten on rebuild) | user 2026-10-24 |
| D3 | No flag | `MakeReadyApp` mounts `UI2Root` unconditionally; no build setting, UserDefaults key or server flag selects a shell. Supersedes UI 2.0 D2 and `docs/ui2/migration.md` isolation rule 1 + the `ui2-cutover` suite (recorded in d2m by F5). Why: clean break, same bundle id, no new App Store approval. Rejected: TestFlight-only runtime toggle, separate Release-UI2 config, new bundle id, server per-user flag — the owner wants no toggling | user 2026-10-24 |
| D4 | Release cadence | Every TestFlight build archived after Phase 2 is 2.0, even with Login as its only working screen; App Store timing is not decided here. Archiving stays the owner's call (builder.md). Why: ship the new app early. Rejected: wait for parity before TestFlight (delays real-device feedback on the new app for months; the owner accepts a near-empty build) | user 2026-10-24 |
| D5 | Legacy disposition | Tag the last commit before legacy leaves the target `legacy-final`. **First move every model type out of UI files into `State/Models/`** (kept): `Pages/Manage/Program/Models/StudyModels.swift`, `Pages/Manage/Group/Models/GroupModels.swift`, and the type declarations of `GroupInviteData`/`GroupInviteResponse` (`Pages/Manage/Group/GroupInvitePage.swift`), `LessonInviteData`/`LessonInviteResponse` (`Pages/Manage/Group/Enrollment/StudyInvitePage.swift`), `BibleVersion`/`BibleTranslationsResponse` (`Pages/Bible/BibleVersionMenu.swift`), `SplitCalendarEvent`/`CalendarActivityIcon` (`Components/Calendar/CalendarModels.swift`), `ActivityLogResponse` (`Components/Card/CardActivity.swift`), `LessonActivityStatus` (`Components/Card/CardData.swift`), plus any other type a kept file needs that the compiler names. **Then remove from the `MakeReady` target** (files stay on disk): `MainView.swift`, `LoginView.swift`, `Pages/**`, `Components/**`, `Services/NavigationCoordinator.swift`, `Services/Route.swift`, `Services/OverlayManager.swift`, `Colors.swift`, `Typography.swift`, `Fixtures/**`, `FixturesManager.swift`, `CARD_ARCHITECTURE.md`, and the UI utilities `Utilities/CachedAsyncImage.swift` + `Utilities/CachedCardImage.swift` (2.0 has its own `Ui2ImageCache`); `Utilities/ActivityStyle.swift` loses its `Color` members or leaves if nothing kept uses it. **Keep compiled:** `State/**` (incl. `State/API/APIClient.swift`, `State/Actions/**`, `State/Models/**`, `State/Persistence/**`), `AuthManager.swift`, `Configuration.swift` + `Configuration/*.xcconfig`, `AppDelegate.swift`, `MakeReadyApp.swift` (rewritten), `Info.plist`, `Assets.xcassets`, `Fonts/`, `Preview Content`, `ContactsManager.swift`, `Services/PushNotificationManager.swift`, `Services/LocalPortHealer.swift`, `Services/BibleCacheManager.swift`, `Services/BibleSearchService.swift`, `Services/GlobalSearchEngine.swift`, `Services/PhotoLibraryManager.swift`, `Services/Highlighting/**`, remaining `Utilities/**`. Enforcement: `npm run ios:build-check` green with no file from the remove list in the target. Why: legacy is read on disk or run from the tag; no dead UI in the binary; models are state, not components. Rejected: keep compiled but unreferenced (dead code compiles and lints); a separate legacy scheme (upkeep as foundations change) | user 2026-10-24 · file lists (assumed at audit) 2026-10-25 |
| D6 | Shared foundations | 2.0 reuses `AppState`, Actions, `APIClient`, `AuthManager`, the Keychain session and `StatePersistence` as they are. Containers read `AppState.shared` (the `@Observable` singleton every Action already writes — `AppState.swift:68`); `AuthManager` is created by `MakeReadyApp` and injected with `.environment(authManager)` as today, read by `UI2Root` and containers via `@Environment(AuthManager.self)`. Components and screens never read either (UI 2.0 D37). Why: zero components from legacy is a UI rule; state and services are not components. Rejected: a new 2.0 store (rewrite with no gain); `@Environment` injection of AppState (no Action reads it that way; two access paths) | (assumed at brainstorm) · access path corrected at audit 2026-10-25 |
| D7 | Login wiring | `LoginContainer` renders `LoginScreen`; `onSignIn` → `AuthManager.signIn()`; the container owns `authenticating`/`errorMessage` as `@State` (AuthManager exposes neither). Outcomes: (1) success → `isAuthenticated` flips and `UI2Root` mounts the shell; (2) Google callback `makeready://auth/error?message=…` (the server's iOS leader gate, `auth.ts:349`) → `AuthManager` throws a typed `AuthError.leaderAccessDenied`; the container shows "This account doesn't have leader access."; (3) `ASWebAuthenticationSessionError.canceledLogin` → idle, no message; (4) anything else → "Authentication failed". For the Local `/auth/dev-login` path, `AuthManager` calls `GET /auth/leader-access` **before** setting `isAuthenticated`; `canAccess:false` → sign out + outcome (2). `isAuthenticated` never flips true for a denied account, so the shell never mounts for it. Why: login spec §3 (OQ-login-003, -005); the server gates Google at the callback, so the client must read that redirect. Rejected: checking `/auth/leader-access` after `isAuthenticated` flips (shell flashes and fires Home queries for a member) | (assumed at brainstorm) · mechanics corrected at audit 2026-10-25 |
| D8 | Home data | `HomeDashboardContainer` fills Overview (KPI rail) and Activity (day rail + completed chart; metric coverage per D25) from `POST /api/analytics/query` with `GET /api/analytics/meta`; Sessions, Engagement and Following render their §3 `empty` state (zeroed arrays, "0 enrollments"). No server change. Why: three home-dashboard §5 API-GAPs need server work that would delay release 1. Rejected: close all gaps now (large server phase); no data at all (Home looks dead) | user 2026-10-24 |
| D9 | Home not-yet-wired actions | `onPickMetrics`, `onOpenEngagement`, `onFollowEnrollment`, `onProgramMenu`, `onOpenGroup` are no-ops; the controls render as designed. `onJumpToToday` and `onSelectSessionRange` work (the range re-scopes an empty section, so it only changes the dropdown label). Why: faithful to Figma and its diff; each target lands later. Rejected: hide them (a spec deviation per control; Following empty would lose its only affordance) | user 2026-10-25 |
| D10 | Unwired sections and tabs | All 8 TopNav sections (Home · Library · Groups · Members · Enrollments · Invites · Programs · Media) and all 5 TabBar cells are present and selectable. Library…Media, Calendar and Search show an empty page: full-bleed `color-layout-background`, no component. TabBar Add and every TopNav expanded-card add slot are no-ops. Why: keeps C-019/C-084's closed sets; nothing off-registry (UI 2.0 D6). Rejected: wire the built list roots now (much larger feature); hide unwired items (contract deviation) | user 2026-10-24 |
| D11 | Who draws navigation | The shell draws `TopNav` once, pinned under the status bar, and `TabBar` once, pinned above the home indicator; root screens render content only. The shell spec in d2m (F2) owns the exact placement, safe area and scroll interaction. Why: TopNav keeps its selection, scroll offset and morph across sections; one owner. Rejected: screens own their navigation (TopNav resets per section, two owners); a `showsNav` prop (dead code path, undesigned prop) | user 2026-10-24 |
| D12 | TopNav scope | TopNav exists only while TabBar `home` is selected. Calendar, Search and Profile never show it, and switching back to Home restores the last TopNav section and scroll offset for the life of the process | user 2026-10-24 |
| D13 | Entry point | After sign-in and on every cold launch with a valid session: TabBar `home` (MakeReady logo, cell 1) + TopNav section `Home` → `home-dashboard`. Re-tapping TabBar `home` returns to section Home. Why: Home is the first page. Rejected: restoring the last tab across launches (no designed need; D43 makes it ephemeral) | user 2026-10-25 |
| D14 | TopNav morph | Release 1 ships the full expand/collapse, finger-tracked morph of C-019 (collapsed tab row ⇄ expanded card row) to the choreography the `shell-topnav` d2m spec rules (OQ-C-019-5/6 defaults unless the owner rules otherwise). Selecting a card collapses the row. Why: the owner wants the real nav from release 1. Rejected: collapsed-only first (recommended, declined) | user 2026-10-24 |
| D15 | Sign out | Profile = empty page + one C-048 `PageActionButton` "Sign out", `role: secondary` (UI 2.0 D57) → `AuthManager.signOut()` → `UI2Root` shows Login. Marked a stopgap until `profile-home` is designed. Why: testers must switch accounts. Rejected: wait for the design (reinstall to switch); hidden long-press (undiscoverable) | user 2026-10-24 |
| D16 | Dev environment switcher | Only when `Configuration.devMode` is true: below Sign out on Profile, one C-047 `RadioOptionRow` per `Configuration.SelectedEnvironment` (`local`, `staging`, `production`), `description` = health ("Reachable"/"Unreachable"/"Checking…"), `selected` = current. Selecting one does exactly what legacy `ProfilePage.swift:168-205` does, moved into an `EnvironmentActions` struct: `AppState.shared.persistImmediately()` → set `Configuration.selectedEnvironment` → `AppState.shared.reloadForEnvironmentSwitch()`; `.local` → `LocalPortHealer.heal()` then sign in to the reachable local server, and on failure revert to the previous environment and show the error per `/ios-error-surface`; `.staging`/`.production` → `AuthManager.checkAuthStatus()` then `loadInitialData()` if still signed in, else Login. Health is a re-implemented reachability check (the legacy one is private to ProfilePage). Never rendered in Release. Why: the legacy switcher leaves the target. Rejected: on Login (undesigned UI there); no switcher (rebuild to switch) | user 2026-10-25 · switch mechanics corrected at audit 2026-10-25 |
| D17 | Push notifications and opened files | `PushNotificationManager` keeps registering and keeps the APNs token flow (it has no legacy-navigation dependency). A notification tap opens the app to D13's entry point; `UI2Shell` clears `PushNotificationManager.shared.pendingDeepLink` on mount, so a stale link never fires later. A `.makeready` file opened from Files is ignored in release 1 (the document type stays declared in `Info.plist`). `MakeReadyApp`'s rewritten body keeps its `onOpenURL` → `handleDeepLink` and AppDelegate wiring; `KeyboardToolbarInstaller` is dropped. Why: legacy routing leaves the target; 2.0 routes arrive with their screens | (assumed at brainstorm) · amended at audit 2026-10-25 |
| D18 | Rename is pixel-neutral | Phase 1 changes paths, target names, imports and settings only. Its gate is a capture of every built component and screen whose PNG matches the pre-rename render (diff 0%). Why: proves the move changed nothing | (assumed at brainstorm) |
| D19 | Shell state | Selected tab, selected section, TopNav `expansion` and `scrollOffset` are `@State` on the shell (UI 2.0 D43) — not persisted, not in `AppState` | (assumed at spec) 2026-10-25 |
| D20 | Home data storage | A new `DashboardActions` (in `State/Actions/`) loads Overview/Activity data into a new `AppState.dashboard` domain (KPI rows, day buckets) keyed by metric name + date; cache-first, refreshed in the container's `.task` (UI 2.0 D39), included in the disk snapshot (D41) as a `decodeIfPresent` key so an existing legacy snapshot still decodes (`PersistedState.swift:264-286`). The container maps it to `HomeDashboardScreen.State` in a pure, unit-tested function | (assumed at spec) 2026-10-25 · snapshot rule added at audit |
| D21 | KPI selection | Read `GET /api/preferences/dashboard.kpis`; the value is a JSON-array string of metric names. `isDefault:true` or an empty/invalid value → the default list from D25. A name absent from `/api/analytics/meta` is skipped. `metricCount` = "N metrics" for the cards shown. Event-class metrics: 24 points = the last 24 days via the `day` dimension, value = the 24-day total, % change via `compareToPrevious`. Snapshot-class metrics: queried with no window — value only, empty series, no trend (the server rejects windows on them, `analytics.service.ts:541`) | (assumed at spec) 2026-10-25 · corrected at audit |
| D22 | Activity window | Every analytics query sends `timezone: TimeZone.current.identifier` (the server defaults to UTC). Day buckets: the 28 days before today and today, via `lesson_completions` × `day`. The 7 days after today render with zero completed. The scheduled series is per D25. `chartToday` = today; the visible window opens centred on today | (assumed at spec) 2026-10-25 · corrected at audit |
| D24 | Initial load | `UI2Shell` calls `AppState.shared.loadInitialData()` once on mount (the only caller was legacy `MainView.swift:157`), and `HomeDashboardContainer` waits for it before its first analytics query. Analytics queries pass `filters.organizationId` = `AppState.organizationId` when it is set; scope otherwise per D26 | (assumed at audit) 2026-10-25 |
| D25 | Home metrics the catalog lacks | Overview shows exactly two KPI cards in this order: **Completed lessons** = `lesson_completions` (event class; 24-day `day` series, 24-day total, % change via `compareToPrevious`) and **Total video time** = `watch_seconds` (snapshot class; queried with no window; value formatted as hours, empty series, no average label, no trend). **Total time in lessons is not rendered.** Activity: completed per day = `lesson_completions` × `day`; `chartScheduled` is all zeros; each day card's minutes line reads "0 mins". These defaults also stand when `dashboard.kpis` is unset (D21). Server stays ⬜. Why: release 1 ships with no server phase. Rejected: add server metrics now (a server phase before Home); Completed lessons only (drops a value the catalog can serve) | user 2026-10-25 |
| D26 | Whose numbers Home shows | When `AppState.organizationId` is set, every Home query sends `filters.organizationId` = it. When it is nil, queries send no org filter and Home shows the server's default scope as returned — for a non-owner leader every org where they hold a role plus groups they created; for a Super Admin the whole platform. Enforcement: test (d). Why: every leader sees numbers; the server already scopes safely. Rejected: empty Home unless the user owns an org (non-owner leaders see nothing) | user 2026-10-25 |
| D27 | Session loss and offline launch | `AuthManager.checkAuthStatus()` signs out only on a 401 from `/auth/me`; offline, timeout, 5xx and 429 keep the cached user and the shell opens on cached `AppState`. Any 2.0 Action that receives a 401 calls `AuthManager.signOut()`, and `UI2Root` shows Login. (`APIClient` today maps every non-2xx to `serverError`; it gains a distinguishable 401 case.) Enforcement: test (f). Why: an offline leader keeps their app; an expired session ends cleanly. Rejected: today's behaviour (offline launch shows Login; a mid-session 401 shows stale data until relaunch) | user 2026-10-25 |
| D28 | Error surface in release 1 | Release 1 has no user mutation; errors are logged through the existing `recordError` path with no on-screen banner (legacy `ErrorBannerHost` leaves with `Components/`). The Login error line and the D16 switch error are the only surfaced errors. A 2.0 error host is a later feature's | (assumed at audit) 2026-10-25 |
| D23 | Folder on disk | `iphone/MakeReadyUI/` sits beside `iphone/MakeReady/`; `.swiftlint.yml` `included:` gains `MakeReadyUI`, and `.swiftlint-baseline.json` paths are rewritten to match | (assumed at spec) 2026-10-25 |

## Contract

No producer change. These are the existing server endpoints the 2.0 iPhone shell consumes; every
one is unchanged by this feature.

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `GET /auth/google?platform=ios` | server | iphone (unchanged use; **new: reads the error redirect**) | none | web session | redirect to `makeready://…?code=`; a non-leader → `makeready://auth/error?message=…`, no session (`auth.ts:349`) | — |
| `POST /auth/exchange` | server | iphone (unchanged use) | none | `{code}` | `{sessionId, userId}` | 400/401 |
| `POST /auth/dev-login` | server | iphone (Local env only, unchanged) | none; route exists only when `NODE_ENV=development` | `{email}` | `{success, user{id,email,name,avatarURL}, sessionCookie}` — not leader-gated (D7 adds the check) | 404 outside development |
| `GET /auth/me` | server | iphone (unchanged use) | session | — | user | 401 |
| `GET /auth/leader-access` | server | iphone (**new consumer**, dev-login path) | session | — | `{canAccess}`: true for Super Admin, an active org's owner, or any Owner/Admin/Group Leader role; false for inactive or member-only (`auth.ts:20-42`) | 401 |
| `POST /auth/logout` | server | iphone (unchanged use) | session | — | 200 | — |
| `GET /api/analytics/meta` | server | iphone (**new consumer**) | session | — | `{success, freshAsOf, metrics[{name,label,format,type,class,dimensionsAllowed,…}], dimensions[{name,kind,unit?}], ranges[]}`; data refreshes every 10 min | 401 |
| `POST /api/analytics/query` | server | iphone (**new consumer**) | session; server appends the caller's scope (`analytics.ts:73-83`) | `{metrics[≤10], dimensions[≤2] (day/week/month need from+to), filters{organizationId?, from?, to? (YYYY-MM-DD), range?, …}, timezone (default UTC), compareToPrevious?, limit?, orderBy?}` (`analytics.ts:119`) | `{success, freshAsOf, resolvedQuery{…,timezone,appliedScope}, rows[{day?, <metric>: int}], previousRows?, truncated?}`; time dimensions zero-filled | 400 (unknown metric, window on a snapshot metric), 401, 404 (filter outside scope / empty scope), 429 (120/min), 504 |
| `GET /api/preferences/:key` | server | iphone (**new consumer**) | session | key `dashboard.kpis` (free-form namespace) | 200 `{key, value: string, isDefault}` — a missing key is `isDefault:true`, `value:""`; never 404 (`preferences.ts:163`) | 401 |

**Module interface (iphone-internal):** `MakeReadyUI.LoginScreen(state:onSignIn:)`,
`MakeReadyUI.HomeDashboardScreen(state:…callbacks)` as rebuilt by F3, `TopNav`, `TabBar`,
`PageActionButton`, `RadioOptionRow`. Consumers: the iphone containers. d2m owns their shape; a
mismatch is routed back to d2m, never patched in `MakeReadyUI/`.

## Schema & API changes

No schema change (established 2026-10-25).

**Data plan:** none — no rows are written or migrated. The only new persisted data is the on-device
`AppState.dashboard` snapshot (D20), cleared by `AppState.clearAllData()` on sign-out.

## iphone

**Phase 1 — rename + link.** Move the folder (`git mv`); in the pbxproj re-parent the one `UI2Preview` group to the main group with `path = MakeReadyUI` (file refs are group-relative — no per-file rewrite), rename target/product/bundle id `com.makeready.UI2Preview` → `com.makeready.MakeReadyUI`, config-list names, proxies and embed entries;
`@testable import UI2Preview` → `MakeReadyUI` in `MakeReadyCaptureTests/ViewRegistry.swift`,
`CaptureRunner.swift` and `MakeReadyCapture/MakeReadyCaptureApp.swift`; replace `UI2Preview.` module qualifiers in those files (≈100 in ViewRegistry, 4 in CaptureRunner incl. a scanned string at :322); rename
`iphone/scripts/ui2-preview-sync.rb` (path :24, target :29, group parent :38 → main group) and update `iphone/scripts/capture-targets.rb:35,111-127`; SwiftLint paths (D23, incl. the `Tokens.swift` regex at `.swiftlint.yml:55` and 9 baseline entries); link + embed in
`MakeReady` (target dependency, Frameworks build file, a new Embed Frameworks phase, `@executable_path/Frameworks` runpath) — extend `capture-targets.rb`'s idempotent embed to the app target. Update the module `README.md` to drop "preview only". d2m settings change (D1) is
applied with d2m's own tooling by the owner (F5).

**Phase 2 — clean break + Login.** Tag `legacy-final`. Move model types into `State/Models/`, then remove legacy UI from the target (D5), resolving whatever else the compiler reports in kept files by moving a type, never by keeping a UI file (F6). `AuthManager` gains the D7 error redirect + dev-login gate. `MakeReadyApp` mounts
`UI2Root` (D3); `UI2Root` switches on `AuthManager.isAuthenticated` between `LoginContainer` and a
placeholder shell (an empty page until Phase 3). An archive here is a valid login-only TestFlight
build (D4).

**Phase 3 — shell.** `UI2Shell`: `TabBar` (selected = `UI2Tab`), the TopNav host on `home` only
(D11, D12, D14) — `TopNav` takes `expansion`/`scrollOffset` from the caller and has only a tap gesture, so the finger-tracked drag lives in the host — section switching, empty pages (D10), `UI2Route` with tab/section cases only, `loadInitialData` (D24), clearing `pendingDeepLink` (D17).
Gated on F2.

**Phase 4 — Home.** `DashboardActions`, `AppState.dashboard`, `HomeDashboardContainer` (D8, D9,
D20–D22). Gated on F3.

**Phase 5 — Profile + push.** `ProfileStopgapContainer` (D15, D16); push tap → entry point (D17).

House rules that bind every phase: no `APIClient` calls from containers or views; overlays only via
a typed route (none in release 1); never `.sheet`/`.fullScreenCover`/`asyncAfter`; errors routed per
`/ios-error-surface`; `swiftlint` from `iphone/`; iPhone commits are staged for the owner.

## capture

Update the references that follow the rename: `capture/lib/ui2-tokens.mjs:16` (output path) and `:106` (the generated header comment — regenerate `Tokens.swift` in the same commit), comments in `capture/server.mjs:1251` and `capture/src/lib/ui2-sample-call.js:17`; `.claude/scripts/list-ui2-refs.mjs:238` (`previewDir`); path and sync-script strings in `.claude/commands/ui2-component-{build,delete,merge,update}.md` and `ui2-resolve.md` (the scope-fence rules at `ui2-component-build.md:118,121` change deliberately); `.claude/commands/*`, `.claude/scripts/*` and `.claude/builder.md`
mentions; `docs/ui2/preview-build.md` + module README paths. Fixture keys (`component.ui2.C-###`,
screen keys) do not change. Re-capture every built component and screen and diff against the
pre-rename renders (D18).

## Testing

**iphone.** `npm run ios:build-check` every phase; `cd iphone && swiftlint` every phase; XCTest
(`--test`): (a) `HomeDashboardContainer` mapping — analytics rows + preference → `State` (KPI order,
"N metrics", day buckets across the 28/1/7 window, empty Sessions/Engagement/Following);
(b) `LoginContainer`/`AuthManager` — success; the `auth/error` callback → leader-access message with `isAuthenticated` never true; dev-login `canAccess:false` → same; cancel → idle; other failure → "Authentication failed"; (c) shell — Home re-tap returns to section Home;
TopNav absent on calendar/search/profile; section restore after a tab round-trip; (d) `DashboardActions` — sends the device `timezone`, `organizationId` when set, no window on snapshot metrics; (e) `PersistedState` — a legacy snapshot with no `dashboard` key decodes; (f) launch auth — per D27's ruling for offline, 5xx, 429 and 401.

**capture.** Pre/post-rename capture of all built rows, diff 0% (D18). Post-Phase 4: capture of
`HomeDashboardContainer` fed a fixture `AppState` vs the d2m `home-dashboard` frame (advisory %).

**Cross-app E2E walk (verify, once).** `/dev-start` → simulator on Local → DEV_MODE build → Sign in
(dev-login) → Home with live Overview/Activity → swipe and morph the TopNav through all 8 sections →
each TabBar tab → Profile → switch environment → sign back in → Sign out → Login. Mind `/auth/*`'s 10 req/min/IP limit — a full Google sign-in costs ~5.

**Human-verification script.**
1. Cold launch signed out → 2.0 Login (logo, "Welcome to MakeReady", Google button). No legacy UI anywhere.
2. Sign in with a leader account → Home tab, Home section, dashboard visible between TopNav and TabBar.
3. Overview KPI cards show real numbers (per D25; analytics lags up to ~10 min); Activity day cards and chart show real completed lessons per day, Jump to today recenters both.
4. Sessions, Engagement, Following show their empty state; their + / → / ⋯ do nothing.
5. Swipe the TopNav; drag it open and closed; pick each of the 8 sections — all but Home are empty pages.
6. TabBar: Calendar, Search empty, no TopNav; Add does nothing; Home brings back the section you left.
7. Profile → Sign out → Login. Sign in with Google as a member-only account → "This account doesn't have leader access." and no shell flash.
8. Kill and relaunch signed in → straight to Home, no Login flash (Google sign-in; Local dev-login never caches the user). Relaunch in airplane mode → per D27.
9. Install this build over a legacy TestFlight build already signed in → straight into 2.0 Home, no re-login.

## Out of scope

- Server work of any kind, including the three home-dashboard API-GAPs (sessions, engagement aggregate, followed enrollments) — a later feature.
- Wiring any screen other than Login, Home and the Profile stopgap (groups-home, members-home, enrollments-home, invites-home, study-programs, calendar-home, search-home, every detail/flow screen) — later per-area features.
- The KPI picker, follow picker, and every Home action in D9.
- `profile-home`, `library-home`, `media-home` (undesigned).
- Multi-org / account switching.
- The web client and members' experience.
- App Store submission.
- Writing any d2m spec, contract, decision, note or build — F1–F5 belong to `/d2m-*` and `/ui2-*`.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | d2m's `get_screen`/`get_component` fail: table `public.Note` missing in d2m's database | Owner runs d2m's migration before Phase 3; Phases 1–2 do not need d2m reads |
| F2 | `shell-topnav` and `shell-tabs` are queued with no spec; D11/D14 need their placement, safe-area and morph rules | Owner specs both in d2m (no-figma; sources C-019, C-084, `docs/features/navigation/01-account-switcher-analysis.md`), including "root screens draw no app chrome". **Gates Phase 3** |
| F3 | `HomeDashboardScreen` draws its own `TopNav` (and `onSelectTab`/`onToggleNav` props); six other roots draw TopNav, two draw TabBar | Owner rebuilds `home-dashboard` in d2m without app chrome before Phase 4; the other eight before each is wired. **Gates Phase 4** |
| F4 | The built `HomeDashboardScreen.State` has no per-section `loading`/`error` inputs though home-dashboard §3 lists them | Release 1 is cache-first (D20): first load renders `empty`, a failed refresh keeps the last data. Owner adds the states via d2m when convenient — build-time risk, Phase 4 |
| F5 | UI 2.0 D2 + `migration.md` + `preview-build.md` rule 1 now contradict D3/D1; d2m settings name `UI2Preview` | Owner records the supersession as a d2m decision and updates the settings + docs through d2m; builder does not write them |
| F6 | Kept foundations may reference further removed types beyond D5's list (the push path itself is clean — `PushNotificationManager` has no legacy-navigation dependency) | Phase 2 resolves every remaining compile error by moving the type or cutting the reference, never by keeping a UI file — build-time risk, Phase 2 |
| F7 | home-dashboard frame shows 3 KPI cards while its header reads "5 metrics" | D21 renders the count of what is shown; flagged to the owner at the walk |
| F8 | contract: two of three designed KPIs and the scheduled series have no event-class metric (`analytics-metrics.ts:112-298`); `watch_seconds` is snapshot-class and rejects windows | D25 ruled 2026-10-25 |
| F9 | contract: the server gates Google sign-in for iOS at the OAuth callback (`auth.ts:349-361`), so `/auth/leader-access` alone could never produce the denial copy | D7 corrected: read the `auth/error` redirect |
| F10 | `AppState`, `PersistedState` and Actions compile against model types declared under `Pages/**` and `Components/**` | D5 corrected: relocate them first (Phase 2) |
| F11 | `/api/organizations/my/organization` matches owners only, so non-owner leaders have no `organizationId`; Super Admin analytics scope is platform-wide | D26 ruled 2026-10-25 |
| F12 | Launch treats any `/auth/me` error as sign-out; no global 401 handling | D27 ruled 2026-10-25 |
| F13 | `UI2Preview` imports UIKit in one file, contrary to D1's "SwiftUI only" | build-time risk, Phase 1 — identify the file; UIKit in the module is acceptable (the real rule: it never imports `MakeReady`) |
| F14 | Legacy `ErrorBannerHost` leaves with `Components/`, so `recordError(surface:)` has no on-screen host in 2.0 | D28 |
