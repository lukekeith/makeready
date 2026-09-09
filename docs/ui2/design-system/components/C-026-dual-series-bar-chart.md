# C-026 DualSeriesBarChart — pannable day-column time chart: scheduled track + completed fill per day

Status: new · Specced: 2026-09-03 · Owner-designated: `/ui2-component time-bar-chart
<set url>` — owner pasted the variant-set link directly (normative per DECISIONS.md D10;
"time-bar-chart" is the invocation alias, the registry name stays role-based).

## 1. Normative source

- Variant set **"Bar chart"** — node `3633:4505`,
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3633-4505
  — two symbols: `state=Default` `3633:4504`, `state=Today` `3672:10323` (each 440×149).
- Frozen snapshot: `assets/C-026-dual-series-bar-chart.png` (whole set, captured
  2026-09-03 via get_screenshot + download_assets export).
- Known instance: home-dashboard frame node `3673:12011` is an instance of
  **state=Today** (verified 2026-09-03: instance internals resolve to `3672:103xx` ids).
- Sheet copy: not re-probed — the pasted node *is* the full set (variant enumeration is
  complete from the set itself); whether the set frame is parented to sheet `3632:4502`
  is unrecorded and immaterial to the contract.
- This contract **supersedes** the approximations in `../../screens/home-dashboard.md`
  §4 (relocated here 2026-09-03). Corrections vs that section, measured from the set's
  vector layers: high gridline is `color-highlight` (was stated `White/20%`), low
  gridline is `color-white-50` (was stated `White/20%`), and the TODAY rule is a
  **solid** 1px line (was stated dashed).

**Deviations (closed list):** — none —. Anything else that differs from the source is a
defect.

## 2. Anatomy & geometry

Fixed footprint 440×149 (full-bleed within `space-page-margin` insets on consumers).
Vertical map (y within component):

| y | Element |
|---|---|
| 0–15 | **Max badge**: value text right-aligned, container at x=409, Inter Regular 12 `color-highlight` (font flag: OQ-home-dashboard-5); wrapper carries a vestigial r4 with no fill/border — no visual effect, not a token use |
| 23 | **High gridline**: full-width hairline, 0.5pt `color-highlight`, dash 2/2 |
| 23–129 | **Column plot area** (baseline y=129; columns bottom-anchored; tallest sample column 98pt — sample fills are illustrative, per the sheet's sample-data convention) |
| 86–101 | **Min badge**: value text at x=416, Inter Regular 12 `color-text-primary`; same vestigial r4 wrapper |
| 109 | **Low gridline**: full-width hairline, 0.5pt white @50% (`color-white-50`), dash 2/2 |
| 137–152 | **Tick row**: inset x=15, width 400; ~5 date labels at data-driven x offsets (sample: "Jul 3 / Jul 10 / Jul 17 / Jul 24 / Aug 2"), Inter Regular 12 `color-white-50` |

**Columns:** one per day of the visible window (sample: 29), flex-equal width
(≈13.24pt at 29 columns), gap 2 (`space-chip-gap`), square corners. Each column is a
bottom-anchored stack: column height ∝ **scheduled** count; a bottom segment of height ∝
**completed** count fills `color-accent` (Purple/100%); the remainder above it is the
track, `color-white-20`. Completed ≤ scheduled by construction.

**Today overlay** (`state=Today` only): vertical rule at today's column boundary
(sample x=349), **solid** 1px `color-highlight`, spanning high gridline → baseline
(y 23–129, h 106); "TODAY" label Inter Bold 10 `color-highlight` right-aligned to the
rule (sample x=331, y=2).

All colors resolve to existing tokens — this set introduced **zero new tokens**
(variables consumed: `White/20%`, `Purple/100%`, `Text highlight`, `Color/Base/White`,
`White/50%`). Flagged literals: none beyond the vestigial r4 wrappers and the Inter
annotation font (OQ-home-dashboard-5).

## 3. Variant & state matrix

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| state | Default (`3633:4504`) | No today rule/label; every column renders its completed fill | designed-unconsumed — semantically the rendering when today is outside the visible window (fully-past pan position) |
| state | Today (`3672:10323`) | Solid `color-highlight` rule + "TODAY" label at today's column; the 6 columns right of the rule render **track-only** (future days have no completions); the sample additionally hides today's own fill (OQ-C-026-2) | **consumed** — home-dashboard Activity section (instance `3673:12011`) |
| — | empty window (no data) | undesigned | proposed default: render tick row only; no columns, no gridlines, no badges (OQ-C-026-1) |
| — | loading / error / pressed | undesigned | none proposed — chart is display-only; interactivity is pan only |

`state` is **derived, not a free prop**: Today rendering applies exactly when today's
date falls inside the visible window. Variants not in this table may not be built
without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `days` | `[(date, scheduled: Int, completed: Int)]` | one entry per day of the loaded timeline; column height ∝ scheduled, fill ∝ completed |
| `window` | date range | visible slice; drives which columns render, the tick labels, the max/min badge values, and the derived Default/Today rendering |
| `onPan` | callback | pan handler; the consumer syncs the shared timeline (home-dashboard: day rail ⇄ chart, one timeline, standard scroll physics) |

Behavior carried from home-dashboard §3 (still normative there): horizontally pannable;
timeline shared with the day rail; "Jump to today" recenters both.

## 5. Composition

- **Consumes:** no registry sub-components — bars, hairlines, rule, and labels are leaf
  geometry/text internal to this component (verified against the full node tree
  2026-09-03).
- **Consumed by:** home-dashboard (Activity section, `state=Today` instance). No other
  known or anticipated consumers yet.
- Siblings, not variants (verified distinct anatomy): C-024 SparkBarChart
  (in-card single-series micro bars), C-030 TimeActivityChart (fixed-period gradient-masked time chart),
  C-029 RadialDayClock (radial).

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-026-1 | Empty/zero-data window is undesigned — proposed default: tick row only, no columns/gridlines/badges. Acceptable? | No | Owner |
| OQ-C-026-2 | In the Today symbol, today's own column has its completed fill present but **hidden** (layer `3672:10393` hidden=true). Sample-data quirk or intent that today never shows a fill? Proposed default: today's column shows its real partial fill; only future columns are track-only | No | Owner |
| OQ-C-026-3 | Do max/min badge values recompute per visible window during pan (proposed default: yes, pinned at the gridline ends), or stay fixed to the loaded timeline's extremes? | No | Owner |
| (ref) OQ-home-dashboard-5 | Annotation font is Inter (Regular 12 ticks/badges, Bold 10 TODAY) vs SF Pro everywhere else — the owner-designated set itself uses Inter, new evidence toward "intentional" | No — becomes a closed deviation once ruled | Owner |
