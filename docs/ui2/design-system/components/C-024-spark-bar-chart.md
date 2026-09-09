# C-024 SparkBarChart — in-card miniature single-series bar chart over a time period

Status: new · Specced: 2026-09-03 · Owner-designated: `/ui2-component <set url>` — owner
pasted the set link with a behavioral feature list (recorded in §4) and asked to
establish the chart naming pattern. Renamed this run from **MiniBarSparkline** (ID
stable; owner ruling 2026-09-03: chart components end `-Chart`, the qualifier names
form/scale, `Spark-` = in-card miniature — pattern recorded in the registry rules
header).

## 1. Normative source

- Variant set **"mini day chart"** — node `3672:9689` (on the component sheet),
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3672-9689
  — six symbols, `state` {Activity 1, Activity 2, No activity} × `align` {center,
  bottom}, each 97×64: Activity1/center `3672:9688`, Activity2/center `3672:9763`,
  NoActivity/center `3672:9690`, Activity1/bottom `3673:11386`, Activity2/bottom
  `3673:11411`, NoActivity/bottom `3673:11436`.
- Frozen snapshot: `assets/C-024-spark-bar-chart.png` (whole set, captured 2026-09-03).
- Owner behavioral requirements (invocation 2026-09-03) extend the contract beyond the
  drawn samples — §4 marks each owner-specified capability; they are normative intent,
  their undesigned visuals carry proposed defaults + OQs.
- This contract **supersedes** `../../screens/home-dashboard.md` §4's C-024 section
  (relocated here 2026-09-03) and corrects one semantic there and in C-023 KpiCard's
  section: the dashed annotation line is the series **average** with its value label —
  not a "max annotation" (owner ruling; the design agrees: in Activity1/bottom the line
  sits at mid-height, ~20/52pt below the tallest bar).

**Deviations (closed list):**

1. **`align=top` has no Figma symbol.** The set designs `center` and `bottom` only. `top` is
   owner-required (invocation 2026-09-03) and its geometry was **ruled by the owner on
   2026-09-07** (OQ-C-024-1) rather than drawn: the exact vertical mirror of `bottom`. A
   built render of this state therefore has no counterpart in the frozen snapshot, and the
   snapshot must not be read as evidence for or against it.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Sample footprint 97×64 (the symbols); the component itself is container-sized (§4
sizing). Horizontal row of bars, gap 2 (`space-chip-gap`), justified center.

**Bars:** 2pt wide, corner radius 2 (`radius-bar`), fill `color-accent`; height ∝
value (sample max 52pt within the 64pt symbol); **zero values render as 2×2pt dots**.
Sample count: 24 bars.

**Alignment:** `align=bottom` — bars grow up from the bottom edge (baseline row of
zero-dots). `align=center` — bars grow symmetrically from the vertical centerline,
waveform-style. `align=top` (owner ruling 2026-09-07, OQ-C-024-1; no Figma symbol — §1
deviation 1) — the **exact vertical mirror of `bottom`**: bars hang down from the top edge
with the zero-dot row along that edge, the average hairline measured down from the top, and
the annotation stack mirrored — hairline first with the label **below** it, the stack's top
edge on the average y.

**Average annotation** (designed on the bottom symbols; owner-generalized): a stack
(gap 4, items-end) positioned at the average value's y — label (SF Pro Semibold 12/12
`color-text-secondary`, = `type-caption-semibold`; sample "24hrs") right-aligned above
a full-width dashed hairline, 0.5pt `color-white-50` dash 2/2 (the program's standard
chart hairline — same recipe as C-026's low gridline). Left-side label placement is
owner-specified, undesigned (OQ-C-024-4). Note this annotation is SF Pro, unlike
C-026/C-029/C-030's Inter annotations (OQ-home-dashboard-5 does not extend here).

No new tokens; flagged literals: 2pt bar/dot module and the 0.5pt dash-2/2 hairline.

## 3. Variant & state matrix

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| align | center (`3672:9688` et al.) | bars mirror about the vertical center; no annotation designed in the center samples | **consumed** — C-025 DayActivityCard middle block (home-dashboard, members-profile, enrollment-home hosts) |
| align | bottom (`3673:11386` et al.) | bars rise from baseline; average annotation designed | **consumed** — C-023 KpiCard (home-dashboard Overview rail) |
| align | top | exact vertical mirror of `bottom`: bars hang from the top edge (zero-dot row along it), average hairline measured down from the top, annotation stack mirrored — hairline above its label, stack top on the average y. **No Figma symbol** — geometry by owner ruling, §1 deviation 1 | **unconsumed** — owner-required (invocation 2026-09-03); geometry **ruled by the owner 2026-09-07**, resolving OQ-C-024-1. No screen consumes it yet |
| state | No activity (both aligns) | every bar renders the 2pt zero-dot (center: dotted midline; bottom: dotted baseline) | **consumed** — the rendering behind C-025's `isZero` |
| state | Activity 1 / Activity 2 | — sample data series, not distinct behaviors | n/a (samples) |
| — | loading / error / pressed | undesigned | none proposed — display-only |

`state=No activity` is derived (all-zero series), not a free prop. Variants not in this
table may not be built without a ruling.

## 4. Props contract

Owner-specified capabilities (invocation 2026-09-03) are marked ⊕; designed behavior
unmarked.

| Prop | Type | Purpose |
|---|---|---|
| `series` | `[Double]` | the single data series over the period, any point count |
| `targetBars` ⊕ | `Int?` | desired rendered bar count; when `series.count` exceeds it, values are aggregated per bucket to consolidate into `targetBars` bars (aggregation function: OQ-C-024-2); nil = one bar per point |
| `align` | `top ⊕ / center / bottom` | bar anchoring (top is owner-required, undesigned — OQ-C-024-1) |
| `widthFill` ⊕ | mode | how the row fills the container width: bars stretch (wider bars, 2pt gap) or gaps stretch (2pt bars, wider gaps) — owner: "depending on the amount of data"; explicit prop vs automatic rule is OQ-C-024-3 |
| `showAverage` | `Bool` | render the dashed average line at the series-average y |
| `averageLabel` | `String?` | label at the average line (sample "24hrs"); nil = line only |
| `averageLabelSide` ⊕ | `left / right` | label placement (right designed; left undesigned — OQ-C-024-4) |

**Sizing** ⊕: the component has no intrinsic size — it fills the height and width of
its container; a fixed-height rendering is achieved by fixing the container (the 97×64
symbols are samples of this, not an intrinsic footprint). Bar heights scale to the
container: series max → full available height (half-height per side when centered).

## 5. Composition

- **Consumes:** no registry sub-components — bars, dots, hairline, and label are leaf
  geometry/text (verified against the full node tree 2026-09-03).
- **Consumed by:** C-023 KpiCard (bottom + average annotation), C-025 DayActivityCard
  (center; No-activity state behind `isZero`). Anticipated: any card needing an inline
  single-series trend.
- Siblings, not variants (verified distinct anatomy): C-026 DualSeriesBarChart
  (full-size, two series, pannable), C-030 TimeActivityChart (gradient-masked fixed
  period), C-057 PercentBar (single progress value, not a series).

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| ~~OQ-C-024-1~~ | **RESOLVED 2026-09-07 (owner).** `align=top` renders as the exact vertical mirror of `bottom` — bars hang from the top edge, annotation stack mirrored below its line — as proposed. Recorded in §2 Alignment and the §3 matrix; carried in §1 as deviation 1 because no Figma symbol exists for it | — | — |
| OQ-C-024-2 | Aggregation function when consolidating `series` into `targetBars` buckets — proposed default: SUM per bucket (counts/durations); mean would flatten peaks. Confirm, and confirm equal-width bucketing | No | Owner |
| OQ-C-024-3 | The bars-stretch vs gaps-stretch width-fill choice: explicit consumer prop, or an automatic rule keyed to bar count ("depending on the amount of data")? If automatic, what's the threshold? | No | Owner |
| OQ-C-024-4 | Average label on the LEFT is undesigned — proposed default: mirror of the right placement (left-aligned above the line). Also confirm label content format (sample "24hrs" = value + unit run together) | No | Owner |
