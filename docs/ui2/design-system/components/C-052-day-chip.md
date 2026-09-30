# C-052 DayChip — the 32×40 rounded box holding one ordinal program-day number

Status: new · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-052 <node url>` with
the **set** `3495:2778` pasted by the owner 2026-09-11 (D10). The pasted node is the component
set itself, not an instance — no upward resolution was needed.

**Contract relocated this run.** Until now this row's contract was
`screens/study-program-home.md` §4 "C-052 DayChip (new — introduced by this screen)", four
sentences written while specifying the screen that consumes it. This file replaces it and the
screen's subsection becomes a pointer. The relocation is justified because the component file
adds material the screen section could not carry: per-symbol node ids, the measured type and
its match to `type-body`, the fact that the `Default` fill is **translucent** rather than the
grey the eye reads, the fixed-width/clipping behaviour, the frozen whole-set snapshot, and five
open questions.

**What this run corrects in the relocated text** (closed list — the screen section was right on
every other point):
1. The screen section said the number is "SF Pro Regular 14 **white**" without a leading. It is
   Regular **14 / 14**, which is `type-body` exactly — the program's second clean re-use of that
   row after C-022's stacked form (§2).
2. The screen section described `Default`'s fill as "`color-white-20` fill" without saying it is
   **translucent**. It is white at 20% alpha: on the set frame's `#1e1e1e` authoring ground it
   composites to `#4b4b4b`, and on `color-layout-background` it reads ≈`#363738`. A build that
   hard-codes either grey is wrong (§1 deviation 3).
3. The screen section listed props as "`day: Int`, `state`, `onTap`" — kept, with types and
   semantics stated (§4), and with `day`'s Figma type (`string`, default `"1"`) recorded as
   source evidence rather than as the contract.
4. The frozen snapshot is re-frozen as the **whole set** (72×140 at 4×), replacing the
   single-symbol 128×160 PNG that was on disk. Every other set-sourced row (C-021, C-045,
   C-053) freezes the set, and that is what `syncUi2Row` registers per state.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3495-2778
  — set `3495:2778` ("Day"), 72×140, ingested 2026-09-11. Two symbols on one axis:

  | Symbol | Node | Size | Text node |
  |---|---|---|---|
  | `state=Default` | `3495:2777` | 32×40 | `3495:2776` "Day" |
  | `state=Active` | `3495:2787` | 32×40 | `3495:2788` "Day" |

- **One axis, two values, no third.** `state` is the only variant property the set declares
  (`get_design_context` types it `state?: "Default" | "Active"`). The axis name and both value
  names are **author-written**, not Figma's `Property 1` / `Variant2` placeholders, so registry
  rule 6 needs no rename here — it needs only the record that the strings were checked.
- **Not on the component sheet.** `3632:4502` was enumerated in full this run: its frames
  include a "Day" (`3672:9223`) and a "Date" (`3672:10251`), but those are **C-025
  DayActivityCard** (131×192) and **C-070 DateBlock** (97×38). No 32×40 symbol exists anywhere
  on the sheet. This set is frame-local to the study-program-home area, which is what the
  registry row already claimed and this run verifies rather than assumes (D9).
- Instantiated on the current study-program-home frame at `3833:33431`–`3833:33444`, inside the
  rail frame `3833:33430` ("Days", 474×40).
- Frozen snapshot: `assets/C-052-day-chip.png` — the whole set at 4×, captured 2026-09-11.

**Deviations (closed list):**
1. **The chip does not hug its content.** The box is a fixed 32×40 with `overflow: clip`; the
   number is centred inside it. A label wider than 32 is **clipped**, not wrapped and not grown.
   Only single- and double-digit days are instantiated anywhere in the source (§3c, OQ-C-052-4).
2. **The number's white is raw `#ffffff`**, bound to no Figma variable, while **both** chip
   fills **are** bound (`White/20%`, `Purple/100%`). One component spends a bound and an
   unbound colour side by side — the same shape C-053 shows inverted (its fill raw, its label
   bound). OQ-C-052-2.
3. **`Default`'s fill is translucent, not grey.** `color-white-20` is white at **20% alpha**.
   The frozen snapshot's `#4b4b4b` is that fill composited over the set frame's `#1e1e1e`
   ground — verified by measurement: `0.2 × 255 + 0.8 × 30 = 75` against a sampled (75, 75, 75).
   Over `color-layout-background` (#030405), where the chip actually sits, the same fill reads
   ≈`#363738`. The alpha is the contract; neither composite is.
4. **The set frame's `#1e1e1e` ground is Figma authoring furniture**, not part of the component,
   and neither is the dashed purple component-set outline in the export. Same as C-053's set.
5. **Neither symbol has a border, a shadow, an icon, a dot or a press treatment.** A rounded
   rectangle and one text run is the whole anatomy (§5).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

| Part | Geometry |
|---|---|
| Chip | fixed **32 × 40**, contents centred on both axes, `radius-card-sm` (4), `overflow: clip`, fill per state (§3a). No stroke |
| Number | SF Pro **Regular 14 / 14** (`type-body`), raw `#ffffff`, `nowrap` |

**The centring is measured, not assumed.** In both symbols the text node sits at x 12.5 / y 13
with a 7 × 14 box, so its centre is (16, 20) — exactly half of 32 × 40. The 14-tall box is the
leading: `leading-none` at 14pt, which is what makes this `type-body` (Regular 14/14) rather
than one of the program's four other 14-size rows.

**No padding is authored.** The chip is a centring box of fixed size, not an inset one, so
nothing here cites `space-*`. That is the same reasoning C-053 §2 gives for recording its px 8 /
py 4 as measured paddings rather than as spacing tokens — the direction is just reversed: there
is no inset to name.

**Flagged literal (D7):** the number's `#ffffff`, per §1 deviation 2. It is emitted as the raw
value the source states rather than silently promoted to `color-text-primary`, because promoting
it would assert a binding Figma does not have. This is the **seventh** component to show the
raw-hex-equal-to-a-token pattern (C-034, C-045, C-033, C-046, C-053, C-022) and the **second**
where the unbound value is a plain white text run — C-022's inline form is the first, and
OQ-C-022-4 already asks the same question there.

**Tokens.** `get_variable_defs` on the set returns exactly two variables, and both already have
rows. **This run mints no token.**

| Token | Value | Figma variable | Used by |
|---|---|---|---|
| `color-white-20` | #ffffff33 | `White/20%` | the `Default` chip fill — spent here as a **translucent ground on a tappable surface**, where the program's other consumers spend it on borders, dimmed runs and C-075's baked glyph fill |
| `color-accent` | #6c47ff | `Purple/100%` | the `Active` chip fill |
| `radius-card-sm` | 4 | observed | both chips' corner radius |
| `type-body` | SF Pro Regular 14 / 14 | observed | the number, in both states — the **second clean re-use** of this row outside home-dashboard, after C-022's stacked form |
| — | raw `#ffffff` | **none** | the number's colour, in both states — flagged, OQ-C-052-2 |

## 3. Variant & state matrix

### 3a. The closed matrix

| `state` | Chip fill | Number | Geometry delta | Consumption |
|---|---|---|---|---|
| `Default` | `color-white-20` (translucent, §1 deviation 3) | raw `#ffffff`, `type-body` | none | **consumed** — `study-program-home` day rail, 13 of the frame's 14 instances |
| `Active` | `color-accent` (opaque) | raw `#ffffff`, `type-body` — identical | none | **consumed** — `study-program-home` day rail, exactly 1 instance (`3833:33431`, day 1) |

Variants not in this table may not be built without a ruling.

**The fill is the only delta.** Size, radius, clipping, text node position, type and text colour
are byte-for-byte the same in both symbols; `state` selects a background and nothing else.

### 3b. What `Active` means, and what it does not

`Active` marks the **selected** day, not "today":

- The rail draws days **1…14** with day 1 `Active`, while the Lessons section header reads
  "31 days" — so the rail is a horizontally scrolling window over the program's N days and the
  `Active` chip is the one the rail opens on.
- The numbers are **ordinal program days** (Day 1 … Day N) on a program *template*. A template
  has no current calendar date, so "today" has no referent on this screen. `C-070 DateBlock`
  is where the program expresses "today" (its `state=Today` renders a `color-highlight` "TODAY"
  label), and that is a different row on a different anatomy.
- This matches the program's established vocabulary for selection: **C-035 FilterChip** carries
  an `active` {false, true} axis meaning "this filter is the current selection".

What selection *does* is the screen's contract, not this row's: `screens/study-program-home.md`
§3 proposes that the chip scrolls the lesson list to that day's card, parked as
OQ-study-program-home-11. This row owns the appearance and the `onTap` callback only.

### 3c. Undesigned states (proposed defaults + OQ)

- **Pressed.** No pressed symbol in either state. Proposed default: no bespoke treatment —
  system tap feedback only, as every other tappable 2.0 row proposes. This is the component half
  of `OQ-study-program-home-7`, which already parks "DayChip beyond Default/Active"; recorded
  here so the build lane sees it on the row. OQ-C-052-3.
- **Disabled, locked, completed, has-no-lesson.** Undesigned and **not proposed**. A day rail is
  an obvious place for per-day status, and the superseded frame is not evidence either way, but
  nothing in the current source draws a third fill. Under `preview-build.md` §3 rule 7 a
  proposed default is not rendered; here there is not even a proposal. OQ-study-program-home-7
  is the owner's existing hook for it.
- **Selection cardinality.** The source designs exactly one `Active` among fourteen. Zero
  `Active` and two-or-more `Active` are both undrawn. Proposed default: **exactly one per
  rail**, with zero legal only while the rail itself is empty. OQ-C-052-1.
- **Three-or-more digits.** `overflow: clip` on a fixed 32 box means a wide number is cut, not
  accommodated. Proposed default: out of contract — program day counts are 1…N and no source
  draws N ≥ 100. OQ-C-052-4.
- **Hit target.** The tappable area is the drawn 32 × 40. C-021 GlyphButton states 44pt, C-069
  gives it a 40pt slot and C-040 draws it at 24pt visual in a 56pt bar — this is the fourth
  distinct tappable size in the program and the first that is *narrower* than 40 on one axis.
  Proposed default: none — the program's hit-target thread decides. OQ-C-052-5.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `day` | `Int` | The ordinal program day rendered in the box — Day 1 … Day N, not a calendar date. Figma types the text override as `day?: string` with default `"1"`; that is the source's authoring type, and every instance in every source is an integer, so the contract is `Int` (§1 deviation 1 governs what happens if it is ever wide) |
| `state` | `Default \| Active` | Selects the chip fill and nothing else (§3a). `Active` means "this is the selected day" (§3b) |
| `onTap` | `() -> Void` | Fires on tap. What the caller does with it — scrolling a lesson list, filtering, navigating — belongs to the consuming screen, not to this row |

The number's colour, size and position are **not** props: both states render an identical text
run and no override exists for them.

## 5. Composition

**Consumes: nothing.** Verified against the set's subtree, not assumed — each symbol has exactly
one child, a text node, and there are no vectors, no nested instances and no image fills. A
rounded rectangle and one run of type resolve to no other registry row.

**Consumed by:** `study-program-home` — the Lessons day rail (`3833:33430`), 14 instances,
`space-chip-gap` (2) between them, rail width 474 = 14 × 32 + 13 × 2, scrolling horizontally
inside a 408 content column. The screen's element map
(`screens/assets/study-program-home.elements.json`) records **13** of them, ending at
`3833:33443`: the fourteenth sits past the frame's right edge and the map records what is
visible. Fourteen is the source's count; thirteen is the capture's.

**Anticipated:** any 2.0 surface needing a compact ordinal-day selector. It is deliberately
**not** the program's date component and does not compete with the two that are:

| Row | Anatomy | Renders |
|---|---|---|
| **C-052 DayChip** | 32×40, r4, filled, number only | an **ordinal program day**, selectable |
| C-070 DateBlock | 97×38, unfilled, label row + Bold 18 number | a **calendar date** inside C-025 |
| C-060 CalendarDateCard | 96×88, r8, bordered card, Regular 40 date | a **calendar date** as a standalone card |

C-070's registry row already carries this distinction; it is restated here so the three can be
told apart from either end.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-052-1 | **Selection cardinality.** The source draws exactly one `Active` among fourteen. Is exactly-one an invariant the component may assume (so `state` could collapse to a rail-level `selectedDay`), or may a rail render zero `Active` — on first load, or after the user scrolls away? Proposed default: exactly one, zero only when the rail is empty (§3c) | No — default proposed | Owner |
| OQ-C-052-2 | **The number's white is raw and its siblings' fills are bound.** `#ffffff` is hex-equal to `color-text-primary` but binds no variable, while `White/20%` and `Purple/100%` both do. Bind it, or is this authoring drift? Seventh site of the pattern (C-034, C-045, C-033, C-046, C-053, C-022) and the second on a plain white **text** run — it should be settled with OQ-C-022-4, which asks the identical question about C-022's inline value | No | Owner |
| OQ-C-052-3 | **Pressed state undesigned.** No pressed symbol exists for a component whose entire purpose is being tapped. Proposed default: system feedback only. Component half of OQ-study-program-home-7; recorded on the row so the build lane sees it without reading the screen spec | No — default proposed | Owner |
| OQ-C-052-4 | **Fixed width clips.** 32pt with `overflow: clip` fits one and two digits comfortably and cuts three. Is a ≥100-day program out of scope (proposed), or does the chip need to grow / the rail need a different treatment at that length? | No — default proposed | Owner |
| OQ-C-052-5 | **32 × 40 is the fourth tappable size in the program**, and the first under 40 on an axis, beside C-021's stated 44pt, C-069's 40pt slot and C-040's 24pt-in-56pt bar. Does the rail chip get an expanded hit target, or is 32 wide deliberate given the 2pt gap? Feeds the existing thread, OQ-C-021-2 / OQ-C-040-7 | No | Owner |
