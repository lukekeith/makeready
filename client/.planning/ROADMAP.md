# Roadmap: MakeReady Laravel Migration

## Overview

Full big-bang migration of the React SPA to Laravel 12 with Blade templates + Vue.js islands (no Inertia, no Node runtime), driven by Twilio A2P compliance requirements. The migration progresses in four coarse phases: first proving the deployment infrastructure and shipping compliance pages (the primary goal), then building the Blade + Vue hybrid component library, then migrating all interactive member-facing pages, and finally delivering content features and the admin panel before cutover.

After v1.0 ships, v2.0 adds a full web-based admin CRUD panel (phases 5-9) giving group leaders the same capabilities as the iPhone app. v2.1 adds a unified member management interface at /admin/members with cross-group views, tag-based filtering, member profile drill-down, and activity history replay.

## Milestones

- ✅ **v1.0 Laravel Migration** - Phases 1-4 (shipped 2026-03-18)
- 🚧 **v2.0 Admin CRUD Panel** - Phases 5-9 (in progress)
- 📋 **v2.1 Member Management & Activity History** - Phases 10-14 (planned)

## Phases

<details>
<summary>✅ v1.0 Laravel Migration (Phases 1-4) - SHIPPED 2026-03-18</summary>

- [x] **Phase 1: Foundation + Compliance** - Laravel + Blade SSR on Railway (PHP-FPM + Nginx), cookie proxy auth, compliance pages shipped (completed 2026-03-17)
- [x] **Phase 2: Component System** - Blade + Vue hybrid component library: ~52 Blade components for server rendering, ~8 Vue islands for interactivity, PHP CVA helper, BEM SCSS (completed 2026-03-17)
- [x] **Phase 3: Join Flows + Member Pages** - All join flows and authenticated member pages migrated (completed 2026-03-18)
- [x] **Phase 4: Content + Admin + Cutover** - Lesson activity, admin panel, infrastructure hardening, and production cutover (completed 2026-03-18)

### Phase 1: Foundation + Compliance
**Goal**: The Laravel app runs on Railway with Blade templates producing server-rendered HTML, the cookie proxy auth layer proves round-trip login works, and compliance pages are publicly crawlable
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, COMP-01, COMP-02, COMP-03, COMP-04, INFR-01, INFR-02
**Success Criteria** (what must be TRUE):
  1. `curl https://[railway-url]/privacy` returns the privacy page content in the raw HTML response body (not a blank div)
  2. `curl https://[railway-url]/terms` returns the terms page with STOP and HELP visible in bold in the raw HTML
  3. An unauthenticated request to a protected route (`/home`) receives a server-side redirect (HTTP 302), not a blank page
  4. The cookie proxy auth middleware forwards API session cookies correctly (verified via tests)
  5. The Railway deployment runs PHP-FPM + Nginx via custom Dockerfile; deploying a new commit serves the app correctly
**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Archive React SPA, init Laravel 12, Vite config, Dockerfile, shared layout
- [x] 01-02-PLAN.md — API service layer, cookie proxy, auth middleware
- [x] 01-03-PLAN.md — Compliance pages (privacy, terms, sms-opt-in)
- [x] 01-04-PLAN.md — CI/CD pipeline + end-to-end verification

### Phase 2: Component System (REVISED — Blade + Vue Hybrid)
**Goal**: Every presentation-only component exists as a Blade component with correct visual fidelity, interactive components remain as Vue SFCs, the PHP CVA helper maps variants to BEM classes, and all SCSS compiles through Vite
**Depends on**: Phase 1
**Requirements**: CSYS-01, CSYS-02, CSYS-03, CSYS-04, CSYS-05, CSYS-06, CSYS-07, CSYS-08
**Success Criteria** (what must be TRUE):
  1. A `<x-primitive.button variant="Primary">` renders with correct BEM classes (`Button Button--primary`) in the HTML response
  2. All ~60 component SCSS files compile through Vite without errors (`npm run build` passes)
  3. The Navigation Blade component renders with correct selected state based on server-side route detection
  4. Histoire shows stories for the ~8 interactive Vue components (PhoneEntry, Modal, etc.)
  5. Only ~8 Vue SFCs remain in resources/js/components/ — all others are Blade at resources/views/components/
  6. `php artisan test` passes all component smoke tests
**Plans:** 7/3 plans complete

Plans (original Vue-only — completed before architecture revision):
- [x] 02-01-PLAN.md — Infrastructure: CVA wrapper, Histoire, Pinia modal store, layouts, reference Button
- [x] 02-02-PLAN.md — All 21 remaining primitive Vue components
- [x] 02-03-PLAN.md — All 29 domain Vue components
- [x] 02-04-PLAN.md — 5 panel components, barrel export

Plans (REVISED — Blade + Vue hybrid conversion):
- [x] 02-05-PLAN.md — Foundation: PHP cva() helper, SCSS relocation, app.scss imports, test scaffold
- [x] 02-06-PLAN.md — All ~52 anonymous Blade components (primitives, domain, layout, panel)
- [x] 02-07-PLAN.md — Cleanup: remove replaced Vue SFCs/stories, update app.js, visual verification

### Phase 3: Join Flows + Member Pages
**Goal**: A new member can join a group and complete the full onboarding flow, and an existing member can navigate all authenticated member pages
**Depends on**: Phase 2
**Requirements**: JOIN-01, JOIN-02, JOIN-03, JOIN-04, JOIN-05, JOIN-06, JOIN-07, MEMB-01, MEMB-02, MEMB-03, MEMB-04, MEMB-05, MEMB-06, MEMB-07
**Success Criteria** (what must be TRUE):
  1. A user can enter a group code, complete profile, phone, and verification steps, tick the SMS consent checkbox, and land on the group home page — with join flow state surviving a page refresh mid-flow
  2. The SMS consent checkbox is unchecked by default and submission is blocked server-side if it is not checked
  3. A logged-in member can view their groups list, navigate to a group home page, and see studies and events
  4. A member can view and edit their profile and see changes reflected after saving
  5. The public landing page and login page render with full content visible in the raw HTML response (SSR verified via curl)
**Plans:** 4/4 plans complete

Plans:
- [x] 03-01-PLAN.md — Foundation: layouts (auth + home), Vue AJAX islands (JoinPhoneIsland, JoinVerifyIsland), routes, test scaffolds
- [x] 03-02-PLAN.md — All join flows: group join (5 steps), event join (4 steps), study join (4 steps), join code entry
- [x] 03-03-PLAN.md — Public home page + member login flow (phone auth) + logout
- [x] 03-04-PLAN.md — Authenticated member pages: home, groups list, group home, profile view/edit

### Phase 03.1: Visual Fidelity — Rewrite all Blade components and page templates to produce HTML/CSS identical to the original React app (INSERTED)

**Goal:** Every Blade page template and component produces HTML with the same BEM class names, DOM nesting, and SCSS styling as the original React app — achieving pixel-level visual fidelity across all 16 pages
**Requirements**: VF-SCSS, VF-HTML, VF-COMP, VF-PAGE, VF-ALL
**Depends on:** Phase 3
**Success Criteria** (what must be TRUE):
  1. All 14 page-level SCSS files from the React archive exist in `resources/css/pages/` and compile via `npm run build`
  2. Every Blade page template uses the same root BEM class as its React equivalent (e.g., `MemberHomePage` not `HomeAuthenticated`)
  3. Button component always wraps content in `Button__content` span, Jump variants render `Button__details`
  4. No Blade page contains extra `<section>`, `<h2>`, or wrapper elements that the React page does not render
  5. Human visual comparison confirms pages look identical to the React app
**Plans:** 4 plans

Plans:
- [x] 03.1-01-PLAN.md — SCSS foundation: migrate 14 page SCSS files, fix Button inner structure, create VisualFidelityTest
- [x] 03.1-02-PLAN.md — Rewrite 6 core pages (public-home, home, group-home, study-home, login, profile)
- [x] 03.1-03-PLAN.md — Rewrite 10 remaining pages (join flows, previews, admin, groups, lesson, study-code)
- [x] 03.1-04-PLAN.md — Full automated + visual verification checkpoint

### Phase 4: Content + Admin + Cutover
**Goal**: Lesson activity with video and rich text works, the admin panel is accessible to leaders, all edge-case pages exist, and the app is ready to replace the React SPA in production
**Depends on**: Phase 3
**Requirements**: CONT-01, CONT-02, CONT-03, CONT-04, CONT-05, CONT-06, CONT-07, ADMN-01, INFR-03, INFR-04
**Success Criteria** (what must be TRUE):
  1. A member can open a lesson, play an HLS video, and write a SOAP journal entry using the BulletTextInput contenteditable editor — all without SSR hydration errors in the browser console
  2. A non-member can access a study preview or lesson preview page and see content in the raw HTML response
  3. An organisation leader can access the admin panel; a non-leader receives a 403 response
  4. Navigating to a non-existent URL renders the 404 Blade page with visible content (not a blank page)
  5. The production Railway deployment serves the Laravel app at the live domain with all pages returning correct HTTP status codes
**Plans:** 4/4 plans complete

Plans:
- [x] 04-01-PLAN.md — Study home page + LessonIsland Vue SPA + lesson activity page with AJAX proxy routes
- [x] 04-02-PLAN.md — Admin panel + study code entry + error pages (404/500)
- [x] 04-03-PLAN.md — Public preview pages (study + lesson preview with isPreview mode)
- [x] 04-04-PLAN.md — Production cutover: push to Railway, verify live, rollback plan

</details>

---

### v2.0 Admin CRUD Panel (In Progress)

**Milestone Goal:** Group leaders can manage their entire organization from the web — full CRUD for programs, groups, enrollments, lessons, activities, members, and posts — matching the capabilities of the iPhone leader app.

**Phase Numbering:**
- Decimal phases (3.1) inserted between integers in numeric order
- v2.0 begins at Phase 5

- [ ] **Phase 5: Admin Shell** - Single AdminIsland Vue app with Pinia, Vue Router, sidebar nav, avatar menu, and experience toggle
- [x] **Phase 6: Groups CRUD** - Full group management with cover image upload, settings, and tabbed detail view (completed 2026-03-20)
- [x] **Phase 7: Programs + Lessons** - Study program CRUD with nested lessons management and reorder (completed 2026-03-20)
- [x] **Phase 8: Activity Editor** - Per-lesson activity CRUD with plain text editor, type-specific fields, and reorder (completed 2026-03-20)
- [x] **Phase 9: Members, Enrollments, Posts, Analytics, Profile** - Remaining entity management, analytics dashboard, and profile editing (completed 2026-03-20)

### Phase 5: Admin Shell
**Goal**: Group leaders can access a fully operational admin panel shell — authenticated, client-side-navigable, and free of CSRF failures — before any domain-specific CRUD is built
**Depends on**: Phase 4
**Requirements**: SHELL-01, SHELL-02, SHELL-03, SHELL-04, SHELL-05, SHELL-06, SHELL-07
**Success Criteria** (what must be TRUE):
  1. Leader navigates to /admin and sees the admin layout with sidebar navigation and avatar menu, without a full page reload when switching between sections
  2. Unauthenticated user accessing /admin is redirected to the login page server-side
  3. Leader clicks "Member Experience" in the avatar menu and lands on /member/home; a member clicks "Group Leader Admin" in their avatar menu and lands on /admin
  4. A POST request from within AdminIsland reaches the Laravel API proxy and succeeds with a 200 (not a 419 CSRF failure)
  5. Navigating between admin sections via sidebar links does not destroy Vue state or Pinia store data
**Plans:** 2/3 plans complete

Plans:
- [x] 05-01-PLAN.md — Server infrastructure: catch-all route, admin Blade layout, AdminController, ApiService.delete(), app.js wiring, test scaffolds
- [x] 05-02-PLAN.md — AdminIsland Vue app: sidebar nav, Vue Router, section placeholders, avatar menu, CSRF config, SCSS
- [ ] 05-03-PLAN.md — Experience toggle: "Group Leader Admin" link in member navigation avatar menu

### Phase 6: Groups CRUD
**Goal**: Leader can create, view, edit, and delete groups with cover images and settings, and see a tabbed detail view ready for members, enrollments, and posts
**Depends on**: Phase 5
**Requirements**: GRP-01, GRP-02, GRP-03, GRP-04, GRP-05, GRP-06, GRP-07
**Success Criteria** (what must be TRUE):
  1. Leader sees a table of all their groups with name, cover image thumbnail, member count, and privacy status
  2. Leader creates a new group, uploads a cover image (tested with a file 3-4 MB), and the group appears in the list
  3. Leader edits group metadata and settings (name, description, welcome message, privacy, max members) and changes are reflected after saving
  4. Leader deletes a group after confirming the dialog, and the group is removed from the list
  5. Group detail page shows tabs for Members, Enrollments, Posts, and Settings with correct tab switching
**Plans**: 3 plans

Plans:
- [ ] 06-01-PLAN.md — Server infrastructure: AdminApiProxyController, route registration, GroupsAdminTest scaffold
- [ ] 06-02-PLAN.md — Pinia stores, reusable admin components (AdminTable, AdminForm, AdminConfirmDialog), groups list CRUD
- [ ] 06-03-PLAN.md — Group detail view with tabs, settings form, cover image upload

### Phase 7: Programs + Lessons
**Goal**: Leader can create, publish, and manage study programs with nested lessons in the correct day order
**Depends on**: Phase 5
**Requirements**: PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-06, PROG-07, LSSN-01, LSSN-02, LSSN-03, LSSN-04, LSSN-05
**Success Criteria** (what must be TRUE):
  1. Leader sees a table of all study programs with name, cover image thumbnail, lesson count, and publish status (draft/published)
  2. Leader creates a program using a template selector, uploads a cover image, and the program appears in the list
  3. Leader toggles a program between published and draft, and the status updates immediately in the list
  4. Leader opens a program detail, sees the ordered lesson list, and can add a lesson, edit its title, delete it, and reorder it (up/down)
  5. Leader deletes a program after confirming the dialog, and it disappears from the list
**Plans**: 3 plans

Plans:
- [ ] 07-01-PLAN.md — ProgramsAdminTest scaffold, programs domain store, programs list and detail UI stores
- [ ] 07-02-PLAN.md — Programs list view with create (template selector), edit, delete CRUD
- [ ] 07-03-PLAN.md — Program detail with tabs, cover image, publish toggle, lessons management with drag-and-drop reorder

### Phase 8: Activity Editor
**Goal**: Leader can manage all activities within a lesson — adding typed activities, editing content, managing scripture references and read blocks, and reordering
**Depends on**: Phase 7
**Requirements**: ACTV-01, ACTV-02, ACTV-03, ACTV-04, ACTV-05, ACTV-06, ACTV-07, ACTV-08, ACTV-09
**Success Criteria** (what must be TRUE):
  1. Leader opens a lesson and sees the list of activities with type badge and title; activities reflect the current saved order
  2. Leader adds a new activity, selects a type (READ, VIDEO, SOAP, OIA, DBS, HEAR, USER_INPUT), and it appears in the list
  3. Leader edits a READ activity and types plain text content using a textarea; saving the activity does not corrupt the content visible to members in the lesson
  4. Leader adds scripture source references on an activity and saves successfully
  5. Leader reorders activities and the new order persists after page reload
**Plans**: 3 plans

Plans:
- [ ] 08-01-PLAN.md — Test scaffold, domain store activity CRUD, UI stores (program-detail expand, activity-detail editor)
- [ ] 08-02-PLAN.md — Activity list component with type badges, add/delete/reorder, integration into Lessons tab accordion
- [ ] 08-03-PLAN.md — Type-gated activity editor panel, read blocks CRUD, source references, help panel, reset

### Phase 9: Members, Enrollments, Posts, Analytics, Profile
**Goal**: Leader can manage group memberships, enroll groups in programs, create group posts, view engagement analytics, and edit their own profile
**Depends on**: Phase 7 (enrollments need programs), Phase 6 (members/posts/enrollments are group-scoped)
**Requirements**: MMBR-01, MMBR-02, MMBR-03, MMBR-04, MMBR-05, MMBR-06, ENRL-01, ENRL-02, ENRL-03, ENRL-04, ENRL-05, SCHD-01, SCHD-02, SCHD-03, SCHD-04, POST-01, POST-02, POST-03, POST-04, POST-05, POST-06, ANLT-01, ANLT-02, ANLT-03, ANLT-04, PROF-01, PROF-02
**Success Criteria** (what must be TRUE):
  1. Leader views the members tab of a group, sees pending requests with approve/reject buttons, approves a request, and the member moves to the active list with the correct role
  2. Leader creates an enrollment for a group by selecting a program, a start date, enabled days, SMS time, and timezone; the enrollment appears in the group's enrollments tab with a lesson schedule
  3. Leader creates a group post of each type (announcement, poll, event, video), and the posts appear in the posts list with correct type and preview
  4. Leader opens the analytics dashboard and sees KPI cards (group count, member count, active enrollments), the engagement heatmap, and the weekly activity chart populated with real data
  5. Leader edits their profile name and uploads a new profile picture, and the changes are reflected in the avatar menu
**Plans**: 6 plans

Plans:
- [ ] 09-01-PLAN.md — Test scaffold + Members tab (stores, list, approve/reject, profile, role change, remove)
- [ ] 09-02-PLAN.md — Enrollments tab (stores, list, create form with day checkboxes, delete with unenroll info)
- [ ] 09-03-PLAN.md — Enrollment detail with scheduled lessons CRUD (view, edit title, add, delete)
- [ ] 09-04-PLAN.md — Posts tab (stores, paginated list, type-aware create form)
- [ ] 09-05-PLAN.md — Analytics dashboard (ApexCharts install, KPI cards, heatmap, weekly chart, calendar)
- [ ] 09-06-PLAN.md — Profile section (memberId prop plumbing, name edit, avatar upload)

---

### v2.1 Member Management & Activity History (Planned)

**Milestone Goal:** Group leaders can see, manage, and understand every member across their entire organization from a single unified interface at /admin/members — with cross-group aggregation, tag-based filtering, member profile drill-down, multi-group assignment, and full activity history replay.

- [x] **Phase 10: Foundation** - Register /admin/members route, install TanStack packages, add Members sidebar nav item (completed 2026-03-21)
- [x] **Phase 11: Cross-Group Aggregation** - Domain stores for fan-out member aggregation (all-members.domain) and activity history shell (member-activity.domain) (completed 2026-03-21)
- [x] **Phase 12: Virtualized Member Table + Tag Filters** - AdminVirtualTable component, MemberFilterBar, members-list.ui store, MembersSection wired end-to-end (completed 2026-03-21)
- [x] **Phase 13: Member Profile Drawer** - MemberProfileDrawer with contact info, multi-group assignment, and enrollment progress summary (completed 2026-03-21)
- [ ] **Phase 14: Activity History** - Lesson completion list, full activity replay, per-enrollment timeline, and activity log (gated on API verification)

## Phase Details

### Phase 10: Foundation
**Goal**: The /admin/members route is registered and navigable, TanStack Table and Virtual packages are installed, and the Members link appears in the admin sidebar — so the entire feature is reachable from day one of development
**Depends on**: Phase 9
**Requirements**: MLIST-08
**Success Criteria** (what must be TRUE):
  1. Leader clicks "Members" in the admin sidebar and navigates to /admin/members without being redirected to the dashboard
  2. Navigating directly to /admin/members in the browser address bar loads the page (not a catch-all redirect)
  3. `npm install` completes with `@tanstack/vue-table` and `@tanstack/vue-virtual` present in package.json
**Plans**: 1 plan

Plans:
- [ ] 10-01-PLAN.md — Install TanStack packages, register /admin/members route, add Members sidebar nav item

### Phase 11: Cross-Group Member Aggregation
**Goal**: A reactive, deduplicated flat array of all members across all leader groups is available in Pinia — loaded in parallel with per-group error resilience — so every downstream feature has a correct data foundation
**Depends on**: Phase 10
**Requirements**: MLIST-01
**Success Criteria** (what must be TRUE):
  1. Leader navigating to /admin/members triggers a parallel load of all groups; the member list populates without waiting for all groups to finish
  2. A member who belongs to two groups appears exactly once in the list, with both group names shown on their row
  3. If one group's member API call fails, the remaining members from other groups still appear and a warning banner lists the failed group by name
**Plans**: 1 plan

Plans:
- [ ] 11-01-PLAN.md — all-members.domain fan-out store with deduplication, member-activity.domain shell, members-section.vue mount wiring

### Phase 12: Virtualized Member Table + Tag Filters
**Goal**: Leaders can view all members in a performant virtualized table and narrow the list by name search, group, lesson completion status, or activity type using tag chips — with all filter state owned exclusively by Pinia
**Depends on**: Phase 11
**Requirements**: MLIST-02, MLIST-03, MLIST-04, MLIST-05, MLIST-06, MLIST-07, MLIST-09
**Success Criteria** (what must be TRUE):
  1. Leader types a name into the search input; pressing enter or clicking "Add" adds a filter chip and the table updates to show matching members
  2. Leader selects a group chip, a lesson status chip, and an activity type chip simultaneously; the table shows only members matching all active filters
  3. Leader clicks the X on an individual chip to remove it; the table updates immediately to reflect the removal
  4. Leader clicks "Clear all" and all filter chips disappear and the full member list is restored
  5. Each member row displays name, avatar, group membership chips, and last active date
**Plans**: 2 plans

Plans:
- [ ] 12-01-PLAN.md — members-list.ui Pinia store, AdminVirtualTable component with TanStack Virtual spacer-row pattern, SCSS
- [ ] 12-02-PLAN.md — MemberFilterBar component with reka-ui Combobox, members-section.vue full wiring, smoke test

### Phase 12.1: Migrate admin to shadcn-vue + Tailwind (INSERTED)

**Goal:** Replace all BEM admin components with shadcn-vue equivalents, install and scope Tailwind CSS v4 to the admin island only, and delete all admin SCSS files — so the admin panel looks and feels like a modern shadcn app with dark zinc theme while member-facing Blade pages remain untouched
**Requirements**: INFRA-TW, INFRA-SHADCN, SHELL-SIDEBAR, SHELL-LAYOUT, COMP-TABLE, COMP-DIALOG, COMP-FORM, COMP-UPLOAD, COMP-ACTIVITY, COMP-VTABLE, COMP-FILTER, COMP-DRAWER, SECT-DASH, SECT-GROUPS, SECT-PROGRAMS, SECT-PROFILE, SECT-MEMBERS, SCSS-CLEANUP
**Depends on:** Phase 12
**Success Criteria** (what must be TRUE):
  1. Admin panel renders with shadcn dark zinc theme; member-facing Blade pages are visually unaffected
  2. Sidebar collapses to icon-only mode and expands back, with correct navigation active states
  3. All 5 section views (Dashboard, Groups, Programs, Profile, Members) render using shadcn components and Tailwind classes
  4. Virtual member table still scrolls smoothly with 500+ rows using TanStack Virtual
  5. Member profile drawer slides from right using shadcn Sheet with proper animation
  6. All 16 admin SCSS files are deleted and app.scss has zero admin @use imports
  7. `npm run build` passes with both SCSS and Tailwind compiling successfully
**Plans:** 5/5 plans complete

Plans:
- [ ] 12.1-01-PLAN.md — Infrastructure: install Tailwind v4, shadcn-vue, vee-validate, lucide; create admin.css with source(none) scoping; update vite.config and admin Blade layout
- [ ] 12.1-02-PLAN.md — Shell + core components: rewrite admin-island.vue (SidebarProvider), admin-sidebar.vue (shadcn Sidebar), AdminConfirmDialog (AlertDialog), AdminTable (shadcn Table)
- [ ] 12.1-03-PLAN.md — Form + media components: rewrite AdminForm (shadcn inputs), AdminImageUpload (Avatar), AdminActivityList (Accordion + Badge)
- [ ] 12.1-04-PLAN.md — Members components: rewrite AdminVirtualTable (hybrid shadcn Table + TanStack Virtual), MemberFilterBar (Combobox + Badge), MemberProfileDrawer (Sheet)
- [ ] 12.1-05-PLAN.md — Section views + SCSS cleanup: update all 5 section views to Tailwind, delete 16 admin SCSS files, remove app.scss imports, human verification

### Phase 13: Member Profile Drawer
**Goal**: Leaders can open any member's full profile from the member list — seeing contact details, group memberships, and enrollment progress summary — and can add or remove the member from groups directly in the drawer
**Depends on**: Phase 12
**Requirements**: MPROF-01, MPROF-02, MPROF-03, MPROF-04, MPROF-05
**Success Criteria** (what must be TRUE):
  1. Leader clicks a member row and a slide-over drawer opens immediately, showing name, phone, email, avatar, groups, and joined date
  2. Leader sees enrollment progress for each program the member is enrolled in, showing percentage complete and completed/total lesson count
  3. Leader clicks "Add to group", selects a group the member is not already in, and the member's group chips update in the drawer
  4. Leader clicks "Remove from group" next to a group, confirms the dialog, and that group is removed from the member's drawer without closing the drawer
  5. The drawer does not expose any edit controls for name, phone, or email — all contact info is display-only
**Plans**: 2 plans

Plans:
- [ ] 13-01-PLAN.md — member-detail.ui store, MemberProfileDrawer component with contact info, groups, enrollment progress, SCSS
- [ ] 13-02-PLAN.md — Group add/remove actions, confirm dialog, row click wiring, cache invalidation, human verification

### Phase 14: Activity History
**Goal**: Leaders can navigate a member's full lesson history — seeing completion status per lesson, replaying written responses and video progress, and viewing a per-enrollment day-by-day timeline — all read-only
**Depends on**: Phase 13
**Requirements**: MACT-01, MACT-02, MACT-03, MACT-04, MACT-05, MACT-06
**Success Criteria** (what must be TRUE):
  1. Leader opens a member profile and sees a list of all lessons the member has participated in, each with a status chip (completed, in-progress, or upcoming)
  2. Leader clicks a lesson and sees the full activity replay: SOAP journal entries, USER_INPUT responses, and video watch progress rendered in human-readable form (not raw JSON)
  3. Leader types in the activity history search box and the lesson list filters to matching lesson titles, enrollment names, or completion statuses
  4. Leader opens an enrollment's day-by-day timeline and sees which lessons were completed on which dates
  5. Leader views the activity log tab and sees timestamped auth, join, and access events for the member
  6. No edit, delete, or reply controls appear anywhere in the activity history view
**Plans**: 0/TBD

Plans:
- TBD (gated on API verification)

**Research gate:** Phase 14 must not begin until `GET /admin/api/members/:memberId/lessons` (or equivalent admin-scoped path) is called directly and the response shape, auth pattern (isGroupLeader bypass), and written-response content format (Lexical JSON vs HTML vs plain text) are confirmed. Run `/gsd:research-phase 14` before planning.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 3.1 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 12.1 → 13 → 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation + Compliance | v1.0 | 4/4 | Complete | 2026-03-17 |
| 2. Component System | v1.0 | 7/7 | Complete | 2026-03-17 |
| 3. Join Flows + Member Pages | v1.0 | 4/4 | Complete | 2026-03-18 |
| 3.1 Visual Fidelity | v1.0 | 4/4 | Complete | 2026-03-18 |
| 4. Content + Admin + Cutover | v1.0 | 4/4 | Complete | 2026-03-18 |
| 5. Admin Shell | v2.0 | 2/3 | In Progress | - |
| 6. Groups CRUD | v2.0 | 3/3 | Complete | 2026-03-20 |
| 7. Programs + Lessons | v2.0 | 3/3 | Complete | 2026-03-20 |
| 8. Activity Editor | v2.0 | 3/3 | Complete | 2026-03-20 |
| 9. Members, Enrollments, Posts, Analytics, Profile | v2.0 | 6/6 | Complete | 2026-03-20 |
| 10. Foundation | v2.1 | 1/1 | Complete | 2026-03-21 |
| 11. Cross-Group Member Aggregation | v2.1 | 1/1 | Complete | 2026-03-21 |
| 12. Virtualized Member Table + Tag Filters | v2.1 | 2/2 | Complete | 2026-03-21 |
| 12.1 Migrate Admin to shadcn-vue + Tailwind | 5/5 | Complete   | 2026-03-22 | - |
| 13. Member Profile Drawer | v2.1 | 2/2 | Complete | 2026-03-21 |
| 14. Activity History | v2.1 | 0/TBD | Not started | - |
