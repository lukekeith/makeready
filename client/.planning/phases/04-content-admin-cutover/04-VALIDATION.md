---
phase: 4
slug: content-admin-cutover
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | PHPUnit (Laravel) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter "ContentPagesTest\|PreviewTest"` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** `php artisan test --filter "ContentPagesTest\|AdminTest\|ErrorPagesTest"`
- **After every plan wave:** `php artisan test`
- **Before cutover:** Full suite must be green + `npm run build` clean
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | CONT-01 | Feature | `php artisan test --filter ContentPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | CONT-02 | Feature | `php artisan test --filter ContentPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | CONT-03 | Smoke | `php artisan test --filter ContentPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | CONT-04 | Smoke | `php artisan test --filter ContentPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | CONT-07 | Feature | `php artisan test --filter ContentPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | CONT-05 | Feature | `php artisan test --filter PreviewTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | CONT-06 | Feature | `php artisan test --filter PreviewTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | ADMN-01 | Feature | `php artisan test --filter AdminTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | INFR-03 | Feature | `php artisan test --filter ErrorPagesTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | INFR-04 | Feature | `php artisan test --filter ErrorPagesTest` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `tests/Feature/ContentPagesTest.php` — study home, lesson, study code tests
- [ ] `tests/Feature/PreviewTest.php` — study/lesson preview tests
- [ ] `tests/Feature/AdminTest.php` — admin panel tests
- [ ] `tests/Feature/ErrorPagesTest.php` — 404/500 error page tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HLS video plays | CONT-03 | Requires browser + video stream | Start dev server, navigate to lesson, play video |
| SOAP journal saves | CONT-04 | Interactive rich text | Type in BulletTextInput, verify save via API |
| Lesson step transitions | CONT-02 | Vue SPA behavior | Navigate through video → read → input → complete |
| Railway deployment works | Cutover | Requires Railway infra | Push to main, verify app.makeready.org responds |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
