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
- [x] **card-study** ↔ `CardStudy` — DONE (reference comparison)
- [x] **card-group** ↔ `GroupCard` — Row / RowSelected / Mini / MiniSelected
- [ ] **card-member** ↔ `MemberListItem` (4 variants: contact / member / member+invite / multi-group)
- [ ] **card-event** ↔ `CardEvent` / `CardEventMini`
- [ ] **card-enrollment** ↔ `UpcomingLessonCard` / `CardProgramFull`
- [ ] **card-post** ↔ post card (group wall) / `SkeletonPostCard`
- [ ] **card-video** ↔ iPhone video card
- [ ] **card-search-result** ↔ `CardSearchResult`
- [ ] **swipeable-card** ↔ `SwipeableCard` / `SwipeableGroupCard`

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
- [ ] **home-dashboard** ↔ `pages.home` (`MainView`)
- [ ] **member-home** ↔ member home (iPhone)
- [ ] **lesson** ↔ member lesson player (read / SOAP / video)
- [ ] **login** ↔ `pages.login` (`LoginView`)
- [ ] **calendar-screen** ↔ calendar tab
- [ ] **library-grid** ↔ media library tab
- [ ] **list-screen** / **detail-screen** ↔ generic list/detail
- [ ] **join-group** / **join-code** / **accept-invite** / **invite-flow** ↔ (mostly member-facing web; confirm iPhone analogs)
- [ ] **group-announcements** / **shared-with-me** / **public-home** / **privacy** / **not-found** ↔ (web-only? mark N/A if no iPhone analog)

---

## Notes / decisions
- Pairs with **no iPhone analog** (member-facing web flows) should be marked **N/A** rather than left open — the tool is for parity where both exist.
- This list is seeded from the web Histoire stories (`resources/js/components/**/*.story.vue`, `resources/js/pages/**/*.story.vue`) and the iPhone component/page inventory; verify each iPhone counterpart exists before building its harness.
