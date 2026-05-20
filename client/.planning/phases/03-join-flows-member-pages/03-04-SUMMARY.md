---
phase: 03-join-flows-member-pages
plan: "04"
subsystem: member-pages
tags: [controllers, blade, api-service, member-pages, home, groups, profile]
dependency_graph:
  requires: ["03-01", "03-03"]
  provides: ["home-authenticated", "groups-list", "group-home", "profile-view-edit"]
  affects: ["authenticated-member-experience"]
tech_stack:
  added: []
  patterns:
    - "ApiService.patch() for PATCH requests with cookie forwarding"
    - "ApiService.upload() for multipart file upload forwarding"
    - "Single-group redirect in HomeController"
    - "Multi-API-call controller (GroupHomeController loads 3 endpoints)"
    - "Profile edit with PATCH + avatar upload with multipart"
key_files:
  created:
    - app/Http/Controllers/GroupsController.php
    - app/Http/Controllers/GroupHomeController.php
    - app/Http/Controllers/ProfileController.php
    - resources/views/pages/home-authenticated.blade.php
    - resources/views/pages/groups.blade.php
    - resources/views/pages/group-home.blade.php
    - resources/views/pages/profile.blade.php
  modified:
    - app/Services/ApiService.php
    - app/Http/Controllers/HomeController.php
    - tests/Feature/MemberPagesTest.php
decisions:
  - "Http::fake() FIFO ordering: moved contested fakes out of setUp() and into per-test fakeAuthWithGroups() helper to avoid first-match priority conflicts between session and groups fakes"
  - "setUp() now registers only non-contested fakes (group detail, posts, enrollment); session+groups registered together per-test"
  - "Group body extraction uses dual-key check: data ?? groups ?? [] to handle API response inconsistency"
  - "Avatar upload returns JSON (suitable for AJAX or direct form submit) rather than a redirect"
metrics:
  duration: "~8 min"
  completed: "2026-03-17"
  tasks_completed: 2
  files_changed: 10
---

# Phase 3 Plan 4: Authenticated Member Pages Summary

**One-liner:** All 4 authenticated member pages implemented with SSR via ApiService: home (single-group redirect), groups list, group home (3 API calls), and profile (PATCH update + multipart avatar upload).

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | ApiService methods + HomeController + GroupsController + GroupHomeController + 3 Blade templates | 532f8b5 | ApiService.php, HomeController.php, GroupsController.php, GroupHomeController.php, home-authenticated.blade.php, groups.blade.php, group-home.blade.php |
| 2 | ProfileController + profile.blade.php + complete MemberPagesTest | 568b09b | ProfileController.php, profile.blade.php, MemberPagesTest.php |

## What Was Built

### ApiService additions
- `patch(endpoint, data, request)`: mirrors `post()` but uses `Http::patch()`. Used by ProfileController for member profile updates.
- `upload(endpoint, fileKey, file, request)`: attaches file content via `Http::attach()` for multipart forwarding. Returns same `[status, body, setCookies]` shape.

### HomeController (updated)
- Injects ApiService via constructor.
- Fetches `/api/groups`, extracts group list from `data` or `groups` key (API inconsistency guard).
- Single-group redirect: if exactly 1 group, `redirect()->route('group.home', ['groupId' => ...])`.
- Multi-group: renders `pages.home-authenticated` with Navigation (selected=home) and group-list-card loop.

### GroupsController (new)
- Same groups-fetching logic as HomeController but always renders the full list (no single-group redirect).
- Renders `pages.groups` with Navigation (selected=home) and group-list-card loop.

### GroupHomeController (new)
- Loads 3 API endpoints upfront (sequential, all before render): group public data, posts feed (limit=10), study enrollment.
- Null-safe defaults for each: non-200 responses produce null/empty arrays.
- Forwards Set-Cookie from all 3 responses.
- Renders `pages.group-home` with group-card Header, study-card Progress (if enrolled), group-post-card feed.

### ProfileController (new)
- `show()`: reads member from middleware attribute, renders `pages.profile`.
- `update()`: validates first_name/last_name (required), gender/birthday (nullable); calls `api->patch()`; redirects to `/profile` with flash success or error.
- `uploadAvatar()`: validates image max 5MB; calls `api->upload()`; returns JSON response.

### Blade Templates
- `home-authenticated.blade.php`: Navigation selected=home, PageTitle "My Groups", group-list-card loop or empty-state.
- `groups.blade.php`: Navigation selected=home, PageTitle "Groups", same group card loop.
- `group-home.blade.php`: Navigation selected=home, GroupCard mode=Header, StudyCard mode=Progress (if enrolled), GroupPostCard feed or empty-state.
- `profile.blade.php`: Navigation selected=profile, Avatar display + file-input upload form, ProfileForm component pre-populated from middleware member data, flash messages.

## Test Results

```
Tests:    1 incomplete, 133 passed (255 assertions)
Duration: 2.67s
```

All MemberPagesTest tests pass:
- `test_authenticated_home_renders` — 200, sees "Test Group" + "Other Group"
- `test_authenticated_home_single_group_redirect` — 302 to `/groups/group-1`
- `test_groups_list` — 200, sees group name
- `test_group_home_renders` — 200, sees group name
- `test_profile_view` — 200, sees member name
- `test_profile_update` — redirects to `/profile`
- `test_profile_update_validates` — session has errors for first_name + last_name
- All 5 smoke tests pass

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Http::fake() FIFO ordering conflict between setUp() and per-test fakes**

- **Found during:** Task 2 (test completion)
- **Issue:** Plan's test structure assumed per-test `Http::fake()` calls would override setUp fakes. Laravel 12 FIFO means first-match wins — setUp fakes take priority over per-test fakes for same URL patterns. `test_authenticated_home_renders` got single-group redirect (302) when expecting 200 with 2 groups; `test_authenticated_home_single_group_redirect` got 200 rendering when expecting redirect.
- **Fix:** Restructured setUp() to exclude contested fakes (`*/api/groups`, `*/api/members/session`). Added `fakeAuthWithGroups(array $groups)` helper that registers session + groups together in one `Http::fake()` call per-test. Each test that needs specific group counts calls this helper with the exact data needed.
- **Files modified:** tests/Feature/MemberPagesTest.php
- **Commit:** 568b09b

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Remove `*/api/groups` and session fakes from setUp() | First-match-wins FIFO means setUp fakes beat per-test overrides; per-test helpers give each test full control |
| `fakeAuthWithGroups()` registers session + groups in one Http::fake() call | Single call ensures URL priority is deterministic within the call |
| Avatar upload returns JSON | Appropriate for both AJAX and standard form submit; POST redirect would break AJAX callers |
| Dual-key extraction: `data ?? groups ?? []` | Matches API inconsistency noted in plan — some endpoints return `data`, others return `groups` |

## Self-Check: PASSED

All key files exist. Commits 532f8b5 and 568b09b confirmed in git log.

| Check | Result |
|-------|--------|
| app/Services/ApiService.php | FOUND |
| app/Http/Controllers/HomeController.php | FOUND |
| app/Http/Controllers/GroupsController.php | FOUND |
| app/Http/Controllers/GroupHomeController.php | FOUND |
| app/Http/Controllers/ProfileController.php | FOUND |
| resources/views/pages/home-authenticated.blade.php | FOUND |
| resources/views/pages/groups.blade.php | FOUND |
| resources/views/pages/group-home.blade.php | FOUND |
| resources/views/pages/profile.blade.php | FOUND |
| tests/Feature/MemberPagesTest.php | FOUND |
| Commit 532f8b5 | FOUND |
| Commit 568b09b | FOUND |
