# Phase 12: Virtualized Member Table + Tag Filters - Validation Architecture

**Extracted from:** 12-RESEARCH.md
**Phase:** 12-virtualized-member-table-tag-filters

---

## Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel Feature Tests) |
| Config file | `/phpunit.xml` |
| Quick run command | `php artisan test --filter=MembersAdminTest` |
| Full suite command | `php artisan test --testsuite=Feature` |

## Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MLIST-02 | Search input creates name filter tag | manual (Vue component behavior) | n/a -- no JS test framework | n/a |
| MLIST-03 | Group filter tag chips | manual (Vue component behavior) | n/a -- no JS test framework | n/a |
| MLIST-04 | Status filter tag chips | manual (Vue component behavior) | n/a -- no JS test framework | n/a |
| MLIST-05 | Activity type filter tag chips | manual (Vue component behavior) | n/a -- no JS test framework | n/a |
| MLIST-06 | Remove individual/all filter tags | manual (Vue component behavior) | n/a -- no JS test framework | n/a |
| MLIST-07 | Table row renders name, avatar, groups, last active | smoke -- page renders member table markup | `php artisan test --filter=MembersAdminTest` | Wave 0 |
| MLIST-09 | 500+ members virtualized without degradation | manual browser perf test (scroll 500 rows) | n/a -- no automated perf test | n/a |

## Sampling Rate

- **Per task commit:** `php artisan test --filter=MembersAdminTest`
- **Per wave merge:** `php artisan test --testsuite=Feature`
- **Phase gate:** Full suite green before `/gsd:verify-work`

## Wave 0 Gaps

- [ ] `tests/Feature/MembersAdminTest.php` -- covers MLIST-07 smoke: GET /admin/members renders AdminIsland with members section mounted; verifies route returns 200 with correct blade layout

*(All MLIST-02 through MLIST-06 and MLIST-09 are Vue component interaction tests -- no JS test framework exists in this project. Behavior is verified by manual testing during `/gsd:verify-work`.)*
