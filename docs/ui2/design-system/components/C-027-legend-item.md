# C-027 LegendItem — a series dot and its name, one entry of a chart legend

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-027` with
no URL — the row's own Figma ref was the starting point, and this run **resolved it to the
component it was an instance of** (see §1). The row's prior contract was the two-line §4
subsection in `screens/home-dashboard.md`; this file **relocates** it (pointer left there).

**The ref this run started from was an instance, not a component.** The registry carried
`node 3673:12013 (in 3622:5487)` — one of the two legend instances sitting on the home-dashboard
frame. Resolving it upward found the main symbol `3605:4385` and, above that, the **variant set
`3605:4386`**, which carries a **second variant the instance ref could not show**. Asking Figma to
type the instance returns `property1?: "Default"` — a one-value union, because an instance has one
value; asking the *set* returns `property1?: "Default" | "Variant2"`. Specced from the instance,
this row would have been recorded as single-state, wrongly.

**Closed change list vs. the superseded `home-dashboard.md` §4 contract:**
1. **Source moves from an instance to the set** `3605:4386` — and the row gains a **second
   designed variant** (§3a). §4 described one thing; there are two.
2. **Correction — the label colour is `text/navigation` #8d9fa7, not `text/secondary`.** §4 said
   "`text/secondary`", which is **#85979e** — a different colour, not an alias. The same
   correction C-029 made for the hour labels on this screen (§2).
3. **Correction — the label's leading is 24, not 14.** §4 gave no leading; `tokens.md`'s
   `type-caption` (Regular 12/**14**) cited "legends" as one of its observation sources, which
   asserted 14. Measured here at **Regular 12/24** in both variants. That citation is withdrawn
   in `tokens.md` this run (§2).
4. **The prop contract is `color`, `label` and `onTap`** (owner ruling 2026-09-11). The prior §4
   listed `color, label`, and an earlier draft of this file **struck `color`** on the grounds that
   the dot's fill arrives with the Figma variant rather than an instance override. That reasoned
   from how the set is *authored* instead of from what the component *is*: a legend labels
   whatever series a chart plots, so a component that only renders the two colours Figma happened
   to draw is useless to the third series. `color` is restored, the axis is dropped (§1), and
   `onTap` is added so the presenting surface can make the entry do something.
5. **Geometry pinned:** 8pt dot + 8 gap + label, item height **24** (the label's line box), widths
   124 / 118 content-driven (§2).
6. **The frozen snapshot is re-frozen as the whole set.** The previous asset was a 4× crop of one
   consumed instance — one variant, no set frame. It is replaced by the 3× set export, matching
   C-021 / C-045 / C-053 and what `syncUi2Row` registers per state (§1).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3605-4386
  — set `3605:4386` ("Legend item"), 164×108, at (2708, 969). Ingested 2026-09-11. One axis,
  two symbols. **The axis and its second value are unnamed in Figma** — `Property 1` and
  `Variant2` are the placeholders it auto-assigns. Per registry naming rule 6 those strings are
  recorded here, as source evidence, and **nowhere else in this contract**:

  | Figma symbol name (evidence only) | Node | Size | Dot | Label (as drawn in the set) |
  |---|---|---|---|---|
  | `Property 1=Default` | `3605:4385` | 124×24 | `3605:4380`, `color-accent` | `3605:4381` "Completed lessons" |
  | `Property 1=Variant2` | `3605:4387` | 118×24 | `3605:4388`, `color-white-20` | `3605:4389` "Total engagement" |

  **The axis is not a prop** (owner ruling 2026-09-11). The two symbols differ in exactly one
  thing — the dot's fill — and that is a value the consumer supplies, because a legend labels
  whatever series its chart plots. So the fill is the `color` prop (§4) and these two symbols
  are its two **designed values** (§3a), not a variant axis to model.

- **Consumed twice on one screen.** `home-dashboard`'s Legend row (`3673:12012`, a frame that is
  a *sibling* of the C-026 chart instance, not part of it) holds `3673:12013` (the `color-accent`
  symbol) and `3673:12014` (the `color-white-20` one).
- **No sheet copy to probe.** A variant set *is* the main component, so the component sheet
  (`3632:4502`, D9) cannot hold variants this set does not — a sheet entry would be an instance of
  this same set. The phase-1 sheet probe is satisfied by having resolved the set itself.
- Frozen snapshot: `assets/C-027-legend-item.png` — the whole set at 3×, captured 2026-09-11.
  Replaces a 4× single-instance crop (change-list item 6).

**Deviations (closed list):**
1. **`Variant2`'s label as drawn in the set is "Total engagement"; its only consumption overrides
   it to "Scheduled lessons".** The set's sample string is therefore stale with respect to the one
   place the variant is used, and "Scheduled lessons" — not "Total engagement" — is what pairs
   with C-026's track. Recorded, not resolved: OQ-C-027-3.
2. The axis is named **`Property 1`** and its second value **`Variant2`** — Figma's defaults,
   carried verbatim because renaming them here would invent a vocabulary the source does not
   have. What they *mean* is §3a; what they should be called is OQ-C-027-1.
3. The dot is exported as an SVG circle rather than a shape with a fill, in both variants. This is
   an export artifact of a plain `ellipse` node, not baked artwork: the fill is variable-bound in
   both cases (`Purple/100%`, `White/20%`) and reads out of the vector as such. Unlike C-072 and
   C-074, this dot earns **no registry row** — it is a shape, not artwork (§5).
4. Widths differ per variant (124 vs 118) because the labels do. Width is content-driven (§3b).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A dot and a word, laid out in a row, centred on each other.

| Part | Geometry |
|---|---|
| Row | horizontal, `items: center`, gap **8**; content-hugging both axes. Height **24**, width content-driven. No padding, no background, no border |
| Dot | **8×8** circle, fill = the `color` prop (§4); the two designed values are in §3a. Vertically centred — it sits at y=8 in the 24pt row, 8 above and 8 below |
| Label | SF Pro **Regular 12**, leading **24**, variable `text/navigation` #8d9fa7, `nowrap` |

**The height is the label's line box.** 24 = the label's leading; the dot (8) is centred inside
it and sets nothing. Width = 8 + 8 + label, which is 124 for "Completed lessons" (label 108) and
118 for "Total engagement" (label 102).

**Flagged literals (D7):**
- **The label colour.** Variable `text/navigation` #8d9fa7 has **no token row** — `tokens.md`
  records it only as a near-duplicate of `color-nav-text` (#8ea0a7) and as the hex-twin of
  `color-nav-border-active`. Cite the variable until the owner consolidates, exactly as
  `C-029-radial-day-clock.md` §2 does for the hour labels. This run makes C-027 the **third**
  text consumer of that variable; the hygiene note in `tokens.md` is updated accordingly.
  OQ-C-027-2.
- **The label's type, Regular 12/24.** No row carries it. `type-caption` is Regular 12/**14** and
  had cited "legends" among its observation sources — an assertion this measurement contradicts,
  so that citation is withdrawn in `tokens.md` this run. Not minted off one component, per the
  same D7 reasoning as C-046's Bold 14/14. OQ-C-027-2.
- **The 8pt gap and the 8pt dot.** Both are recorded as measured values rather than as
  `space-element-gap` (8). The gap is hex-equal to it and is genuinely a gap between siblings, so
  the case for citing the token is stronger here than in C-053 or C-038 — but the *dot diameter*
  is a size, not a spacing, and naming one and not the other inside a two-part component would be
  arbitrary. Both are carried as the component's own measurements. OQ-C-027-4.

**Tokens.** `get_variable_defs` on the set returns exactly `Purple/100%` (#6c47ff),
`White/20%` (#ffffff33) and `text/navigation` (#8d9fa7). The first two are bound to
`color-accent` and `color-white-20`; the third is the flagged literal above. **This run mints no
token row.**

## 3. Variant & state matrix

### 3a. The closed matrix

These are the two **designed values of `color`** (§1), not a variant axis. The state label is
the role the value plays in its consuming chart.

| State | `color` | Label (in the set) | Width | Consumption |
|---|---|---|---|---|
| `primary` | `color-accent` (#6c47ff) | "Completed lessons" | 124 | **consumed** — home-dashboard Legend row, instance `3673:12013`, label unmodified |
| `secondary` | `color-white-20` (#ffffff33) | "Total engagement" | 118 | **consumed** — home-dashboard Legend row, instance `3673:12014`, label **overridden** to "Scheduled lessons" (§1 deviation 1) |

Variants not in this table may not be built without a ruling.

**`color` is not closed to these two.** The table is closed as a record of what Figma *designs*;
the prop's value set is `tokens.md`'s colour family, because a legend entry takes the colour of
whatever series it labels (§4). A third series needs no new state here — it needs a token.

**The two designed values are the two series of C-026.** `C-026-dual-series-bar-chart.md` §2
states that each day column's "**completed** count fills `color-accent`… the remainder above it is
the track, `color-white-20`" — the same two colours, in the same order, on the same screen,
directly under that chart. That correspondence is what names the two states `primary` and
`secondary`, and it is also why neither is named `completed`/`scheduled`: registry naming rule 1
names the role, not the first consumer, and a legend entry outlives this one chart.

### 3b. Width is not a variant

The row hugs its label, so a different word gives a different width with no other change — 124 for
"Completed lessons", 118 for "Total engagement", and 123 for "Scheduled lessons" as instantiated.
The set demonstrates this rather than asserting it: the two symbols differ in width only because
their sample labels differ.

### 3c. Undesigned states (proposed defaults + OQ)

- **A third series.** Figma designs two colours because its one consumer plots two series. This
  is **not a missing state**: `color` takes any `tokens.md` colour (§4), so a third series is a
  new value, not a new design.
- **Interaction — RULED 2026-09-11 (owner): the component is tappable.** It carries `onTap`, and
  **what tapping does belongs to the presenting surface**, not to this row — a legend entry may
  filter its chart on one screen and do nothing on another. No **pressed** symbol is designed,
  so the press *feedback* is still undesigned; proposed default: standard system feedback, no
  bespoke treatment (OQ-C-027-5).
- **Disabled / selected.** Not designed and not proposed. If a surface uses tap to toggle a
  series, the "off" look is that surface's question until a frame answers it.
- **Truncation.** The label is `nowrap` and the component hugs it, so nothing in the source says
  what happens when a legend row runs out of width. Proposed default: the row does not truncate
  and the *legend container* — which is the screen's, not this component's (§5) — decides. OQ-C-027-5.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `color` | a `tokens.md` colour token | The dot's fill — the series this entry labels. §3a's two rows are its **designed** values, not its whole range |
| `label` | `String` | The series name. A real per-instantiation override: home-dashboard replaces the set's "Total engagement" with "Scheduled lessons" (§1 deviation 1) |
| `onTap` | `() -> Void` | Makes the entry tappable. **This row does not define what tapping does** — the presenting surface does (§3c). No render effect |

Three props, and that is the whole contract: a legend entry is a colour, a word, and somewhere to
send a tap.

**`color`'s value set is owned by `tokens.md`, not by this row** and not by another registry row,
so §4 cites the family rather than enumerating it (`preview-build.md` §3 rule 5's reasoning: one
owner per value set). Restating the two designed colours as the type would close the prop to the
one chart C-027 happens to serve today, which is the opposite of what a legend is for.

**Why there is no variant prop.** The two Figma symbols differ in exactly one thing — the dot's
fill — which is `color`. Modelling that difference *also* as an axis would give one value two
owners and let a fixture set them to disagree. The axis is dropped, per registry naming rule 6;
§1 keeps Figma's own strings as evidence.

## 5. Composition

**Consumes:** nothing. An 8pt circle and a text run resolve to no other registry row. The dot is
deliberately **not** minted: C-072 LinkStatusGlyph and C-074 PersonGlyph earned rows because they
are *artwork* whose fill is baked in, where this is a shape with a variable-bound fill — the same
reasoning that left C-029's 4pt tick dots unregistered.

**Consumed by:** `home-dashboard` (Activity section, twice — one instance per variant).

**Not part of C-026.** The Legend frame `3673:12012` is a sibling of the chart instance
`3673:12011` on the screen, and `C-026-dual-series-bar-chart.md` documents no legend — verified
this run. The two components are paired by the screen's layout (`home-dashboard.md` §2: "inset 16,
gap 16"), not by composition. **The legend row itself has no registry row** and does not need one
while its only construction is two of these in a row; if a second screen legends a chart, that
container is the thing to mint.

**Anticipated:** any 2.0 surface that plots a multi-series chart. C-024 SparkBarChart is
single-series and legends nothing; C-030 TimeActivityChart uses a gradient rather than discrete
series. Because `color` is a free token and `onTap` is the surface's to define (§4), a new chart
needs no change here — which is the point of dropping the axis.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| ~~OQ-C-027-1~~ | ~~**The axis and its second value are unnamed.**~~ **CLOSED 2026-09-11 by the owner, and the question was wrong to exist.** Figma's `Property 1` / `Variant2` are placeholders, and parking them behind an OQ shipped them into the fixture, `CaptureComponent` and the Swift signature (`LegendItem(property1: .variant2, …)`) while the OQ waited. The ruling: the axis is **not a prop at all** — the two symbols differ only in the dot's fill, so that is `color`, and they are its designed values. Generalised into **registry naming rule 6**: name every axis, value and prop in the run that specs it; ask the owner if unclear; never park a placeholder | — | closed |
| OQ-C-027-2 | **The label's colour and type both lack token rows.** The colour is variable `text/navigation` #8d9fa7 (no row; hex-twin of `color-nav-border-active`, near-duplicate of `color-nav-text`) — this row is its **third** text consumer. The type is Regular **12/24**, the program's first, and `type-caption` (12/14) had wrongly cited this legend as evidence. Mint `color-text-navigation` and a 12/24 row, or consolidate? Both flags are recorded in `tokens.md` | No | Owner |
| OQ-C-027-3 | **`Variant2`'s sample label is stale.** The set draws "Total engagement"; its only consumption overrides it to "Scheduled lessons", which is what actually pairs with C-026's track. Update the set's sample, or is "Total engagement" a second intended use? | No | Owner |
| OQ-C-027-4 | **The 8pt gap and 8pt dot are carried as literals.** The gap is hex-equal to `space-element-gap` and is a true sibling gap, so it has a better claim to that token than the insets other rows have flagged; the dot's 8 is a size and has none. Cite the token for the gap, leave both as measurements, or mint a size row? | No | Owner |
| OQ-C-027-5 | **Press feedback and overflow are undesigned.** The component **is** tappable (owner, 2026-09-11 — §3c), but no `pressed` symbol exists, so the feedback is a proposed default: standard system treatment. Nothing says what a long label does in a fixed-width row either; §3c proposes no truncation, with the legend container scrolling | No — defaults proposed | Owner |
