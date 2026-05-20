---
phase: 7
slug: programs-lessons
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel feature tests) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test tests/Feature/ProgramsAdminTest.php` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `php artisan test tests/Feature/ProgramsAdminTest.php`
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | PROG-01..07, LSSN-01..05 | Integration | `php artisan test tests/Feature/ProgramsAdminTest.php` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | PROG-01..07 | Build | `npm run build` | ✅ | ⬜ pending |
| 07-03-01 | 03 | 3 | LSSN-01..05 | Build | `npm run build` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Feature/ProgramsAdminTest.php` — covers PROG-01 through PROG-07 and LSSN-01 through LSSN-05
  - Follows GroupsAdminTest.php pattern: Http::fake() per test, fakeSession() helper
  - PROG-04 uses UploadedFile::fake() for multipart
  - LSSN-05 verifies lessonOrder key in request body

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Programs table with real data | PROG-01 | Vue rendering + API | Navigate to /admin/programs, verify table |
| Template selector in create form | PROG-02 | Dynamic select populated from API | Click Create, verify template dropdown loads |
| Publish toggle updates immediately | PROG-05 | Reactive UI state | Toggle publish, verify badge changes |
| Lesson drag-and-drop reorder | LSSN-05 | vue-draggable-plus interaction | Drag lesson, verify new order persists |
| Lesson delete re-fetches program | LSSN-04 | Day number reassignment | Delete middle lesson, verify day numbers update |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
