---
phase: 3
slug: join-flows-member-pages
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter "JoinFlowTest\|MemberPagesTest"` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** `php artisan test --filter "JoinFlowTest\|MemberPagesTest"`
- **After every plan wave:** `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | JOIN-01 | Feature | `php artisan test --filter JoinFlowTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | JOIN-05 | Feature | `php artisan test --filter JoinFlowTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | JOIN-06 | Feature | `php artisan test --filter JoinFlowTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | JOIN-07 | Feature | `php artisan test --filter JoinFlowTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | JOIN-02 | Feature | `php artisan test --filter StudyJoinTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | JOIN-03 | Feature | `php artisan test --filter EventJoinTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | JOIN-04 | Feature | `php artisan test --filter JoinFlowTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-01 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-02 | Feature | `php artisan test --filter MemberLoginTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-03 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-04 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-05 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-06 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | MEMB-07 | Feature | `php artisan test --filter MemberPagesTest` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `tests/Feature/JoinFlowTest.php` — group join flow tests (session, steps, AJAX)
- [ ] `tests/Feature/StudyJoinTest.php` — study join flow tests
- [ ] `tests/Feature/EventJoinTest.php` — event join flow tests
- [ ] `tests/Feature/MemberPagesTest.php` — authenticated member page tests
- [ ] `tests/Feature/MemberLoginTest.php` — login flow tests
- [ ] `resources/views/layouts/auth.blade.php` — auth layout (centered)
- [ ] `resources/views/layouts/home.blade.php` — home layout (nav + content)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Join flow visual match | JOIN-01 | Visual comparison | Compare with React app screenshots |
| Phone entry Vue island works | JOIN-05 | Interactive JS | Enter phone, receive code, verify |
| Member profile edit saves | MEMB-06 | API integration | Edit profile, verify changes persist |
| SSR verified via curl | MEMB-01 | Content check | `curl /` shows HTML content |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
