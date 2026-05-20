---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Admin CRUD Panel
status: planning
stopped_at: "Checkpoint: 12.1-05 Task 4 human-verify — admin panel visual verification pending"
last_updated: "2026-03-22T00:09:45.299Z"
last_activity: 2026-03-21 — v2.1 roadmap created; 20/20 requirements mapped across phases 10-14
progress:
  total_phases: 16
  completed_phases: 14
  total_plans: 48
  completed_plans: 51
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-21)

**Core value:** Group leaders can see, manage, and understand every member across their entire organization from a single unified interface
**Current focus:** v2.1 Phase 10 — Foundation (route, packages, sidebar nav)

## Current Position

Phase: 10 of 14 (Foundation)
Plan: — (not yet planned)
Status: Ready to plan
Last activity: 2026-03-21 — v2.1 roadmap created; 20/20 requirements mapped across phases 10-14

Progress (v2.1): [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity (v2.0 reference):**
- Total plans completed (v2.0): ~19 plans
- Average duration: ~7 min/plan
- Total execution time: ~133 min

**By Phase (v2.0):**

| Phase | Plans | Avg/Plan |
|-------|-------|----------|
| 05-admin-shell | 2 | ~10 min |
| 06-groups-crud | 3 | ~8 min |
| 07-programs-lessons | 3 | ~11 min |
| 08-activity-editor | 3 | ~3 min |
| 09-members-enrollments | 6 | ~7 min |

**v2.1 Trend:** Not started
| Phase 10-foundation P01 | 8 | 2 tasks | 4 files |
| Phase 11-cross-group-member-aggregation P01 | 1 | 2 tasks | 3 files |
| Phase 12-virtualized-member-table-tag-filters P01 | 2min | 2 tasks | 4 files |
| Phase 12 P02 | 2 | 2 tasks | 6 files |
| Phase 13-member-profile-drawer P01 | 2 | 2 tasks | 4 files |
| Phase 12.1-migrate-admin-to-shadcn-vue-tailwind P01 | 178s | 2 tasks | 165 files |
| Phase 12.1-migrate-admin-to-shadcn-vue-tailwind P02 | 5min | 3 tasks | 17 files |
| Phase 12.1-migrate-admin-to-shadcn-vue-tailwind P03 | 205s | 2 tasks | 4 files |
| Phase 12.1 P04 | 8min | 2 tasks | 4 files |
| Phase 12.1-migrate-admin-to-shadcn-vue-tailwind P05 | 4min | 3 tasks | 21 files |

## Accumulated Context

### Decisions

Key v2.1 architectural constraints (from research):
- [v2.1]: No cross-group aggregate API — fan out to per-group members endpoint using Promise.allSettled; deduplicate by userId client-side in all-members.domain
- [v2.1]: TanStack Table must receive computed(() => [...store.allMembers]) not a shallowRef — prevents stale data after mutations
- [v2.1]: Virtualization and pagination are mutually exclusive — getCoreRowModel() only; fixed row height estimateSize: () => 56
- [v2.1]: All filter state must live in Pinia (members-list.ui store) — never split between TanStack column filter model and Pinia
- [v2.1]: /admin/members route must be registered before any component work — catch-all wildcard currently redirects unregistered paths to dashboard
- [v2.1]: Phase 14 (Activity History) is gated on API verification — do not plan or execute until GET /admin/api/members/:memberId/lessons is confirmed
- [Phase 10-foundation]: No loading skeleton or empty state in members-section.vue placeholder — added only title per user decision
- [Phase 10-foundation]: /admin/members route inserted before catch-all to prevent wildcard redirect to /admin dashboard
- [Phase 11-cross-group-member-aggregation]: allMembers is a computed reading membersDomain.membersByGroup reactively — re-evaluates per group load for progressive rendering without manual watchers
- [Phase 11-cross-group-member-aggregation]: member-activity.domain shell kept minimal — Phase 14 gated on API endpoint verification, shell prevents breaking changes when Phase 14 populates refs
- [Phase 12-virtualized-member-table-tag-filters]: memberColumns exported from members-list.ui.ts alongside store — co-locates column definitions with the domain type they describe
- [Phase 12-virtualized-member-table-tag-filters]: status/type filter stubs return true — Phase 14 activity data required before real filter logic can be implemented
- [Phase 12]: reka-ui ComboboxRoot uses controlled model-value with local ref reset — ensures combobox input clears after selection
- [Phase 12]: Warning banner styles added to admin-virtual-table.scss not a new file — banner is rendered by members-section.vue which already uses that BEM block namespace
- [Phase 13-member-profile-drawer]: Enrollment endpoint failures silently set enrollmentProgress to [] — not all members have enrollments so 404/errors are expected
- [Phase 13-member-profile-drawer]: closeDrawer resets state with 200ms setTimeout delay to allow slide-out transition to complete before data clears
- [Phase 13-member-profile-drawer]: removeFromGroup looks up membership ID from membersDomain.membersByGroup cache; loads group first if uncached — avoids passing userId to removeMember which expects membership ID
- [Phase 12.1]: Tailwind v4 @theme inline used to bridge CSS variable HSL values to Tailwind color utilities
- [Phase 12.1]: components.json created manually — shadcn-vue init CLI is interactive and cannot be automated with --yes
- [Phase 12.1-02]: SidebarProvider forced dark mode via class='dark' on container — admin island only, no global body .dark
- [Phase 12.1-02]: AdminTable preserves original string[] columns + TableRow[] rows interface — not migrated to column-definition pattern
- [Phase 12.1]: AdminForm Select uses String() model-value coercion for dynamic field binding — Select requires string, fields array holds any-typed values
- [Phase 12.1]: AdminActivityList Accordion wraps VueDraggable — AccordionTrigger delegates to handleActivityClick; editor in AccordionContent only when editingActivityId matches
- [Phase 12.1]: Spacer rows in virtual table use bare <tr class=border-0> not <TableRow> — prevents hover/focus styles leaking onto invisible spacer rows
- [Phase 12.1]: @radix-icons/vue installed — missing dep used by shadcn Command/Dialog/Dropdown components (pre-existing omission from Plan 01)
- [Phase 12.1-05]: reka-ui TabsRoot replaced with shadcn Tabs in groups/programs — shadcn provides identical v-model with dark theme styling
- [Phase 12.1-05]: All 16 admin SCSS files deleted — app.css reduced from 163.90 kB to 125.58 kB after removing all admin @use imports

### Roadmap Evolution

- Phase 12.1 inserted after Phase 12: Migrate admin to shadcn-vue + Tailwind (URGENT) — user wants to upgrade admin UI quality before continuing member management phases. All existing BEM admin components replaced with shadcn-vue. Tailwind scoped to AdminIsland only. Blade/SSR pages remain SCSS/BEM.

### Pending Todos

- Phase 13-02 checkpoint pending — human verification of member profile drawer was in progress when 12.1 was inserted. Resume after 12.1 completes, but drawer will be rebuilt with shadcn-vue anyway.

### Blockers/Concerns

- [Phase 14 — CRITICAL]: Activity history API endpoints unconfirmed. GET /admin/api/members/:memberId/lessons and lesson detail with activity progress have no iPhone reference. Must run /gsd:research-phase 14 before planning Phase 14. If endpoints require server-side work, escalate as cross-repo blocker.
- [Phase 14 — HIGH]: isGroupLeader bypass through Laravel proxy unverified. Admin proxy session satisfying both Google OAuth and member auth requirement needs prototype confirmation.
- [Phase 14 — HIGH]: Written response content format (SOAP journals, USER_INPUT) may be Lexical JSON, HTML, or plain text. Renderer cannot be selected without inspecting a real API response.
- [Phase 11 — LOW]: Per-group member API pagination shape unconfirmed. If cursor-paginated, all-members.domain fan-out must handle append-on-scroll. Inspect response envelope during Phase 11 implementation.

## Session Continuity

Last session: 2026-03-22T00:09:45.296Z
Stopped at: Checkpoint: 12.1-05 Task 4 human-verify — admin panel visual verification pending
Resume file: None
