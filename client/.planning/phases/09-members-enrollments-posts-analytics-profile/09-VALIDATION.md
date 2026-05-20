---
phase: 9
slug: members-enrollments-posts-analytics-profile
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for the final admin panel phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel feature tests) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test tests/Feature/Phase9AdminTest.php` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~6 seconds |

---

## Sampling Rate

- **After every task commit:** Run targeted test filter
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 6 seconds

---

## Wave 0 Requirements

- [ ] `tests/Feature/Phase9AdminTest.php` — Consolidated proxy tests for all Phase 9 API routes (members MMBR-01..06, enrollments ENRL-01..05 + SCHD-01..04, posts POST-01..06, analytics ANLT-01..04, profile PROF-01..02). Created in Plan 01 Task 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Approve/reject membership request | MMBR-03/04 | Full round-trip | View pending, approve, verify moves to active |
| Enrollment form with day checkboxes | ENRL-02 | Complex form | Select program, set days, verify schedule |
| Post type-specific forms | POST-02..06 | Dynamic UI | Create each post type, verify fields |
| Heatmap + weekly chart rendering | ANLT-02/03 | ApexCharts rendering | View dashboard, verify charts populate |
| Profile avatar update reflects in menu | PROF-02 | Cross-component | Upload avatar, verify sidebar avatar updates |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity
- [ ] Wave 0 covers all MISSING references
- [ ] Feedback latency < 6s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
