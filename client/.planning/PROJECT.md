# MakeReady Web Client

## What This Is

The MakeReady web client — a Laravel application with Blade templates for server-side rendering and Vue.js islands for interactive components. No Inertia.js, no Node runtime. Blade handles all SSR, Vue compiles at build time via Vite. The existing external API stays unchanged. The member experience (join flows, group home, lessons, profile) was migrated from a React SPA in v1.0. The admin panel (v2.0) gives group leaders full CRUD management of study programs, groups, enrollments, lessons, members, and posts — matching the capabilities of the iPhone leader app.

## Core Value

Group leaders can manage their entire organization from the web — creating study programs, managing groups, scheduling lessons, and handling membership — while members continue to have a polished, server-rendered experience.

## Current Milestone: v2.1 Member Management & Activity History

**Goal:** Give group leaders a unified, virtualized member management interface at /admin/members with cross-group views, tag-based filtering, multi-group assignment, and deep activity history replay — so leaders can understand and manage every member across their entire organization.

**Target features:**
- Top-level /admin/members page with all members across all groups in a single virtualized list (TanStack Table)
- Tag-based search/filter system (name, group, lesson status, activity type) — not live filtering
- Multi-group member assignment (add/remove members from groups)
- Member activity history with full replay (written responses, video progress, timestamps, scripture readings)
- Searchable activity history per member
- Lesson completion tracking per member (navigate every lesson, see completion status and activity results)
- Existing per-group members tab preserved alongside new top-level view

## Requirements

### Validated

<!-- Existing capabilities from current React app that must be preserved -->

- ✓ Member login via phone verification (SMS-based auth) — existing
- ✓ Group join flow (multi-step: code → profile → phone → verify → confirm) — existing
- ✓ Event join flow — existing
- ✓ Study join flow — existing
- ✓ Group home page with studies and events — existing
- ✓ Study home with lesson list — existing
- ✓ Lesson activity page with steps (Video, SOAP journal, etc.) — existing
- ✓ Member profile viewing and editing — existing
- ✓ Groups list for authenticated members — existing
- ✓ Privacy policy page — existing
- ✓ Terms of service page — existing
- ✓ Public home / landing page — existing
- ✓ Admin panel for organization leaders — existing
- ✓ Modal service for menus, overlays, and fullscreen modals — existing
- ✓ Rich text editor (Lexical) for content input — existing
- ✓ HLS video playback in lessons — existing
- ✓ SMS consent checkbox in join flow (unchecked by default) — existing
- ✓ 404 not found page — existing
- ✓ Lesson preview for non-members — existing
- ✓ Study preview for non-members — existing

### Active

<!-- v2.0 Admin CRUD Panel -->

- [ ] Admin layout shell with navigation, avatar menu, and member/admin experience switching
- [ ] Study Programs CRUD (create, read, edit, delete with cover image upload)
- [ ] Lessons CRUD within programs (add, edit title, delete, reorder)
- [ ] Activities CRUD within lessons (full activity editor: READ, VIDEO, SOAP, scripture references, read blocks)
- [ ] Groups CRUD (create, read, edit, delete with cover image and settings)
- [ ] Enrollments CRUD (enroll group in program, schedule, unenroll)
- [ ] Scheduled Lessons within enrollments (view, edit title, add, delete)
- [ ] Group Members management (view, approve/reject requests, change roles, remove)
- [ ] Group Posts CRUD (announcements, polls, events, videos)
- [ ] Analytics dashboard (group/member counts, heatmap, weekly stats, calendar)
- [ ] Leader profile editing
- [ ] MobX store architecture for admin (domain stores for API, UI stores for component props)
- [ ] Admin component library (tables, forms, tabs, modals — BEM/SCSS, no Tailwind)

### Out of Scope

- Changing the external API — Laravel consumes it as-is
- iPhone app changes — it calls APIs directly, unaffected
- Database/ORM (Eloquent) — no local database, all data via API
- Rewriting the API server — only replacing the client + Express proxy
- Member experience changes — v1.0 migration is complete
- Video upload/transcoding — reference existing video URLs only
- Real-time/WebSocket features — standard request/response only

## Context

- **v1.0 migration complete**: Member experience (join flows, group home, lessons, profile) fully migrated from React SPA to Laravel Blade + Vue islands.
- **Current architecture**: Laravel 12, Blade SSR, Vue.js islands via Vite. All data from `https://api.makeready.org`. No local database.
- **Component system**: 50+ Blade components (primitive/domain/layout/panel) with BEM SCSS. Vue islands for interactivity only.
- **Authentication**: Phone-based SMS verification. API issues session cookies. Laravel forwards them transparently.
- **iPhone app reference**: The iPhone app (`../iphone`) is the existing leader admin tool. The web admin panel should match its capabilities. Key entities: Programs, Lessons, Activities, Groups, Enrollments, Members, Posts.
- **iPhone API patterns**: All CRUD goes through the same REST API the web app already consumes. Endpoints are well-established (see iPhone app's Actions files for full list).
- **MobX pattern required**: Domain stores handle API calls and raw data. UI stores compute component props. Pages read from stores, never call APIs directly. This matches the original React architecture.

## Constraints

- **API compatibility**: Must consume existing MakeReady API without changes — iPhone app depends on it
- **No Tailwind**: Component-driven BEM/SCSS only. No CSS frameworks. No inline styles.
- **No database**: Laravel will NOT use Eloquent/database — all data via external API
- **MobX architecture**: Domain stores for API, UI stores for component props, pages never call loading functions
- **Visual consistency**: Admin pages should match the aesthetic of the member experience (dark theme, same fonts, same component patterns)
- **Framework**: Laravel Blade + Vue.js islands (no Inertia.js, no Node runtime)
- **Hosting**: Railway (PHP-FPM + Nginx)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Laravel Blade + Vue islands | Proven in v1.0 migration, no reason to change | ✓ Good |
| Transparent cookie proxy for auth | API manages sessions, Laravel forwards cookies | ✓ Good |
| No local database | All data via external API | ✓ Good |
| Admin at /admin (not /member/admin) | Leaders are not members — separate route prefix | ✓ Good |
| Master-detail with tabs for nested entities | Consistent UX: click entity → tabs for children (members, enrollments, lessons) | — Pending |
| MobX stores for admin state | Domain stores for CRUD API calls, UI stores for computed props | — Pending |
| Avatar menu for experience switching | Member ↔ Admin toggle in avatar dropdown on both experiences | — Pending |
| Match iPhone app capabilities | Web admin should have feature parity with iPhone leader app | — Pending |

---
*Last updated: 2026-03-21 after v2.1 milestone initialization*
