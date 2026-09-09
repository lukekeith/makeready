# C-029 RadialDayClock — 24-hour radial activity ring with center key value

Status: new · Specced: 2026-09-03 · Owner-designated: `/ui2-component day-activity-chart
<node url>` — owner pasted the node link directly (normative per DECISIONS.md D10;
"day-activity-chart" is the invocation alias, the registry name stays role-based).

## 1. Normative source

- Frame **"Time chart"** — node `3634:4871` (357×326),
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3634-4871
  — a **plain frame, not a Figma component/set**: no variant axes exist in the source.
- Frozen snapshot: `assets/C-029-radial-day-clock.png` (captured 2026-09-03).
- Known sibling copy: home-dashboard's Sessions chart node `3636:5161` (the registry's
  previous ref — same name/anatomy; both are frame copies, neither is an instance of the
  other). The owner-designated `3634:4871` is now the normative ref.
- Sheet copy: none probed — no component of this anatomy is recorded on sheet
  `3632:4502`; the owner designated this frame directly.
- This contract **supersedes** `../../screens/home-dashboard.md` §4's C-029 section
  (relocated here 2026-09-03). Corrections vs that section, measured 2026-09-03: all
  chart text is **Inter**, not SF Pro (extends OQ-home-dashboard-5); the center value is
  Inter **Regular** 24 (was "Bold ~24"); the caption is Inter **Bold 18/24**
  `color-text-secondary` (was "Regular ~13"); hour labels are Inter Bold 12 bound to
  variable `text/navigation` #8d9fa7 (was "`text/secondary`"); the base ring is
  `color-white-10` (unstated before); and the arcs render in **three opacity bands** —
  `Purple/100%` / `Purple/50%` / `Purple/20%` — not a single purple.

**Deviations (closed list):** — none —. Anything else that differs from the source is a
defect.

## 2. Anatomy & geometry

Footprint 357×326; the donut is 280×280 centered at (178, 163) of the frame (x=38,
y=23); labels overhang the frame's layout box on all four sides.

**Base ring:** circle r=135 (centerline; 270pt diameter), stroke 10pt
`color-white-10`, full 360°.

**Activity arcs:** 10pt strokes on the same r=135 centerline, `color-accent` at one of
three opacities per arc — 100% (`Purple/100%`), 50% (`Purple/50%`), 20% (`Purple/20%`)
— opacity encodes activity concentration for that span (sample: 3 solid, 2 half, 1
faint). Arc angular spans in the sample are continuous (not hour-quantized) —
quantization is OQ-C-029-3; butt caps (no rounding observed in the path strokes).

**Tick dots:** 24 dots, 4pt diameter, fill `color-white-20`, evenly spaced (15°) on a
r=150 circle (300pt box centered on the donut) — one per hour.

**Hour labels:** 8, at the 3-hour compass points just outside the tick circle — 12 AM
top, then clockwise 3 AM, 6 AM (right), 9 AM, 12 PM (bottom), 3 PM, 6 PM (left), 9 PM.
Inter Bold 12, variable `text/navigation` #8d9fa7 — that variable has **no token row**
(near-duplicate of `color-nav-text` #8ea0a7, existing tokens.md hygiene flag; cite the
variable until the owner consolidates). Inter font: OQ-home-dashboard-5.

**Center key value** (146pt wide stack, gap 4, centered in the donut): value row —
number Inter Regular 24/24 `color-text-primary` + 2gap + unit Inter Regular 14/14
`color-text-secondary`, bottom-aligned; caption row — Inter Bold 18/24
`color-text-secondary`, centered (sample: "32 min / Average session").

No new tokens; flagged literals: 10pt ring stroke, 4pt dots, r135/r150 radii, the
`text/navigation` binding, and the Inter typography (all above).

## 3. Variant & state matrix

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| — | single designed rendering (`3634:4871`) | — (the source is a plain frame; no variant axes) | **consumed** — home-dashboard Sessions section (sibling frame copy `3636:5161`) |
| — | empty period (no activity) | undesigned | proposed default: base ring + ticks + labels only, no arcs; center value renders "0 min" with caption unchanged (OQ-C-029-2) |
| — | loading / error / pressed | undesigned | none proposed — display-only; the Sessions time-range dropdown (C-028) re-feeds it, the chart itself has no interactivity |

Variants not in this table may not be built without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `hourValues` | `[Double]` (24) | activity concentration per hour of the day; drives which angular spans render arcs and each arc's opacity band (banding rule: OQ-C-029-1) |
| `centerValue` | String | center number (sample "32") |
| `centerUnit` | String | unit beside the number (sample "min") |
| `centerCaption` | String | caption under the value (sample "Average session") |

Carried from home-dashboard §3 (still normative there): the Sessions time-range filter
(C-028 InlineDropdown: All time · Year · Month · Week) applies to this chart and C-030
together.

## 5. Composition

- **Consumes:** no registry sub-components — ring, arcs, dots, labels, and the center
  stack are leaf vectors/text internal to this component (verified against the full
  node tree 2026-09-03).
- **Consumed by:** home-dashboard (Sessions section). No other known or anticipated
  consumers yet.
- Siblings, not variants (verified distinct anatomy): C-030 TimeActivityChart (linear
  fixed-period gradient bars), C-026 DualSeriesBarChart (pannable day columns), C-062
  PercentDisc (small percent circle, not a time chart).

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-029-1 | How do `hourValues` map to the three arc opacity bands (100/50/20)? Proposed default: terciles of the period's non-zero hourly activity | No | Owner |
| OQ-C-029-2 | Empty period is undesigned — proposed default: ring + ticks + labels, no arcs, center "0 min". Acceptable? | No | Owner |
| OQ-C-029-3 | Sample arc spans are continuous (endpoints not on hour boundaries). Should the build render continuous minute-resolution spans (proposed default, per sample) or quantize arcs to whole hours? | No | Owner |
| (ref) OQ-home-dashboard-5 | Chart text here is entirely Inter (labels, value, unit, caption) — third chart component confirming the Inter-in-charts pattern | No — becomes a closed deviation once ruled | Owner |
