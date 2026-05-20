---
phase: 6
slug: groups-crud
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel feature tests) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test tests/Feature/GroupsAdminTest.php` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `php artisan test tests/Feature/GroupsAdminTest.php`
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | GRP-01 | Smoke | `php artisan test --filter test_groups_list_renders` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | GRP-02 | Integration | `php artisan test --filter test_create_group_proxy` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | GRP-03 | Integration | `php artisan test --filter test_update_group_proxy` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | GRP-04 | Integration | `php artisan test --filter test_update_group_settings_proxy` | ❌ W0 | ⬜ pending |
| 06-01-05 | 01 | 1 | GRP-05 | Integration | `php artisan test --filter test_cover_image_upload_proxy` | ❌ W0 | ⬜ pending |
| 06-01-06 | 01 | 1 | GRP-06 | Integration | `php artisan test --filter test_delete_group_proxy` | ❌ W0 | ⬜ pending |
| 06-01-07 | 01 | 1 | GRP-07 | Smoke | `php artisan test --filter test_group_detail_renders` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Feature/GroupsAdminTest.php` — covers GRP-01 through GRP-07
  - Uses `Http::fake()` to mock external API, tests Laravel proxy routing and response forwarding
  - GRP-05 uses `UploadedFile::fake()->image('cover.jpg', 800, 600)->size(2000)` for multipart
  - All tests use `fakeSession()` helper pattern from AdminTest.php

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Groups table renders with data | GRP-01 | Vue rendering + API data | Navigate to /admin/groups, verify table shows groups |
| Cover image upload UI | GRP-05 | File input + preview | Click upload, select image, verify preview and save |
| Delete confirmation dialog | GRP-06 | reka-ui Dialog interaction | Click delete, verify dialog, confirm, verify removal |
| Tab switching on group detail | GRP-07 | reka-ui Tabs interaction | Click each tab, verify content switches |
| Form field persistence | GRP-03/04 | Full round-trip | Edit fields, save, reload, verify persistence |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
