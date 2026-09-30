# C-022 MetaPair — a value and its label, inline or stacked

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-022` with no
URL — the row's own Figma refs were the starting point, and this run **resolved the instance the
registry carried (`3673:12445`) to its variant set** (`3636:5616`), then resolved the second source
the row inherited from C-041. The prior contract was the three-line §4 subsection in
`screens/home-dashboard.md`; this file **relocates** it (pointer left there).

**This run exists to settle OQ-C-022-1.** On 2026-09-11 the owner removed **C-041 DetailPair** as
an accidental duplicate of this row and moved its four consuming screens here. That left C-022
describing an *inline* pair while four screens consumed a *stacked* one, with no ruling on which
was normative. The answer, from the sources: **both are designed, both are consumed, and neither
can be dropped** — so C-022 carries a `layout` axis (§3a).

**Closed change list vs. the superseded `home-dashboard.md` §4 contract:**
1. **The row has two Figma sources, and neither is an instance.** The inline form is set
   `3636:5616` ("Text metadata"); the stacked form is set `3499:27340` ("Detail"), inherited from
   C-041. §4 cited only the instance `3673:12445`.
2. **The inline form has an `align` axis** — two designed symbols, where §4 described one.
3. **`align` does not align anything.** `align=Right` **swaps the order** of the value and the
   label; both symbols are the same 79×24 box and neither sets a text-alignment or justification
   property. Recorded because a build that reads the name literally — `.frame(alignment:
   .trailing)` — renders the wrong thing (§2).
4. **The stacked form is fully specced here for the first time**, carried from C-041's measurements
   and re-verified against the source this run (§3a).
5. **Correction — the inline type is Regular 12/24**, not the Regular 12 with no leading that §4
   implied. `C-030-time-activity-chart.md` §2 had already measured 12/24 independently on the tick
   row it builds from this component; this run confirms it at the source.
6. **The two forms disagree about white.** The stacked set binds `Color/Base/White`; the inline set
   binds nothing for its value run (plain white, hex-equal to `color-text-primary`). One registry
   row, two bindings for one role — OQ-C-022-4.
7. **A mis-tagged element map was corrected the same run**: `home-dashboard.elements.json` reffed
   `3676:12466` as C-022, but that node is a plain frame holding a text run and a `Chevron--down`
   instance — it is the Sessions header's **C-028 InlineDropdown**, exactly as
   `home-dashboard.md` §2 describes it. Repointed to C-028.
8. **Frozen snapshots re-frozen from both sets** (§1), replacing a 220×96 crop.

## 1. Normative source

**Two sets, because the merge is a registry decision and Figma has not made it.** Both are
normative; neither contains the other.

- **Inline** — https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3636-5616
  — set `3636:5616` ("Text metadata"), 120×108, at (6726, 910). Axis `align`:

  | Symbol | Node | Size | First run | Second run |
  |---|---|---|---|---|
  | `align=Left` | `3636:5615` | 79×24 | `3636:5613` value, white | `3636:5614` label, `color-text-secondary` |
  | `align=Right` | `3636:5617` | 79×24 | `3636:5619` label, `color-text-secondary` | `3636:5618` value, white |

- **Stacked** — https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3499-27340
  — set `3499:27340` ("Detail"), 134×78, at (3050, 384). **One symbol**, `3499:27339`, 78×36,
  holding `3499:27337` (label) over `3499:27338` (value). Figma names that symbol
  `Property 1=Default` — its auto-assigned placeholder, recorded here as evidence only and kept out
  of §3 and §4 per registry naming rule 6. Inherited from C-041 on 2026-09-11.

- The owner-pasted ref the registry carried, `3673:12445`, is an **instance** of `align=Left` on
  the home-dashboard frame. Resolved upward this run.
- Frozen snapshot: `assets/C-022-meta-pair.png` — the **inline** set at 3×, captured 2026-09-11.
  ⚠️ **Partial by construction:** it shows the inline form only, because the stacked form is a
  different Figma frame. The stacked set is frozen beside it as
  `assets/C-022-meta-pair-stacked.png` (3×, same date), which the parser does not read. **A build
  run can diff the inline states and not the stacked ones** until the two sets are unified in
  Figma — OQ-C-022-2. Same class as C-038's partial-snapshot flag.

**Deviations (closed list):**
1. **`align` is a misleading axis name, kept anyway.** It selects the **order** of the two runs,
   not an alignment property. It is the designer's own name rather than a Figma placeholder, and
   it describes the intent a consumer has (put the value toward the gutter), so it is carried —
   but §2 and §3a state the mechanism, and no build may implement it as an alignment. Contrast
   registry rule 6, which strikes placeholders: this is a real name that is imprecise, not an
   absent one.
2. Both sets' root carries a **`radius-card-sm` (4) with no fill and no border** — no visual
   effect. Vestigial, the same authoring residue `C-026-dual-series-bar-chart.md` §2 records on
   its badge wrappers.
3. The stacked symbol's label reads "enrollments" over a value of "5"; the inline symbols read
   "3"/"enrollments". Sample content — every consumption supplies its own pair (§4).
4. The inline set binds no variable for its value's white (§1 change-list 6).
5. The `layout` axis in §3a **does not exist in Figma.** It is this row's model of two Figma
   sources the owner merged into one registry row. Named here, per §3a.
6. **`layout=stacked valueFirst=yes` is not drawn in Figma.** It is an owner ruling made on
   2026-09-11 as a comment on the built preview (§3a records the wording and the timestamp).
   The stacked set still has exactly one symbol, `3499:27339`, so **no frozen snapshot can
   confirm this state** — a build renders it from the contract alone, and its diff against the
   design pane is expected to be empty rather than matching. Closing this properly is a Figma
   symbol; until one exists, the contract is the only source for this state.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Two text runs — a **value** and a **label** — and nothing else. No icon, no ground, no border, no
shadow. The `layout` axis (§3a) decides whether they sit in a row or a column, and that choice
carries the type size, the gap and the order with it.

| Part | `layout=inline` | `layout=stacked` |
|---|---|---|
| Root | horizontal, `items: center`, gap **4**; content-hugging. Height **24** | vertical, `items: start`, gap **8**; content-hugging. Height **36** |
| Value | SF Pro **Regular 12**, leading **24**, white | SF Pro **Regular 14**, leading **14** (`type-body`), white |
| Label | SF Pro **Regular 12**, leading **24**, `color-text-secondary` | SF Pro **Regular 14**, leading **14** (`type-body`), `color-text-secondary` |
| Order | `align=Left` value→label · `align=Right` label→value (§3b) | **label over value**; `valueFirst=yes` swaps it to value over label (§3a, owner-ruled) |

**Each height is the sum of its own type.** Inline: 24 = one 24pt line box, both runs sharing it.
Stacked: 36 = 14 + 8 + 14. Neither height is set.

**Note the two forms invert the reading order.** Inline `align=Left` leads with the value ("3
enrollments"); stacked, **as drawn**, leads with the **label** ("enrollments" over "5"). That is a
substantive difference between the merged halves, not a layout detail, and it is why §3a keeps
them as separate rows rather than describing one anatomy with a direction flag.

The owner's `valueFirst` ruling (§3a) is what closes that inversion when a consumer wants it
closed: `layout=stacked valueFirst=yes` leads with the value, exactly as inline `align=Left`
does. It is deliberately an **added state rather than a redefinition** — the drawn stacked form
keeps its anatomy, its name and its four consuming screens untouched. OQ-C-022-9 asks whether
`valueFirst` and `align` should later consolidate into one order axis spanning both layouts.

**Flagged literals (D7):**
- **The inline type, Regular 12/24.** No token row carries it: `type-caption` is Regular
  12/**14**. This is the **second independent component** to measure it after C-027 LegendItem,
  which crosses the threshold `tokens.md` states for minting — recommended there, not minted here,
  because it should be settled together with `type-caption`. OQ-C-022-3.
- **The inline value's white.** Hex-equal to `color-text-primary` but bound to no Figma variable,
  where the stacked form's white **is** bound. OQ-C-022-4.
- **The 4pt and 8pt gaps.** Recorded as measured values rather than as `space-meta-gap` (4) and
  `space-element-gap` (8). Both are hex-equal, and both are genuinely gaps between siblings — the
  case for citing the tokens is stronger here than for the pill insets C-053 §2 flags. Carried as
  measurements pending the same spacing ruling. OQ-C-022-5.

**Tokens.** `get_variable_defs` returns `text/secondary` (#85979e) on the inline set, and
`text/secondary` + `Color/Base/White` on the stacked set. Both resolve to existing rows
(`color-text-secondary`, `color-text-primary`). The stacked type resolves cleanly to `type-body`.
**This run mints no token row.**

## 3. Variant & state matrix

### 3a. The closed matrix

`layout` is this row's own axis (§1 deviation 5); `align` exists only on the inline form.

| `layout` | `align` | `valueFirst` | Anatomy | Size | Consumption |
|---|---|---|---|---|---|
| `inline` | `Left` | — | row, gap 4, Regular 12/24, **value→label** | 79×24 at sample | **consumed** — home-dashboard (3 instances, all resolved individually this run: `3636:5623`, `3673:12445`, `3636:5627`); C-030 tick row ×4 (`C-030` §2: "value … + 4gap + unit") |
| `inline` | `Right` | — | row, gap 4, Regular 12/24, **label→value** | 79×24 at sample | **designed-unconsumed** — no resolved instance uses it (OQ-C-022-6) |
| `stacked` | — | — | column, gap 8, Regular 14/14, **label over value** | 78×36 at sample; grid-consumed at 196×36 | **consumed** — members-profile, study-program-home, enrollment-home, invite-home, all in 2×2 grids (inherited from C-041 on 2026-09-11) |
| `stacked` | — | `yes` | column, gap 8, Regular 14/14, **value over label** | 78×36 | **unconsumed** — **owner-ruled 2026-09-11**, not drawn in Figma (§1 deviation 6). No screen renders it yet |

Variants not in this table may not be built without a ruling.

**The fourth row is an owner ruling, not a Figma reading.** It was made as a comment on the
built `stacked` preview — "we need a way to reverse the stack so the number is on top and the
label is on bottom, this should be another stacked variant" (2026-09-11T22:45:25.134Z,
comparison `ui2-c-022`). The owner is the person §3d's OQ was waiting on, so the comment
**is** the ruling, and it lands in the contract rather than being improvised in Swift —
`preview-build.md` §3 rule 6 keeps its hold that the contract is the only place a state may be
added. What the ruling does **not** do is claim Figma designs it: §1 deviation 6 says it does
not, and a build renders it knowing the frozen snapshot cannot confirm it.

**This table is the answer to OQ-C-022-1.** "One anatomy survives" was not available: the inline
form is consumed by home-dashboard and C-030, the stacked form by four other screens, and dropping
either would change what a shipped screen renders. The axis is the only reading consistent with
both D5 and the consumption facts.

### 3b. `align` swaps order; it does not align

Both inline symbols are the same 79×24 box, and neither sets a text-alignment or justification
property. `align=Right` reorders the two runs so the **value** sits on the right — which is what a
right-hand grid column or a trailing header accessory wants. Verified in the export: `align=Left`
reads white-then-`#85979e` left to right, `align=Right` reads `#85979e`-then-white.

A build must implement this as **order**, not as alignment. `.frame(alignment: .trailing)` would
right-align a box that is already content-sized — a no-op — and leave the runs in the wrong order.

### 3c. Width is not a variant

Every form hugs its content: 79 and 78 are what the sample strings measure. The stacked form's
consumers place it in fixed 196×36 grid cells, which is the **cell's** geometry, not this row's.

### 3d. Undesigned states (proposed defaults + OQ)

- **A stacked `align`.** Still not designed and still not proposed: the stacked set has one symbol,
  and inventing a right-aligned stacked pair would pre-empt OQ-C-022-2's question about whether the
  two sets merge in Figma at all. ~~Nor is a reversed stacked ORDER proposed, for the same
  reason.~~ **Superseded 2026-09-11 for the order half only:** the owner ruled the reversed order
  in (§3a `valueFirst`). The distinction that survives is the one that mattered — this section
  declines to *invent* a state, and an owner ruling is not an invention. A horizontal `align` for
  the stacked form remains undesigned and unproposed.
- **Interaction.** No pressed, hover or disabled symbol, and no action prop in either form — a
  meta pair is a read-out. Proposed default: non-interactive. Where a consumer makes one tappable
  (C-020 SectionHeader's `meta-button` accessory pairs it with a C-021 GlyphButton), the tap
  target is the **consumer's**, not this row's.
- **Truncation.** Both runs are `nowrap` and the component hugs them; nothing in either source says
  what a long value or label does in a fixed grid cell, which the stacked form always sits in.
  Proposed default: the label truncates before the value. OQ-C-022-7.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `value` | `String` | The number or short datum (e.g. "3", "5", "0 mins") — rendered white in every form |
| `label` | `String` | What the value counts (e.g. "enrollments", "metrics") — `color-text-secondary` in every form |
| `layout` | `inline \| stacked` | Row or column, and with it the type size, gap and order (§2, §3a). This row's own axis, not Figma's (§1 deviation 5) |
| `align` | `Left \| Right` | **Inline only.** The order of the two runs (§3b) — *not* an alignment. Ignored when `layout=stacked`, whose order is `valueFirst`'s |
| `valueFirst` | `Bool` | **Stacked only.** `true` puts the value above the label, reversing the drawn order (§3a). Defaults to `false` — the drawn form. Ignored when `layout=inline`, whose order is `align`'s |

`value` and `label` are unchanged from the superseded §4. `layout` and `align` were added by the
2026-09-11 full-set run: `align` because the inline set designs it, `layout` because the owner's
merge requires it. **`valueFirst` was added the same day by owner ruling** (§3a), and it is the
one prop in this table with no Figma symbol behind it.

**Each layout reads exactly one order prop, and ignores the other.** `align` is inert under
`layout=stacked`; `valueFirst` is inert under `layout=inline`. That is a sparse matrix, not two
missing states — §3d declines to propose a stacked `align`, and an inline `valueFirst` would just
be `align` spelled twice.

**Why `valueFirst` rather than extending `align`.** `align`'s values are `Left`/`Right`, which
name nothing in a column, and folding the stacked order into them would have re-keyed the
**drawn** stacked state — whose name is the DB key its design versions and pinned comments hang
off (`preview-build.md` §3 rule 7). A new prop adds a state without disturbing one. The tidier
long-run model — one order axis spanning both layouts, absorbing `align` — is **OQ-C-022-9**, and
it is deliberately left as a ruling rather than taken here, because it renames a shipped prop
across C-030, C-064, C-020 and five screens.

## 5. Composition

**Consumes:** nothing. Two text runs resolve to no other registry row.

**Consumed by:**
- `home-dashboard` — section-header accessories (×3 resolved) and, via **C-030**, the tick row (×4)
- `members-profile`, `study-program-home`, `enrollment-home`, `invite-home` — 2×2 detail grids,
  `layout=stacked` (inherited from C-041, 2026-09-11)
- **C-030 TimeActivityChart** (`C-030` §5 lists it as a consumed sub-component)
- **C-064** — enrollment-home, per the registry row's standing note
- **C-020 SectionHeader** pairs it with C-021 GlyphButton in its `meta-button` accessory

**Absorbed:** ~~C-041 DetailPair~~, removed 2026-09-11 by owner ruling as an accidental duplicate.
Its ID is struck through and retained; all 19 of its snapshot bounding boxes were repointed here.

**Raised at merge time, still open:** C-041's nearest structural twin on file was **C-071
ValuePair** (stacked, two `type-caption` lines, gap 8, 95×36) — closer to the stacked form than
the inline one this row was named for. The owner directed C-022; whether C-071 belongs in the same
consolidation is OQ-C-022-8.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| ~~OQ-C-022-1~~ | ~~**Does C-022 gain a layout axis, or is one anatomy the survivor?**~~ **CLOSED 2026-09-11 by this run:** a layout axis, because both forms are designed in Figma and both are consumed — inline by home-dashboard + C-030, stacked by four screens — so "one survivor" would change what a shipped screen renders (§3a) | — | closed |
| OQ-C-022-2 | **Should the two Figma sets be unified?** The merge is a registry decision; Figma still has `3636:5616` and `3499:27340` as separate components. Until they are one set with a `layout` axis, this row's frozen snapshot covers the inline form only and **a build cannot diff the stacked states** (§1). Unify in Figma, or accept a two-asset row? | No — but it gates a complete build | Owner |
| OQ-C-022-3 | **Regular 12/24 has no token row, and now two components.** C-027 LegendItem found it; C-022's inline form is the second, with C-030 having measured it independently. `tokens.md`'s own stated threshold ("two occurrences") is met. Mint it — and settle it against `type-caption` (Regular 12/**14**), one leading away — or keep flagging? | No | Owner |
| OQ-C-022-4 | **One row, two whites.** The stacked set binds `Color/Base/White`; the inline set binds nothing for the same role. Bind the inline one, or is the merged row expected to carry both? | No | Owner |
| OQ-C-022-5 | **The 4pt and 8pt gaps are carried as measurements**, though both are hex-equal to `space-meta-gap` / `space-element-gap` and both are true sibling gaps — a stronger claim on those tokens than the pill insets other rows flag. Cite the tokens, or hold for one spacing ruling? | No | Owner |
| OQ-C-022-6 | **`align=Right` is designed and unconsumed.** Every resolved inline instance is `align=Left`. Is the right-hand order intended for the trailing accessory slot (where C-020's `meta-button` sits), or is it dead? | No | Owner |
| OQ-C-022-7 | **Truncation is undesigned**, and the stacked form always sits in a fixed 196×36 grid cell, so it is the form most likely to overflow. §3d proposes the label truncates before the value | No — default proposed | Owner |
| OQ-C-022-9 | **Should `valueFirst` and `align` consolidate into one order axis?** Both select which run leads; `align` does it horizontally (`Left` = value first) and `valueFirst` vertically. One axis — say `order: value-first \| label-first` — would span both layouts, remove the sparse matrix, and close the reading-order inversion §2 flags. It also renames a shipped prop across C-030, C-064, C-020 and five screens, and re-keys two built states, so it was not taken when `valueFirst` was ruled in | No | Owner |
| OQ-C-022-10 | **Does `layout=stacked valueFirst=yes` get a Figma symbol?** It is owner-ruled and built, but undrawn (§1 deviation 6), so it is the one state whose render no snapshot can check — the diff pane has nothing to show. Draw it into set `3499:27340`, or accept a contract-only state? Related to OQ-C-022-2, which already blocks diffing the drawn stacked state | No — but it is why one state cannot be visually verified | Owner |
| OQ-C-022-8 | **Does C-071 ValuePair belong in this consolidation?** It is stacked, two lines, gap 8, 95×36 — structurally nearer C-022's stacked form than its inline one, and it carries a 7-value `state` colour axis this row has no equivalent of. Raised when C-041 was merged; not acted on | No | Owner |
