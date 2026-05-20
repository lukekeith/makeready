---
phase: 11-cross-group-member-aggregation
plan: 01
subsystem: ui
tags: [pinia, vue, typescript, cross-group, deduplication, promise-allsettled]

# Dependency graph
requires:
  - phase: 10-foundation
    provides: members-section.vue placeholder, admin route, sidebar nav wired
provides:
  - Cross-group member aggregation via useAllMembersDomain with UnifiedMember interface
  - Promise.allSettled fan-out with per-group error resilience and failedGroups tracking
  - allMembers computed that reactively deduplicates members by userId across all groups
  - useMemberActivityDomain shell store for Phase 14 (Activity History)
  - members-section.vue wired to trigger loadAll() on mount
affects: [12-virtualized-table-filters, 13-member-profile-drawer, 14-activity-history]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-store composition: useAllMembersDomain calls useGroupsDomain() and useMembersDomain() at top of setup function"
    - "Progressive loading via reactive computed: allMembers re-evaluates each time membersByGroup mutates"
    - "Promise.allSettled fan-out: all per-group loadMembers() fired in parallel, failures collected into failedGroups"

key-files:
  created:
    - resources/js/islands/admin-island/stores/domain/all-members.domain.ts
    - resources/js/islands/admin-island/stores/domain/member-activity.domain.ts
  modified:
    - resources/js/islands/admin-island/sections/members-section.vue

key-decisions:
  - "allMembers computed reads from membersDomain.membersByGroup reactively — each per-group load triggers re-evaluation without manual watchers"
  - "ISO string comparison used for lastActive derivation — sufficient given joinedAt format from API"
  - "member-activity.domain.ts intentionally minimal (shell only) — Phase 14 populates refs after API endpoint verification"

patterns-established:
  - "Cross-domain composition pattern: domain stores compose peer domain stores by calling use*Domain() inside setup function"
  - "Resilient fan-out pattern: Promise.allSettled + failedGroups array for partial-success handling"

requirements-completed: [MLIST-01]

# Metrics
duration: 1min
completed: 2026-03-21
---

# Phase 11 Plan 01: Cross-Group Member Aggregation Summary

**Pinia store that fans out per-group member loads via Promise.allSettled, deduplicates by userId into a reactive UnifiedMember computed, and wires members-section.vue to trigger loading on mount**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-21T18:05:48Z
- **Completed:** 2026-03-21T18:06:45Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- useAllMembersDomain store with UnifiedMember interface, allMembers computed with userId deduplication, loadAll() with Promise.allSettled fan-out
- useMemberActivityDomain shell store with empty refs for Phase 14 to populate
- members-section.vue wired to loadAll() on mount with loading state, member count, and failed groups warning

## Task Commits

1. **Task 1: Create all-members.domain and member-activity.domain stores** - `757e04e` (feat)
2. **Task 2: Wire members-section.vue to trigger loadAll on mount** - `1f56260` (feat)

## Files Created/Modified
- `resources/js/islands/admin-island/stores/domain/all-members.domain.ts` - Cross-group aggregation store with UnifiedMember interface, deduplication computed, and Promise.allSettled loadAll()
- `resources/js/islands/admin-island/stores/domain/member-activity.domain.ts` - Shell store with empty refs for Phase 14
- `resources/js/islands/admin-island/sections/members-section.vue` - Wired to loadAll() on mount, shows loading/count/failed groups indicators

## Decisions Made
- allMembers is a `computed` (not a shallowRef) reading from membersDomain.membersByGroup — aligns with v2.1 architectural constraint from STATE.md
- ISO string comparison (`member.joinedAt > existing.lastActive`) used for lastActive because joinedAt strings from the API are sortable ISO format
- Shell store kept minimal by design — Phase 14 gated on API endpoint verification per STATE.md blocker

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Pre-existing TypeScript errors in histoire.config.ts, join-verify-island.vue, and lesson-island.vue — out of scope, not related to this plan's changes. Vite build passes successfully.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- allMembers computed is ready for Phase 12 (virtualized TanStack Table) to consume via computed(() => [...store.allMembers])
- failedGroups ref available for Phase 12 to render per-group error banners
- useMemberActivityDomain shell in place for Phase 13/14 to populate without breaking changes
- NOTE: Verify per-group member API pagination shape during Phase 12 implementation (STATE.md low-priority blocker)

---
*Phase: 11-cross-group-member-aggregation*
*Completed: 2026-03-21*
