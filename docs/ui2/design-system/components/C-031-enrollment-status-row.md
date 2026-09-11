# C-031 EnrollmentStatusRow — one aggregate's completion, as a disc + labelled bar row

Status: `new` · Specced: 2026-09-10 · Owner-designated: `/ui2-component EnrollmentStatusRow
<set url>` with the set `3526:30288` pasted by the owner 2026-09-10 (D10 — the owner's paste
designates the SET normative; the registry already anchored this row to it, alongside the
home-dashboard frame instance `3622:5617`). This file **relocates** the contract from
`screens/home-dashboard.md` §4 (pointer left there).

Includes sub-component **C-073 StatusPercentDisc** (own registry row, contract in §3c below —
it is instantiated nowhere but inside this row, and it is a distinct component from C-062
PercentDisc, which OQ-C-031-5 asks the owner to confirm or consolidate).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3526-30288
  — set `3526:30288` (Figma name "Progress status"), one axis `state`, **1** symbol
  (`state=Default`, `3526:30287`), 410×64. Parented to the component sheet at (4291, 901), so
  D9's sheet caveat and D10's owner designation both apply and agree.
- Sub-component main: `3525:30266` ("Percent indicator", `property1=Default`) → C-073.
- Consuming instance measured for the width deviation: `3622:5617` (home-dashboard Engagement).
- Frozen snapshot: `assets/C-031-enrollment-status-row.png` (1046×352, 2×) — captured 2026-09-10
- C-073 frozen snapshot, same capture: `assets/C-073-status-percent-disc.png` (128×128, 2×)

**Corrects `screens/home-dashboard.md` §4**, which this file supersedes: that section states
the right column's 16pt gap but not the row's internal **8pt** gap, and types the count as
"right-aligned 40pt" without saying the label and bar cells are the two flexing cells. Both are
measured here. No prop is renamed.

**Deviations (closed list):**
1. All strings — "Members current", "52", "78", "178 total members enrolled across 8 groups"
   — are per-instantiation content.
2. The set frame is 523×176 with 20pt gutters around the symbol; the component is the 410×64
   symbol, not the frame.
3. The component is **width-driven**. The symbol is 410 wide; both consuming screens render it
   at 408, and the difference is absorbed by the two flexing cells (label and bar, 137 → 136
   each — measured on `3622:5617`). Height is fixed at 64 by the disc.
4. The disc's ground is `rgba(108,255,115,0.2)` — the status colour at **20% opacity**, and
   **not variable-bound**, where the disc's number *is* bound (`green`). Same
   band-colour-at-20% construction `screens/enrollment-home.md` §4 states for C-062, and
   `tokens.md` has neither a `color-positive-20` row nor an opacity-modifier mechanism
   (§3c, OQ-C-031-2).
5. The C-057 bar's fill in the consumed sample is the raw literal `#4deb4b`, not
   `color-positive` (#6cff73) — C-057's already-recorded green anomaly, OQ-home-dashboard-6.
   Its sibling sample renders `#ff4759`, hex-equal to `color-negative` and likewise unbound.
6. **One symbol spends two greens.** The disc's number is the bound `green` #6cff73; the bar
   beside it is the literal #4deb4b. This is the strongest evidence yet on
   OQ-home-dashboard-6 and is recorded, not designed around (OQ-C-031-2).
7. The bar's fill length is C-057 sample content (`percent=25` → a 29pt fill in a 255pt track,
   ≈11%) and does **not** equal the disc's 78%. The two are not a designed relationship
   (OQ-C-031-3).
8. The disc declares `px14 py18` in the source but centres its content (`justify-center`), so
   the effective inset is 14 / **20** and the declared vertical padding is inert. §3c states
   the measured centring, not the declared padding.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

410×64 in the set, **width-driven** (deviation 3). No fill, no border, no radius — the row
paints nothing of its own; every pixel belongs to one of its two slots.

Root: a horizontal pair, vertically centred, gap **16** — FLAGGED LITERAL: `tokens.md`'s
spacing family is 16/16/8/32/4/2/24, and its two 16s (`space-page-margin`,
`space-card-padding`) are a page inset and a card inset. Neither names a gap *inside* a row
between a leading indicator and its content column, so D7's "per-component literal, explicitly
flagged" path applies rather than a new token row (OQ-C-031-6).

1. **Disc** — **C-073 StatusPercentDisc**, 64×64, fixed. It is the only thing that sets the
   row's 64pt height.

2. **Info** — flexible width (330 at the set's 410, 328 at a consumer's 408), intrinsic height
   46, vertically centred in the 64pt row (9pt above and below). A two-row column, gap **16**
   — the same flagged literal as the root gap, and for the same reason:

   - **Metrics row** — full width, 16 tall, contents vertically centred, gap
     `space-element-gap` (8). Three cells, left → right:
     - **Label** — `type-body` (Regular 14/14) `color-text-primary`, **flexes**.
     - **Count** — `type-body` `color-text-primary`, **right-aligned in a fixed 40pt cell**.
     - **C-057 PercentBar** (`style=Thick` 16pt, `aligned=Right`), **flexes**. At the set's
       410 the two flexing cells are 137 each; the bar is the full 16pt row height.
   - **Subtitle** — full width, `type-body` (Regular 14/14) `color-text-secondary`, one line.

   *(`type-body`'s line-height was carried as unmeasured in `tokens.md` and is measured here at
   14/14 — this row is the observation the token row already cited.)*

The column closes on 46 exactly: `16 + 16 + 14`.

## 3. Variant & state matrix

### 3a. `state` (1 designed)

| `state` | Geometry delta | Consumption |
|---|---|---|
| `Default` | the only symbol; §2 as measured | consumed — home-dashboard (Engagement), study-program-home (Group Activity) |

The set carries no second value on this axis, and no other axis. `state` therefore names one
thing today; whether it is a real axis awaiting siblings or a Figma habit is not something the
source says.

### 3b. Status colour, zero state, interaction — undesigned

| Aspect | Status |
|---|---|
| `statusColor` beyond green | **undesigned**. One symbol exists and it is green. The banding rule (which percentage earns which colour) is undesigned program-wide — OQ-home-dashboard-3, OQ-study-program-home-5. **Proposed default + OQ-C-031-1:** the prop stays open (any status colour), and no threshold is invented. |
| zero / empty | **undesigned**. `screens/study-program-home.md` §3 says the section renders "C-031 zeroed" at zero enrollments, and OQ-study-program-home-7 already owns the undesigned zero visuals. **Proposed default + OQ-C-031-4:** 0 in the disc, a zero-width bar fill, and the strings the consumer supplies — nothing new drawn. |
| `pressed` / `disabled` | **undesigned**. §4 gives the row no action prop, and neither consuming spec taps the row itself (home-dashboard's Engagement arrow lives on C-020's accessory, and where it leads is OQ-home-dashboard-1). **Proposed default + OQ-C-031-4:** no feedback treatment is added. |

### 3c. C-073 StatusPercentDisc — the 64pt completion disc

64×64, `radius-circle`. Ground = **the status colour at 20% opacity** (deviation 4). Content is
a horizontal pair, **centred** in the box (deviation 8) — measured 36×24 at (14, 20):

| Element | Type | Colour |
|---|---|---|
| number | `type-value-emphasis` (SF Pro Bold 18/24) | the status colour |
| `%` | `type-caption-semibold` (SF Pro Semibold 12/12) | the status colour |

The `%` sits in a 12pt line box centred against the number's 24pt box (offset 6), so the two
read as centre-aligned rather than baseline-aligned. The glyph is **drawn by the component**,
not carried in the prop (§4).

One designed state (`property1=Default`, green). It is **not** C-062 PercentDisc: C-062 encodes
its band in colour *and diameter* (80 / 56 / 44) and types its number Bold 14 + `%` Semibold 9,
where this disc is fixed at 64 and types Bold 18 + Semibold 12. The registry has recorded them
as siblings since 2026-09-02; OQ-C-031-5 asks whether that survives.

*(`type-caption-semibold`'s line-height was carried as unmeasured in `tokens.md` and is measured
here at 12/12 — this glyph is one of the two observations that token row already cited.)*

Variants not in this table may not be built without a ruling.

## 4. Props contract

**C-031 EnrollmentStatusRow**

| Prop | Type | Purpose |
|---|---|---|
| `percent` | `String` | the disc's number — **without** the `%`, which C-073 draws (§3c) |
| `label` | `String` | the metrics row's leading label; flexes (§2) |
| `count` | `String` | the metrics row's count; right-aligned in a fixed 40pt cell |
| `progress` | `Double` | → **C-057 PercentBar**; a different quantity from `percent` (OQ-C-031-3) |
| `subtitle` | `String` | the second line |
| `statusColor` | color | the disc's ground (at 20%) and number, and the bar's fill — §3b |

The source types `percent` and `count` as display strings ("78", "52"), the same shape
OQ-C-033-5 raises for C-033; OQ-C-031-6 carries it.

**C-073 StatusPercentDisc:** `percent: String` · `statusColor: color` — §3c.

`progress` and the bar's geometry delegate to **C-057 PercentBar**; that row owns the
`style`/`aligned` set and it is not restated here.

## 5. Composition

- **Consumes:** C-073 StatusPercentDisc (64, `Default`) · C-057 PercentBar (`Thick` / `Right`).
- **Consumed by:** home-dashboard (Engagement section, instance `3622:5617`) ·
  study-program-home (Group Activity section, program-scoped). C-073 is consumed by C-031 alone.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-031-1 | `statusColor` is a prop with exactly one designed value (green). Does this row carry a closed colour set the way C-033 §3b does (green / yellow / red), and what thresholds pick it? Program-wide siblings: OQ-home-dashboard-3, OQ-study-program-home-5 | No — blocks a faithful build of any non-green state | owner |
| OQ-C-031-2 | **Two greens in one symbol** (deviation 6): the disc's number is the bound `green` #6cff73, the bar beside it the literal #4deb4b. Which is canonical? This is the decisive evidence for OQ-home-dashboard-6, and it also asks whether the disc's 20%-opacity ground earns a token (`color-positive-20` exists for accent as `color-accent-20`, and C-062 states the same "band colour at 20%" with no row either) | No — token ruling | owner |
| OQ-C-031-3 | `percent` (disc, 78) and `progress` (bar, ≈11% of track) disagree in the one designed symbol. Are they the same quantity rendered twice — in which case the sample is simply inconsistent — or two different measures (e.g. "% current" vs "% of target")? The row needs to know, because a build that ties them together cannot be undone by data | No | owner |
| OQ-C-031-4 | Zero state and interaction are undesigned though both consumers can reach zero and one sits under a tappable section header — proposed defaults in §3b are to draw nothing new | No | owner |
| OQ-C-031-5 | **C-073's identity.** Is the 64pt fixed-size disc genuinely a second component beside **C-062 PercentDisc** — the evidence is a different type scale (Bold 18 + Semibold 12 vs Bold 14 + Semibold 9) and a colour prop rather than band-encoded sizing — or should the two consolidate into one disc row with `size` and `color` props? Related: `-Disc` is not one of the registry's sanctioned family suffixes, the same gap OQ-C-033-8 raises for `-Glyph` | No | owner |
| OQ-C-031-6 | The root gap and the Info column gap are both **16**, and `tokens.md`'s two 16s are a page inset and a card inset. Mint a spacing row for an intra-row / intra-column gap, or keep them as this row's flagged literals? Also: `percent` and `count` are display strings in the source, where a build would rather have numbers — same question as OQ-C-033-5 | No | owner |
