---
phase: 09-members-enrollments-posts-analytics-profile
plan: "05"
subsystem: admin-analytics-dashboard
tags: [analytics, apexcharts, pinia, vue, dashboard, heatmap]
dependency_graph:
  requires: [groups.domain.ts, programs.domain.ts]
  provides: [analytics.domain.ts, analytics.ui.ts, dashboard-section.vue]
  affects: [admin-island, dashboard route /admin]
tech_stack:
  added: [apexcharts@^5.10.4, vue3-apexcharts@^1.11.1]
  patterns: [pinia-composition-store, apexcharts-series-transform, n1-cap-pattern]
key_files:
  created:
    - resources/js/islands/admin-island/stores/domain/analytics.domain.ts
    - resources/js/islands/admin-island/stores/ui/analytics.ui.ts
    - resources/css/components/admin/admin-dashboard.scss
  modified:
    - resources/js/islands/admin-island/sections/dashboard-section.vue
    - resources/css/app.scss
    - package.json
decisions:
  - "loadAll() caps enrollment detail fetches at 50 to prevent unbounded N+1 cascade — all groups' enrollments are collected first, then sliced before fetching details"
  - "Calendar loading uses separate isCalendarLoading flag so KPI cards and charts render immediately without waiting for the slow N+1 cascade"
  - "heatmapSeries uses colorScale ranges (not single color) to give visual gradient from near-zero to high activity"
  - "weeklyChartOptions categories mapped from domain.weeklyData.map(d => d.date) inside computed so categories stay reactive"
metrics:
  duration: 3 min
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 6
---

# Phase 09 Plan 05: Analytics Dashboard Summary

**One-liner:** ApexCharts heatmap + bar chart analytics dashboard with KPI cards and async calendar using Pinia stores with N+1-capped enrollment cascade.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Install ApexCharts and create analytics domain/UI stores | eb0d571 | analytics.domain.ts, analytics.ui.ts, package.json |
| 2 | Rewrite dashboard-section.vue with KPI cards, charts, and calendar | 4ab0e6b | dashboard-section.vue, admin-dashboard.scss, app.scss |

## What Was Built

### Analytics Domain Store (`analytics.domain.ts`)
- `loadHeatmap()` — GET `/admin/api/activity-logs/stats/heatmap` → `HeatmapBucket[]`
- `loadWeeklyStats()` — GET `/admin/api/activity-logs/stats` → `DayActivityCount[]`
- `loadCalendarEvents()` — N+1 cascade: loads all groups, then all group enrollments, caps at 50, loads enrollment details in parallel, extracts upcoming `lessonSchedules`, sorts by date
- `loadAll()` — heatmap + weekly stats in parallel, then calendar non-blocking
- Separate `isCalendarLoading` flag so fast data renders first

### Analytics UI Store (`analytics.ui.ts`)
- `totalGroups`, `totalMembers`, `activeEnrollments` KPI computeds
- `heatmapSeries` — 7-row ApexCharts series (Sun-Sat) × 24 columns (hour:00)
- `heatmapOptions` — dark theme, transparent background, colorScale from near-transparent to #7c3aed
- `weeklyChartSeries`, `weeklyChartOptions` — bar chart, #6c47ff, borderRadius 4
- `upcomingEvents` — first 20 from sorted calendarEvents
- `loadDashboard()` — calls groupsDomain.loadGroups() then domain.loadAll()

### Dashboard Section (`dashboard-section.vue`)
- 3 KPI cards (Groups / Total Members / Active Enrollments) with Lucide icons
- 2-column chart row: weekly bar chart + 7x24 heatmap
- Upcoming lessons calendar list with date, title, group name columns
- All three sections have loading/empty states

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- Build: `npm run build` passes (3.25s, 2464 modules)
- ApexCharts bundles as separate chunk (~517 kB gzipped 140 kB)
- Both stores type-check cleanly with TypeScript

## Self-Check

- [x] analytics.domain.ts exists at expected path
- [x] analytics.ui.ts exists at expected path
- [x] admin-dashboard.scss exists at expected path
- [x] dashboard-section.vue updated from stub
- [x] app.scss imports admin-dashboard
- [x] Commits eb0d571 and 4ab0e6b exist in git log
