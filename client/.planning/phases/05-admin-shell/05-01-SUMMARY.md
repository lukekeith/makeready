---
phase: 05-admin-shell
plan: 01
subsystem: ui
tags: [laravel, vue, vue-router, blade, pinia, admin, admin-shell]

# Dependency graph
requires:
  - phase: 04-content-admin-cutover
    provides: AdminController with member.auth middleware, ApiService get/post/patch, Vue island mounting pattern
provides:
  - Laravel catch-all route /admin/{any?} named admin.shell serving admin Blade shell
  - admin Blade layout (layouts/admin.blade.php) with CSRF meta tag, no sidebar in Blade
  - AdminIsland mount point with JSON island props (avatarUrl, initials, memberName, googleEmail, logoutUrl)
  - vue-router@4.x installed
  - ApiService.delete() method for CRUD operations
  - Placeholder admin-island.vue and router.ts (build-safe for Plan 02)
  - AdminShellTest.php with 7 tests covering catch-all routing and auth redirect
affects:
  - 05-admin-shell/05-02 (builds AdminIsland Vue component, depends on admin.shell route and placeholder files)
  - 06-groups-crud (uses admin.shell catch-all, ApiService.delete)
  - all subsequent admin phases

# Tech tracking
tech-stack:
  added: [vue-router@^4.6.4]
  patterns:
    - Single AdminIsland Vue app with Vue Router (not per-section islands — shared Pinia state)
    - Catch-all Laravel route /admin/{any?} with Vue Router client-side navigation
    - Island props via JSON-encoded data-props attribute — AdminIsland bootstraps without extra API round-trip
    - ApiService.delete() mirrors patch() pattern (no body parameter for DELETE requests)

key-files:
  created:
    - resources/views/layouts/admin.blade.php
    - resources/js/islands/admin-island/admin-island.vue
    - resources/js/islands/admin-island/router.ts
    - tests/Feature/AdminShellTest.php
  modified:
    - routes/web.php
    - app/Http/Controllers/AdminController.php
    - app/Services/ApiService.php
    - resources/views/pages/admin.blade.php
    - resources/js/app.js
    - tests/Feature/AdminTest.php
    - package.json

key-decisions:
  - "admin.shell route name (not 'admin') — prefixed group with name() yields admin.shell"
  - "Island props built in PHP controller, not fetched by Vue — avoids extra API round-trip on initial load"
  - "No ModalProvider island in admin layout — admin uses its own modal pattern inside AdminIsland"
  - "Placeholder admin-island.vue and router.ts created in Plan 01 so Vite build succeeds before Plan 02 builds real components"
  - "AdminShellTest.php merges new catch-all/island tests with existing SHELL-04 NavigationIsland tests from prior file"

patterns-established:
  - "Admin catch-all: Route::get('/{any?}')->where('any', '.*') inside prefix('admin') group"
  - "Island bootstrap props: PHP builds islandProps array, view passes via compact(), Blade json_encode() into data-props"
  - "AdminIsland Vue Router registration: if (name === 'AdminIsland') { app.use(adminRouter) } in island auto-mounter"

requirements-completed: [SHELL-01, SHELL-05, SHELL-06]

# Metrics
duration: 18min
completed: 2026-03-20
---

# Phase 5 Plan 01: Admin Shell Infrastructure Summary

**Laravel catch-all /admin/{any?} route serving Vue Router-ready Blade shell with AdminIsland mount point, vue-router@4.x installed, ApiService.delete() added, and placeholder Vue files enabling build-safe Plan 02 development**

## Performance

- **Duration:** 18 min
- **Started:** 2026-03-20T04:15:00Z
- **Completed:** 2026-03-20T04:33:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Laravel catch-all route `/admin/{any?}` (named `admin.shell`) serves admin Blade shell for all sub-paths — Vue Router handles client-side navigation
- Admin Blade layout (`layouts/admin.blade.php`) with CSRF meta tag; no sidebar in Blade (sidebar belongs to Vue AdminIsland)
- `AdminController.show()` builds island props (avatarUrl, initials, memberName, googleEmail, logoutUrl) and passes via JSON `data-props` attribute — no extra API round-trip on load
- `vue-router@^4.6.4` installed (v4.x pinned, not v5); AdminIsland registered in `app.js` with Vue Router plugin applied per-island
- `ApiService.delete()` added mirroring `patch()` pattern for all future CRUD phases
- `AdminShellTest.php` with 7 tests covering mount point, catch-all routing, unauthenticated redirects, island props, and CSRF meta; full 175-test suite passes

## Task Commits

Each task was committed atomically:

1. **Task 1: Install vue-router, create catch-all route, admin layout, controller, and ApiService.delete()** - `1462724` (feat)
2. **Task 2: Register AdminIsland in app.js and create test scaffolds** - `125e933` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `resources/views/layouts/admin.blade.php` - Minimal admin HTML shell with CSRF meta, @yield('content'), no sidebar
- `resources/views/pages/admin.blade.php` - Mounts AdminIsland with JSON-encoded island props
- `resources/js/islands/admin-island/admin-island.vue` - Placeholder SFC wrapping RouterView (build-safe for Plan 02)
- `resources/js/islands/admin-island/router.ts` - Placeholder createRouter with /admin/:pathMatch catch-all
- `tests/Feature/AdminShellTest.php` - 7 tests: catch-all routing, island mount, CSRF meta, member data props, auth redirect
- `routes/web.php` - Replaced single /admin route with prefix('admin').name('admin.').group() catch-all
- `app/Http/Controllers/AdminController.php` - Updated show() to build islandProps and return view with compact
- `app/Services/ApiService.php` - Added delete() method after patch()
- `resources/js/app.js` - Added AdminIsland import, router import, componentRegistry entry, and if-name guard for router plugin
- `tests/Feature/AdminTest.php` - Updated to route('admin.shell'), assertSee AdminIsland, removed phone/member-info tests
- `package.json` - Added vue-router@^4.6.4 dependency

## Decisions Made
- Named route is `admin.shell` (not `admin`) because `prefix('admin')->name('admin.')` produces `admin.shell` — all tests updated accordingly
- Island props built in PHP (not fetched by Vue) so AdminIsland can render immediately without a loading state on first paint
- `AdminShellTest.php` preserved existing SHELL-04 NavigationIsland tests from the prior version of the file while adding the new SHELL-01/05/06 catch-all tests

## Deviations from Plan

None - plan executed exactly as written. The existing `AdminShellTest.php` contained prior tests that were preserved and merged with the new tests rather than overwriting.

## Issues Encountered
- `AdminShellTest.php` already existed with SHELL-04 NavigationIsland tests from a prior phase. Merged both test sets into the file rather than discarding existing coverage.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Catch-all route, admin layout, and AdminIsland mount point are all ready
- Placeholder `admin-island.vue` and `router.ts` let Plan 02 iterate on real component without touching `app.js`
- `ApiService.delete()` available for all CRUD phases starting at Phase 6

---
*Phase: 05-admin-shell*
*Completed: 2026-03-20*
