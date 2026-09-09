# C-030 TimeActivityChart — fixed-period activity intensity: gradient fill masked by data bars

Status: new · Specced: 2026-09-03 · Owner-designated: `/ui2-component time-activity
<node url>` — owner pasted the component link directly (normative per DECISIONS.md D10)
with the stated purpose: "bars as a mask for a gradient fill to illustrate activity
during a fixed period of time; doesn't pan left/right, represents one period of time,
namely a 24-hr period". Renamed this run from **GradientHistogram** (ID stable; the
owner's axis ruling — see §3 note — makes "histogram" a misnomer: this is a time chart
over a fixed window, not a frequency distribution).

## 1. Normative source

- Main component **"Week completions"** — frame `3636:6337`, single symbol
  `style=Default` `3636:6336` (438×140),
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3636-6337
  (the Figma frame/layer name "Week completions" is historical — the Figma-name column
  convention applies; it does not describe the role).
- Frozen snapshot: `assets/C-030-time-activity-chart.png` (captured 2026-09-03).
- Known instance: home-dashboard Sessions section (registry previously cited frame-local
  node `3636:6548`).
- Sheet copy: not re-probed — the pasted node is the main component itself (single
  designed variant); sheet membership unrecorded and immaterial to the contract.
- This contract **supersedes** `../../screens/home-dashboard.md` §4's C-030 section
  (relocated here 2026-09-03) and **corrects its axis semantics** (owner ruling
  2026-09-03): x = position within one fixed, non-panning time window (e.g. a 24-hour
  day) and bar height = activity intensity at that time — NOT a session-length
  distribution; the "N mins" ticks in the sample are sample labels only.

**Deviations (closed list):** — none —. Anything else that differs from the source is a
defect.

## 2. Anatomy & geometry

Root: 438 wide vertical stack, gap 16 — chart area over tick row (140 total).

**Chart area (438×100):** a single horizontal gradient fill, alpha-masked by the bar
shapes. Gradient (left→right): `#ff4759` at 0% (raw literal in Figma, hex-equal to
`color-negative`/variable `Red/100` but not variable-bound — hygiene flag, OQ-C-030-3)
→ `color-accent` at 25% → `color-accent` at 75% → `color-positive` at 100%. Color is
pure positional encoding across the period (period start reads red, midday span purple,
period end green); it carries no per-bar meaning.

**Bar mask** (from the vector layer, measured 2026-09-03): bars 3px wide, corner radius
1.5 (pill ends), 5px pitch (2px gap), bottom-anchored to y=100; sample holds 88 bars
(88 × 5 ≈ 438 — bin count = width ÷ 5px pitch); bar height ∝ bin intensity, max 100;
near-zero bins render as ≥3px dot stubs in the sample. Bar/gap/radius values are
flagged literals (mask geometry, no tokens).

**Tick row (24pt, inset 16, justified space-between):** 4 × C-022 MetaPair — value
(SF Pro Regular 12/24 `color-text-primary`) + 4gap + unit (`color-text-secondary`).
Sample labels: "0 mins · 15 mins · 30 mins · 45 mins" — sample only per the axis
ruling; real labeling for a 24-hr instance is undesigned (OQ-C-030-2). Tick typography
is SF Pro here (unlike C-026's Inter annotations — no font flag needed).

## 3. Variant & state matrix

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| style | Default (`3636:6336`) | — (the only designed variant) | **consumed** — home-dashboard Sessions section (frame-local node `3636:6548`) |
| — | empty period (no activity) | undesigned | proposed default: all bins render the 3px dot stub at baseline, gradient still applied; ticks unchanged (OQ-C-030-1) |
| — | loading / error / pressed | undesigned | none proposed — display-only, no interactivity (fixed window, no pan) |

Owner axis ruling (2026-09-03, this run): x-axis = time within one fixed non-panning
window; supersedes home-dashboard §4's session-length reading. Variants not in this
table may not be built without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `bins` | `[Double]` | activity intensity per time slice of the fixed window, in order; count = chart width ÷ 5px pitch (88 at 438pt); values scale to bar heights, window max → 100pt |
| `tickLabels` | `[(value: String, unit: String)]` | 4 justified C-022 MetaPairs under the chart (e.g. hour marks for a 24-hr instance — pending OQ-C-030-2) |

No pan/interaction props — the component renders one fixed period. Aggregation (which
period, what resolution feeds `bins`) is consumer-side data prep.

## 5. Composition

- **Consumes:** C-022 MetaPair (tick row, ×4). Bars/gradient/mask are internal leaf
  geometry — no other registry rows (verified against the full node tree 2026-09-03).
- **Consumed by:** home-dashboard (Sessions section, below C-029 RadialDayClock — both
  read the same time-range filter per that spec). No other known or anticipated
  consumers yet.
- Siblings, not variants (verified distinct anatomy): C-026 DualSeriesBarChart
  (pannable multi-day dual series), C-024 SparkBarChart (micro bars, solid fill),
  C-029 RadialDayClock (radial 24-h ring).

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-030-1 | Empty/zero-activity period is undesigned — proposed default: all bins render the 3px baseline dot stub with the gradient applied. Acceptable? | No | Owner |
| OQ-C-030-2 | Tick labels for the real 24-hr instance are undesigned (sample shows "0/15/30/45 mins"). Proposed default: 4 justified hour MetaPairs ("12 AM · 6 AM · 12 PM · 6 PM"). Confirm labeling + whether home-dashboard's instance switches to hours | No | Owner |
| OQ-C-030-3 | Gradient's red stop is raw `#ff4759` — hex-equal to variable `Red/100` (`color-negative`) but unbound in Figma. Bind it (Figma cleanup), or is the stop deliberately independent of the negative-semantics token? | No | Owner |
