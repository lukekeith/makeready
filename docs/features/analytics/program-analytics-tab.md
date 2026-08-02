# Program Home Analytics Tab — UI Spec (iPhone)

Replaces the "Coming soon" stub at `ProgramHomePage.swift:1631-1645` (tab wiring :528/:541, refresh stub :395). Ticket: monday#12661762474. Unfiltered, program-scoped; the only control is the time toggle on the Recent Activity chart. All data reads the flat analytics layer (architecture.md) via one wrapper endpoint.

## Data contract — `GET /api/programs/:id/analytics`

One round trip assembling registry queries (+ the two engagement-shaped series). Org-scoped access like `/api/enrollments/:id/completion-stats`. Query params: `timezone` (IANA), `days` (for the heatmap window, default 30).

```jsonc
{
  "success": true,
  "freshAsOf": "2026-07-29T20:40:00Z",
  "kpis": {
    "membersReached": 24, "activeEnrollments": 3, "totalEnrollments": 5,
    "lessonCompletions": 212, "completionRate": 0.68,          // Σ lessonCompletions ÷ Σ per-enrollment (active members × active schedules) — see metrics-catalog.md
    "videoCompletions": 87, "watchSeconds": 154320, "avgWatchPercent": 0.83
  },
  "recent": {                                                   // three pre-zero-filled series
    "week":  [{ "date": "2026-07-23", "count": 4 }, …],         // 7 daily points
    "month": [{ "date": "…", "count": … }, …],                  // 30 daily points
    "year":  [{ "date": "2025-08-01", "count": … }, …]          // 12 monthly points
  },
  "heatmap": [{ "day": 0, "hour": 8, "count": 3 }, …],          // engagement.ts shape, program-scoped
  "topGroups": [{ "groupId": "…", "groupName": "…", "memberCount": 9, "lessonCompletions": 20, "completionPct": 0.74 }, …],  // owner-requested 2026-07-30: every enrolled group ranked by completion, top 10; pct = completions ÷ Σ(active members × active schedules) per group
  "funnel":  [{ "dayNumber": 1, "membersCompleted": 22 }, …],   // one row per curriculum day; distinct members with LESSON_COMPLETED for that day (not partial activity)
  "contentMix": [{ "activityType": "VIDEO", "completions": 87 }, …],
  "topMembers": [{ "memberId": "…", "name": "…", "avatarUrl": null, "groupName": "…", "completions": 41 }, …],   // top 10
  "topEnrollments": [{ "enrollmentId": "…", "groupName": "…", "memberCount": 9, "lessonCompletions": 70, "completionPct": 0.74 }, …]
}
```

iPhone: models in `State/Models/` (move `HeatmapBucket`/`DayActivityCount` out of `MemberHomePage.swift:1098-1120` into a shared model file while adding the new types), fetch via a `ProgramActions.getProgramAnalytics(programId:)` action, cache-first in AppState (`programAnalyticsById: [String: ProgramAnalytics]`), background refresh on tab select + pull-to-refresh via the existing `refreshCurrentTab` case 2.

## Layout (top → bottom, ScrollView)

Reference styling: `MainHome.chartsSection` (:585-645) — section title `Typography` + card backgrounds, `chartLoadingState` skeleton while `!loaded`, empty-state overlay pattern for zero data.

### 1. KPI grid — 2×2 `Kpi` (.standard, uniform cells)
Built as explicit rows of fixed-height (116pt) cells using `Kpi(expand: true)` (param added 2026-07-30: fills the proposed frame, content top-leading, so the card background stretches) — a bare LazyVGrid let each card hug its content, producing ragged widths/heights. `.standard`, not the originally-specced `.compact`, because compact drops the `description` line ("of {total} total").
- **Members reached** (`membersReached`) — icon `person.2`
- **Active enrollments** — value `activeEnrollments`, description "of {totalEnrollments} total"
- **Lessons completed** (`lessonCompletions`)
- **Completion rate** (`completionRate`, `.percent`)

### 2. Video row — 2 `Kpi` (.compact)   *(owner-requested)*
- **Watch time** — `watchSeconds` formatted "42h 12m" (`.custom` value type)
- **Video completions** — `videoCompletions`, description "avg {avgWatchPercent}% watched"
Hide the whole row when the program has no video activities.

### 3. Recent activity — segmented `Week · Month · Year` + `VerticalBarChart`
- **Columns, not a line (owner direction 2026-07-30):** discrete daily counts must read exactly; the original monotone LineChart implied values between days and made magnitudes hard to judge. `VerticalBarChart` brand color; `showValues` on the 7-bar week view only; the 30-bar month view thins x-axis marks to ~weekly via the chart's `xAxisValues` param (added for this — category labels must stay unique per bar or Swift Charts merges them).
- Series come pre-zero-filled from the server; toggle is pure client state (all three series in the one payload — no refetch).

### 4. Activity heatmap — `HeatMapChart`, "like the dashboard"
- Mirror `MainHome` exactly: 7 columns × 24 rows, x = day labels, y = `12a…11p`, `chartHeight: 576`, default brand ramp.
- **Mapping trap**: `HeatMapChart` field names are transposed — map `bucket.day → week` and `bucket.hour → day` exactly as `MainHome.heatmapData` (:48-58) does.
- Window: last 30 days (denser than the dashboard's 7 at program scale). Caption "Last 30 days".

### 1b. Top groups — table, directly below the KPI grid (owner-requested 2026-07-30, shipped with B2)
One card, a divider-separated row per enrolled group (top 10 by completion %): group name + "{memberCount} members" subtitle, trailing completion % over a "Completion" caption (mirrors the left subtitle's type/opacity) + thin brand capsule progress fill. Data = `topGroups` (server-ranked; groups with zero completions still listed). Section hidden when the program has no enrolled groups. Tab order is now: KPI grid → Top groups → Recent activity → heatmap → (Phase C sections) → freshness footer.

### 5. Lesson funnel — `VerticalBarChart`
- x = "Day 1"…"Day N" (`funnel.dayNumber`), y = `membersCompleted`, `showValues: false` above ~10 bars.
- This is popular-content AND drop-off in one chart: tall bars = popular lessons, the cliff = where members stop. Section caption: "Members completing each day".

### 6. Content mix — `DonutChart` + `DonutChartLegend`
- Slices = `contentMix` by activity type (Video / Read / Exegesis / Write / YouTube), center label = total completions, `centerLabelSubtext: "completions"`. First production DonutChart use.
- Hide when the program has < 2 activity types.

### 7. Top members — leaderboard list (top 5, "Show all" expands to 10)
- Row: rank number + `Avatar` (initials fallback per compare-memory) + name + group name subtitle + trailing completion count. Reuse the member-row component family; no new component.

### 8. Top enrollments — ranked rows
- Row: group name + "{memberCount} members" subtitle + trailing `completionPct` badge + a thin progress fill (HorizontalBarChart-style, or an inline capsule fill — match `CardLesson` fill idiom).
- Full list (programs rarely exceed ~10 enrollments); tapping a row is a non-goal for v1.

### Empty / loading / freshness

**Sparse data is the launch-day norm, not the edge case** (production currently holds ~60 engagement events total): every section must look intentional at 1-20 events — LineChart with `.monotone` over 3 points, a heatmap with 5 filled cells on the quiet ramp, a funnel with single-digit bars. Design-review each chart against a 5-event fixture, not just the rich mock.
- Whole-tab empty state when the program has zero enrollments **or zero activity anywhere in the payload** (owner rule 2026-07-30): illustration-free, "No activity yet — analytics appear once groups enroll and members engage." (matches MainHome's empty-overlay tone).
- **Per-section zero data → HIDE the section** (owner rule 2026-07-30, supersedes the original keep-with-overlay pattern): Top groups hides when no group has a completion; Recent activity hides only when ALL THREE series are flat (one empty period keeps the section — the toggle's other periods have data — with its per-period overlay); heatmap hides when no bucket is non-zero; plus the original video-row and donut hide-rules.
- **Heatmap zero-fill:** the server sends only non-zero buckets and HeatMapChart's domain is data-driven, so the client zero-fills the full 7×24 grid before charting — sparse data must never drop empty day columns (found via the `analytics-sparse` capture variant).
- Footer caption: "As of {freshAsOf, relative}" — surfaces the matview refresh honestly.

## Build order

| Step | What | Files |
|---|---|---|
| B1 | Wrapper endpoint (kpis + recent + heatmap only, funnel/mix/tops return `[]`) | `server/src/routes/program-analytics.ts` + `services/analytics.service.ts` |
| B2 | Tab UI sections 1, 3, 4 + loading/empty/freshness | `ProgramHomePage.swift` + models + `ProgramActions` |
| C1 | Registry queries for funnel/mix/tops + video KPIs in the wrapper | server |
| C2 | Sections 2, 5, 6, 7, 8 | iPhone |

Phase A (the analytics layer itself) precedes B1 — see architecture.md. Do NOT ship the tab reading the transactional tables directly "temporarily"; the layer is the point.

## Out of scope (repeat of dossier)
`MainHome`/`HomeActions` untouched (Phase D migrates them); `EnrollmentSchedulePage` untouched; web LeaderApp program-home twin is a later parity pass; no ledger writes.
