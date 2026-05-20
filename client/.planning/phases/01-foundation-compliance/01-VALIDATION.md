---
phase: 1
slug: foundation-compliance
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pest PHP (Laravel 12 default, runs on PHPUnit) |
| **Config file** | `phpunit.xml` |
| **Quick run command** | `php artisan test --filter ComplianceTest` |
| **Full suite command** | `php artisan test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `php artisan test --filter ComplianceTest`
- **After every plan wave:** Run `php artisan test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | FOUND-01 | Feature (HTTP) | `php artisan test --filter ProjectBootTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | FOUND-02 | Feature (HTTP) | `php artisan test --filter SsrHtmlTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | FOUND-03 | Manual / CI | `docker build -t test .` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | FOUND-04 | Unit | `php artisan test --filter ApiServiceTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | FOUND-05 | Feature (HTTP) | `php artisan test --filter CookieProxyTest` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | FOUND-06 | Feature (HTTP) | `php artisan test --filter AuthMiddlewareTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | COMP-01 | Feature (HTTP) | `php artisan test --filter PrivacyPageTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | COMP-02 | Feature (HTTP) | `php artisan test --filter TermsPageTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | COMP-03 | Feature (HTTP) | `php artisan test --filter SmsOptInPageTest` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | COMP-04 | Feature (HTTP) | `php artisan test --filter SmsOptInPageTest` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | INFR-01 | Manual / CI | GitHub Actions workflow | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | INFR-02 | Manual | Code review | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/Feature/ProjectBootTest.php` — Laravel boots, returns 200
- [ ] `tests/Feature/SsrHtmlTest.php` — Pages return full HTML
- [ ] `tests/Feature/ApiServiceTest.php` — API service sends correct headers
- [ ] `tests/Feature/CookieProxyTest.php` — Cookie forwarding works
- [ ] `tests/Feature/AuthMiddlewareTest.php` — Protected routes redirect
- [ ] `tests/Feature/ComplianceTest.php` — Privacy, terms, sms-opt-in content
- [ ] `Dockerfile` — Docker build succeeds
- [ ] `.github/workflows/ci.yml` — CI pipeline runs tests

*Pest PHP is included by default in Laravel 12 — no additional framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Railway deployment works | FOUND-03 | Requires Railway infra | Push to Railway, verify app responds |
| CI pipeline runs | INFR-01 | Requires GitHub Actions | Push commit, verify workflow passes |
| Env vars documented | INFR-02 | Documentation review | Check `.env.example` has all vars |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
