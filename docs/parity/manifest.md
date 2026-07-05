# iPhone → Web Leader-App Parity Manifest

The master tracker for porting every iPhone leader screen to the mobile-web
LeaderApp (`/admin`, `client/resources/js/islands/leader-app/`) with pixel-level
parity. **This file is the source of truth for what's done** — update it at the
end of every screen's work so a fresh session can pick up exactly where the last
one stopped.

**How to work a screen:** run `/parity-screen` (no argument — takes the first
unchecked item in the **Build queue** below, whose order encodes dependencies)
or `/parity-screen <screen-id>` to target one directly. The skill encodes the
proven pipeline (analyze iPhone → build shared twin → register compare →
capture both → diff → wire production → verify → update this manifest).

**Status legend** (a screen advances through these in order):

| Status | Meaning |
|---|---|
| `—` | not started |
| `spec` | iPhone source analyzed, layout/data/transition spec captured in a memory or notes |
| `twin` | shared Vue twin built + registered (component-capture + app.scss) |
| `compare` | compare fixture + adapter registered, web + iPhone shots captured, diff inspected |
| `wired` | production route/store/overlay wiring done, build + tests green |
| ✅ `verified` | user verified live + compare comments resolved |

## Foundation (done — reuse, don't rebuild)

- ✅ **Overlay system** — `islands/leader-app/overlay/`: `overlay-routes.ts`
  (Route registry, priorities 100/200/300), `overlay.store.ts` (priority-sorted
  stack, two-phase dismiss, `dismissThen`), `managed-modal.vue` (bottom sheet,
  springs, drag-dismiss), `overlay-host.vue` (z = 100+index), `slide-stack.vue`
  (300ms ease-in-out, mount-then-slide, completion-tied unmount),
  `managed-menu.vue` (content-sized bottom card #111215/stroke #242937,
  tertiaryLabel grabber as first layout child, scrim tap ALWAYS dismisses,
  grabber-only drag-dismiss; see `parity-managed-menu` memory).
  **Missing:** `managed-page.vue` (horizontal push
  chrome — only `.memberRequests` uses it on iOS).
- ✅ **Animated not-ready border** — `styles/_animated-border.scss` mixin
  (rotating conic brand ring, frozen in `.capture-page`/`.capture-wrap`).
- ✅ **Swipe + drag-reorder** — `swipeable-card` twin (iOS mechanics: progressive
  reveal, velocity snap, `bare` production mode, `action`/`tap` emits) +
  `dragula-list` twin (long-press lift, drop indicator, FLIP make-way,
  `reorder` emit). Wrap any card twin; see `parity-swipeable-drag-reorder`
  memory for the gating/endpoint patterns.
- ✅ **Confirm-dialog service** — `overlay/confirm-dialog.store.ts`
  (`useConfirmDialog().confirm({title,message,buttons}) → Promise<index|null>`;
  `present({sticky:true})` returns an update/close handle for in-flight button
  states like "Adding...") + `overlay/confirm-dialog-host.vue` mounted once in
  leader-app.vue (fixed full-screen blurred scrim, z-500, DialogOverlay
  scale-in — the /library/programs chrome). EVERY iOS-style alert/confirm must
  present through this — no local dialog scrims. All 11 prior call sites
  migrated 2026-07-03 (library, edit-day, program-home, create-program,
  edit-read-activity).
- ✅ **ConfirmationOverlay route host** — `components/confirmation-overlay-modal.vue`
  presents the ConfirmationOverlay twin through the raw `.confirmationOverlay`
  overlay route (blurred scrim, content-appear motion, live getter props);
  reuse for any processing→success confirmation.
- ✅ **Interactive twin inputs** — text-input / multiline-text-input / tag-input
  / toggle-control / search-field have additive `interactive` modes; PageHeader
  / PageTitle / TabSlider / NavBar / AddMenu / ActionCardMenu / DialogOverlay
  have additive emits. **Twins must only ever change additively** (compare
  snapshots bind no listeners / pass no new props).
- Key memories: `leader-app-study-management`, `leader-app-library-page`,
  `compare-twins-index` (+ per-twin traps), `admin-mobile-web-rebuild`.

## Tab roots

| Screen | iPhone source | Compare id | Status | Notes |
|---|---|---|---|---|
| Home dashboard | `Pages/Main/MainHome.swift` | `home-dashboard` | ✅ verified | `views/dashboard-view.vue`; Activity sub-tab still static |
| Groups (3 tabs) | `Pages/Manage/Member/MemberHomePage.swift` | `groups` / `group-members` / `groups-enrolled` | ✅ verified | `views/groups-view.vue`; header paperplane/plus no-ops |
| Library Programs | `Pages/Main/MainLibrary.swift` (tab 0) | `study-programs` | ✅ verified | `views/library-view.vue`; filters + sort wired (see library-filters-sort queue item) |
| Library Media | `Pages/Main/MainLibrary.swift` (tab 1) | `media` | ✅ verified | media detail overlay on tap not built |
| Calendar | `Pages/Main/MainCalendar.swift` | `calendar` (iPhone-only) | — | ComingSoonView stub |
| Global search | `Pages/Search/GlobalSearchPage.swift` | `search` (iPhone-only) | — | ComingSoonView stub |
| Profile | `Pages/Profile/ProfilePage.swift` | — | — | ComingSoonView stub |
| Notification feed | `Pages/Notifications/NotificationFeedPage.swift` | — | — | PageHeader bell not wired |

## Study program management

| Screen | iPhone source | Compare id | Status | Notes |
|---|---|---|---|---|
| Program Home | `Pages/Manage/Program/ProgramHomePage.swift` | `program-home` | ✅ verified | shared `ProgramHome` twin; Enrollments tab wired 2026-07-03 (see queue item); publish-badge dialogs + export flow wired; eye/preview icon still no-op |
| Edit Program (settings pane) | `ProgramHomePage.editProgramContent` | — (no iPhone ViewRegistry case yet) | wired | `edit-program-pane.vue`; add `pages.edit-program` to ViewRegistry for a composed compare |
| EditDay (lesson editor) | `Pages/Manage/Program/EditDay.swift` | `edit-day` (variants: mixed/empty) | wired | `edit-day-pane.vue`; compare = CAPTURE-ONLY `EditDay` twin (adapter mirrors studyActivityCard mapping) + new `pages.edit-day` ViewRegistry case; parity fixes must land in the pane too |
| Add-activity menu | `Components/Navigation/AddActivityMenu.swift` | `AddActivityMenu` | compare | `add-activity-menu.vue` (raw chrome) — the island component IS the twin (registered in ComponentCapture; capture-only `statusBar` prop). BOTH platforms captured + diffed structurally tight 2026-07-04 (0.82%, remaining = font/glyph artifacts). Production parity fixes found by the diff: VIDEO label was white-on-white (CardActivityType gained additive `labelColor`), tiles were fixed 120px vs iOS fluid aspectRatio(1) columns, missing 32px header spacer, title line-height pinned to 29px (web font line box pushed grid 4pt low). iPhone = `pages.add-activity-menu` ViewRegistry case with `.transaction { disablesAnimations }` (view fades from opacity 0 on .onAppear). Fixture is type PAGE (absolute-inset overlay ⇒ component-type live preview collapses to 0 height). Awaiting live verify |
| Write activity editor | `EditUserInputActivityPage.swift` | `edit-user-input-activity` (variants: default/configured/help-enabled) | wired | `EditUserInputActivity` twin (pane is now a thin wrapper); iOS-exact chrome ("Edit Activity", "Activity title", long help-toggle copy, Preview button) |
| YouTube activity editor | `EditYouTubeActivityPage.swift` | `edit-youtube-activity` (variants: default/configured) | wired | `EditYouTubeActivity` twin (pane is now a thin wrapper); iOS field order (title→URL), thumbnail+play preview well, Preview button |
| Read activity editor | `EditReadActivityPage.swift` | `edit-read-activity` (variants: default/configured/highlighting) | ✅ verified | full spec in `parity-edit-read-activity` memory (tri-state Save, locked/editable block duality, auto-save split); `EditReadActivity` twin (Screen 1) built + adapter toClient added, BOTH variants diffed structurally tight (accepted: floating-label ghost, line-wrap font metrics, paintbrush glyph approximation); Screen 1 WIRED (EditDay READ tap → edit-read-activity-pane: tri-state save, add custom block via iOS source menu, delete dialog, drag-reorder, swipe-delete, expand/collapse; store readBlocks CRUD + themes; MarkdownEditor additive interactive textarea). Pane = EditDay precedent (capture-only twin, shared scss). Screen 2 style interactivity WIRED (BlockStyleEditor additive interactive: theme native-select, font tiles → fontSize null==m, color well → 24-swatch picker + opacity slider menu on dynamic id, image well → backgroundSourceMenu → MediaLibraryPicker modal → backgroundImageUrl). ALL flows wired 2026-07-03: (a) highlighter/.stylePicker — SelectableLockedBlockView additive verse-tap selection (tap=select, tap-again-inside=confirm→StylePickerMenu on stylePicker_id menu route, replace-overlapping PATCH selections optimistic) + highlight-mode dims/border/disables + multi-verse gutter-number rendering; (b) FULL Bible passage picker — BiblePassagePicker twin + bible-passage-picker-host (books/chapters/verses grids, Charter reader with verse-tap selection, smart search + recents, version menu) + leader-bible store, confirm→addSourceReference→iOS appendNewBlocksToEnd quirk→Set-titles modal (exact strings); (c) Photos/Take-Photo — file inputs (capture attr) → canvas ≤2000 JPEG 0.85 → org media upload → backgroundImageUrl, uploading scrim. COMPARE: `highlighting` variant (web-forward) + new `bible-passage-picker` comparison (books/reader/search, WEB-ONLY — UIKit overlay has no ViewRegistry case). Confirm dialogs via the shared confirm-dialog service; toggles/expand-collapse animated. Spec memories: `parity-edit-read-activity`, `parity-bible-passage-picker`. ✅ verified 2026-07-04 |
| Exegesis activity editor | `EditExegesisActivityPage.swift` | `edit-exegesis-activity` (variants: default/configured) | wired | full spec in `parity-edit-exegesis-activity` memory. WIRED 2026-07-04: `EditExegesisActivity` twin (passage chip row, inline BlockStyleEditor w/o themes, #1A1D28 preview + ExegesisVerseView) + adapter toClient — BOTH variants diffed structurally tight vs the existing iPhone refs on first capture; `edit-exegesis-activity-pane` in EditDay (native DOM selection → word-snapped auto-highlight POST, tap-highlight → `exegesisHighlightActionMenu` menu (new `ExegesisHighlightMenu` twin + WEB-ONLY compare `exegesis-highlight-menu`: actions/note-editor) with PREV/count/NEXT + deferred note drafts saved on Save, delete; passage via shared Bible picker gated by the 'Change passage?' confirm (iOS ships it unreachable — ported by intent), style snapshot re-applied after the server replace; Cancel reverts unsaved style). ExegesisVerseView gained additive interactive + selectedRange + multi-verse gutter rendering + font-size-scaled line pitch. Store: exegesis-highlights CRUD. Build + 234 tests green. Awaiting live verify |
| Video activity picker | `Pages/Video/…` + `VideoActivityPicker` | `video-activity-picker` (default variant, iPhone-only) | wired | FRAMING (see `parity-video-activity-picker` memory): iOS picker = DEVICE Photos picker + camera; web maps the iOS media-library-item path — picker twin (library-panel layout: album header + 4-col 9:16 grid + duration badges) lists uploaded videos (GET /api/videos/me, ready only) via managed-modal from the EditDay VIDEO card tap; select → PATCH {videoId,videoUrl,status COMPLETE} with card spinner (non-optimistic, iOS); configured tap/eye-swipe → playback modal (HTML5 video + Remove → PATCH nulls/PENDING); video card shows thumbnail/duration/Select-video. COMPARE: web side now previewable (2026-07-03) — default (empty library panel) + 'library' variant (seeded grid); iPhone pane shows the recorder (harness can't seed showingLibrary) — see fixture note. Upload/record = excluded hardware |
| Create Program | `Pages/Manage/Program/CreateProgramPage.swift` | `create-program` | ✅ verified | `CreateProgram` twin + `create-program-modal.vue` (SlideStack → ProgramHomeModal `preloaded` on success); Library plus-menu entry live (via `.libraryAddMenu` managed-menu); verified 2026-07-03 |
| Exegesis highlight modal | `ExegesisHighlightModal.swift` | — | — | topLevel overlay |
| Read activity preview | `ReadActivityPreviewModal.swift` | — | — | web preview may substitute |

## Group management

| Screen | iPhone source | Compare id | Status | Notes |
|---|---|---|---|---|
| Group Home | `Pages/Manage/Group/GroupHomePage.swift` | `group-home` (variants: default/posts) | wired | WIRED 2026-07-04: `.groupHome` + `.lessonActionMenu` overlay routes (Route.swift-exact), `group-home-modal.vue` host + `leader-group-home` store (group/posts+cursor pagination via twin scroll `loadMore`/join-request badge/next-lesson across active enrollments), Groups-tab CardGroup tap presents; lesson menu rows iOS-exact — Open Lesson LIVE (invite URL → new tab), Edit Activities/Share/Add/Delete dismiss-only until their queue items (enrollment-schedule, StudyInvitePage); toolbar icons + Invite/Enroll inert (edit-group/members/invite/enrollment-flow items); chips inert = TRUE parity (iOS stubs). Build + 234 tests green. COMPARE 2026-07-04: GroupHomeLeader extended additively (statusBar, cover, badge, NEXT LESSON CardLesson, posts wall w/ GroupPostCard + SkeletonPostCard + pagination spinner); default variant diffed pixel-aligned (1.29%, residual = s22 title Display-vs-Text width artifact); `posts` variant web-forward (iPhone can't seed posts/nextLesson — live API); SlideStack gained additive `detailEdge: leading`. SPEC captured 2026-07-04 (`parity-group-home` memory). CORRECTIONS: page = `.groupHome` MODAL overlay (dismissOnTapOutside true), settings form is INLINE (`editGroupContent`) as the outer SlideStack's `.leading` detail (NOT EditGroupPage.swift), members/enrollments/invite = inner TRAILING SlideStack panes; iOS post-create chips + calendar icon are stubs; iOS addScheduledLesson bug (empty body vs required lessonId). Production wiring: CardGroup tap in Groups tab |
| Create Group | `Pages/Manage/Group/CreateGroupPage.swift` | — | — | entry: Groups header plus + AddMenu item |
| Edit Group | INLINE `editGroupContent` in `GroupHomePage.swift:381-529` (NOT EditGroupPage.swift) | `edit-group` (WEB-ONLY — iOS form is private @State-gated) | wired | WIRED 2026-07-04: `EditGroup` twin (composes CoverImagePicker .display / TextInput floating / MultilineTextInput / 3× bare ToggleControl in one group card / AgeRangeInput / MenuInput wheel — iOS-exact strings) + web-only compare captured; ToggleControl gained additive `bare`, AgeRangeInput additive `interactive` (invisible native selects, iOS wheel ranges); group-home-modal hosts it as the leading SlideStack detail (gearshape → seeded drafts — WEB DECISION: drafts not iOS live-bindings; Done = optimistic slide-back + fire-and-forget PATCH; cover = downscale 1200px JPEG → base64 JSON on Done; maxMembers null for Unlimited — iOS omits, can't clear). **SERVER FIX: memberDirectory added to PATCH+create zod → memberDirectoryEnabled column, exposed in all 4 group responses (was silently stripped for BOTH platforms; iOS toggle never persisted).** Build + 234 tests green. SPEC 2026-07-04 (`parity-edit-group` memory): exact strings for all 6 field groups; iOS quirks = LIVE group bindings (no draft) + optimistic Done (fire-and-forget PATCH, no spinner); cover = base64 JSON like program covers. ⚠️ SERVER BUG: `memberDirectory` missing from PATCH zod — silently dropped (fix required for the toggle to work). Outer SlideStack `.leading` detail of the .groupHome modal |
| Group Invite | `Pages/Manage/Group/GroupInvitePage.swift` | `group-invite` (WEB-ONLY, variants: default/toast/error) | wired | WIRED 2026-07-04: `GroupInvite` twin (code card w/ brand@0.2 stroke + brand@0.1 row, 264px white QR card rendering the REAL server bitmap, 3 BoxButtons, Copied toast — iOS-exact strings; fixture embeds a pre-generated deterministic QR for code ABC123; NEW `--color-brand-10` token); group-home-modal gained the INNER trailing SlideStack (rightScreen), paperplane + Invite button both open it (iOS handleInvite); store prefetches GET /api/groups/:id/invite during loadGroupHome (iOS :887); copy code/link → clipboard + 2s toast; Share Invite/Invite friends = navigator.share (iOS payload shapes) w/ copy fallback; join link opens origin+/join/group (env-aware, like iOS openJoinPage). Build + 234 tests green. SPEC 2026-07-04 (`parity-group-invite` memory). CORRECTION: does NOT use ShareInviteSheet/InviteQRCodeView — renders the plain 512px no-logo server QR from `GET /api/groups/:id/invite`; group URL `app.makeready.org/join/group/{code}` (≠ org-wide `www…/join/{code}`); shares TEXT+URL not the QR image. Trailing SlideStack pane (paperplane + Invite button) |
| Group members | `Pages/Manage/Group/Member/GroupMembersPage.swift` | `group-members-page` (WEB-ONLY, variants: default/requests/empty — NOT `group-members`, the TAB comparison) | wired | WIRED 2026-07-05: `GroupMembersPage` twin (floating SearchField + 60px pad + 52px mask-image fade, Requests section w/ Respond pills, "Members" header only when requests exist, CardMember rows w/ Joined/Requested "MMM d, yyyy", empty/error/no-results states — iOS-exact strings); CardMember gained additive `inviteLabel` ("Respond"); host: person.2 → `openMembers` (members fetched on pane open like iOS .task; requests warm from the badge prefetch — store keeps full rows now), search live client-side; member/request taps + Respond intentionally unbound (member-profile / member-request-respond items). Build + 234 tests green. SPEC 2026-07-05 (`parity-group-members` memory). CORRECTIONS: composes CardMember (NOT MemberListItem — no scrubber/sections), flat name-sorted list, floating SearchField over 60pt pad + 52pt gradient mask, Requests section ("Respond" purple ActionButton) with "Members" header only when requests exist. Member/request taps + Respond modal = separate items |
| Member profile | `Pages/Manage/Member/MemberProfilePage.swift` | — | — | |
| Member requests | `Pages/Manage/Member/MemberRequestsPage.swift` | — | — | the ONLY `.page` chrome route (horizontal push) — needs `managed-page.vue` |
| Member request respond | `MemberRequestRespondModal.swift` | — | — | topLevel raw |
| Change membership | `ChangeMembershipModal.swift` | — | — | topLevel raw |
| Member overview | `MemberOverview.swift` | — | — | |

## Enrollment flows (dismissOnTapOutside: false modals)

| Screen | iPhone source | Compare id | Status | Notes |
|---|---|---|---|---|
| Enrollment flow modal | `Group/Enrollment/EnrollmentFlowModal.swift` | — | — | multi-step: SelectGroup/SelectStudyProgram/ConfirmEnrollment/SelectEnrollDate |
| Enrollment schedule | `EnrollmentSchedulePage.swift` | — | — | entry: Program Home Enrollments tab + Groups Enrolled tab |
| Edit enrollment day | `EditEnrollmentDay.swift` | — | — | |
| Enrollments list | `EnrollmentsListPage.swift` | — | — | |
| Study invite | `StudyInvitePage.swift` | — | — | |
| Unenroll options | `UnenrollOptionsModal.swift` | — | — | UnenrollConfirmation twin exists |

## Other

| Screen | iPhone source | Compare id | Status | Notes |
|---|---|---|---|---|
| Org Home | `Pages/Manage/Org/OrgHomePage.swift` | — | — | |
| Invite contacts | `InviteContactsPage.swift` (Pages/…) | — | — | AddMenu → Invite member → Invite contacts |
| Share invite (QR) | `Components/Display/ShareInviteSheet.swift` | — | ✅ verified | `share-invite-sheet.vue` (predates overlay manager — migrate onto it) |
| Global AddMenu | `Components/Navigation/AddMenu.swift` | `AddMenu` (component) | ✅ verified | `add-menu-sheet.vue` (predates overlay manager — migrate) |
| Bible reader/page | `Pages/Bible/…` | `bible-passage-picker` (web-only) | — | large; decide scope separately. The PICKER overlay (BibleReaderOverlay: grids + reader + smart search + version menu) is already built as the `BiblePassagePicker` twin + `bible-passage-picker-host` + `leader-bible` store for edit-read-activity — a standalone reader page can reuse all of it |
| Video recording | `Pages/Video/…` | — | **excluded** | hardware capture — not portable |
| Lesson/Post/Event detail (search results) | `Pages/Search/*.swift` | — | — | after global search |

## Build queue (dependency-ordered)

`/parity-screen` with no argument takes the **first unchecked item** here.
Each item lists what it *needs* (must be checked first) and what it *unlocks*.
Check items off as they reach ✅ verified. Some items are foundation/work items
rather than literal screens — they still run through the same pipeline.

- [x] **program-home** + **edit-program** + **edit-day** + **edit-user-input-activity** + **edit-youtube-activity** — the study-management core (foundation: overlay system, SlideStack, animated border)
- [x] **swipeable-card + drag-reorder** — ✅ verified 2026-07-02. SwipeableCard twin has full iOS mechanics (progressive 24→48 reveal, velocity snap, tap-to-close, `action`/`tap` emits, `bare` mode); new `dragula-list` twin (long-press lift, white@6% 48px indicator, FLIP reorder). Wired: lesson delete+reorder (Program Home), activity reset/clear/delete+reorder (EditDay, iOS gating incl. rawStatus COMPLETE), program delete (Library, creator-gated via island `memberId`), exact iOS confirm strings (DialogOverlay + additive `destructive` style). Spec memory: `parity-swipeable-drag-reorder`. Unlocked: group/enrollment swipe actions later.
- [x] **program-publish-export** — ✅ verified 2026-07-02. Publish badge → Publish/Unpublish DialogOverlay (exact strings) with the zero-activity "Cannot Publish" gate; share icon → GET export-preview → new `export-confirm-overlay` twin (Kpi iconValue grid) → POST export (binary via proxy passthrough) → ConfirmationOverlay (additive secondary button) via the `.confirmationOverlay` route (`confirmation-overlay-modal.vue` host), Save = download `.makeready` / Discard. No compare fixture (ExportConfirmOverlay is private on iOS). Spec memory: `parity-publish-export`. Program Home chrome complete except the eye/preview icon.
- [x] **create-program** — `CreateProgramPage.swift` (ViewRegistry `pages.create-program` exists). Needs: nothing (reuses Edit Program form pieces). Unlocks: Library plus-menu "Study Program" item. **Status: wired, diff clean** — `create-program` twin (empty-form defaults = the iPhone ViewRegistry render; capture-only statusBar; additive MenuInput `interactive` native-select mode), compare fixture+adapter registered, BOTH shots captured, all compare pins resolved (last: `.ToggleControl` BEM collision with the legacy form variant — renamed to `.ToggleRow`; the toggle-description wrap now matches iOS exactly), store createProgram/loadTemplates/addTags (cover + tags synced AFTER create like iOS), `.createProgram` overlay route, dismiss-then-present from the Library create menu, post-create in-place slide to Program Home (`preloaded`). Build+tests green. Spec memory: `parity-create-program`. ✅ verified 2026-07-03.
- [x] **managed-menu chrome** — `managed-menu.vue` (iOS ManagedMenuView: content-sized bottom card, #111215 fill, #242937 stroke, shadow, same springs) wired into overlay-host. Needs: nothing. Unlocks: every `.menu`-priority route (filter/style/highlight/user menus). **Status: wired** — chrome built + `menu` branch in overlay-host; first consumer = `.libraryAddMenu` (Library "+" create menu migrated off LeaderMenuOverlay onto the overlay manager with real `dismissThen` → `.createProgram`; the setTimeout hack is gone). SPEC CORRECTIONS (see `parity-managed-menu` memory): EditDay does NOT present `.lessonActionMenu` (GroupHome/EnrollmentSchedule/Calendar/MainHome do — wire when those port); the Library sort menu is a native SwiftUI `Menu` popover, NOT ManagedMenuView (`.librarySortMenu` route is registered-but-unused on iOS — library-filters-sort item must pick a web equivalent). No compare fixture: same precedent as managed-modal (chrome verified live through consumers; ActionCardMenu content already compare-verified; ManagedMenuView's deferred entrance would snapshot offscreen). Build + host tests green. ✅ verified 2026-07-03.
- [x] **library-filters-sort** — ✅ verified 2026-07-03. Library filter chip dropdowns + Browse-all sort menus. Needs: managed-menu chrome (✓). **COMPARE (policy 2026-07-03): filter states previewable** — LibraryPrograms/LibraryMedia twins gained additive chips/sortLabel/openPanel props; study-programs variants default/filters-active/tags-panel-open + media filters-active captured (web-forward — iPhone panes show the default tab, see fixture notes). Sort MENU itself still has no fixture (managed-menu chrome precedent). **Status: wired** — FilterChipDropdown twin gained ADDITIVE `interactive` mode (live search, toggle/clearAll emits; captured rendering unchanged, recaptured to confirm); library-view chips are live triggers (iOS labels incl. "My content"/"N tags", active = white capsule) with the instant no-animation panel overlay + black@0.5 scrim under the sticky top bar; tags/leaders/type filters REFETCH server-side (?tag/?leaders/?tags/?type via proxy), media time + both sorts client-side; FilterState persistence to /api/preferences/filters.library.{programs,media} (1500ms debounce, iOS-shape JSON incl. enum display-strings, "My content" leaders default when no explicit pref); sort menus present via managed-menu on `.librarySortMenu` (iOS uses a native Menu popover — no web idiom; checkmark rows). Spec memory: `parity-library-filters-sort`.
- [x] **edit-read-activity** — ✅ verified 2026-07-04. `EditReadActivityPage.swift` (ViewRegistry exists). The deepest editor: read blocks (RichTextInput ✓ + DragulaView), third-level SlideStack to BlockStyleEditor (StylePickerMenu ✓, BackgroundSwatch ✓, CoverImagePicker ✓), MediaLibraryPicker pane. Needs: swipeable-card + drag-reorder, managed-menu chrome. **FULLY wired 2026-07-03, verified 2026-07-04** (see row). Also produced the shared confirm-dialog service + animated toggles/expand-collapse (foundation).
- [ ] **edit-exegesis-activity** — `EditExegesisActivityPage.swift` (ViewRegistry exists). Needs: edit-read-activity (✓) + managed-menu chrome (✓). **Status: WIRED 2026-07-04** (see row). Awaiting live verify.
- [ ] **video-activity-picker** — **Status: wired** (see row). PICKING from uploaded library only — device pick/recording/upload are hardware scope, excluded. Needs: nothing. Awaiting live verify.
- [ ] **program-enrollments-tab** — **Status: wired.** ProgramHome twin tab 1 extended ADDITIVELY (enrollments/enrollmentsLoading props + addEnrollment/selectEnrollment emits): 3× SkeletonCardGroup loading, CardGroup rows (new additive `subtitle` prop = creator name; clock metadata = iOS dateRangeString "MMM D - MMM D" uppercased local-tz, start-only when no end; NO member count — iOS omits it) + plus BoxButton; empty state corrected to iOS strings ("Groups enrolled in this program will appear here") + add button. Store loadProgramEnrollments (GET /api/programs/:id/enrollments); modal loads once on first tab select (iOS .task). Row tap + add INERT (enrollment-schedule/flow are later items). COMPARE: 'enrollments' variant added (2026-07-03, web-forward — iPhone pane stays on tab 0, see fixture note); tab-0 capture confirmed unchanged. Needs: nothing. Unlocks: enrollment-flow entry points. Awaiting live verify.
- [ ] **group-home** — `GroupHomePage.swift`. **Status: WIRED 2026-07-04** (see row). SlideStack `detailEdge: leading` foundation BUILT (consumed by edit-group next). Unlocks: the whole group chain. Awaiting live verify.
- [ ] **edit-group** — the INLINE `editGroupContent` form in `GroupHomePage.swift:381-529`. **Status: WIRED 2026-07-04** (see row) — first consumer of SlideStack `detailEdge: leading`; server memberDirectory zod fix included. Awaiting live verify (with group-home).
- [ ] **group-invite** — `GroupInvitePage.swift`. **Status: WIRED 2026-07-04** (see row) — inner trailing SlideStack added to the group-home host (members/enrollments panes plug into it next). Groups-header paperplane still TODO (needs a group picker or per-group entry — decide when wiring). Awaiting live verify (with group-home).
- [ ] **group-members** — `GroupMembersPage.swift`. **Status: WIRED 2026-07-05** (see row; SPEC CORRECTION: uses CardMember, NOT MemberListItem). Awaiting live verify (with the group chain).
- [ ] **member-profile** — `MemberProfilePage.swift`. Needs: group-members.
- [ ] **managed-page chrome + member-requests** — `managed-page.vue` (iOS ManagedPageView horizontal push: easeOut 300ms in / easeIn 250ms out, edge-swipe back) + `MemberRequestsPage.swift` (its only consumer). Needs: group-members.
- [ ] **member-request-respond + change-membership** — the two topLevel raw modals. Needs: member-requests.
- [ ] **enrollment-flow** — `EnrollmentFlowModal.swift` multi-step (SelectGroup / SelectStudyProgram / ConfirmEnrollment / SelectEnrollDate; dismissOnTapOutside: false; CardStudySelectable ✓, GroupSelectorSheet ✓, DatePickerField ✓). Needs: program-enrollments-tab, group-home.
- [ ] **enrollment-schedule** — `EnrollmentSchedulePage.swift` + `EditEnrollmentDay.swift` + `UnenrollOptionsModal.swift` (UnenrollConfirmation ✓, ScheduledLessonCard ✓). Needs: enrollment-flow.
- [ ] **calendar** — `MainCalendar.swift` (month grid component is new; UpcomingLessonCard ✓, WeekdayIndicator ✓). Needs: nothing (richer once enrollment-schedule exists).
- [ ] **global-search** — `GlobalSearchPage.swift` (SearchableList ✓; per-entity result modals use string-keyed overlay ids). Needs: managed-menu chrome.
- [ ] **search-detail-pages** — `LessonDetailPage` / `PostDetailPage` / `EventDetailPage`. Needs: global-search.
- [ ] **profile** — `ProfilePage.swift` (UserMenu twin ✓). Needs: nothing.
- [ ] **notification-feed** — `NotificationFeedPage.swift` + PageHeader bell wiring. Needs: nothing (deep links richer as screens land).
- [ ] **org-home** — `OrgHomePage.swift`. Needs: nothing.
- [ ] **invite-contacts** — `InviteContactsPage.swift` (AddMenu → Invite member → Invite contacts). Needs: nothing.
- [ ] **overlay-migration cleanup** — move the pre-overlay-manager surfaces (dashboard AddMenuSheet, ShareInviteSheet, Library create-menu / LeaderMenuOverlay) onto the overlay manager + managed-menu chrome. Needs: managed-menu chrome. Do last-ish; pure refactor.
