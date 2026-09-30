# C-035 FilterChip — a 24pt pill whose label is the filter's current selection

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-035 <node url>`
with `3668:7390` pasted by the owner 2026-09-11 (D10). That node is an **instance** — one of
members-home's two chips — so this run resolved it to its main component, the variant set
`3561:33782`, and specced that. The row's prior contract was the six-line §4 subsection in
`screens/members-home.md`; this file **relocates** it (pointer left there).

**The component has four designed variants. Its contract described one.** The pasted instance
types with no variant union at all, which reads as "plain component" — but its internal node ids
(`3668:7602`, `3668:7570`) belong to a *symbol*, `3668:7569`, whose name is
**`type=Menu,active=false`**. Two axes. The parent set carries all four combinations, and three
of them have never appeared in a screen spec.

**Closed change list vs. the superseded `members-home.md` §4 contract:**
1. **Source moves from an instance to the set** `3561:33782`, and the row gains **two axes** —
   `type` {Menu, Button} × `active` {false, true}, all four designed (§3a). §4 described
   `type=Menu, active=false` and nothing else.
2. **Correction — "pressed" is not this component's second state.** §4 said "States: `default`
   (as measured) and `pressed` (standard highlight); no distinct 'filtered' treatment is in the
   source". There **is** a designed active treatment, in both types, and it is not a press
   highlight: `type=Button` fills `color-neutral-800` with white text, `type=Menu` fills white
   with black text and a black chevron. A genuine `pressed` state remains undesigned (§3c).
3. **The chevron's colour is recorded for the first time** — `color-text-secondary` (#85979e)
   when inactive, `color-black` when active. §4 stated the chevron's size and not its fill.
4. **Two Bold-14 leadings inside one component:** the `type=Menu` label is Bold 14/**22** (as §4
   said) and the `type=Button` label is Bold 14/**24**. §4 could not have seen the second (§2).
5. **`type=Button` draws no border and, when inactive, no ground at all** — a bare label. The
   "24pt pill, 1px border" description holds only for `type=Menu`.
6. **Consumption is narrower than the registry implied.** All **eight** instances across
   members-home, groups-home and enrollments-home were resolved individually this run and every
   one is `type=Menu, active=false`. The other three variants are designed-unconsumed (§3a).
7. **The frozen snapshot is re-frozen as the whole set.** The previous asset was a 3× crop of one
   consumed instance ("All Groups") — one variant of four.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3561-33782
  — set `3561:33782` ("Fitler tags" — the source's own spelling, preserved here only as the layer
  name per registry naming rule 1), 192×108, at (2680, 1318). Ingested 2026-09-11. Two axes, four
  symbols:

  | Symbol | Node | Size | Label node |
  |---|---|---|---|
  | `active=true, type=Button` | `3561:33781` | 48×24 | `3561:33778` |
  | `active=false, type=Button` | `3561:33783` | 48×24 | `3561:33784` |
  | `type=Menu,active=false` | `3668:7569` | 70×24 | `3668:7570` (chevron `3668:7602`) |
  | `active=true, type=Menu` | `3668:7609` | 70×24 | `3668:7611` (chevron `3668:7610`) |

- **Owner-pasted node:** `3668:7390`, an instance on members-home, 112×24. Resolved upward to the
  set above (this run's first act).
- **The set is the component**, so the component sheet (`3632:4502`, D9) can hold no variant it
  does not; a sheet entry would be an instance of this same set. The set sits at (2680, 1318),
  in the same neighbourhood as C-034's sheet set `3561:33795`.
- Frozen snapshot: `assets/C-035-filter-chip.png` — the whole set at 3×, captured 2026-09-11.
  Replaces a single-instance crop (change-list item 7).

**Deviations (closed list):**
1. **The four symbols are named inconsistently in the source.** Three read `active=X, type=Y`;
   `3668:7569` reads `type=Menu,active=false` — reversed order, no space after the comma. The
   axes and values are identical; only the label text differs. Recorded so a later reader does
   not mistake it for a different property (OQ-C-035-2).
2. **The set's own layout is 2pt out of square.** The Button column's second row sits at y=64,
   the Menu column's at y=62. This is the set frame's arrangement, not a component measurement —
   every symbol is 24 tall.
3. **`active=true, type=Menu` carries a 1px border in `Color/Base/White` over a
   `Color/Base/White` fill** — a border that cannot be seen, on the variant whose ground is the
   same colour. Vestigial, like the r4 wrapper C-026 §2 records on its badges. It is stated here
   because it is in the source, not because it renders.
4. The chevron is exported as an SVG path whose fill is **baked into the artwork** — two
   different assets, `#85979E` inactive and `black` active — rather than tinted at the call site.
   Same construction as C-072's link glyph.
5. The sample label is "Now" in all four symbols; every consumption overrides it (§4).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A 24pt-tall pill containing a label, and — in `type=Menu` only — a leading chevron.

| Part | Geometry |
|---|---|
| Pill | horizontal, `items: center`, `justify: center`; **px 8**; `radius-card` (8); height **24**, width content-driven. Ground and border per variant (§3a). `type=Menu` adds gap **4**; `type=Button` has no gap because it has one child |
| Chevron (`type=Menu` only) | **16×16**, leading. Fill baked into the artwork: `color-text-secondary` inactive, `color-black` active (§1 deviation 4) |
| Label | SF Pro **Bold 14**; leading **22** in `type=Menu`, **24** in `type=Button` (§ below); colour per variant (§3a); `nowrap` |

**Widths are the sum.** `type=Menu` at the sample label: 1 + 8 + 16 + 4 + 32 + 8 + 1 = **70**, the
two 1s being the border, which is why the chevron sits at x=9 and not x=8. `type=Button`, which
has no border: 8 + 32 + 8 = **48**.

**Two leadings, one component.** The Menu label is Bold 14/**22** and the Button label is Bold
14/**24** — same face, same size, same weight, differing by variant axis alone. Bold 14/24 is
already on file from C-062 (this is its second site); Bold 14/**22** is **new to the program**,
which now carries five Bold-14 leadings: 14 (C-046), 16 (`type-nav-label`), 20
(`type-title-card`), 22 (here), 24 (C-062 + here). Neither is minted as a token off this
component. OQ-C-035-3.

**Flagged literals (D7):**
- **The label colour in the two inactive variants.** Variable `text/navigation` #8d9fa7 has **no
  token row** — `tokens.md` records it only as a near-duplicate of `color-nav-text` (#8ea0a7) and
  as the hex-twin of `color-nav-border-active`. Cite the variable until the owner consolidates,
  as `C-029-radial-day-clock.md` §2 and `C-027-legend-item.md` §2 do. This run **attributes** the
  consumer `tokens.md` had recorded as "members-home's Bold 14/22 label" to C-035 by name.
  OQ-C-035-4.
- **Both label leadings**, per the paragraph above. OQ-C-035-3.
- **The px 8 inset and the 4pt gap.** Recorded as measured values rather than as
  `space-element-gap` (8) and `space-meta-gap` (4). The gap is a true sibling gap and hex-equal to
  `space-meta-gap`; the inset is a pill inset, the case C-053 §2 and C-038 §2 both flag. Carried
  together for the same reason C-027 §2 gives: naming one and not the other inside a two-part
  component would be arbitrary.

**Tokens.** `get_variable_defs` on the set returns exactly `Color/Neutral/neutral-800` (#1e2939),
`Color/Neutral/neutral-600` (#4a5565), `Color/Base/Black`, `Color/Base/White`, `text/secondary`
(#85979e) and `text/navigation` (#8d9fa7). Every one but the last resolves to an existing row
(`color-neutral-800`, `color-neutral-600`, `color-black`, `color-text-primary`,
`color-text-secondary`). **This run mints no token row.** One role note: `Color/Base/White` is
bound here as a **fill**, where `tokens.md` carries that white only as `color-text-primary` — the
same variable-role mismatch C-038 found with `Border` (OQ-C-035-4).

## 3. Variant & state matrix

### 3a. The closed matrix

| `type` | `active` | Ground | Border | Chevron | Label | Width | Consumption |
|---|---|---|---|---|---|---|---|
| `Menu` | `false` | none | 1px `color-neutral-600` | `color-text-secondary` | Bold 14/22, `text/navigation` | 70 | **consumed ×8** — members-home (2), groups-home (2), enrollments-home (4); every instance verified individually this run |
| `Menu` | `true` | `color-text-primary` (white) | 1px white, invisible (§1 deviation 3) | `color-black` | Bold 14/22, `color-black` | 70 | **designed-unconsumed** — no screen draws a chosen filter (OQ-C-035-1) |
| `Button` | `false` | none | none | — | Bold 14/24, `text/navigation` | 48 | **designed-unconsumed** (OQ-C-035-5) |
| `Button` | `true` | `color-neutral-800` | none | — | Bold 14/24, `color-text-primary` | 48 | **designed-unconsumed** (OQ-C-035-5) |

Variants not in this table may not be built without a ruling.

**What `active` means is not the same in both types.** In `type=Menu` the active treatment is a
full inversion — white ground, black chevron and label — which reads as "this filter is applied".
In `type=Button` it is a filled pill against a bare label, which reads as "this option is
selected" in a group. The axis name is shared; the interaction models plausibly are not, and no
screen exercises either (OQ-C-035-5).

### 3b. Width is not a variant

Both types hug their label: 70 and 48 are what "Now" measures in each. The eight consumed
instances run 83–117 wide on their real labels ("All Groups", "All Leaders", "All Orgs",
"Active", …) with no other change.

### 3c. Undesigned states (proposed defaults + OQ)

- **`pressed`.** Not designed — and the superseded §4 contract asserted it as one of two states,
  which is the error this run corrects. Proposed default: standard system press feedback, no
  bespoke symbol. OQ-C-035-6.
- **`disabled`.** Not designed and not proposed. A filter with no available options is a screen
  concern, and nothing in the source says the chip has a disabled look.
- **Truncation.** The label is `nowrap` and the chip hugs it, so the source says nothing about a
  long selection in a full rail. Proposed default: the chip does not truncate and the rail
  scrolls; enrollments-home's four chips already total more than the 408pt content width.
  OQ-C-035-6.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `type` | `Menu \| Button` | Selects the presentation: `Menu` is a chevroned selector that presents C-036; `Button` is a chevron-less pill (§3a). Carried verbatim from the source axis |
| `active` | `Bool` | Selects the active treatment within the chosen `type` (§3a) |
| `label` | `String` | The chip's text. In `type=Menu` this is **the filter's current selection**, not a static name — every consumption overrides the sample "Now" |
| `onTap` | `() -> Void` | `type=Menu` presents **C-036 FilterMenuOverlay**; `type=Button`'s action is undesigned (OQ-C-035-5). No render effect |

**`active` was not in the prior contract and is not optional to model**: three of the four
designed variants are unreachable without it.

## 5. Composition

**Consumes:** nothing with a registry row. The chevron is 16pt baked artwork of the kind C-072
LinkStatusGlyph and C-074 PersonGlyph were minted for — but it is **deliberately not minted
here**. Chevrons already appear unrowed as anatomy in **C-028** (14pt down), **C-042** (18pt) and
**C-067** (chevron-right), so minting one row off this component would leave three rows still
citing loose chevrons and pre-empt the rule the program is already waiting on. That rule is
**OQ-C-038-7** ("When does a glyph earn a registry row?"), and this chevron — a fourth size, a
second direction, two baked fills — is recorded there as evidence rather than as a new question.

**Presents:** **C-036 FilterMenuOverlay**, on tap, in `type=Menu`. C-036's row already records
these chips as its consumers. The overlay is presented, not nested — it is not part of this
component's anatomy.

**Consumed by:** `members-home` (×2), `groups-home` (×2), `enrollments-home` (×4) — all eight
`type=Menu, active=false`.

**Anticipated:** any 2.0 list surface with a filter rail. `type=Button`'s segmented-selection
shape has no anticipated home yet, which is what OQ-C-035-5 asks about.

**Adjacent rows checked, no consolidation proposed.** **C-043 MetaChip** is also a 24pt bordered
chip, but it is a metadata *read-out* with `type` {Single, Key value} and `state` {Default,
Purple, Complete} from a different set (`3518:29457`) — display, not control. **C-069
NavTabButton** is also a p8 text pill with an `active` axis, but its active delta is colour only
(`C-019` §2b states this explicitly) where C-035's adds a ground, and its label is
`type-nav-label` (Bold 14/16) against C-035's 14/24. Distinct anatomy, distinct roles; no
duplicate row and no merge proposed.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-035-1 | **No screen draws an applied filter.** `type=Menu, active=true` is fully designed (white ground, black chevron and label) and consumed nowhere, while all eight live chips sit inactive — yet three of them read "All Groups" / "All Leaders" / "All Orgs", which are *unset* filters. So the active treatment is probably what a chosen option should look like and the screens simply never show one. Confirm, and the screens gain a state; deny, and the variant is dead | No | Owner |
| OQ-C-035-2 | **The set's symbol names are inconsistent.** `3668:7569` reads `type=Menu,active=false` where its three siblings read `active=X, type=Y`. Same axes, same values — cosmetic, but it is what made the second axis easy to miss. Normalise in Figma? | No | Owner |
| OQ-C-035-3 | **Two Bold-14 leadings in one component.** `type=Menu` labels are 14/**22**, `type=Button` labels 14/**24**, differing by variant axis alone. 22 is new to the program, which now has five Bold-14 leadings (14/16/20/22/24). One component spending two of them is the strongest evidence yet that these are drift — settle with OQ-C-062-3 and OQ-C-046-6 as one typography ruling | No | Owner |
| OQ-C-035-4 | **Token roles.** (a) The inactive label colour is variable `text/navigation` #8d9fa7, which still has no token row while its hex-twin `nav/border-active` does — C-035 is one of its three consuming rows. (b) `Color/Base/White` is bound here as a **fill**, where `tokens.md` carries that white only as `color-text-primary`; same mismatch C-038 found with `Border` | No | Owner |
| OQ-C-035-5 | **What is `type=Button` for?** Both its variants are designed and neither is consumed. It has no chevron, so it presents no menu — it reads as a segmented single-select, a different interaction from the Menu type sharing the same `active` axis. Name its role and its action, or is it superseded by the Menu type? | No | Owner |
| OQ-C-035-6 | **`pressed` and overflow are undesigned.** §3c proposes system press feedback and a scrolling rail with no truncation. The prior contract asserted `pressed` as a designed state; it is not. enrollments-home's four chips already exceed the 408pt content width, so the overflow answer is load-bearing there | No — defaults proposed | Owner |
