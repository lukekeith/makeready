# C-031 EnrollmentStatusRow — one aggregate's completion, as a disc + labelled bar row

Status: `new` · Specced: 2026-09-10 · Owner-designated: `/ui2-component EnrollmentStatusRow
<set url>` with the set `3526:30288` pasted by the owner 2026-09-10 (D10 — the owner's paste
designates the SET normative; the registry already anchored this row to it, alongside the
home-dashboard frame instance `3622:5617`). This file **relocates** the contract from
`screens/home-dashboard.md` §4 (pointer left there).

Includes the completion disc, which was **C-073 StatusPercentDisc** until it was merged into
**C-062 PercentDisc** on 2026-09-11 (`/ui2-component-merge C-062 C-073`); §3c is now a pointer.
This row renders C-062 at `size=Green 2` (64) and supplies `statusColor`. The disc is still
instantiated nowhere but inside this row — what the merge settled is that it was never a
*separate component*, which is what ~~OQ-C-031-5~~ had been asking.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3526-30288
  — set `3526:30288` (Figma name "Progress status"), one axis `state`, **1** symbol
  (`state=Default`, `3526:30287`), 410×64. Parented to the component sheet at (4291, 901), so
  D9's sheet caveat and D10's owner designation both apply and agree.
- Sub-component main: `3525:30266` ("Percent indicator", `property1=Default`) → **C-062
  PercentDisc** (`size=Green 2`), absorbed from ~~C-073~~ on 2026-09-11. That node is now a
  normative source of C-062 §1.
- Consuming instance measured for the width deviation: `3622:5617` (home-dashboard Engagement).
- Frozen snapshot: `assets/C-031-enrollment-status-row.png` (1046×352, 2×) — captured 2026-09-10
- The disc's frozen snapshot, same capture: `assets/C-073-status-percent-disc.png` (128×128, 2×)
  — kept on disk as the merge's evidence. ⚠️ It shows the **pre-merge** type scale, which C-062
  §1 deviation 10 records this row no longer renders

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
   colour-at-20% construction `../design-system/components/C-062-percent-disc.md` states for C-062
   (whose colour became a continuous ramp by owner ruling 2026-09-11), and
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

1. **Disc** — **C-062 PercentDisc** at `size=Green 2` (64×64), supplying `statusColor`
   (merged from ~~C-073~~, 2026-09-11). It is the only thing that sets the
   row's 64pt height.

2. **Info** — flexible width (330 at the set's 410, 328 at a consumer's 408), intrinsic height
   46, vertically centred in the 64pt row (9pt above and below). A two-row column, gap **16**
   — the same flagged literal as the root gap, and for the same reason:

   - **Metrics row** — full width, 16 tall, contents vertically centred, gap
     `space-element-gap` (8). Three cells, left → right:
     - **Label** — `type-body` (Regular 14/14) `color-text-primary`, **flexes**.
     - **Count** — `type-body` `color-text-primary`, **right-aligned in a fixed 40pt cell**.
     - **C-057 PercentBar** (`size=lg` 16pt, `aligned=Right`; Figma spells that size `Thick` — renamed by note `2026-09-12T02:28:29.097Z`), **flexes**. At the set's
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

### 3c. The completion disc — now C-062 PercentDisc

**Merged 2026-09-11** (`/ui2-component-merge C-062 C-073`). This subsection was C-073
StatusPercentDisc's contract; the owner ruled the two discs one component, and the contract is now
`C-062-percent-disc.md`. This row renders **C-062 at `size=Green 2`** (64x64) and supplies
`statusColor`.

**What the merge changed here, in one line:** the disc keeps its 64pt diameter, its 20%-opacity
status ground and its drawn percent glyph, but renders C-062's type scale - **Bold 14/24 +
Semibold 9/12** rather than the Bold 18/24 + Semibold 12/12 this section used to specify. That is
a **visible change to this row on both its screens**, ruled by the owner at merge time and tracked
as OQ-C-062-12; the next capture of home-dashboard and study-program-home is expected to differ
from their frozen snapshots in the disc's type size.

The percent glyph is still drawn by the disc, not carried in `percent` (see below) - C-062 section 2
owns that construction, and it is the one the two rows always shared.

## 4. Props contract

**C-031 EnrollmentStatusRow**

| Prop | Type | Purpose |
|---|---|---|
| `percent` | `String` | the disc's number — **without** the `%`, which C-062 draws (§3c) |
| `label` | `String` | the metrics row's leading label; flexes (§2) |
| `count` | `String` | the metrics row's count; right-aligned in a fixed 40pt cell |
| `progress` | `Double` | → **C-057 PercentBar**; a different quantity from `percent` (OQ-C-031-3) |
| `subtitle` | `String` | the second line |
| `statusColor` | color | the disc's ground (at 20%) and number, and the bar's fill — §3b |

The source types `percent` and `count` as display strings ("78", "52"), the same shape
OQ-C-033-5 raises for C-033; OQ-C-031-6 carries it.

**The disc's own props** are **C-062 PercentDisc**'s (`percent`, `size`, `statusColor`); this row
supplies `size=Green 2` and `statusColor`. Restating them here would violate
`preview-build.md` §3 rule 5 — the providing row owns its value set.

`progress` and the bar's geometry delegate to **C-057 PercentBar**; that row owns the
`style`/`aligned` set and it is not restated here. **That contract now exists** —
`C-057-percent-bar.md`, written 2026-09-11 from the owner-designated set `3526:30471`; until
then this sentence delegated to an eight-line block in an archive. It confirms deviation 7
above (the sample fill widths are hand-drawn and compute to no law) and adds that **all three**
of the bar's fill colours are unbound, not just the green.

## 5. Composition

- **Consumes:** **C-062 PercentDisc** (`size=Green 2` at 64, with `statusColor`) · C-057
  PercentBar (`size=lg` / `aligned=Right`, `fillStyle=solid` with this row's status colour as the `fillColor` override).
- **Consumed by:** home-dashboard (Engagement section, instance `3622:5617`) ·
  study-program-home (Group Activity section, program-scoped).

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-031-1 | `statusColor` is a prop with exactly one designed value (green). Does this row carry a closed colour set the way C-033 §3b does (green / yellow / red), and what thresholds pick it? Program-wide siblings: OQ-home-dashboard-3, OQ-study-program-home-5 | No — blocks a faithful build of any non-green state | owner |
| OQ-C-031-2 | **Two greens in one symbol** (deviation 6): the disc's number is the bound `green` #6cff73, the bar beside it the literal #4deb4b. Which is canonical? This is the decisive evidence for OQ-home-dashboard-6, and it also asks whether the disc's 20%-opacity ground earns a token (`color-positive-20` exists for accent as `color-accent-20`, and C-062 stated the same "band colour at 20%" with no row either). **NARROWED 2026-09-11:** C-062's colour is now interpolated from `percent`, so its 20% ground *cannot* have a static token by construction — **MOVED 2026-09-11** by the C-073 merge: the surviving token half now lives on the keeper as **OQ-C-062-11**, because the fixed-colour path is C-062's `statusColor` override) | No — token ruling | owner |
| OQ-C-031-3 | `percent` (disc, 78) and `progress` (bar, ≈11% of track) disagree in the one designed symbol. Are they the same quantity rendered twice — in which case the sample is simply inconsistent — or two different measures (e.g. "% current" vs "% of target")? The row needs to know, because a build that ties them together cannot be undone by data | No | owner |
| OQ-C-031-4 | Zero state and interaction are undesigned though both consumers can reach zero and one sits under a tappable section header — proposed defaults in §3b are to draw nothing new | No | owner |
| ~~OQ-C-031-5~~ | **CLOSED 2026-09-11 — answered by `/ui2-component-merge C-062 C-073`: they are ONE component, and C-073's row is struck through.** Retained for the trail: **C-073's identity.** Is the 64pt fixed-size disc genuinely a second component beside **C-062 PercentDisc** — the evidence is a different type scale (Bold 18 + Semibold 12 vs Bold 14 + Semibold 9) and a colour prop rather than band-encoded sizing — or should the two consolidate into one disc row with `size` and `color` props? Related: `-Disc` is not one of the registry's sanctioned family suffixes, the same gap OQ-C-033-8 raises for `-Glyph`. **2026-09-11, two new pieces of evidence** (OQ-C-062-5): C-062's `Green 2` disc is **64pt — exactly this row's fixed diameter**, so size no longer distinguishes them and only the type scale does; and C-062's colour is now *computed from `percent`* while C-073's is a `statusColor` prop, which is either the real distinction or the next thing to unify | No | owner |
| OQ-C-031-6 | The root gap and the Info column gap are both **16**, and `tokens.md`'s two 16s are a page inset and a card inset. Mint a spacing row for an intra-row / intra-column gap, or keep them as this row's flagged literals? Also: `percent` and `count` are display strings in the source, where a build would rather have numbers — same question as OQ-C-033-5 | No | owner |
