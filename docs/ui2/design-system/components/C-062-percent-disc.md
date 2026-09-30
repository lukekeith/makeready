# C-062 PercentDisc — a completion number, coloured by how good that number is

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-062 <set url>`
with the set `3822:34382` pasted by the owner 2026-09-11 (D10). The paste **confirms** the ref the
registry already carried rather than replacing it — same node, now with every symbol pinned, its
existing frozen snapshot re-verified, and the geometry measured for the first time. This file
**relocates** the contract from `screens/enrollment-home.md` §4 (pointer left there).

**Closed change list vs. the superseded enrollment-home §4 contract:**
1. **Correction — the component is ALWAYS 80×80.** §4 read the six variants as "designed sizes
   `Green 1` (80pt) … `Red 1` (44pt)", i.e. as though the component's footprint changed. It does
   not: every symbol is an 80×80 slot and it is the **disc inside** that varies (§2). A consumer
   laying out a `Red 1` reserves **80**, not 44 — the old reading would have under-reserved by
   36pt.
2. The three previously unmeasured variants are pinned: `Green 2` = **64**, `Yellow 2` = **48**,
   `size6` = **40**. The full ladder is 80 / 64 / 56 / 48 / 44 / 40 — two steps per colour band.
3. **Type leadings recorded for the first time**: the number is Bold 14 / **24** and the `%` is
   Semibold 9 / **12**. §4 gave sizes and weights with no leading.
4. **`size6` is a RED disc.** Its axis value is the only one of the six that does not name its
   colour, so the variant list read as five colours plus an unknown (§1 deviation 3).
5. The number/`%` type is **identical in all six variants** — it does not scale with the disc.
6. New evidence on two existing OQs, recorded in §6: `Green 2`'s disc is **64**, exactly C-073
   StatusPercentDisc's diameter (OQ-C-031-5), and the set samples **29** in all six symbols, which
   resolves half of OQ-C-025-4.
7. **Owner ruling 2026-09-11 — colour is continuous, not banded.** A single colour, computed from
   `percent` along a red→amber→green ramp, drives both the disc fill (at 20%) and the text (§2a).
   This supersedes the six fixed swatches, **answers OQ-C-062-1** by splitting colour from size,
   mints `color-warning` as the ramp's mid anchor, and makes the band-threshold question moot for
   this component — there are no thresholds left to set.
8. **Owner ruling 2026-09-11 — the diameter is the consumer's choice.** `size` keeps its six
   designed diameters and is independent of `percent` (§4), which retires the source's
   size↔colour double encoding and closes OQ-C-062-9.

**Merged 2026-09-11 — C-073 StatusPercentDisc absorbed (`/ui2-component-merge C-062 C-073`).**
The owner ruled the two rows one component. C-073 was the fixed 64pt disc specced inside
`C-031-enrollment-status-row.md` §3c; it is struck through in the registry, its ID kept per the
append-only rule. What the merge decided, in the owner's words *"statusColor override only"*:
1. **C-073's geometry was already this row's.** Its 64pt disc is exactly `size=Green 2`, and its
   `%`-centred-against-the-number's-24pt-box construction is the one §2 already describes — C-062
   §2 had even cited C-073 as sharing it. So it maps onto an existing state and **adds no row to
   §3a**; `Green 2` simply moves from designed-unconsumed to consumed.
2. **`statusColor` is added as an optional override** (§2a, §4) — the one genuine capability C-073
   had that this row lacked: a caller-supplied colour instead of the computed ramp.
3. **C-073's larger type scale is DROPPED** (Bold 18/24 + Semibold 12/12 → this row's Bold 14/24 +
   Semibold 9/12). This is the one part of the merge that **changes what a shipped screen
   renders** — C-031 appears on home-dashboard and study-program-home — and it was the owner's
   explicit choice over keeping both scales behind a second axis. Recorded as OQ-C-062-12.
4. **OQ-C-031-5 is CLOSED** by this merge — it asked whether C-073 was genuinely a second
   component. It was not. OQ-C-031-2's surviving half (the 20% ground token) moves here as
   OQ-C-062-11.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3822-34382
  — frame `3822:34382` ("Percent and size") on the component sheet, 120×535, **one axis (`size`),
  6 symbols**, a complete ladder with no sparse cell:

  | Figma symbol | node | slot | disc | disc offset |
  |---|---|---|---|---|
  | `size=Green 1` | `3822:34381` | 80×80 | **80** | (0, 0) |
  | `size=Green 2` | `3822:34400` | 80×80 | **64** | (8, 8) |
  | `size=Yellow 1` | `3822:34405` | 80×80 | **56** | (12, 12) |
  | `size=Yellow 2` | `3822:34410` | 80×80 | **48** | (16, 16) |
  | `size=Red 1` | `3822:34415` | 80×80 | **44** | (18, 18) |
  | `size=size6` | `3822:34420` | 80×80 | **40** | (20, 20) |

- Frozen snapshot: `assets/C-062-percent-disc.png` — frozen by the `enrollment-home` run and
  **re-verified 2026-09-11**: this run rendered the same node again and all six symbols are
  identical to the frozen artifact, so Figma has not drifted and no re-spec event is recorded.
- Sheet copy: this **is** the sheet entry; there is no separate frame-local copy.

- **Second normative source, from the merge** —
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3525-30266
  — main component `3525:30266` ("Percent indicator", Figma's placeholder `property1=Default`),
  64×64, one designed symbol, green. Absorbed from C-073 on 2026-09-11. Its frozen snapshot
  `assets/C-073-status-percent-disc.png` stays on disk as the evidence for the merge; it shows
  the **pre-merge** type scale, which deviation 9 says this row no longer renders.

**Deviations (closed list):**
1. The percent string is per-instantiation content. The set samples **`29`** in all six symbols
   — see §6 on what that does to OQ-C-025-4.
2. The 80×80 slot carries a corner radius of 32 and `overflow-clip` but **no fill**, so its
   rounding never renders. It is a clipping container, not a visible shape.
3. The axis is named **`size`**, but its values name a **colour and a step** (`Green 1`,
   `Yellow 2`, …) — and one value, **`size6`**, names neither, though it is a red disc
   identical in construction to `Red 1`. The axis name and that one value are Figma-side
   defects; §3a reads the axis by what it draws.
4. Figma spells the disc's corner radius as a literal **32** on five of the six discs and **40**
   on `Green 1`. Every one of those is ≥ 50% of its own diameter, so all six clamp to true
   circles; only `Green 1`'s 40 is an exact 50%. They are recorded here as `radius-circle`
   because that is what they render as.
5. The yellow (#ffb53e) is bound to **no Figma variable** in either of its variants — ground or
   number. Green binds `green` and red binds `Red/100`; yellow is raw hex in a set where the
   other two bands are not (§2).
6. **The colour model is an owner ruling (2026-09-11) and supersedes the set's discrete
   swatches.** Colour is a **continuous function of `percent`** (§2a), not one of six fixed
   values. The set remains normative for every other property — slot, disc ladder, number
   block, type — and it is not contradicted so much as interpolated: its six symbols draw only
   **three** distinct colours, and those three are exactly the ruling's anchors (§2a). The
   visible consequence is enumerated in §3a: the three variants `enrollment-home` consumes
   render a different colour under the ruling than the frozen snapshot shows, because the
   snapshot samples the anchors and the screen's percentages fall between them.

9. **This row now spans TWO Figma components, and Figma has not merged them.** `3822:34382` (the
   six-symbol ladder) and `3525:30266` (the 64pt status disc) are separate components in the file;
   the merge is a **registry** decision (D6, one row per component), exactly as C-022's `layout`
   axis is. OQ-C-062-10.
10. **The absorbed source's type scale is not rendered.** `3525:30266` draws Bold 18/24 +
   Semibold 12/12; this row draws Bold 14/24 + Semibold 9/12 in every state, by the owner's merge
   ruling. So a diff of C-031's disc against that snapshot is EXPECTED to differ in type size, and
   that is the ruling rather than a defect. OQ-C-062-12.
Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Three nested parts, and nothing else — no ring, no track, no stroke, no icon.

| Part | Geometry |
|---|---|
| Slot | **80×80 in every variant.** No fill; `overflow-clip`; contents centred on both axes. This is the component's footprint (§3b) |
| Disc | a circle of the variant's diameter (§3b), centred in the slot, filled the **ramp colour at 20% opacity** (§2a), `radius-circle` |
| Number block | **28×24**, centred in the *disc*. A centred row of two runs, no gap — 19 + 9 = 28 exactly |
| └ number | SF Pro **Bold 14 / 24**, 19×24, the **ramp colour at full opacity** (§2a) |
| └ `%` | SF Pro **Semibold 9 / 12**, 9×12, the **ramp colour at full opacity**, **centred against the number's 24pt box** (y-offset 6), not baseline-aligned |

The `%` glyph is **drawn by the component**, not carried in the prop (§4) — the same construction
C-073 StatusPercentDisc uses.

**The number block does not scale.** It is 28×24 with the same type in all six variants, so as the
disc shrinks from 80 to 40 the number stays put and the ring of colour around it thins. At `size6`
(40) the 28-wide block occupies 70% of the disc's width.

### 2a. The colour ramp (owner ruling, 2026-09-11)

**One colour is computed from `percent` and used for both the ground and the text.** It is
continuous — there are no bands and no thresholds.

**Anchors** (the ramp is pinned at three points, and these are exactly the three colours the
source's six symbols draw):

| `percent` | Colour | Token |
|---|---|---|
| **0** | #ff4759 | `color-negative` |
| **50** | #ffb53e | `color-warning` |
| **100** | #6cff73 | `color-positive` |

**Rule.** Clamp `percent` to 0…100, then interpolate **componentwise in sRGB** between the two
adjacent anchors — `color-negative`→`color-warning` over 0…50, `color-warning`→`color-positive`
over 50…100 — and round each channel to the nearest integer.

**Application.** Disc fill = that colour at **20% opacity**. Number and `%` = that colour at
**100%**. Nothing else in the component takes colour.

**The `statusColor` override (absorbed from C-073, 2026-09-11).** When a consumer supplies
`statusColor`, **that colour replaces the ramp's output entirely** — disc fill at 20%, number and
`%` at 100%, by the same application rule. `percent` then drives the number alone and has no
colour effect. This is the one capability the merge carried over from C-073, whose disc took its
colour from a prop rather than from its value: C-031 EnrollmentStatusRow colours the disc, the
bar and the row's status together, which a self-computing disc cannot do.

Supplying it is a deliberate opt-out of §2a's whole argument, so the rule is stated the strong
way: **a disc either computes its colour or is told it, never both.** Which of the two a row
should use is a design decision, not a fallback — OQ-C-062-11.

**Worked values** (the acceptance criteria for a build):

| `percent` | Ramp colour | Disc fill |
|---|---|---|
| 0 | `#FF4759` | `#FF4759` @ 20% |
| 24 | `#FF7C4C` | `#FF7C4C` @ 20% |
| 50 | `#FFB53E` | `#FFB53E` @ 20% |
| 65 | `#D3CB4E` | `#D3CB4E` @ 20% |
| 78 | `#ADDE5C` | `#ADDE5C` @ 20% |
| 100 | `#6CFF73` | `#6CFF73` @ 20% |

**Two consequences worth stating.** (a) The ruling **dissolves the 20%-ground token question for
this component**: an interpolated colour cannot have a static token row, so OQ-C-031-2's request
for `color-positive-20` / `color-negative-20` no longer applies here — it survives only for
C-073, whose disc is a fixed colour. (b) sRGB is the proposed interpolation space, not a designed
one: a perceptual space (OKLCH) would keep the mid-ramp more saturated and is a visible
difference, so the space is called out as OQ-C-062-7 rather than left implicit.

**Flagged literals (D7):**
- **The 20% ground needs no token** under the ruling — see §2a(a). It is an opacity applied to a
  computed colour, so there is nothing static to name.
- **The mid anchor is minted as `color-warning` (#ffb53e).** The ruling promotes it from an
  incidental "fourth band colour" to a structural anchor of a program-level ramp, which is what
  earns it a row under D7. It still binds **no Figma variable** anywhere in the set (deviation 5)
  — green binds `green` and red binds `Red/100` — so the Figma side is a cleanup, OQ-C-062-8.
- **The number's Bold 14 / 24** has no token row. It is the program's **fourth** Bold-14 leading
  — beside `type-title-card` (Bold 14/20), `type-nav-label` (Bold 14/16) and C-046's Bold 14/14 —
  and its 24 leading matches `type-input` / `type-nav-action` (both Regular 14/24). Carried as a
  per-component literal rather than a unilateral mint; OQ-C-062-3 folds it into the program's
  pending Bold-leading ruling.
- **The `%`'s Semibold 9 / 12** has no token row and is the **smallest type in the program** by
  3pt (`type-caption` and friends bottom out at 12). OQ-C-062-3.

**Tokens.** `get_variable_defs` on the set returns exactly `green` (#6cff73) and `Red/100`
(#ff4759), both already bound. **One row is minted this run**: `color-warning` (#ffb53e), the
ramp's mid anchor.

## 3. Variant & state matrix

### 3a. The closed matrix

**Colour is no longer an axis** (§2a). What the six symbols differ in is **diameter alone**, so
the matrix below is a ladder of sizes whose value *names* are historical — they name the colour
each symbol happened to be drawn in, which the ruling has now decoupled (deviation 3, OQ-C-062-6).

| `size` | Disc | Source colour (now historical) | Consumption |
|---|---|---|---|
| `Green 1` | **80** | green | **consumed** — enrollment-home (78%); C-025 `Percent circle` centres this variant in its 97×86 wrapper |
| `Green 2` | **64** | green | **consumed** — C-031 EnrollmentStatusRow (absorbed from C-073 on 2026-09-11; supplies `statusColor`) → home-dashboard, study-program-home |
| `Yellow 1` | **56** | amber | **consumed** — enrollment-home (65%) |
| `Yellow 2` | **48** | amber | **designed-unconsumed** (OQ-enrollment-home-8) |
| `Red 1` | **44** | red | **consumed** — enrollment-home (24%) |
| `size6` | **40** | red | **designed-unconsumed** (OQ-enrollment-home-8) |

Variants not in this table may not be built without a ruling.

### 3b. What the ruling changes on screen — enumerated

The three consumed instances keep their diameters and **change colour**, because the frozen
snapshot samples the ramp's anchors while the screen's percentages fall between them:

| Instance | Diameter | Snapshot colour | Ramp colour (§2a) |
|---|---|---|---|
| enrollment-home, 78% | 80 | `#6CFF73` green | **`#ADDE5C`** yellow-green |
| enrollment-home, 65% | 56 | `#FFB53E` amber | **`#D3CB4E`** amber-green |
| enrollment-home, 24% | 44 | `#FF4759` red | **`#FF7C4C`** red-orange |

This is a deviation of the **ruling** from the **snapshot**, not a defect in either: §1 deviation
6 records it, and a preview build should render the ramp colour and report the difference rather
than matching the picture.

### 3c. Diameter is the disc's, not the component's

Every variant occupies **80×80**. What the axis changes is the disc drawn inside that slot, which
is why the ladder can shrink without any consumer re-flowing: C-025 reserves one 97×86 wrapper and
every variant fits it. §1's change 1 records that the superseded contract read this the other way.

### 3d. Undesigned states (proposed defaults + OQ)

- **Zero / no data.** `percent = 0` is now fully defined by §2a — it is the ramp's red anchor. What
  remains undesigned is **absence**: a disc with no percent at all. Proposed default: the component
  is not rendered; a consumer with nothing to show shows nothing. OQ-C-062-4.
- **100%.** The colour is defined (green anchor). The geometry is not: the number block is fixed at
  28 wide (§2) and "100" is three digits. Proposed default: the row is centred and unclipped, so it
  widens past 28 and the disc does not change. OQ-C-062-2.
- **Out-of-range.** §2a clamps to 0…100, so 120% renders as 100's green. Proposed default, stated
  by the ramp rule itself.
- **Interaction.** No pressed, disabled or selected symbol; no action prop. The disc is a
  read-out. Proposed default: non-interactive.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `percent` | `Int` | The number drawn, **and** the sole input to the colour ramp (§2a). Clamped to 0…100 for colour; the `%` glyph is not part of it — §2 draws that separately |
| `size` | `Green 1 \| Green 2 \| Yellow 1 \| Yellow 2 \| Red 1 \| size6` | Selects the **disc diameter only** (§3a): 80 / 64 / 56 / 48 / 44 / 40 |
| `statusColor` | `color?` | **Optional override, absorbed from C-073 (2026-09-11).** When supplied it replaces the ramp's computed colour for both the 20% ground and the 100% text (§2a); `percent` then drives the number only. Omitted ⇒ the ramp. Its designed value is C-031's green |

**The 2026-09-11 ruling split what used to be one axis.** Colour is now derived from `percent` and
nothing else; `size` carries diameter and nothing else. That **answers OQ-C-062-1**, which asked
whether the single `size` axis should be re-cut — it has been, by the ruling rather than by a
re-spec, and the superseded §4's `percent, band` pair is wrong in the other direction: there is no
`band` prop, because there are no bands.

**`size` is independent of `percent`** (owner, 2026-09-11, closing OQ-C-062-9). The source's
double encoding — bigger *and* greener together — is deliberately retired: a disc now says *how
good* in colour and *how prominent* in size, and the two need not agree. A consumer picks the
diameter that fits its layout; `percent` drives colour alone. `enrollment-home`'s three instances
therefore keep the diameters they have (80 / 56 / 44) and change only colour (§3b).

## 5. Composition

**Consumes:** nothing. The disc is a filled circle and two text runs; it resolves to no other
registry row.

**Consumed by:** `enrollment-home` (three variants) · **C-025 DayActivityCard** (`Percent circle`,
which centres `Green 1` in a 97×86 wrapper) · **C-031 EnrollmentStatusRow** (`size=Green 2` at 64,
supplying `statusColor`) → home-dashboard, study-program-home.

**Anticipated:** any completion read-out that wants magnitude encoded twice.

**Absorbed:** ~~C-073 StatusPercentDisc~~, merged into this row 2026-09-11 by owner ruling
(`/ui2-component-merge C-062 C-073`). Its ID is struck through and retained; its contract was
`C-031-enrollment-status-row.md` §3c, which is now a pointer here. **OQ-C-031-5 — "is C-073
genuinely a second component?" — is closed by that merge: it is not.**

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-062-1 | ~~**Is `size` one axis or two?** It selects diameter and band colour as an inseparable pair…~~ **ANSWERED 2026-09-11 by the owner's colour ruling**: the two are now separate — colour is a continuous function of `percent` (§2a), `size` carries diameter alone (§4). The successor question is OQ-C-062-9 | — | *closed* |
| OQ-C-062-2 | **Three digits.** The number block is 28 wide with "29" sampled everywhere; 100% is three digits, and under the ramp 100 is the one value the happiest disc will actually reach. §3d proposes it simply widens past 28 (the row is centred and unclipped) and the disc is unaffected. Confirm, or design the 100 case | No | Owner |
| OQ-C-062-3 | **Two untokened type styles.** The number is **Bold 14/24** — the program's FOURTH Bold-14 leading (beside 14/20, 14/16 and C-046's 14/14), though its 24 matches `type-input`'s. The `%` is **Semibold 9/12**, the smallest type in the program by 3pt. Mint rows, or keep both flagged? This belongs with the pending Bold-leading ruling rather than being settled here | No | Owner |
| OQ-C-062-4 | **Absence, not zero.** `percent = 0` is now defined (§2a's red anchor). A disc with *no* percent is still undesigned; §3d proposes not rendering the component at all | No | Owner |
| ~~OQ-C-062-5~~ | **CLOSED 2026-09-11 by `/ui2-component-merge C-062 C-073`** — the merge this row's evidence was arguing for happened, and OQ-C-031-5 closed with it. Retained for the trail: **New evidence for OQ-C-031-5** (is C-073 a separate component?): this set's `Green 2` is a **64pt** disc — *exactly* C-073's fixed diameter — and at that identical size the two type their contents differently (**Bold 14/24 + Semibold 9/12** here vs C-073's **Bold 18/24 + Semibold 12/12**). So the diameter no longer distinguishes them; only the type scale does. **The colour ruling sharpens this**: C-062's colour is now computed from `percent` while C-073's is a `statusColor` prop, which is either the real distinction between the two rows or the next thing to unify | No | Owner |
| OQ-C-062-6 | **Figma naming (deviation 3):** the axis is `size` and its values name colours — which the ruling has now made *actively* misleading, since a `Green 1` disc renders red at 10%. Renaming the six values to their diameters (`80`/`64`/`56`/`48`/`44`/`40`) would make the set self-describing; the registry name and `C-062` are unaffected either way | No | Owner |
| OQ-C-062-7 | **Interpolation space.** §2a specifies componentwise **sRGB** as the proposed default. A perceptual space (OKLCH) holds saturation better through the middle of a red→amber→green ramp, where sRGB dips toward mud around 65–75%. Visible, and cheap to change in one place | No — §2a states the proposal | Owner |
| OQ-C-062-8 | **The amber anchor has no Figma variable.** `color-warning` (#ffb53e) is minted here because the ruling makes it structural, but green binds `green` and red binds `Red/100` while amber binds nothing, in either variant. A Figma variable would close the last raw colour in this set | No | Owner |
| OQ-C-062-10 | **Should Figma unify the two components this row now spans?** `3822:34382` (the six-symbol ladder) and `3525:30266` (the 64pt status disc) remain separate in the file; the merge that made them one row is a registry decision Figma has not made (§1 deviation 9). Unify them into one set with a `size` axis, or accept a two-source row — the same shape as C-022's OQ-C-022-2 | No — but it is why one source's snapshot no longer matches this row | Owner |
| OQ-C-062-11 | **`statusColor` vs the ramp — when should a consumer use which?** Carried from ~~OQ-C-031-2~~'s surviving half. §2a states the strong rule (a disc either computes its colour or is told it, never both) but not the *policy*: C-031 supplies it so the disc, the bar and the row agree, while every other consumer lets `percent` decide. Also the token half of that OQ: the override's 20% ground **can** have a static token (`color-positive-20`) where the ramp's cannot, so the question that §2a dissolved for the computed path survives for this one | No | Owner |
| OQ-C-062-12 | **The absorbed type scale was dropped, and it changes two shipped screens.** The merge ruled C-031's disc renders this row's Bold 14/24 + Semibold 9/12 rather than C-073's Bold 18/24 + Semibold 12/12. home-dashboard and study-program-home both render that disc, so their next capture will differ from their frozen snapshots in the disc's type size — **expected, not a defect**. Confirm after seeing it on screen, or restore the larger scale as a second axis | No — owner already ruled; this is the visible consequence | Owner |
| OQ-C-062-9 | ~~**Does the diameter also follow `percent`?**~~ **ANSWERED 2026-09-11 (owner): the diameter is the consumer's choice.** `size` remains a prop with the six designed diameters and is independent of `percent`; only colour is computed. So the source's double encoding is deliberately retired — a disc says "how good" in colour only, and says "how prominent" in size, and the two no longer have to agree | — | *closed* |
