---
phase: 06-groups-crud
plan: "01"
subsystem: admin-api-proxy
tags: [api-proxy, laravel, php, testing, groups-crud]
dependency_graph:
  requires: []
  provides: [AdminApiProxyController, GroupsAdminTest]
  affects: [routes/web.php]
tech_stack:
  added: []
  patterns: [admin-api-proxy, multipart-upload-detection, per-test-http-fake]
key_files:
  created:
    - app/Http/Controllers/AdminApiProxyController.php
    - tests/Feature/GroupsAdminTest.php
  modified:
    - routes/web.php
decisions:
  - "[Phase 06-01]: handlePost() inspects $request->hasFile('image') to route multipart uploads to ApiService::upload() vs ApiService::post()"
  - "[Phase 06-01]: Proxy route /admin/api/{path} uses Route::match(['GET','POST','PATCH','PUT','DELETE']) and must appear before catch-all /{any?} in the admin group"
  - "[Phase 06-01]: PUT treated same as PATCH — both dispatched to ApiService::patch() since external API only uses PATCH"
metrics:
  duration_minutes: 2
  completed_date: "2026-03-19"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 6 Plan 01: Admin API Proxy Infrastructure Summary

**One-liner:** Laravel proxy controller routes all /admin/api/* HTTP methods to external API via ApiService, with multipart upload detection, registered before the Blade catch-all.

## What Was Built

### AdminApiProxyController

`app/Http/Controllers/AdminApiProxyController.php` — New controller injecting `ApiService`, exposing a single `handle(Request $request, string $path)` method that:

- Builds the external endpoint as `/api/{path}` with query string appended if present
- Uses `match(strtolower($request->method()))` to dispatch GET/POST/PATCH/PUT/DELETE
- Delegates POST to private `handlePost()` which detects `$request->hasFile('image')` to route multipart uploads to `ApiService::upload()` or JSON body to `ApiService::post()`
- Returns `response()->json($result['body'], $result['status'])` with Set-Cookie headers forwarded
- Returns 405 for unsupported methods

### Route Registration

`routes/web.php` — Added inside the `admin.` named group, before the `/{any?}` catch-all:

```php
Route::match(['GET', 'POST', 'PATCH', 'PUT', 'DELETE'], '/api/{path}', [AdminApiProxyController::class, 'handle'])
    ->where('path', '.*')
    ->name('api.proxy');
```

This produces route name `admin.api.proxy` and matches `/admin/api/*` for all HTTP verbs.

### GroupsAdminTest

`tests/Feature/GroupsAdminTest.php` — 7 test methods covering GRP-01 through GRP-07:

| Test | Requirement | Method | Endpoint |
|------|-------------|--------|----------|
| test_groups_list_proxy | GRP-01 | GET | /admin/api/groups |
| test_create_group_proxy | GRP-02 | POST | /admin/api/groups |
| test_update_group_proxy | GRP-03 | PATCH | /admin/api/groups/grp-1 |
| test_update_group_settings_proxy | GRP-04 | PATCH | /admin/api/groups/grp-1 |
| test_cover_image_upload_proxy | GRP-05 | POST multipart | /admin/api/groups/grp-1/cover-image |
| test_delete_group_proxy | GRP-06 | DELETE | /admin/api/groups/grp-1 |
| test_group_detail_renders | GRP-07 | GET | /admin/groups/grp-1 |

Each API proxy test uses `Http::assertSent()` to verify the correct external endpoint was called. The cover image test uses `UploadedFile::fake()->image()` and `$this->call()` to send a real multipart request.

## Verification

```
php artisan test tests/Feature/GroupsAdminTest.php
  PASS  Tests\Feature\GroupsAdminTest
  7 passed (18 assertions) in 0.15s

php artisan test
  Tests: 1 incomplete, 182 passed (360 assertions)
  Duration: 3.94s — no regressions

php artisan route:list --path=admin
  GET|POST|PATCH|PUT|DELETE|HEAD  admin/api/{path}  admin.api.proxy
  GET|HEAD                        admin/{any?}       admin.shell
```

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 32fa191 | feat(06-01): create AdminApiProxyController and register proxy route |
| 2 | 576bbc2 | feat(06-01): add GroupsAdminTest with all 7 test cases (GRP-01 to GRP-07) |

## Self-Check: PASSED
