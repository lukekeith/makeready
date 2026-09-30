# C-064 DateSpanIndicator — the length of a scheduled range, read out between two arrows

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-064
https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3836-7920` — the
owner pasted node `3836:7920`, which is a **symbol**, not a set; this run resolved it upward to its
variant set `3836:7921` (the same upward resolution the C-022 run made from `3673:12445`).

The prior contract was the six-line §4 subsection in `screens/enrollment-home.md`; this file
**relocates** it (pointer left there). The relocation is justified because the component file adds
material the screen section could not carry: the set/symbol split, the arrow artwork's resolution
to a registry row of its own (§5a), and four measurements that contradict the screen's prose.

**Closed change list vs. the superseded `enrollment-home.md` §4 contract:**
1. **The row's Figma ref was a symbol id carrying a set's name.** The registry recorded
   `3836:7920 (sheet, Text metadata)`; `3836:7920` is the symbol and "Text metadata" is the name of
   its parent set, `3836:7921`. Both are pinned separately in §1.
2. **The arrows are not C-021 GlyphButtons, and one of them is not in C-021 at all.** §4 called them
   "arrow-left glyph 24 · arrow-right glyph 24" and resolved them to no registry row, which D6 does
   not allow. The right arrow's vector is **byte-identical** to C-021's `arrow-forward` export (one
   rounding digit apart) but filled `color-white-20`, not `color-accent`; the left arrow is a true
   left-pointing arrow that C-021's nine-glyph set does not contain — C-021's `back` is a
   chevron. **Owner ruling this run: mint C-075 ArrowGlyph** (§5a), under the C-072/C-074 precedent
   for a static glyph with a baked fill.
3. **The two pairs are LOCAL FRAMES, not C-022 MetaPair instances**, and their internal gap is
   **2**, not C-022's 4. §4 stated "**C-022 MetaPair** ×2" as a Figma fact; Figma has
   `3836:7925`/`3836:7926` as plain frames holding raw text runs. The anatomy is C-022's inline
   `align=Left` exactly — Regular 12/24, white value then `color-text-secondary` label — so the
   composition claim stands and the gap is carried as a deviation (OQ-C-064-3).
4. **The 184×88 box is SET, not content-derived.** §4 read "184×88 centered row, 8 gap" as if the
   height were the row's; the content band measures **162×24** and is centred in a fixed box, i.e.
   11pt of horizontal and **32pt of vertical** slack (OQ-C-064-2).
5. **The pairs' white IS variable-bound** here (`Color/Base/White`), where C-022's inline set binds
   nothing for the same run — new evidence on OQ-C-022-4, recorded in `tokens.md`.
6. **Regular 12/24 gains a THIRD independent component** after C-027 and C-022/C-030 — further past
   `tokens.md`'s own stated mint threshold (OQ-C-022-3).
7. **Figma's `Property 1=Default` axis is dropped, not renamed** — one value selects nothing
   (registry rule 6, third bullet).
8. **No frozen snapshot exists on disk** — §1, and OQ-C-064-1.

## 1. Normative source

- **Set** — https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3836-7921
  — set `3836:7921` ("Text metadata"), 224×128, at (1255, 4745) on the component sheet (D9).
  It contains **one symbol**.
- **Symbol** — `3836:7920`, 184×88, at (20, 20) inside the set. Figma names it
  `Property 1=Default` — the placeholder it auto-assigns to an unnamed single-value axis. Recorded
  here as source evidence only, and kept out of §3 and §4 per registry naming rule 6.
- **Children**, in render order: `3836:7914` (`arrow--left`, 24×24) · `3836:7925` ("Months",
  53×24, holding `3836:7915` value + `3836:7922` label) · `3836:7926` ("Days", 37×24, holding
  `3836:7923` value + `3836:7924` label) · `3836:7916` (`arrow--right`, 24×24).
- **Note the set name collides with C-022's.** C-022's inline set `3636:5616` is *also* named "Text
  metadata". Two different sets, one Figma name — which is why registry rule 1 keeps the Figma name
  in the Figma-ref column and names the row for its role.
- **Artwork exported this run:** `assets/C-075-direction-left.svg`, `assets/C-075-direction-right.svg`
  (§5a). Named on `preview-build.md` §3 rule 5's `<C-###>-<prop>-<value>.svg` pattern, so C-075's
  `direction` prop renders as a picture picker in the browser's Data tab.
- **Frozen snapshot:** ⚠️ **none on disk.** This run could not export one — the repo carries no
  Figma REST token and no export tooling, and every existing `assets/*.png` snapshot arrived in one
  bulk owner export (`562b863`). The component is therefore **specced but not buildable**:
  `preview-build.md` §0.4 stops a build run when §1 cites a snapshot that is not on disk, and here
  §1 cites none at all. OQ-C-064-1; the fix is an owner export to
  `assets/C-064-date-span-indicator.png` at 3×, matching its siblings.

**Deviations (closed list):**
1. `3`/`3`, "months"/"days" are sample content; every consumption supplies its own values (§4).
2. **The pasted node was a symbol, not a set** — resolved upward to `3836:7921`, as §1 records.
3. **The `Property 1` axis is dropped rather than renamed.** It has exactly one value, so it
   selects nothing a consumer could set; registry rule 6's third bullet drops such an axis instead
   of naming it. The component has no variant axis at all (§3).
4. The root carries a **`radius-card-sm` (4) with no fill and no border** — no visual effect.
   Vestigial, the same authoring residue `C-022-meta-pair.md` §1 deviation 2 and
   `C-026-dual-series-bar-chart.md` §2 record on their own roots.
5. **The 184×88 frame is fixed and its content is centred in it**, leaving 11pt each side and 32pt
   above and below a 162×24 content band. Carried as measured, flagged in §2, questioned in
   OQ-C-064-2 — a screen that places this in a flex row would hug the content instead.
6. **The value/label pairs are local frames, not C-022 instances**, and their gap is 2 where
   C-022 §2 measures 4. §5 still resolves them to C-022 — the anatomy is identical in every other
   respect — and OQ-C-064-3 asks which gap is normative.
7. **The arrows are not C-021 instances**, and are not tappable here. They resolve to C-075 (§5a).
8. **No frozen snapshot** — see §1. A later Figma edit to this set is therefore *not* currently a
   visible re-spec event, which is the one D5 guarantee this row does not yet have.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A fixed 184×88 box holding one horizontal band: an arrow, two value+label pairs, an arrow. No
fill, no border, no shadow, no label of its own.

| Part | Geometry |
|---|---|
| Root | 184×88 **fixed**; horizontal, `items: center`, `justify: center`, gap **8** (`space-element-gap`); `radius-card-sm` with no fill or border (deviation 4) |
| Content band | 162×24 — the four slots plus three 8pt gaps — centred, leaving 11 left / 11 right and **32 above / 32 below** |
| Leading arrow | **C-075 ArrowGlyph** `direction=left`, 24×24, `color-white-20` (§5a) |
| Months pair | 53×24 — value "3" (8 wide) + gap **2** + label "months" (43 wide) |
| Days pair | 37×24 — value "3" (8 wide) + gap **2** + label "days" (27 wide) |
| Trailing arrow | **C-075 ArrowGlyph** `direction=right`, 24×24, `color-white-20` (§5a) |

**Both pairs:** horizontal, `items: center`, `nowrap`. Value SF Pro **Regular 12**, leading **24**,
white (bound `Color/Base/White` → `color-text-primary`); label SF Pro **Regular 12**, leading
**24**, `text/secondary` → `color-text-secondary`. Value **then** label — C-022's inline
`align=Left` order (§5).

**The 24pt band height is the pairs' line box**, shared by all four text runs; the arrows are 24×24
and centred on it. Neither the band height nor either pair's width is set — they measure their
content. The 88 and the 184 **are** set (deviation 5).

**Tokens.** `get_variable_defs` on the symbol returns exactly three: `White/20%` (#ffffff33 →
`color-white-20`, the arrows), `Color/Base/White` (#ffffff → `color-text-primary`, both values) and
`text/secondary` (#85979e → `color-text-secondary`, both labels). All three resolve to existing
rows. **This run mints no token row.**

**Flagged literals (D7):**
- **The pair type, Regular 12/24.** No token row carries it; `type-caption` is Regular 12/**14**.
  This is the **third independent component** to measure it, after C-027 LegendItem and C-022
  MetaPair (with C-030 having measured it a fourth time on the tick row it builds from C-022).
  `tokens.md`'s stated threshold was already met at two. Recommended there, not minted here, for
  the reason C-022 §2 gives: it should be settled together with `type-caption`. OQ-C-022-3.
- **The 8pt and 2pt gaps.** Recorded as measured values rather than as `space-element-gap` (8) and
  `space-chip-gap` (2). Both are hex-equal, and both are true gaps between siblings — the same
  claim C-022 §2 makes for its own 4 and 8, and carried the same way pending the one spacing
  ruling. OQ-C-022-5.
- **The 184×88 frame and its 11/32 slack.** Stated dimensions rather than tokens, and questioned
  rather than adopted — OQ-C-064-2.

## 3. Variant & state matrix

**This component has no variant axis.** Its set holds one symbol, and Figma's `Property 1=Default`
is a placeholder for an axis that was never named, not an axis with one designed value — registry
rule 6 drops it rather than carrying it into this table (§1 deviation 3).

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| — | `default` | the whole of §2 — there is no delta, because there is nothing to differ from | **consumed** — enrollment-home, the schedule span row, between two C-060 CalendarDateCards |

**On the name `default`.** The component has no axis, but it still needs one named form: that
string is the browser's variant label and the DB key its versions and comments hang off
(`preview-build.md` §3 rule 7), so leaving the cell as prose would key a timeline on a sentence.
`default` is this contract's name for the single designed form — **not** an echo of Figma's
`Property 1=Default`, whose *axis* half is the placeholder rule 6 drops (§1 deviation 3). Were the
axis real, this table would name it.

Variants not in this table may not be built without a ruling.

### 3a. Undesigned states (proposed defaults + OQ)

- **Interaction.** No pressed, hover, focus or disabled symbol, and no action in the source. The
  arrows read as decoration, not controls — they carry C-075's baked `color-white-20` fill rather
  than C-021's tappable purple, and no hit target is drawn. Proposed default: **non-interactive**,
  the whole component a read-out. This is the component-level half of the screen's
  OQ-enrollment-home-5; carried here as OQ-C-064-4.
- **Zero, singular and absent units.** Every measured string is the plural "3". Nothing in the
  source says what "1 month", "0 days", or a span with no months at all renders — whether the
  pair drops out, or reads "0 months". Proposed default: **both pairs always render, and the label
  pluralises with its value**. OQ-C-064-5.
- **Units beyond months and days.** The two pairs are structural in the source, not a list. A span
  of two years has no designed form. Proposed default: none — a longer span still reads in months.
  OQ-C-064-6.
- **Overflow.** Both runs are `nowrap` inside a **fixed** 184pt box, so a long value has nowhere to
  go. Nothing designs the behaviour. Proposed default: the box hugs its content instead of
  clipping — which is really OQ-C-064-2's question. OQ-C-064-2.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `months` | `Int` | The whole months in the span — the leading pair's value ("3") |
| `days` | `Int` | The remaining days in the span — the trailing pair's value ("3") |

`months` and `days` are the prop names the superseded §4 gave, kept verbatim. **Their type is this
run's proposal, not a source fact:** Figma carries only the rendered strings "3"/"3", and typing
them `Int` is what makes the labels the component's own rather than the caller's. If a consumer
must be able to supply the label text, that is a different contract — raised as OQ-C-064-5, which
also owns pluralisation.

**The labels "months" and "days" are not props.** They are fixed by the component's role, which is
why the row is named for the span and not for a generic pair. A component whose labels a consumer
supplies is C-022 MetaPair, which this one composes (§5).

**No `direction`, `tint` or `glyph` prop.** The two arrows are fixed at `left` and `right` and
fixed at `color-white-20`; C-075's `direction` is set by this component, not by its caller (§5a).

## 5. Composition

**Consumes:**
- **C-075 ArrowGlyph** ×2 — `direction=left` and `direction=right`, both `color-white-20`. Minted
  by this run; its contract is §5a below.
- **C-022 MetaPair** ×2 — `layout=inline`, `align=Left`, rendering Regular 12/24 with a white value
  and a `color-text-secondary` label. **With one recorded divergence:** Figma has these as local
  frames at gap **2**, where C-022 §2 measures **4** (§1 change 3, OQ-C-064-3). A build that renders
  real C-022 instances here comes out 4pt wider than the source until that is ruled on.

**Consumed by:**
- `enrollment-home` — §2 item 3, the schedule span row: **C-060 CalendarDateCard** (start) + this
  component (flex) + **C-060** (end).

### 5a. C-075 ArrowGlyph (new — minted by this run)

**Owner ruling, 2026-09-11:** asked in-run and answered *mint a new row*, over extending C-021 with
a tint prop, recording C-021 consumption with deviations, or minting two rows. Minted under the
**C-072 LinkStatusGlyph / C-074 PersonGlyph** precedent: a static vector, fill **baked into the
artwork**, no hit target, no action, no tint prop — which is exactly what these arrows are, and
exactly what C-021 GlyphButton is not.

- **Source:** instances `3836:7914` (`arrow--left`) and `3836:7916` (`arrow--right`), both 24×24,
  inside C-064's symbol `3836:7920`. Anchored on instances, as C-074's row is (`4115:31239`),
  because the run resolved the artwork rather than the icon library's own main components.
- **Geometry:** 24×24 viewBox, one path, no container and no background. The two are mirror images.
- **Fill:** `white @ 20%` (`White/20%` → `color-white-20`), baked into the exported path —
  `fill="white" fill-opacity="0.2"` — not applied by the consumer.
- **Artwork:** `assets/C-075-direction-left.svg`, `assets/C-075-direction-right.svg`.
- **Matrix:** axis `direction`, two values, **both designed and both consumed** by C-064.

| Axis | Value | Geometry | Consumption |
|---|---|---|---|
| direction | `left` | leftward arrow, `M10.5 19.5L11.5575 18.4425L5.8725 12.75H21V11.25H5.8725L11.5575 5.5575L10.5 4.5L3 12L10.5 19.5Z` | **consumed** — C-064 leading slot |
| direction | `right` | rightward arrow, the mirror | **consumed** — C-064 trailing slot |

Variants not in this table may not be built without a ruling.

- **Props:** `direction: left | right`. No tint prop — see the fill note.
- **⚠️ It shares artwork with C-021.** The `right` vector is byte-identical to
  `assets/C-021-glyph-arrow-forward.svg`'s path (`18.4297` vs `18.4298`, export rounding), and
  C-021's own export names its inner group `Arrow--right` — the same icon, drawn once in the file
  and wrapped twice. The rows differ in **fill and role**: C-021 is a 44pt tappable `color-accent`
  button; C-075 is a 24pt static `color-white-20` decoration. This is the **first real evidence on
  OQ-C-021-3**, which asked whether C-021's artwork should be tint-neutral and noted it "only
  matters once a non-purple consumer exists" — one now does. Consolidation is OQ-C-064-7, and it
  sits alongside C-072's own OQ-C-033-8 and C-074's OQ-C-038-7 ("when a glyph earns a row").
- **`left` has no C-021 counterpart.** C-021's `back` is a chevron (`M7.5 12L15 4.5…`), a different
  glyph — so this row is not wholly a duplicate of C-021 under any consolidation.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-064-1 | **No frozen snapshot on disk**, and this run had no way to make one (no Figma REST token, no export tooling in the repo). The row is specced but **not buildable** — `preview-build.md` §0.4 refuses a build with nothing to diff against. Export `assets/C-064-date-span-indicator.png` at 3×? | **Yes — blocks `/ui2-component-build C-064`** | Owner |
| OQ-C-064-2 | **Is the fixed 184×88 box designed, or authoring residue?** The content measures 162×24 and is centred, leaving 11pt horizontally and **32pt** vertically. The screen places this in a flex row between two 96×88 C-060 cards — where 88 matches the cards exactly, which argues the height IS designed, while the 32pt vertical slack argues the box is just a sheet cell. Hug the content, or keep the box? | No | Owner |
| OQ-C-064-3 | **The pairs' gap is 2; C-022's is 4.** Identical anatomy otherwise. Is C-064 consuming C-022 at a tighter gap (making gap a C-022 prop, which it is not today), or has one of the two drifted from the other? Ties into OQ-C-022-5, which holds both rows' gaps as measurements pending one spacing ruling | No | Owner |
| OQ-C-064-4 | **Interaction is undesigned** — §3a proposes non-interactive. The arrows especially read as decoration, but a span indicator flanked by arrows invites a tap. Carries the component-level half of OQ-enrollment-home-5 | No — default proposed | Owner |
| OQ-C-064-5 | **Pluralisation, zero and singular values are undesigned**, and §4's `Int` typing is this run's proposal. Does the component own its labels (and pluralise them), or does the caller supply the strings? | No — default proposed | Owner |
| OQ-C-064-6 | **No unit beyond months and days is designed.** A multi-year span has no form. §3a proposes it still reads in months | No — default proposed | Owner |
| OQ-C-064-7 | **C-075 and C-021 share one vector at two tints** (§5a). Consolidate — make C-021's artwork tint-neutral and let both rows draw from it, the path OQ-C-021-3 anticipated — or keep two rows because the roles differ (tappable purple control vs static decoration)? Sits with OQ-C-033-8 and OQ-C-038-7 | No | Owner |
