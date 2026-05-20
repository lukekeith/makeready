---
phase: 03-join-flows-member-pages
plan: 03
subsystem: auth
tags: [laravel, blade, vue-islands, session, sms-auth, php]

requires:
  - phase: 03-01
    provides: JoinPhoneIsland and JoinVerifyIsland Vue islands, routes registered in web.php, test scaffolds with Http::fake()

provides:
  - PublicHomeController: checks API session, serves SSR public landing or redirects authenticated users
  - MemberLoginController: phone submit, verify submit, logout via ApiService proxy
  - public-home.blade.php: full SSR landing page with logo, description, action buttons, footer
  - login.blade.php: conditional phone/verify steps mounting JoinPhoneIsland and JoinVerifyIsland
  - MemberPagesTest: test_public_home_renders and test_public_home_redirects_authenticated_user passing
  - MemberLoginTest: all 6 login flow tests passing (page, submit, verify render, verify submit, logout)

affects:
  - 03-04 (member authenticated pages — HomeController, ProfileController, GroupsController)

tech-stack:
  added: []
  patterns:
    - "PublicHomeController pattern: API session check → authenticated redirect or SSR view render"
    - "MemberLoginController pattern: Vue island AJAX endpoints returning JSON redirectUrl"
    - "Http::fake() FIFO ordering: setUp stubs win over per-test overrides; restructure setUp to exclude session stub and let each test register its own session fake"
    - "login.blade.php step switch: @if($step === 'phone') / @elseif($step === 'verify') conditional island mounting"

key-files:
  created:
    - app/Http/Controllers/MemberLoginController.php
    - resources/views/pages/public-home.blade.php
    - resources/views/pages/login.blade.php
  modified:
    - app/Http/Controllers/PublicHomeController.php
    - tests/Feature/MemberPagesTest.php
    - tests/Feature/MemberLoginTest.php

key-decisions:
  - "Http::fake() stubs accumulate in FIFO order and first match wins — restructured MemberPagesTest setUp to exclude session stub; each test registers its own session fake to avoid override conflicts"
  - "Public home uses <main> semantic element as outer container (SsrHtmlTest required it)"
  - "submitPhone accepts both 'phoneNumber' and 'phone' keys from request for compatibility with Vue island payload"

patterns-established:
  - "Controllers inject ApiService in constructor; all API calls go through ApiService proxy"
  - "AJAX login endpoints return JSON {redirectUrl} for Vue island redirect handling"
  - "Set-Cookie headers forwarded from API response to client response (critical for session cookie propagation)"

requirements-completed:
  - MEMB-01
  - MEMB-02

duration: 20min
completed: 2026-03-17
---

# Phase 03 Plan 03: Public Home + Member Login Summary

**Phone-based member login flow with SSR public landing page: PublicHomeController session-checks API and serves Blade view, MemberLoginController proxies verify-phone/confirm-verification/logout through ApiService**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-03-17T23:35:00Z
- **Completed:** 2026-03-17T23:55:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Public home page renders full SSR HTML with logo, tagline, and action buttons for login/join when unauthenticated; redirects to /home when already authenticated
- MemberLoginController implements the complete phone login flow: showPhone, submitPhone (JSON redirect), showVerify (session-guarded), submitVerify (session cookie forwarding), logout (API call + session flush)
- login.blade.php mounts JoinPhoneIsland or JoinVerifyIsland conditionally based on `$step` variable
- All MemberLoginTest tests pass (9/9) and MemberPagesTest public home tests pass with correct Http::fake() isolation strategy

## Task Commits

1. **Task 1: PublicHomeController + public-home.blade.php** - `7fd2783` (feat)
2. **Task 2: MemberLoginController + login.blade.php + MemberLoginTest** - `025c031` (feat)

## Files Created/Modified

- `app/Http/Controllers/PublicHomeController.php` - Replaced stub with full session check + SSR render implementation
- `app/Http/Controllers/MemberLoginController.php` - Phone login flow controller with 5 methods
- `resources/views/pages/public-home.blade.php` - SSR landing page with background images, logo, action buttons, footer
- `resources/views/pages/login.blade.php` - Conditional phone/verify step view mounting Vue islands
- `tests/Feature/MemberPagesTest.php` - Added test_public_home_renders (unauthenticated 200) and test_public_home_redirects_authenticated_user (302 to /home); restructured setUp to avoid Http::fake() FIFO ordering conflict
- `tests/Feature/MemberLoginTest.php` - Replaced all markTestIncomplete stubs with real passing tests

## Decisions Made

- **Http::fake() FIFO ordering:** Laravel's Http::fake() accumulates stubs in call order and first-match wins. The setUp's stubs win over per-test overrides. Resolved by removing the session stub from setUp and having each test register its own session fake — `test_public_home_renders` uses unauthenticated, `test_public_home_redirects_authenticated_user` calls `fakeAuthenticatedSession()`.
- **`<main>` semantic tag:** Added `<main>` wrapper to public-home container to satisfy pre-existing SsrHtmlTest which asserts `<main>` tag presence in the `/` response.
- **submitPhone field name:** Accepts both `phoneNumber` and `phone` request keys for compatibility with Vue island submit payloads.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added `<main>` semantic wrapper to public-home.blade.php**
- **Found during:** Task 1 (full test suite run after task commit)
- **Issue:** SsrHtmlTest::test_response_contains_main_tag_from_layout asserted `<main>` tag in GET / response. Initial implementation used `<div class="PublicHomePage__container">` without `<main>`.
- **Fix:** Changed `<div class="PublicHomePage__container">` to `<main class="PublicHomePage__container">`
- **Files modified:** resources/views/pages/public-home.blade.php
- **Verification:** SsrHtmlTest passes (both tests)
- **Committed in:** 025c031 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug fix for semantic HTML)
**Impact on plan:** Necessary for correctness and pre-existing test compatibility. No scope creep.

## Issues Encountered

- Laravel 12 Http::fake() stubs accumulate FIFO and cannot be overridden per-test after setUp has run. Resolved by restructuring setUp to exclude the session stub (moved to per-test helpers).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Public home and login flow complete — foundation for authenticated member pages
- Plan 03-04 (HomeController, GroupsController, ProfileController) can now proceed
- JoinPhoneIsland and JoinVerifyIsland are shared between join flows and login — confirmed compatible

---
*Phase: 03-join-flows-member-pages*
*Completed: 2026-03-17*
