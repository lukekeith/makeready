# C-025 DayActivityCard — one day's activity in a horizontally-scrolling day rail

Status: existing-modified · Specced: 2026-09-10 · Owner-designated: `/ui2-component C-025`
with the set `3672:9223` pasted by the owner 2026-09-10 (D10 — the owner's paste designates
the SET normative; the registry previously anchored this row to the home-dashboard frame
INSTANCE `3673:12007`, which is one symbol of it). This file **relocates** the contract from
`screens/home-dashboard.md` §4 (pointer left there); the two dated amendments in
`screens/members-profile.md` and `screens/enrollment-home.md` are folded in below.

Includes sub-components **C-070 DateBlock** and **C-071 ValuePair** (own registry rows,
contracts below in one file — they ship together, and neither is instantiated anywhere but
inside this card).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3672-9223
  — set `3672:9223` ("Day"), one `state` axis, 3 symbols, each 131×192
- Sub-component sets: `3672:10251` ("Date", 2 symbols) → C-070 · `3673:10832`
  ("Activity details", 7 symbols) → C-071
- Frozen snapshot: `assets/C-025-day-activity-card.png` — captured 2026-09-10
- Sub-component frozen snapshots, same capture: `assets/C-070-date-block.png` ·
  `assets/C-071-value-pair.png`

**Deviations (closed list):**
1. All strings — "AUG", "MON", "24", "TODAY", "27 mins", "1 complete", "0 mins",
   "0 complete", "1", "7:30am", "29%" — are per-instantiation content.
2. The set frame is 171×739 with 20pt gutters around the symbols; the component is the
   131×192 symbol, not the frame.
3. C-071's own frame lays its symbols out at 95pt wide; inside C-025 the slot is 97pt and
   the block is width-driven. The 2pt is the sub-component frame's layout, not a variant.
4. **Corrects `screens/home-dashboard.md` §4, which described `state=Transparent` as the
   whole component** — it recorded the L/R-hairline, no-fill form as the card's only
   geometry. Figma designs three states; the filled one is named `Default` (§3).
5. **Corrects the same §4's zero-state colour**: it states the value lines "render dimmed in
   `text/secondary`". Measured on the frozen snapshot, C-071 `Nothing` renders BOTH lines in
   `color-white-20` (#353637 over the `color-layout-background` ground = #ffffff at 20%);
   `color-text-secondary` is a different designed state (`Muted`, §3b).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

131×192 in every state. Three slots stacked top→bottom, gap `space-element-gap` (8),
content width 97:

1. **C-070 DateBlock** — 97×38.
2. **Body slot** — 97×68 (`Default`) or 97×86 (`Transparent`, `Percent circle`). Holds
   C-024 SparkBarChart (`align=center`) in the two chart states, and a 97×86 `Percent`
   wrapper centring an 80×80 C-062 PercentDisc in `Percent circle`.
3. **C-071 ValuePair** — 97×36.

**The body slot absorbs the whole inset difference between the states** — it is not two
designed chart heights. `Default` insets 17 vertically (1px border + 16) and
`Transparent`/`Percent circle` inset 8; 2 × (17 − 8) = 18, and 86 − 68 = 18. Both stacks
close on 192 exactly:

```
Default      17 + 38 + 8 + 68 + 8 + 36 + 17 = 192
Transparent   8 + 38 + 8 + 86 + 8 + 36 +  8 = 192
```

Horizontal inset is 17 in every state — 1px border + 16 — so the 97pt content width is the
same throughout, measured inside the stroke (the construction C-045 TextInput §2 also uses).

## 3. Variant & state matrix

### 3a. C-025 `state`

| `state` | Delta | Consumption |
|---|---|---|
| `Default` | 1px `color-card-border` on **all four** edges + `color-card-background` fill + rounded corners (measured 2pt — OQ-C-025-2); vertical inset 17; body slot 68 | **designed-unconsumed** — no screen renders it (OQ-C-025-1) |
| `Transparent` | 1px `color-card-border` on **left and right only**, square, no fill; vertical inset 8; body slot 86. Adjacent cards in a rail share borders | consumed — home-dashboard, members-profile |
| `Percent circle` | `Transparent` with the body slot's C-024 replaced by an 80×80 C-062 PercentDisc, centred in a 97×86 wrapper | consumed — enrollment-home |
| pressed / selected / disabled | — undesigned | **proposed defaults + OQ-C-025-5:** no pressed or selected treatment; the card is not tappable in any consuming spec, so no state is added until a frame designs one |

### 3b. C-071 ValuePair `state` (7 designed)

Line 1 over line 2, both `type-caption` (Regular 12/14):

| `state` | Line 1 | Line 2 | Consumption |
|---|---|---|---|
| `Default` | `color-text-primary` | `color-positive` | consumed — home-dashboard ("27 mins" / "1 complete") |
| `Nothing` | `color-white-20` | `color-white-20` | consumed — home-dashboard + members-profile zero state ("0 mins" / "0 complete"); §1 deviation 5 corrects the colour |
| `Muted` | `color-text-primary` | `color-text-secondary` | consumed — members-profile (last-active time) |
| `Lesson day` | `color-accent` | `color-text-secondary` | consumed — enrollment-home (lesson count + time) |
| `Highlighted` | `color-text-primary` | `color-highlight` | designed-unconsumed |
| `Single` | `color-text-primary` | line 2 absent; block stays 36pt | designed-unconsumed (OQ-C-025-6) |
| `Single muted` | `color-white-20` | line 2 absent; block stays 36pt | designed-unconsumed (OQ-C-025-6) |

### 3c. C-070 DateBlock `state` (2 designed)

97×38: a 97×12 label row, gap `space-element-gap` (8), then the day number (24×18).

| `state` | Label row | Day number | Consumption |
|---|---|---|---|
| `Default` | month (left) + weekday (right, justified to the 97pt edge), both `type-caption-bold` `color-text-secondary` | Bold 18 `color-text-primary`, 18pt line box (OQ-C-025-3) | consumed — home-dashboard, members-profile |
| `Today` | ONE label, "TODAY", `type-caption-bold` `color-highlight`; the weekday slot is not rendered | unchanged | consumed — enrollment-home |

Variants not in this table may not be built without a ruling.

## 4. Props contract

**C-025 DayActivityCard:** `state` (`default | transparent | percentCircle`) · `date`
(→ C-070's props) · `series: [Double]?` (→ C-024, the two chart states) · `percent: Int?`
(→ C-062, `percentCircle` only) · `details` (→ C-071's props).

**C-070 DateBlock:** `month: String` · `weekday: String` · `day: String` · `state`
(`default | today`; `today` renders the single highlighted label and ignores
`month`/`weekday`).

**C-071 ValuePair:** `line1: String` · `line2: String?` (nil in `Single` / `Single muted`) ·
`state` — the seven values of §3b.

`percent` and the disc's band delegate to **C-062 PercentDisc**; the size/colour set is that
row's and is not restated here. `series` delegates to **C-024 SparkBarChart**.

## 5. Composition

- **Consumes:** C-070 DateBlock · C-071 ValuePair · C-024 SparkBarChart (`Default`,
  `Transparent`) · C-062 PercentDisc (`Percent circle`, at its 80pt `Green 1` size).
- **Consumed by:** home-dashboard (day rail) · members-profile (day rail) · enrollment-home
  (daily progress rail). C-070 and C-071 are consumed by C-025 alone.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-025-1 | `Default` — the filled, fully-bordered, rounded card — is designed but consumed by **no** screen; all three consumers take `Transparent` or `Percent circle`. Is it a future surface's form, or superseded and due for removal from the set? | No | owner |
| OQ-C-025-2 | `Default`'s corner radius measures 2pt. `tokens.md`'s only 2 is `radius-bar`, coined for sparkline bars. New `radius-card-xs` row, or reuse `radius-bar` under a widened note? | No — blocks a faithful build of `Default` only | owner |
| OQ-C-025-3 | The day number is Bold 18 in an **18pt** line box; `type-value-emphasis` is Bold 18/**24**. New token row, or a flagged literal on this line? | No | owner |
| OQ-C-025-4 | The `Percent circle` sample renders **29%** at C-062's `Green 1` — the largest, greenest band — which contradicts a monotonic percent→band mapping. Direct evidence on **OQ-enrollment-home-3** (the program-wide banding ruling); either the sample is placeholder content or band is an independent prop | No | owner |
| OQ-C-025-5 | Pressed / selected / disabled are undesigned and no consuming spec makes the card tappable — proposed default in §3a is to add none | No | owner |
| OQ-C-025-6 | C-071 `Single` / `Single muted` keep the full 36pt height with one line. Is the block fixed-height by contract, or is the second line's space an artifact of the sub-component frame? | No | owner |
