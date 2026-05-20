---
phase: 2
slug: component-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 2 — Validation Strategy (REVISED — Blade Components)

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel test suite) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter ComponentSmokeTest` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** `php artisan test --filter ComponentSmokeTest`
- **After every plan wave:** `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | CSYS-01 | Build check | `npm run build` | ✅ (kept) | ⬜ pending |
| TBD | 01 | 1 | CSYS-02 | Smoke test | `php artisan test --filter ComponentSmokeTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | CSYS-03 | Manual | `npm run story:dev` | ✅ (kept) | ⬜ pending |
| TBD | 01 | 1 | CSYS-04 | Manual | Histoire ModalProvider story | ✅ (kept) | ⬜ pending |
| TBD | 02 | 2 | CSYS-05 | Smoke test | `php artisan test --filter PrimitiveComponentTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 2 | CSYS-06 | Smoke test | `php artisan test --filter LayoutComponentTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | CSYS-07 | Smoke test | `php artisan test --filter DomainComponentTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | CSYS-08 | Smoke test | `php artisan test --filter PanelComponentTest` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `app/View/helpers.php` — PHP `cva()` helper function
- [ ] `composer.json` autoload.files entry for helpers.php
- [ ] `tests/Feature/CvaHelperTest.php` — unit tests for cva() helper
- [ ] `tests/Feature/ComponentSmokeTest.php` — renders Blade components, asserts 200 + BEM classes
- [ ] Remove/relocate ~50 Vue SFC files that become Blade components

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Histoire shows Vue stories | CSYS-03 | Visual verification | `npm run story:dev`, browse Vue-only components |
| Modal opens/closes | CSYS-04 | Interactive behavior | Open modal via Histoire story, verify Teleport |
| Visual fidelity vs React | CSYS-05-08 | Compare appearance | Side-by-side with archive Storybook screenshots |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
