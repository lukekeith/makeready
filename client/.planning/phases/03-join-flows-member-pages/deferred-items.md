# Deferred Items — Phase 03 Join Flows

## Pre-existing Test Failures (Out of Scope for 03-02)

### SsrHtmlTest::test_response_contains_main_tag_from_layout
- **Status:** FAILING before and after 03-02 changes
- **Cause:** public-home.blade.php and auth.blade.php layout do not contain a `<main>` tag; the test expects one
- **Files:** tests/Feature/SsrHtmlTest.php, resources/views/pages/public-home.blade.php, resources/views/layouts/auth.blade.php
- **Owner:** Future plan — either add `<main>` wrapper to layout or update the test to match the actual structure

### MemberPagesTest::test_public_home_renders
- **Status:** FAILING before and after 03-02 changes
- **Cause:** Uncommitted changes in PublicHomeController.php and MemberPagesTest.php from a prior session
- **Files:** app/Http/Controllers/PublicHomeController.php, tests/Feature/MemberPagesTest.php
- **Owner:** Those files have staged modifications not committed in any phase — needs investigation in a dedicated plan
