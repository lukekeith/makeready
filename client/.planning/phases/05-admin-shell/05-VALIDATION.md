---
phase: 5
slug: admin-shell
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel feature tests) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter AdminTest` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `php artisan test --filter AdminTest`
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SHELL-01 | Feature | `php artisan test --filter AdminTest::test_admin_page_renders_for_leader` | ✅ | ⬜ pending |
| 05-01-02 | 01 | 1 | SHELL-05 | Feature | `php artisan test --filter AdminTest::test_admin_page_redirects_unauthenticated` | ✅ | ⬜ pending |
| 05-01-03 | 01 | 1 | SHELL-05 | Feature | `php artisan test --filter AdminShellTest::test_admin_subpath_redirects_unauthenticated` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | SHELL-02 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_admin_layout_contains_sidebar` | ❌ W0 | ⬜ pending |
| 05-01-05 | 01 | 1 | SHELL-06 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_admin_page_mounts_admin_island` | ❌ W0 | ⬜ pending |
| 05-01-06 | 01 | 1 | SHELL-07 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_admin_subpaths_served_by_same_blade_template` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | SHELL-03 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_admin_avatar_menu_has_member_experience_link` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | SHELL-04 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_member_nav_shows_admin_link_for_google_linked_member` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 1 | SHELL-04 | Feature (SSR) | `php artisan test --filter AdminShellTest::test_member_nav_hides_admin_link_when_no_google_link` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Feature/AdminShellTest.php` — stubs for SHELL-02, SHELL-03, SHELL-04, SHELL-05 (subpath), SHELL-06, SHELL-07
- [ ] Update `tests/Feature/AdminTest.php` — existing assertions will change as Blade template structure changes

*Existing `AdminTest.php` covers SHELL-01 and SHELL-05 (root path). New `AdminShellTest.php` covers server-side preconditions for client-side Vue Router behavior.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sidebar expand/collapse on hover | SHELL-02 | CSS hover + JS interaction | Hover sidebar, verify it expands with labels |
| Vue Router client-side navigation | SHELL-07 | PHPUnit can't execute JavaScript | Click sidebar links, verify no full page reload |
| Pinia state preserved across navigation | SHELL-06 | Requires JS runtime | Navigate between sections, verify state survives |
| CSRF POST success | SHELL-06 | Requires JS runtime + API | Submit a form/action from AdminIsland, verify 200 |
| Skeleton loaders display | SHELL-07 | Visual/JS behavior | Navigate to a section, verify skeleton shows before data |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
