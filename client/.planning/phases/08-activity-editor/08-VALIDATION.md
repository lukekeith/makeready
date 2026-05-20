---
phase: 8
slug: activity-editor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel feature tests) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter ActivitiesAdminTest` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `php artisan test --filter ActivitiesAdminTest`
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | ACTV-01..09 | Feature | `php artisan test --filter ActivitiesAdminTest` | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 2 | ACTV-01..08 | Build | `npm run build` | ✅ | ⬜ pending |
| 08-03-01 | 03 | 3 | ACTV-03..06,09 | Build | `npm run build` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `tests/Feature/ActivitiesAdminTest.php` — covers ACTV-01 through ACTV-09 proxy tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Activity list with type badges | ACTV-01 | Vue rendering | Open lesson, verify activity list |
| Activity type selector | ACTV-02 | Dynamic UI | Add activity, verify type dropdown |
| Activity drag-and-drop reorder | ACTV-08 | vue-draggable-plus | Drag activity, verify order persists |
| Read content textarea save | ACTV-04 | Round-trip | Edit text, save, reload, verify |
| Source reference add | ACTV-05 | Form interaction | Add reference, verify it appears |
| Read block CRUD | ACTV-06 | Complex form | Add/edit/delete/reorder blocks |
| Reset activity | ACTV-09 | Destructive action | Reset, verify content cleared |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity
- [ ] Wave 0 covers all MISSING references
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
