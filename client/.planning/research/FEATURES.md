# Feature Research

**Domain:** Web admin panel for group/community management (study programs, groups, enrollments, members, posts)
**Researched:** 2026-03-19 (v2.0) / 2026-03-21 (v2.1 addendum)
**Confidence:** HIGH — derived directly from the existing iPhone app (the authoritative reference implementation) plus analysis of the established API surface

---

## v2.1 Addendum: Unified Member Management + Activity History Replay

**Researched:** 2026-03-21
**Milestone goal:** `/admin/members` — cross-group member view, tag filtering, multi-group assignment, deep activity history replay

### What Already Exists (v2.0)

Per-group member management is fully implemented:
- Per-group member list (load, display, search by name within group)
- Approve/reject join requests per group
- Change member role (OWNER/ADMIN/MEMBER) per group
- Remove member from group
- View member profile (name, phone, email, groups, joined date)

The API already exposes all needed endpoints — confirmed from server source:
- `GET /api/groups/:id/members` — members per group
- `GET /api/groups/:id/join-requests` — pending requests
- `POST/DELETE /api/groups/:id/join-requests/:id/approve` — approve/reject
- `PATCH /api/groups/:id/members/:id` — change role
- `DELETE /api/groups/:id/members/:id` — remove member
- `POST /api/groups/:id/members` — add existing member to a group
- `GET /api/members/:id/profile` — full profile with all group memberships
- `GET /api/member/lessons?memberId=X` — lesson list with completion status (leader-scoped)
- `GET /api/member/lessons/:lessonScheduleId?memberId=X` — lesson detail with per-activity progress + notes
- `GET /api/member/enrollments` — enrollments with progress percentage
- `GET /api/member/enrollments/:id` — day-by-day enrollment breakdown
- `GET /api/activity-logs?memberId=X` — auth/join/access event log, cursor-paginated
- `GET /api/activity-logs/stats` — aggregate stats groupable by category/activityType/status/day

Activity types in lessons: `READ`, `VIDEO`, `SOAP`, `OIA`, `DBS`, `HEAR`, `USER_INPUT`
SOAP note types stored per-activity: `OBSERVATION`, `APPLICATION`, `PRAYER`, `JOURNAL`, `REFLECTION`, `SCRIPTURE_NOTE`, `QUESTION`

**Critical technical constraint:** `/api/member/lessons` uses `requireMemberAuth`, not `requireAuth`. The `memberId` query param is accepted only when `isGroupLeader` is true (checked server-side by verifying the Google OAuth user owns the org containing the group). The Laravel proxy must forward the leader's Google session alongside the member-impersonation call.

### v2.1 Table Stakes

Features leaders expect from any member management tool. Missing these makes v2.1 feel incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Cross-group member list (all members, deduplicated) | iPhone app shows this; managing N groups without unified view means N separate tabs — impractical for leaders with multiple groups | MEDIUM | Deduplicate by `userId` across groups. N parallel API calls (one per group). TanStack Table for virtualization. Matches iPhone MemberHomePage dedup pattern. |
| Name search across all members | Non-negotiable UX primitive — leaders know people by name, not by group | LOW | Client-side filter on loaded dataset after initial load. Not live API search. |
| Filter by group (chip/tag filter) | Unified list spans all groups; leaders need to narrow context fast | LOW | Client-side filter. Group is a known attribute on every member row from dedup step. |
| Member profile drawer (existing pattern extended) | Already exists per-group; unified view must include it — leaders expect to tap any name and see details | LOW | Reuse existing profile endpoint + existing profile drawer component. Show all groups member belongs to. |
| Lesson completion status per member | Core purpose of a study group — did members do the work? | MEDIUM | Requires leader-scoped call to `/api/member/lessons?memberId=X`. API supports this via `isGroupLeader` flag. Lesson list with status badges (completed/in_progress/upcoming). |
| View member's written responses (SOAP/USER_INPUT) | Leaders guide members — seeing actual responses is essential pastoral context | MEDIUM | `/api/member/lessons/:lessonScheduleId?memberId=X` returns activities with `notes` field. Display read-only. Core differentiator. |
| Video progress per lesson | Video is a core activity type — leader wants to know if the member watched it | LOW | Activity progress includes `completed` + `completedAt` for VIDEO type. Render as completion chip. |
| Enrollment progress summary (% complete) | Dashboard-style progress indicator expected in any LMS-adjacent tool | LOW | `/api/member/enrollments` returns `progressPercentage` + `completedLessons`/`totalLessons`. Summary stats on member profile view. |
| Multi-group assignment (add/remove member from group) | Leaders organize members across groups — membership changes are a regular operational task | MEDIUM | `POST /api/groups/:id/members` + `DELETE /api/groups/:id/members/:id`. Need member search to find a member not yet in a given group. Must invalidate per-group member cache in existing `members.domain.ts`. |

### v2.1 Differentiators

Features that set this apart from basic group management tools.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Full lesson activity replay | Leader can navigate any member's completed lesson and read their exact SOAP journal entries, USER_INPUT responses, scripture notes, video completion | HIGH | Requires: (1) fetch enrollments for member, (2) fetch lessons per enrollment, (3) fetch lesson detail for selected lesson. The `memberId` query param enables leader-scoped reads. No competitor church management tool does this. |
| Searchable activity history | Quickly find when a member completed a specific lesson or study | MEDIUM | Filter lesson list by title, enrollment name, status. Client-side on loaded dataset. API supports limit/offset pagination if dataset is large. |
| Per-enrollment day-by-day timeline | Shows the sequence of when each lesson was completed — useful for follow-up conversations | MEDIUM | `/api/member/enrollments/:id` returns `days[]` with `completedCount`/`totalCount`. Render as a compact timeline within member detail. |
| Activity log timeline (auth/join/access events) | See when a member last logged in, joined a group, accessed content — for follow-up on disengaged members | MEDIUM | `/api/activity-logs?memberId=X` cursor-paginated. Categories: AUTH, JOIN, ACCESS. Useful pastoral engagement signal. |
| Completion badge per lesson (status chip) | Visual at-a-glance status without opening the lesson | LOW | Derived from `status` field: `completed` (green), `in_progress` (yellow), `upcoming` (grey). |

### v2.1 Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Live/real-time member presence | "Online now" indicator for community feel | Project constraint explicitly bans real-time (no WebSocket). Polling creates unnecessary load and flicker. | Show "last active" timestamp derived from most recent activity log entry — sufficient for pastoral use. |
| Editing member responses (SOAP notes, journals) | Leaders might want to "correct" a member's work | Changes member-owned content without consent; trust violation; no API endpoint for this; Prisma Notes table is owned by the member | Read-only replay is correct. Leader annotations are a future v3+ model if needed. |
| Bulk CSV export of all member activity | Requested for "reporting" | Data privacy: exports all member journal content to a file; sensitive for pastoral entries; likely non-compliant | Per-member UI review is appropriate. Export of aggregate stats (completion counts, dates) is acceptable but not raw journal content. |
| Real-time search (type to query API) | Feels faster | Member lists are small enough (hundreds, not millions) for client-side filtering after load. Adds API load + debounce complexity. | Load all members on page load, filter client-side. Matches iPhone app behavior. |
| Messaging from admin panel | Natural adjacency — see a member, message them | Separate product surface; SMS is a Twilio A2P compliance concern already constrained. Leaders have phone numbers for direct contact. | Surface phone number in member profile. Let leaders text from their phone (matches iPhone app pattern — "Text" action button on member profile). |
| Member cohort analytics (retention curves, engagement scoring) | Analytics dashboard exists, leaders want more depth | Enterprise LMS feature not needed for small-to-mid study groups. Months of work for marginal gain. | Aggregate analytics (heatmap, weekly chart) already built. Per-member view is a profile, not a dashboard. |

### v2.1 Feature Dependencies

```
Cross-group member list
    └──requires──> Group list (already in domain store — groups.domain.ts)
    └──requires──> Parallel member loads per group (N API calls on page load)

Member activity history
    └──requires──> Member profile (member userId)
                       └──requires──> Cross-group member list (tap member to get userId)
    └──requires──> Enrollment list for member (memberId)
                       └──requires──> Leader-scoped member session (isGroupLeader flag)
    └──requires──> Lesson detail with activity progress
                       └──requires──> Enrollment list (to enumerate lessons)

Activity log timeline
    └──requires──> Member userId (from profile or member list)
    └──enhances──> Member activity history (adds auth/join events alongside lesson events)

Multi-group assignment
    └──requires──> Cross-group member list (source of truth for current assignments)
    └──requires──> Member search/lookup (find a member not yet in a specific group)
    └──conflicts──> Per-group member list (must invalidate per-group cache after assignment changes)

Per-enrollment day-by-day timeline
    └──requires──> Enrollment list for member

Tag/group filter
    └──requires──> Cross-group member list (groups column populated on every row)

Lesson activity replay
    └──requires──> Lesson completion list (to pick a lesson)
    └──requires──> isGroupLeader API access pattern (critical technical dependency)
```

### v2.1 Dependency Notes

- **`isGroupLeader` API access is a critical technical dependency:** The lesson progress endpoints use `requireMemberAuth`. The `memberId` query param bypass only works when the server confirms the request comes from a group leader (checks Google OAuth user owns the org containing the group). The Laravel proxy must forward both the leader's Google session AND satisfy `requireMemberAuth` for the impersonated member. This needs a dedicated spike/prototype before full implementation. If this access pattern cannot be made to work, all activity history replay features are blocked.
- **Cross-group member list is the foundation for all other v2.1 features.** Build this first. Everything else is navigated from a member selected in this list.
- **Multi-group assignment must invalidate the per-group cache.** The existing `members.domain.ts` store caches members per `groupId`. After a cross-group assignment change, the affected group's cache entry must be cleared or force-reloaded to avoid stale data in the Groups tab member lists.
- **N parallel API calls on load for member list:** With 10 groups, that's 10 simultaneous `/api/groups/:id/members` calls. Current iPhone app does the same (confirmed in `MemberHomePage.loadAllMembers()`). Acceptable at this scale, but worth noting for larger organizations.

### v2.1 MVP Definition

#### Launch With (v2.1)

- [ ] `/admin/members` page with all members deduplicated, TanStack Table, searchable by name — the foundation
- [ ] Filter by group (chip-based, client-side) — prevents overload in multi-group contexts
- [ ] Member profile drawer with groups, contact info, join dates — leader's most frequent need when clicking a name
- [ ] Lesson completion list per member (all lessons, status chips, program name) — "did they do the work?"
- [ ] Lesson detail replay — tap a completed lesson, see each activity result (SOAP notes, USER_INPUT responses, video completion status) — the core differentiator
- [ ] Enrollment progress summary (% complete per study) — quick health check without drilling into lessons

#### Add After Validation (v2.1.x)

- [ ] Activity log timeline per member (AUTH/JOIN/ACCESS events) — add when leaders ask "when did this person last log in?"
- [ ] Multi-group assignment (add/remove member from groups) — add when leaders report needing to reorganize members
- [ ] Per-enrollment day-by-day timeline — add if leaders find the flat lesson list hard to navigate for long programs
- [ ] Cross-group stats summary row (N groups, last active date) — add when member count grows enough to need more row context

#### Future Consideration (v2.2+)

- [ ] Searchable activity history (search by lesson title across all enrollments) — defer until leaders manage enough members to need search
- [ ] Member tags/labels (custom grouping beyond group membership) — needs new API data model
- [ ] Leader annotation on member activity — requires new data model and consent/privacy considerations

### v2.1 Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Cross-group member list (virtualized) | HIGH | MEDIUM | P1 |
| Name search + group filter | HIGH | LOW | P1 |
| Member profile drawer | HIGH | LOW | P1 |
| Lesson completion list per member | HIGH | MEDIUM | P1 |
| Lesson detail activity replay | HIGH | HIGH | P1 |
| Enrollment progress summary | MEDIUM | LOW | P1 |
| Activity log timeline | MEDIUM | MEDIUM | P2 |
| Multi-group assignment | MEDIUM | MEDIUM | P2 |
| Day-by-day enrollment timeline | LOW | MEDIUM | P2 |
| Cross-group stats summary row | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v2.1 milestone to deliver its stated value
- P2: Add after core v2.1 is stable and validated
- P3: Defer to v2.2+

---

---

## v2.0: Admin Panel Feature Research (Original)

*The section below is the original v2.0 research. Preserved as reference for the existing admin panel features.*

---

### v2.0 Table Stakes (Users Expect These)

Features leaders will assume exist on day one. Absence makes the panel feel broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Admin layout shell with nav and avatar menu | Every web admin panel has persistent navigation — without it there is no product | MEDIUM | Fixed left nav or top nav, avatar menu, experience toggle (member/admin). Must render correctly on desktop. All admin sub-pages nest inside this shell. |
| Study Programs list with CRUD | Leaders need to see and manage their programs at a glance | MEDIUM | Cards/table showing name, cover image, publish status, enrollment count. Create, edit, delete. Confirm-before-delete for programs with active enrollments. |
| Program detail with lessons list | Navigating into a program must show its lesson (day) structure | MEDIUM | Master-detail: program header + tabs (Lessons, Enrollments). Lessons ordered by day number. Edit title inline, delete with confirm, add new day, reorder via up/down controls. |
| Activity editor within a lesson | The content of a study program lives in its activities — this is the primary authoring surface | HIGH | Per-lesson activity list. Add activity by type (READ, VIDEO, SOAP, PRAYER, REFLECTION, SCRIPTURE). Edit each activity's content. Reorder. Delete with confirm. Scripture reference fields for SOAP/SCRIPTURE types. |
| Groups list with CRUD | Leader manages one or more groups — the groups list is the home base for group management | MEDIUM | Cards/table with group name, cover image, member count, privacy. Create, edit, delete. Group settings: privacy, allow invites, member directory, welcome message, age range, max members. |
| Group detail with tabs | Clicking a group opens member management, enrollments, and posts in one view | MEDIUM | Tabs: Members, Enrollments, Posts. Tab-based master-detail is the expected pattern (matches iPhone GroupHomePage). |
| Member management | Leaders need to see who is in their groups and take action on requests | MEDIUM | List members with name, avatar, role. Approve/reject pending join requests. Change member role. Remove member. Search within members list. |
| Enrollment management (enroll group in program) | Enrolling a group in a study program is a core leader workflow | HIGH | List active enrollments for a group. Create enrollment: select program, set start date, select enabled days (Sun-Sat), set SMS time and timezone. View scheduled lessons within enrollment. Delete enrollment with unenroll warning. |
| Cover image upload for programs and groups | Leaders expect to brand their programs and groups with images | MEDIUM | File input uploading to `/cover-image` endpoint. Show upload progress, display result inline. Required for both Programs and Groups. No video upload (out of scope per PROJECT.md). |
| Publish/draft toggle for programs | Leaders need to control whether a program is visible before it is ready | LOW | Single boolean toggle on program edit. `isPublished` field. Visually distinct draft vs published state in list. |
| Leader profile editing | Leaders expect to manage their own profile from the admin experience | LOW | Edit name, avatar. Reuses existing profile edit patterns from member experience. |
| Avatar menu with experience switch | Leaders need to move between admin (/admin/*) and member (/member/*) views | LOW | Dropdown on avatar: "Switch to Member View", profile link, logout. Stub already exists on the current admin page — needs proper navigation wiring. |
| Analytics dashboard (KPI cards) | Leaders need an at-a-glance health view of their organisation | LOW | Total groups, total unique members, active enrollments, enrolled lessons. Derived from cached group/member data. Matches iPhone MainHome KPI tiles. |
| Analytics heatmap (day/hour engagement) | Shows when members are actually completing lessons — helps leaders set optimal SMS delivery times | MEDIUM | 7x24 grid heatmap from `GET /api/activity-logs/stats/heatmap`. Visually communicates member engagement patterns. Already modelled in iPhone MainHome. |
| Weekly activity bar chart | Trend view of member lesson completions over past 7 days | LOW | `GET /api/activity-logs/stats` endpoint. Single bar chart. Easy win alongside the heatmap. |

### v2.0 Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Scheduled lesson calendar view | Leaders can see their lesson delivery schedule across all groups at a glance — a unique operational view | HIGH | Month/week calendar populated from enrollment schedules. Events show program name, day number, activity icons. Matches iPhone MainCalendar. Requires loading enrollment details for all groups. Phase 2. |
| Drag-and-drop lesson reorder | Intuitive lesson order editing within a program without numeric inputs | HIGH | Vue island using SortableJS or similar. Server call to `POST /api/programs/:id/reorder-lessons`. High value for content authors but high implementation complexity. Fallback for MVP: up/down arrow buttons (LOW complexity). |
| Drag-and-drop activity reorder | Same as above but within a lesson | HIGH | `POST /api/programs/:id/lessons/:lid/reorder-activities` endpoint confirmed. Same fallback (up/down arrows) for MVP. |
| Group posts CRUD | Leaders can communicate with members via announcements, polls, events, and videos | HIGH | Post types: ANNOUNCEMENT, POLL, EVENT, VIDEO. Create post form with type selector. Paginated post feed. Delete post. Polls require options array. Events require date/location fields. Phase 2. |
| Invite/join-code display in group detail | Leaders need to get members into their group — surfacing the join code from the web admin is essential | LOW | Read-only display of group join code with copy-to-clipboard. Very low effort, high leader value. Should move to P1 if leaders currently rely heavily on iPhone for this. |
| Unenroll flow with lesson data warning | Safely removing a group from a study without silently destroying member progress data | MEDIUM | `GET /api/enrollments/:id/unenroll-info` returns count of lessons with member data. Show warning modal if data exists. Offer cancel-future-lessons vs full delete. Matches iPhone UnenrollOptionsModal. Phase 2. |
| Scheduled activity override per enrollment | Per-enrollment lesson customisation — leaders can override activity content for a specific scheduled lesson independently from the program template | HIGH | Each enrollment's lesson schedules can have their own `scheduledActivities` (confirmed from EnrollmentActions). Enables per-group customisation. Matches iPhone enrollment schedule editing flow. Phase 3. |
| Bible passage picker for READ/SCRIPTURE activities | Structured scripture selection (book, chapter, verse) rather than free-text entry | HIGH | Book/chapter/verse selection flow. Matches iPhone SelectBook/SelectChapter/SelectVerse/SelectPassagePage flow. Requires either Bible data in client or API-powered passage lookup. Complex UI. Phase 3. |

### v2.0 Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time/WebSocket notifications | "Show me when a member joins my group" | Out of scope per PROJECT.md. No WebSocket infrastructure exists. Significant complexity with no established API surface. | Refresh button on member list. Pull-on-navigate pattern is sufficient for operational use. |
| Video upload/transcoding | Leaders want to add video directly to activities in the web admin | Out of scope per PROJECT.md. Video upload is an iPhone-only capability. Transcoding is a separate infrastructure concern not part of this API surface. | Reference existing video URLs only. The `videoUrl` field on activities accepts an existing URL. |
| Rich text editor (Lexical) in activity editor | Parity with the Lexical-based SOAP journal in the member experience | Lexical has no Vue support. A full Vue Lexical integration for authoring would be a major project. The iPhone activity editor uses structured fields (readContent, readBlocks), not a generic rich text format. | Plain textarea for `readContent` in MVP. Simple Markdown or lightweight rich text editor (Tiptap) can be added in Phase 2 if leaders request it. |
| SMS delivery direct control | "Let me send a test SMS or trigger a lesson send from the web" | SMS is managed by the API/backend based on enrollment `smsTime` settings. The web admin has no direct channel to the SMS delivery system. | Expose `smsTime` and `enabledDays` fields clearly in the enrollment create/edit form. That is the full extent of SMS control available through this API. |
| Per-member analytics drill-down | Drill into what each individual member has completed lesson by lesson | The heatmap/weekly stats endpoints are aggregate-only. Per-member analytics would require endpoints that either do not exist or require significant data joins. | Aggregate stats (heatmap, weekly totals) are sufficient for a leader's operational needs. Per-member drill-down is now addressed by the v2.1 member management milestone. |
| Bulk operations (multi-select delete) | Useful for large organisations wanting to delete many groups or programs at once | High UI complexity. High risk of accidental data loss. The API has no bulk delete endpoints — each delete requires a separate request. | Confirm-before-delete on individual items. For the current organisation scale in MakeReady, single-item delete is sufficient. |
| Inertia.js or Vue SPA routing for admin | "Make admin navigation feel like a real SPA" | PROJECT.md explicitly rules out Inertia.js. Vue Router creates a parallel routing system that conflicts with Laravel routes. | Server-rendered Blade pages with Vue islands for interactive parts. Blade handles navigation and routing. Vue islands handle CRUD forms, sortable lists, and modals. This is the established and proven architecture from v1.0. |

---

## Feature Dependencies (v2.0)

```
Admin Layout Shell
    └──required by──> All admin pages (programs, groups, members, analytics)

Study Programs List
    └──required by──> Program Detail
                          └──required by──> Activity Editor
                          └──required by──> Lesson Reorder
                          └──required by──> Program Enrollments view

Groups List
    └──required by──> Group Detail
                          └──required by──> Member Management
                          └──required by──> Enrollment Management
                                                └──required by──> Scheduled Lesson Editing
                                                └──required by──> Calendar View
                                                └──required by──> Unenroll Flow
                          └──required by──> Group Posts

Cover Image Upload ──enhances──> Study Programs (create/edit)
Cover Image Upload ──enhances──> Groups (create/edit)

Analytics: KPI cards ──depends on──> Groups loaded (for member/group counts)
Analytics: Calendar ──depends on──> Enrollment details for all groups

Invite/Join-Code Display ──depends on──> Group Detail (low dependency, easy add)

Unenroll Flow ──depends on──> Enrollment Management

Scheduled Activity Override ──depends on──> Enrollment Management (deep)
Bible Passage Picker ──depends on──> Activity Editor (deep)

Templates list (GET /api/templates) ──required by──> Create Program form (templateId field)
```

### v2.0 Dependency Notes

- **Admin layout shell required by all pages:** Must be built first. Every admin feature lives inside this shell. The `/admin/*` routing structure must be defined before any individual CRUD pages can exist.
- **Groups list required by Group Detail:** The group list is the entry point to all group-scoped features. Member management, enrollments, and posts cannot be reached without it.
- **Program Detail required by Activity Editor:** Activities are nested inside lessons, which are nested inside programs. The master-detail navigation must work before the activity editor is reachable.
- **Enrollment data required by Calendar:** The calendar is computed from enrollment lesson schedules. Enrollment management must be functional before the calendar can show real data.
- **Templates API required by Create Program:** The `POST /api/programs` body requires a `templateId`. The create-program form needs to offer a template selector from `GET /api/templates`. This is a hidden dependency that must be handled in the program creation flow.
- **Cover image upload enhances Programs/Groups:** Not a blocker — programs and groups function without cover images. Upload is expected but can follow basic CRUD if needed.

---

## v2.0 MVP Definition

This is a subsequent milestone on a production Laravel app with an established architecture. "MVP" means the minimum admin panel that gives group leaders full operational control via web, matching the core daily workflows currently covered by the iPhone app.

### Launch With (v2.0 Admin Panel)

- [ ] **Admin layout shell** — without this nothing else exists; routing, nav, avatar menu, experience switch
- [ ] **Study Programs list + CRUD** — creating and publishing study content is the highest-value leader action
- [ ] **Program detail: lessons list with add/delete/edit title** — leaders need to see and structure their program days; up/down reorder is acceptable for MVP (no drag-and-drop required)
- [ ] **Activity editor: add/edit/delete activities (READ, VIDEO, SOAP, PRAYER, REFLECTION, SCRIPTURE)** — primary content authoring workflow; plain text fields for content; structured fields for scripture references
- [ ] **Groups list + CRUD with cover image and settings** — groups are the delivery vehicle for study programs
- [ ] **Group detail: Members tab (view, approve requests, change role, remove)** — member management is the most frequent non-content leader task
- [ ] **Group detail: Enrollments tab (create, view, delete)** — enrolling a group in a program with schedule is the activation step
- [ ] **Analytics dashboard: KPI cards + heatmap + weekly bar chart** — operational health at a glance; low-complexity high-value
- [ ] **Cover image upload for programs and groups** — expected branding capability; single file input per entity
- [ ] **Publish/draft toggle for programs** — needed to control content visibility
- [ ] **Leader profile editing** — self-service expected capability
- [ ] **Templates selector in create-program form** — required by `POST /api/programs` API contract

### Add After Validation (v2.x)

- [ ] **Group posts CRUD (announcements, polls, events, videos)** — important communication tool but not the first thing a leader does on day one; High complexity
- [ ] **Calendar view** — high value for leaders managing multiple groups on overlapping schedules; High complexity
- [ ] **Drag-and-drop reorder for lessons and activities** — up/down arrows are sufficient for MVP; DnD is a polish upgrade
- [ ] **Unenroll flow with lesson data warning** — simple delete is acceptable at launch; the safety modal should be added promptly after first deployment
- [ ] **Invite/join-code display in group detail** — low effort; add shortly after launch

### Future Consideration (v2+)

- [ ] **Scheduled activity override per enrollment** — deep customisation, complex to build and explain; defer until leaders actively request it
- [ ] **Bible passage picker in activity editor** — free-text scripture reference entry is sufficient for MVP; the structured passage picker is a Phase 3 investment
- [ ] **Per-member analytics drill-down** — addressed by v2.1 member management milestone

---

## v2.0 Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Admin layout shell | HIGH | MEDIUM | P1 |
| Study Programs list + CRUD | HIGH | MEDIUM | P1 |
| Program detail: lessons | HIGH | MEDIUM | P1 |
| Activity editor | HIGH | HIGH | P1 |
| Groups list + CRUD | HIGH | MEDIUM | P1 |
| Member management | HIGH | MEDIUM | P1 |
| Enrollment management | HIGH | HIGH | P1 |
| Analytics: KPI cards | MEDIUM | LOW | P1 |
| Analytics: heatmap | MEDIUM | MEDIUM | P1 |
| Analytics: weekly chart | MEDIUM | LOW | P1 |
| Cover image upload | MEDIUM | MEDIUM | P1 |
| Publish/draft toggle | MEDIUM | LOW | P1 |
| Avatar/experience switch | HIGH | LOW | P1 |
| Leader profile editing | LOW | LOW | P1 |
| Templates selector | MEDIUM | LOW | P1 |
| Invite/join-code display | MEDIUM | LOW | P2 |
| Unenroll warning modal | MEDIUM | MEDIUM | P2 |
| Group posts CRUD | MEDIUM | HIGH | P2 |
| Calendar view | HIGH | HIGH | P2 |
| Drag-and-drop reorder | MEDIUM | HIGH | P2 |
| Scheduled activity override | LOW | HIGH | P3 |
| Bible passage picker | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for v2.0 launch
- P2: Add in v2.x after initial launch
- P3: Future consideration, v3+

---

## API Surface Summary (v2.0)

All P1 features are backed by confirmed API endpoints from the iPhone app's Actions files. No API changes are required for the admin panel.

| Entity | Endpoints Confirmed | Notes |
|--------|---------------------|-------|
| Programs | `GET /api/programs`, `POST /api/programs`, `PATCH /api/programs/:id`, `DELETE /api/programs/:id`, `GET /api/programs/:id` (with lessons), `POST /api/programs/:id/cover-image` | Full CRUD; create requires `templateId` |
| Lessons | `POST /api/programs/:id/lessons`, `PATCH /api/programs/:id/lessons/:lid` (title), `DELETE /api/programs/:id/lessons/:lid`, `POST /api/programs/:id/reorder-lessons` | Nested under programs |
| Activities | `POST /api/programs/:id/lessons/:lid/activities`, `PATCH /api/activities/:id`, `DELETE /api/activities/:id`, `POST /api/programs/:id/lessons/:lid/reorder-activities`, `POST /api/activities/:id/reset` | Flat ID space for PATCH/DELETE |
| Activity read blocks | `POST /api/activities/:id/read-blocks`, `PATCH /api/activities/:id/read-blocks/:bid`, `DELETE /api/activities/:id/read-blocks/:bid`, `PATCH /api/activities/:id/read-blocks/reorder` | Content blocks within READ activities |
| Activity source references | `POST /api/activities/:id/source-references` | Bible passage linking |
| Templates | `GET /api/templates` | Required for create-program form |
| Groups | `GET /api/groups`, `POST /api/groups`, `PATCH /api/groups/:id`, `DELETE /api/groups/:id`, `GET /api/groups/:id`, `POST /api/groups/:id/cover-image` | Full CRUD confirmed |
| Members | `GET /api/groups/:id/members`, `GET /api/members/:id/profile` | Role change and remove endpoints need verification from API audit |
| Enrollments | `GET /api/groups/:id/enrollments`, `POST /api/enrollments`, `DELETE /api/enrollments/:id`, `GET /api/enrollments/:id` (with lesson schedules), `GET /api/enrollments/:id/unenroll-info`, `POST /api/enrollments/:id/cancel-future` | Full CRUD confirmed |
| Scheduled lessons | `POST /api/enrollments/:id/schedules`, `PATCH /api/enrollments/:id/schedules/:sid`, `DELETE /api/enrollments/:id/schedules/:sid` | Lesson schedule within enrollment |
| Analytics | `GET /api/activity-logs/stats/heatmap`, `GET /api/activity-logs/stats` | Aggregate only; per-member addressed in v2.1 |
| Posts | `GET /api/groups/:id/posts?limit=N&cursor=X`, `POST /api/groups/:id/posts` | Paginated list + create; delete path needs verification |

---

## Sources

- `/Users/lukekeith/www/makeready/server/src/routes/member-lessons.ts` — lesson progress API (leader-scoped access pattern, schema, memberId param)
- `/Users/lukekeith/www/makeready/server/src/routes/activity-logs.ts` — activity log API (memberId filter, cursor pagination)
- `/Users/lukekeith/www/makeready/server/src/routes/group-members.ts` — add/remove member API
- `/Users/lukekeith/www/makeready/iphone/MakeReady/State/Actions/ProgramActions.swift` — authoritative list of all program/lesson/activity API endpoints (HIGH confidence)
- `/Users/lukekeith/www/makeready/iphone/MakeReady/State/Actions/GroupActions.swift` — authoritative list of all group/member/post API endpoints + member profile endpoint
- `/Users/lukekeith/www/makeready/iphone/MakeReady/State/Actions/EnrollmentActions.swift` — authoritative list of all enrollment/schedule/scheduled-activity API endpoints
- `/Users/lukekeith/www/makeready/iphone/MakeReady/State/Actions/HomeActions.swift` — analytics endpoint surface and KPI data structure
- `/Users/lukekeith/www/makeready/iphone/MakeReady/Pages/Manage/Member/MemberHomePage.swift` — iPhone cross-group member list (dedup pattern, search UX, parallel load strategy)
- `/Users/lukekeith/www/makeready/iphone/MakeReady/Pages/Manage/Member/MemberProfilePage.swift` — iPhone member profile UX (contact actions, group memberships display)
- `/Users/lukekeith/www/makeready/iphone/MakeReady/Pages/Manage/Group/Models/GroupModels.swift` — MemberProfile data model
- `/Users/lukekeith/www/makeready/client/resources/js/islands/admin-island/stores/domain/members.domain.ts` — existing v2.0 member store (confirmed per-group API calls, cache structure)
- `/Users/lukekeith/www/makeready/client/resources/js/islands/admin-island/stores/ui/members-tab.ui.ts` — existing v2.0 per-group member UI store
- `/Users/lukekeith/www/makeready/client/.planning/PROJECT.md` — v2.1 milestone goals, constraints, out-of-scope items

---
*Feature research for: MakeReady web admin panel — v2.0 admin CRUD panel + v2.1 unified member management and activity history*
*Last updated: 2026-03-21*
