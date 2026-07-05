# Compare Manifest — components & pages to add

A living **todo list** of apples-to-apples comparisons to add to the `/compare` tool
(iPhone ↔ Web, same data). Check items off as their comparison is built and captures land.

Status: `[x]` done · `[~]` partial (one side works / needs the other) · `[ ]` not started.

## How to add one (recipe)

For a **component**:
1. Web: register the Vue component in the `ComponentCapture` island
   (`client/resources/js/components/domain/component-capture/component-capture.vue`).
2. iPhone: add a `component.<id>` case to `iphone/MakeReadyCaptureTests/ViewRegistry.swift`
   (build the SwiftUI component from props; extend `CaptureComponent` in `CaptureFixture.swift` if new fields are needed).
3. Adapter: `capture/runners/compare/adapters/<id>.mjs` (`toClient` / `toIphone`), register in `adapters/index.mjs`.
4. Fixture: `capture/fixtures/compare/<group>/<id>.json` (`type: "component"`).
5. Capture both (web instant; iPhone needs an `xcodebuild`).

For a **page**: same, but the web side renders a Blade view (no island) and the iPhone side
needs a `pages.<x>` ViewRegistry case + AppState seeding.

Reference component: `card-study` (`adapters/card-study.mjs`, `fixtures/compare/cards/card-study.json`).
Notes: remote images need pre-seeding (`ImageCache.seed` in `CaptureEnvironment`); iPhone runner
re-records all fixtures per run (env scoping limitation).

---

## Components

### Cards

All iPhone card components are now wired as **iPhone-first** comparisons (variants
derived from each Swift `#Preview`; Vue twin to follow). Web side is intentionally
absent — navigable iPhone-only in `/compare`.

- [x] **card-study** ↔ `CardStudy` — Row / Pending (web DONE)
- [x] **card-group** ↔ `GroupCard` — Row / RowSelected / Mini / MiniSelected (web DONE)
- [x] **CardStudyMini** ↔ `CardStudyMini` — Photo / Pending (iPhone)
- [x] **CardStudySelectable** ↔ `CardStudySelectable` — Unselected / Selected / Draft (iPhone)
- [x] **CardVideo** / **CardVideoMini** ↔ video cards (iPhone)
- [x] **CardEvent** / **CardEventMini** ↔ event cards — Date/Time display (iPhone)
- [x] **CardMember** / **CardContact** ↔ member/contact cards (iPhone)
- [x] **CardActivity** / **CardActivityType** ↔ activity log + type picker (iPhone)
- [x] **CardLesson** ↔ lesson card — 10 variants across planning/lesson/progress/lessonList (iPhone)
- [x] **CardLessonActivity** ↔ activity box — 8 variants (iPhone)
- [x] **ScheduledLessonCard** / **UpcomingLessonCard** ↔ scheduled lesson cards (iPhone)
- [x] **CardEnrolled** / **EnrollmentCard** / **CardProgramFull** ↔ enrollment/program cards (iPhone)
- [x] **CardMediaFull** ↔ media library card (iPhone)
- [x] **CardSearchResult** / **CardBibleSearchResult** ↔ search result cards (iPhone)
- [x] **GroupPostCard** ↔ group wall post card — Text / TextImage / Event / Welcome (iPhone)
- [ ] **swipeable-card** ↔ `SwipeableCard` / `SwipeableGroupCard` (wrapper — deferred)

### Forms
- [ ] **text-input** ↔ `TextInput` (types: email/phone/number/url/password)
- [ ] **textarea** ↔ `MultilineTextInput` / `LargeTextInput`
- [ ] **toggle-control** ↔ `ToggleControl` (+ `ToggleGroup`)
- [ ] **search-field** ↔ `SearchField`
- [ ] **select** / **menu-input** ↔ `MenuInput`
- [ ] **date-picker-field** ↔ `DatePickerField`
- [ ] **tag-input** ↔ (iPhone tag input — confirm exists)
- [ ] **age-range-input** ↔ (iPhone age range — confirm exists)
- [ ] **label** / **field-group** / **help-text** ↔ form scaffolding (low priority)

### Buttons, nav & display
- [ ] **button** ↔ `ActionButton` (5 variants)
- [ ] **avatar** ↔ `Avatar` (6 sizes)
- [ ] **badge** ↔ iPhone badge/pill
- [ ] **page-title** ↔ `PageTitle` (8 variants)
- [ ] **page-header** ↔ `PageHeader`
- [ ] **nav-bar** ↔ `NavBar`
- [ ] **empty-state** ↔ iPhone empty state
- [ ] charts: **heatmap / bar / donut / line** ↔ `HeatMapChart` / `VerticalBarChart` / `DonutChart` / `LineChart`

### Overlays
- [ ] **qr-code** ↔ `InviteQRCodeView`
- [ ] **share-invite-sheet** ↔ `ShareInviteSheet`
- [ ] **add-menu** / **user-menu** ↔ `AddMenu` / `UserMenu`

---

## Pages

- [~] **group-home** ↔ `pages.group-home` — web DONE; iPhone bridged (re-capture to verify; member-vs-leader differs by design)
- [~] **home-dashboard** ↔ `pages.home` (`MainHome`, the default post-login tab) — iPhone scaffolded (fixture `main/home-dashboard.json` + adapter; seeds `homeStats` KPIs/weekly-activity/heatmap). **Needs an iPhone capture run** (xcodebuild) for its reference shot. Web twin deferred: the analog is the admin-SPA dashboard (`admin-island/sections/dashboard-section.vue`), NOT the member `/home` landing.
### Leader main screens — one comparison per tab (scaffolded iPhone-first 2026-06-28; need a capture build + web leader twins)
Tab isolation: MemberHomePage `pendingSubTab` (groups/members/enrolled) + MainPrograms `initialTab` exist; MainHome & MainLibrary need the same `@Binding initialTab` (Activity/Media). Several need new `CaptureState` seeding (activityLogs/members/mediaItems/calendarEvents). Web twins = capture-only leader pages composing existing twins (like group-home-leader); production member pages untouched.
- [~] **activity** ↔ `pages.activity` (MainHome Activity tab) — **WIRED** (ViewRegistry + `MainHome.initialTab`, defaulted app-source); renders chrome+tabs, activity-log CONTENT seeding TODO
- [~] **groups** ↔ `pages.groups` (MemberHomePage tab 0) — **ViewRegistry WIRED** (pendingSubTab:.constant(0)); ready to capture (pending build)
- [~] **group-members** ↔ `pages.group-members` (MemberHomePage tab 1) — **WIRED** (pendingSubTab:.constant(1)); renders chrome+tabs, member CONTENT seeding TODO
- [~] **groups-enrolled** ↔ `pages.groups-enrolled` (MemberHomePage tab 2) — **ViewRegistry WIRED** (pendingSubTab:.constant(2)) + programs/enrollments seeded; ready to capture
- [x] **study-programs** ↔ `pages.study-programs` (MainLibrary tab 0) — iPhone captured + **web twin built** (`LibraryPrograms.vue`: PageHeader + SearchField + filter pills + Browse/sort + CardProgramFull). MAE ~12 (dominated by the inherited CardProgramFull title/book-glyph font rendering — its own component compare is ~7.9).
- [x] **media** ↔ `pages.media` (MainLibrary tab 1) — iPhone captured + **web twin built** (`LibraryMedia.vue`: PageHeader + SearchField + 4 filter pills + 3-col placeholder grid). MAE ~3.3. (iPhone media-item CONTENT seeding still placeholder-only.)
- [~] **program-home** ↔ `pages.program-home` (ProgramHomePage, the .programHome modal) — **web twin built + captured** (`ProgramHome.vue`: PageTitle + CoverImagePicker/PublishBadge + TabSlider + CardLesson list + add-day BoxButton; SHARED with the production leader app). iPhone reference capture pending (needs an xcodebuild run).
- [~] **calendar** ↔ `pages.calendar` (`MainCalendar`) — **WIRED**; renders month grid, calendarEvents CONTENT seeding TODO
- [~] **search** ↔ `pages.search` (`GlobalSearchPage`) — **ViewRegistry WIRED** (indexes seeded programs/groups); ready to capture
- [ ] **member-home** ↔ member home (iPhone)
- [ ] **lesson** ↔ member lesson player (read / SOAP / video)
- [ ] **login** ↔ `pages.login` (`LoginView`)
- [ ] **list-screen** / **detail-screen** ↔ generic list/detail
- [ ] **join-group** / **join-code** / **accept-invite** / **invite-flow** ↔ (mostly member-facing web; confirm iPhone analogs)
- [ ] **group-announcements** / **shared-with-me** / **public-home** / **privacy** / **not-found** ↔ (web-only? mark N/A if no iPhone analog)

---

## Notes / decisions
- Pairs with **no iPhone analog** (member-facing web flows) should be marked **N/A** rather than left open — the tool is for parity where both exist.
- This list is seeded from the web Histoire stories (`resources/js/components/**/*.story.vue`, `resources/js/pages/**/*.story.vue`) and the iPhone component/page inventory; verify each iPhone counterpart exists before building its harness.
