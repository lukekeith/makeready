# C-033 GroupFollowCard — a followed group's completion, in a horizontally-scrolling rail

Status: existing-modified · Specced: 2026-09-10 · Owner-designated: `/ui2-component
GroupFollowCard <set url>` with the set `3620:4662` pasted by the owner 2026-09-10 (D10 —
the owner's paste designates the SET normative; the registry previously anchored this row to
the home-dashboard frame INSTANCE `3622:5628`, which is one symbol of it). This file
**relocates** the contract from `screens/home-dashboard.md` §4 (pointer left there).

Includes sub-component **C-072 LinkStatusGlyph** (own registry row, contract in §3e below —
it is instantiated nowhere but inside this card, and its own set carries a designed state
this card cannot reach, which is OQ-C-033-3).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3620-4662
  — set `3620:4662` ("Group"), two axes (`style` × `color`), **4** symbols, each 179×228.
  Parented to the component sheet `3632:4502` at (3046, 884), so D9's sheet caveat and D10's
  owner designation both apply and agree.
- Sub-component set: `3622:5999` ("Linked", sheet @ (2920, 718)), 2 symbols → C-072.
- Frozen snapshot: `assets/C-033-group-follow-card.png` (914×1874, 2×) — captured 2026-09-10
- C-072 frozen snapshot, same capture: `assets/C-072-link-status-glyph.png`; its two vectors
  exported to `assets/C-072-link-glyph-linked.svg` · `assets/C-072-link-glyph-unlinked.svg`

**Deviations (closed list):**
1. All strings — "Group name", "9", "members", "55%", "complete" — are per-instantiation
   content, with the one exception in deviation 7.
2. The set frame is 457×937 with 20pt gutters around the symbols; the component is the
   179×228 symbol, not the frame.
3. The set is **sparse**: `Default` is drawn only at `color=Green`. `Default × Yellow` and
   `Default × Red` have no symbol (§3c, OQ-C-033-2).
4. The card's fill `#1f2124` and border `#2f363a` are **RAW hex, not variable-bound** —
   hex-equal to `color-card-background` / `color-card-border`. This is the third instance of
   the pattern `tokens.md` already records for C-034 and C-045, not a new colour.
5. **Corrects `screens/home-dashboard.md` §4's prop list**, which names `isLinked` and
   describes the mark as switching between "linked (chain)" and "unlinked (broken chain)".
   The set exposes a boolean **`showLink`** and pins its glyph to C-072 `linked=true`; the
   `linked=false` symbol is designed but is not reachable from this component (OQ-C-033-3).
6. **Corrects the same §4's completion-line rule**, which says the line is "colored by
   completion band". That holds in `No bar`, where **both** the number and its label take the
   band colour. In `Default` only the number takes it; the label renders `color-white-50`
   (§3a).
7. `Default`'s trailing label is the hard-coded string "complete" in the source, where
   `No bar` reads the `label` prop. Recorded, not designed around (§4).
8. `Default`'s C-057 bar renders its sample at `percent=80` with a 222pt fill inside a
   145pt clipped track, so the snapshot reads as fully filled. The fill length is sample
   content, not a designed value.
9. That bar's fill is the raw literal `#4deb4b` — C-057's already-recorded green anomaly
   (OQ-home-dashboard-6) — not `color-positive`.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

179×228 in every state. `radius-card` (8), 1px border `color-card-border` (deviation 4),
fill `color-card-background`, `overflow: clip`.

Padding 16 sits **inside** the 1px border, so every inset from the outer edge is 17 and the
content column is 145 — the construction C-045 §2 and C-025 §2 also use.

Root stack gap **10** — FLAGGED LITERAL: `tokens.md`'s spacing family is 16/16/8/32/4/2/24
and has no 10pt row; 10 occurs exactly once in the program, here, so D7's "per-component
literal, explicitly flagged" path applies rather than a new token row.

Two slots, top→bottom:

1. **Top** — 145 wide, **flexible**: it absorbs the whole height difference between the two
   styles (146 in `Default`, 140 in `No bar`, exactly the 6pt the Completion slot differs
   by). Internal stack gap `space-element-gap` (8):
   - **C-038 Avatar** at 64 — 64×64, `radius-circle`, image cover-cropped (the source's
     64×88 inner frame is the crop, not a size).
   - **Title** — `type-title-card` (Bold 14/20) `color-text-primary`, full content width,
     **wraps** (the source sets `word-break: break-word`, not truncation).
   - **C-072 LinkStatusGlyph** — 16×16, pinned to the slot's top-right corner (x 129, y 0).
     Rendered only when `style = No bar` **and** `showLink` (§3a).
   - Both stacks close at 92 (64 + 8 + one 20pt title line), so the slot carries 54pt
     (`Default`) / 48pt (`No bar`) of trailing slack for a wrapped title — three lines fit,
     a fourth clips against the card's `overflow: clip` (OQ-C-033-4).

2. **Completion** — 145 wide, intrinsic height. Its stack gap and its contents are the
   `style` axis (§3a); both its rows are a `flex` pair with `space-meta-gap` (4) between the
   number and its label, typed `type-page-title` (Regular 14/20).

   *(`type-page-title` is the program's Regular 14/20 row. `tokens.md` flags it against
   `type-body` and `type-input` as a consolidation candidate; this component adds a fourth
   consumer to that count and no new opinion.)*

Both stacks close on 228 exactly:

```
Default   17 + 146 + 10 + 38 + 17 = 228      (Completion = bar 2 + 16 + row 20)
No bar    17 + 140 + 10 + 44 + 17 = 228      (Completion = row 20 + 4 + row 20)
```

## 3. Variant & state matrix

### 3a. `style` (2 designed)

| `style` | Completion slot | Link glyph | Colour rule |
|---|---|---|---|
| `Default` | stack gap 16: **C-057 PercentBar** (`style=Thin`, `aligned=Left`, 145×2) above one completion row. Slot 145×38; Top slot 146 | **never rendered** — the source gates it on `No bar`, so `showLink` has no effect here | number takes the band colour; label is `color-white-50`, and is the literal "complete" (deviation 7) |
| `No bar` | stack gap `space-meta-gap` (4): members row above completion row. Slot 145×44; Top slot 140 | rendered when `showLink` | **both** number and label take the band colour |

The members row ("9" `color-text-primary` + "members" `color-white-50`) exists only in
`No bar`.

### 3b. `color` (3 designed) — the completion band

| `color` | Token | Consumption |
|---|---|---|
| `Green` | `color-positive` (#6cff73) | consumed — home-dashboard |
| `Yellow` | `color-highlight` (#f4ff76) | consumed — home-dashboard |
| `Red` | `color-negative` (#ff4759) | consumed — home-dashboard |

**The band is an independent prop, not a function of `percent`.** All four symbols render
"55%" and differ only in colour. That settles the independence half of
**OQ-home-dashboard-3**; the threshold half stays open there. (Same evidence shape as
OQ-C-025-4 for C-062 PercentDisc, and it points the same way.)

### 3c. Combination coverage

| | `Green` | `Yellow` | `Red` |
|---|---|---|---|
| `Default` | designed — **unconsumed** (OQ-C-033-1) | **not designed** | **not designed** |
| `No bar` | consumed | consumed | consumed |

`Default × Yellow` and `Default × Red` may not be built without a ruling (OQ-C-033-2) —
the more so because `Default`'s only coloured element besides the number is the C-057 bar,
whose fill is a fixed literal (deviation 9) and therefore does not follow the band today.

### 3d. `showLink` (boolean prop, default true)

`true` is consumed. `false` is a designed capability of the source with **no drawn symbol**
— it renders as the glyph's absence. See OQ-C-033-3 for what "absent" is supposed to mean
next to C-072's designed `linked=false`.

### 3e. C-072 LinkStatusGlyph — `linked` (2 designed)

16×16 box in both states; the fill is **baked into the artwork**, not tinted by the
consumer.

| `linked` | Artwork | Fill | Consumption |
|---|---|---|---|
| `true` | two interlocking chain links, 15.02×11.5 in the 16×16 box | `color-text-secondary` | consumed — C-033 `No bar` pins this symbol |
| `false` | a broken chain with radiating ticks, 14×14 in the 16×16 box | `color-brand-highlight` (#c5fff8) | designed, **unreachable from C-033** (OQ-C-033-3) |

`color-brand-highlight` on `linked=false` is this token's first consumption in the program.

### 3f. Interaction states

`pressed` / `selected` / `disabled` — **undesigned**. **Proposed default + OQ-C-033-6:** no
pressed or selected treatment is added. The card is tappable (`onTap`, §4) but no frame
designs the feedback, so none is invented.

Variants not in this table may not be built without a ruling.

## 4. Props contract

**C-033 GroupFollowCard**

| Prop | Type | Purpose |
|---|---|---|
| `style` | `default \| noBar` | §3a — selects the Completion slot's contents and the link glyph's gate |
| `color` | `green \| yellow \| red` | §3b — the completion band; independent of `percent` |
| `title` | `String` | group name; wraps (§2) |
| `photoURL` | `String?` | → **C-038 Avatar** at 64 |
| `members` | `String` | `noBar` only — the members-row number |
| `percent` | `String` | the completion number |
| `label` | `String` | `noBar` only — the word after `percent`; `default` hard-codes "complete" (deviation 7) |
| `showLink` | `Bool` | `noBar` only — §3d |
| `progress` | `Double` | `default` only — → **C-057 PercentBar** |
| `onTap` | action | carried from `home-dashboard` §4; no render effect, no designed pressed state (§3f) |

**C-072 LinkStatusGlyph:** `linked: Bool` — the two values of §3e.

**Names changed from `screens/home-dashboard.md` §4**, which this file supersedes:
`name` → `title` · `memberCount` → `members` · `completionPercent` → `percent` + `color`
(the band split out per §3b) · `isLinked` → `showLink` (deviation 5). The source types
`members` and `percent` as **display strings**, where §4 typed them numerically —
OQ-C-033-5.

`progress` and the bar's geometry delegate to **C-057 PercentBar**; that row owns the
`style`/`aligned` set and it is not restated here. The avatar's initials fallback is
**C-038 Avatar's**, and no symbol in this set draws it (OQ-C-033-7).

## 5. Composition

- **Consumes:** C-038 Avatar (at 64) · C-057 PercentBar (`Thin` / `Left`, `default` only) ·
  C-072 LinkStatusGlyph (`linked=true`, `noBar` only).
- **Consumed by:** home-dashboard (Following rails) — `No bar` at all three colours.
  C-072 is consumed by C-033 alone.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-033-1 | `Default` — the bar-and-no-members form — is designed but consumed by **no** screen; home-dashboard takes `No bar` at all three colours. Future surface, or superseded and due for removal from the set? (Same shape as OQ-C-025-1.) | No | owner |
| OQ-C-033-2 | The set is sparse: `Default` exists only in Green. Does `Default` carry the `color` axis at all — and if so, does its C-057 bar take the band colour, given that fill is the fixed `#4deb4b` literal (deviation 9)? | No — blocks a faithful build of `Default` at Yellow/Red only | owner |
| OQ-C-033-3 | C-072 designs `linked=false` (broken chain, `color-brand-highlight`), but C-033 exposes only `showLink` and pins `linked=true`. Is the card meant to have **three** link states (linked / unlinked / absent), or is absence the unlinked state and `linked=false` artwork for a different consumer? `home-dashboard` §4 assumed the former and that assumption is what deviation 5 corrects | No | owner |
| OQ-C-033-4 | The title wraps with no stated limit. Three lines fit the Top slot's slack; a fourth clips against the card's `overflow: clip`. Max lines, or tail truncation? | No | owner |
| OQ-C-033-5 | `members` and `percent` are display **strings** in the source ("9", "55%"), where `home-dashboard` §4 typed them `memberCount` / `completionPercent` numerically. Does the component take formatted strings, or numbers it formats? | No | owner |
| OQ-C-033-6 | Pressed / selected / disabled are undesigned though the card is tappable — proposed default in §3f is to add none | No | owner |
| OQ-C-033-7 | The avatar's initials fallback is asserted by `home-dashboard` §4 ("per program convention") and drawn by no symbol in this set. Confirm it is C-038's fallback and not a C-033-specific empty state | No | owner |
| OQ-C-033-8 | **C-072's name and family.** `-Glyph` is not one of the registry's sanctioned suffixes (`-Chip/-Card/-Row/-Bar/-Badge/-Header/-Overlay/-Button/-Chart`); a static 16pt indicator matches none of them (`-Badge` is a pill, taken by C-053 StatusBadge). Add `-Glyph` to the family list, or rename? Related: should C-072 and **C-021 GlyphButton** consolidate into one glyph-artwork provider that a button row and a static row both consume — the "value sets have one owner" shape `preview-build.md` §3 rule 5 already uses for C-021's nine glyphs? | No | owner |
