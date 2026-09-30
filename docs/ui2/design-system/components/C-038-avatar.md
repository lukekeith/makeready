# C-038 Avatar — a person's or group's circular image, and what stands in when there isn't one

Status: existing-modified · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-038 <url>`
with `147:1513` pasted by the owner 2026-09-11, then **redirected by the owner in the same run**
to `4115:31205` ("Avatar v2") — the set this contract is written from (D10). This file
**relocates** the contract from `screens/members-home.md` §4 (pointer left there), which carried
three lines of prose, and folds in the size amendments made by `members-profile`, `invite-home`,
`groups-home` and `enrollments-home`.

**Closed change list vs. the superseded members-home §4 contract:**
1. The normative source moves from the single symbol `147:1513` to the set `4115:31205`.
2. The initials fallback stops being an asserted "program convention" and becomes a **designed
   state** with measured geometry — which answers **OQ-C-033-7**.
2b. **Correction.** members-home §4 gave the initials ground as `color-card-background`
   (#1f2124). The designed state fills **#242a3e** — a different colour, and not one the
   program had a token for. Every spec that inherited the old claim is wrong about it; the
   token minted in §2 is the fix.
3. A **third state, `Unknown user`, is recorded for the first time**; it is designed-unconsumed.
4. `size` is demoted from a variant list to a consumer-applied scale (§3b) — the set designs one
   diameter.
5. One token is minted: `color-avatar-fallback` (§2).
6. One sub-component row is minted: **C-074 PersonGlyph** (§5a).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=4115-31205
  — frame `4115:31205` ("Avatar v2"), 80×200, **one axis (`state`), 3 symbols**, ingested
  2026-09-11:

  | Figma symbol | node | size |
  |---|---|---|
  | `state=Has photo` | `4115:31206` | 40×40 |
  | `state=Initials` | `4115:31234` | 40×40 |
  | `state=Unknown user` | `4115:31237` | 40×40 |

- **Predecessor set:** `147:1514` ("Avatar"), 80×980, **16** symbols on a `Person` axis — 14
  sample photographs (`Person=Barry Allen`, `Person=Tony Stark`, …) plus `Person=Initials`
  (`379:5133`) and `Person=Unknown user` (`440:17237`). The registry cited one of its photo
  symbols (`147:1513`) as C-038's ref until this run. `Avatar v2` is the **same artwork**
  re-cut onto a proper state axis — verified byte-identical: both sets serve the fallback
  circle from asset `598cd908…svg` and the sample photograph from `19e1347d…png`. The
  predecessor is superseded, not deleted; it is recorded here so a reader who follows the old
  ref lands somewhere.
- **Not on the component sheet.** The sheet (`3632:4502`, D9) carries no Avatar entry — checked
  by full metadata dump 2026-09-11. This component has only ever lived at its own node, which is
  why the owner's paste is what designates it (D10).
- Frozen snapshot: `assets/C-038-avatar.png` — ⚠️ **PARTIAL (2026-09-10).** The file on disk
  holds only the **`Has photo`** symbol — the single node the registry used to cite — and shows
  neither fallback state. **A full-set export is pending:** select frame `4115:31205` in the
  Figma desktop app → Export @3x PNG → overwrite `assets/C-038-avatar.png`. Until it lands,
  `/ui2-component-build C-038` has no reference for two of the three states and must not claim
  to have diffed them.

**Deviations (closed list):**
1. The initials string "TD" and the sample photograph are per-instantiation content, not
   contract.
2. The set designs exactly **one diameter, 40**. Consumers instance at 32 / 54 / 64 / 164 —
   those are a consumer-applied scale, not variants (§3b).
3. The predecessor set's 14 extra symbols are **sample content on a content axis**
   (`Person=<a person's name>`), not states. Reading them as a variant matrix would mint 14
   variants of one state.
4. The `Unknown user` glyph's artwork carries a 24×24 bounding `rect` at `fill-opacity: 0.01` —
   an export artifact of the source icon component, not a designed wash.
5. Both fallback states' ellipse fills bind the Figma variable named **`Border`** although it is
   a fill, not a stroke (§2, OQ-C-038-1).
6. The initials text draws SF Pro Text **Bold** 17/22 by overriding the weight of the bound
   `Body` variable (Regular 17/22). The binding is to `Body`; the rendered weight is Bold.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A circle, and one of three things inside it. There is no border, no ring, no shadow and no
badge slot in any symbol.

| Part | Geometry |
|---|---|
| Root | 40×40 circle, `radius-circle`. No stroke in any state |
| Photo (`Has photo`) | the image fills the circle edge-to-edge, cover-cropped |
| Ground (both fallbacks) | the same circle filled `color-avatar-fallback` |
| Initials (`Initials`) | text centred on both axes — measured box 24×22 at (8, 9), whose centre is (20, 20). SF Pro Text **Bold 17 / 22**, `color-text-primary` |
| Glyph (`Unknown user`) | **C-074 PersonGlyph** 24×24 at (8, 8) — inset 8 on every side, i.e. **60% of the diameter**, centred |

**New token.** `color-avatar-fallback` = **#242a3e**, from the Figma variable `Border`. It is a
navy and is distinct from all three greys the program already calls borders (`layout/border`
#2f3639, `card/border` #2f363a, `nav/border` #525d60), so it consolidates with none of them. It
is named for its role because the variable's name contradicts its binding — see OQ-C-038-1.

**Flagged literals (D7):**
- The initials' **Bold 17 / 22** has no token row. It is the exact-weight sibling of
  `type-body-lg` (SF Pro Text Regular 17/22) and the program's **first Bold-17**. Minting
  `type-body-lg-bold` off one site would pre-empt the Bold-leading ruling that
  `type-title-card` (Bold 14/20), `type-nav-label` (Bold 14/16) and C-046's Bold 14/14 are
  already queued behind, so it is carried as a per-component literal — OQ-C-038-4.
- The glyph's **24pt size / 8pt inset** are recorded as the **60% ratio** above rather than as
  spacing tokens. `space-element-gap` (8) and `space-row-gap` (24) are hex-equal but are gaps
  between siblings, not an inset inside a circle; citing them would assert that this inset and a
  table's row rhythm are one decision. The ratio is measured at the single designed diameter —
  OQ-C-038-2 asks whether it holds at the others.

**No other new tokens.** `get_variable_defs` on the set returns `Border`, `White/100%`,
`Transparent` and `Body`; the last three are already bound. The fallback glyph is white at
**50%** → `color-white-50` (read out of the exported vector's `opacity="0.5"`, not eyeballed).

## 3. Variant & state matrix

### 3a. The closed matrix

| `state` | Inside the circle | Consumption |
|---|---|---|
| `Has photo` | the image, cover-cropped | **consumed** — members-home (32, in C-037) · members-profile (164) · groups-home (64, in C-037) · enrollments-home (40, in C-058) · invite-home (54) · C-033 GroupFollowCard (64) |
| `Initials` | Bold 17/22 initials on `color-avatar-fallback` | **consumed** — members-home §4 and members-profile both specify the fallback; **this run is the first time it is DESIGNED rather than asserted**, which answers OQ-C-033-7 |
| `Unknown user` | C-074 PersonGlyph at 60%, on `color-avatar-fallback` | **designed-unconsumed** — no screen spec reaches it (OQ-C-038-5) |

Variants not in this table may not be built without a ruling.

### 3b. Size is not a variant

The set designs one diameter, **40**. The four other sizes on file — 32 (members-home rows), 54
(invite-home linked-member block), 64 (groups-home, C-033) and 164 (members-profile identity
block) — were recorded by screen runs measuring *instances*, and the registry listed them as
though the component designed five sizes. It does not: nothing in the anatomy changes with
diameter, so they are one symbol at five scales.

What that leaves open is **how the contents scale**, since both fallbacks contain a fixed-size
child measured only at 40 — OQ-C-038-2.

### 3c. Undesigned states (proposed defaults + OQ)

None of the following is designed; none of it is fact.

- **Photo load failure.** Proposed default: fall through the same chain the state derivation
  uses (§4) — initials if there are any, otherwise `Unknown user`. Legacy `Avatar.swift` does
  exactly this. OQ-C-038-3.
- **Group fallbacks.** Three consumers put a *group* photo in this component. A group has
  neither initials nor an "unknown user". Proposed default: none offered — this needs a ruling,
  not a guess. OQ-C-038-5.
- **Interaction.** No pressed, focused, selected or disabled symbol exists, and the set carries
  no action prop. Proposed default: the avatar is **not** the tap target — its container is
  (evidence: C-037 rows tap as a row). OQ-C-038-6.
- **Badge / presence / status ring.** Not designed and not proposed; the component has no slot
  for one.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `state` | `Has photo \| Initials \| Unknown user` | The Figma axis (§3a). Normally derived rather than passed — see below |
| `imageURL` | `URL?` | The photo. Fills the circle cover-cropped in `Has photo` |
| `initials` | `String?` | The `Initials` string. Sample is 2 characters, uppercase ("TD") — count and casing are OQ-C-038-3 |
| `size` | `CGFloat` | The diameter. Not a variant (§3b); consumers pass 32 / 40 / 54 / 64 / 164 |

**State derivation (proposed default, not designed).** No source states how a consumer picks the
state, and every consumer passes content rather than a state. The proposed rule is the legacy
chain, which `iphone/MakeReady/Components/Display/Avatar.swift` already implements and which the
three designed states line up with one-for-one:

```
imageURL resolves        → Has photo
else initials non-empty  → Initials
else                     → Unknown user
```

`state` stays in this table as an explicit prop because it is the Figma axis and because a
preview fixture can only set props — a state reachable solely by derivation is uncapturable.
Whether the shipped component should expose it as an override, or derive it only, is
OQ-C-038-3.

## 5. Composition

**Consumes:** **C-074 PersonGlyph** — in `Unknown user` only.

**Consumed by:** `members-home` (32, inside C-037) · `members-profile` (164) · `groups-home`
(64, inside C-037) · `enrollments-home` (40, inside C-058) · `invite-home` (54) · **C-033
GroupFollowCard** (64) · **C-037 ListResultRow** · **C-058 GroupSectionHeader**.

**Anticipated:** every future person- or group-bearing row. This is a program primitive.

### 5a. C-074 PersonGlyph — contract

A static filled-person vector. **Not a button** — no hit target, no action, no tint prop; it is
drawn, not pressed. Same shape of row as C-072 LinkStatusGlyph, and recorded the same way.

- **Source:** the `User--filled` instance `4115:31239` inside `state=Unknown user`. Vector
  exported to `assets/C-074-person-glyph.svg`.
- **Geometry:** 24×24 at the designed diameter. Head + shoulders, centred, no frame.
- **Colour:** white at **50% opacity** (`color-white-50`) — baked into the artwork as a group
  `opacity="0.5"`, not consumer-tinted.
- **Variants:** one. No states are designed.
- **Consumed by:** C-038 (`Unknown user`) only.
- **Consolidation:** the same `user--filled` artwork family appears in the sheet's un-specced
  "Search type" set (`3561:34200`) at 18×18 on a `#2f363a` r16 chip — a different export of the
  same icon, not this row. With C-021 GlyphButton and C-072 LinkStatusGlyph, the program now has
  three glyph rows and no rule for when a glyph earns one. OQ-C-038-7.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-038-1 | The fallback ground binds the Figma variable **`Border`** but uses it as a **fill**. `color-avatar-fallback` is named for the role and scoped to this component's use. Does `Border` have other bindings in the file? If it grounds anything else, the token should be renamed wider in place; if it does not, the Figma variable is misnamed and should be renamed there | No | Owner |
| OQ-C-038-2 | **How do the contents scale?** The set designs one diameter (40), where the initials are 17/22 (42.5% of the diameter) and the glyph is 24 (60%). Consumers instance at 32 / 54 / 64 / **164** — at 164 a fixed 17pt initial would be a speck. Proposed default: both scale proportionally by those ratios, matching legacy `Avatar.swift`'s per-size `fontSize` table. Confirm, or design per-size values | **A build must pick one** | Owner |
| OQ-C-038-3 | **State derivation, photo failure, and initials format.** §4's chain is proposed from the legacy implementation, not designed. Confirm (a) the chain, (b) that a photo which fails to load falls through it, (c) that initials are 2 characters uppercased, and (d) whether `state` is an override prop or derived-only | No — §4 states the proposal | Owner |
| OQ-C-038-4 | The initials' **Bold 17 / 22** is the program's first Bold-17 and the exact-weight sibling of `type-body-lg`. Mint `type-body-lg-bold`, or keep the flagged literal? This belongs with the pending Bold-leading ruling (Bold 14/20 vs 14/16 vs C-046's 14/14) — one typography decision should settle all of them | No | Owner |
| OQ-C-038-5 | **Groups use this component, and the fallbacks are person-shaped.** `groups-home`, `C-058` and `C-033` all put a group photo here; a group has no initials and no "unknown user". Meanwhile `Unknown user` is designed and consumed by nothing. Is `Unknown user` the group empty state, the missing-member state, both, or dead? | No | Owner |
| OQ-C-038-6 | No **interactive** state is designed (no pressed / disabled) and the set has no action prop. §3c proposes the avatar is never the tap target — but `members-profile`'s 164 identity avatar is the obvious place for a change-photo affordance. Confirm, or design it | No | Owner |
| OQ-C-038-7 | **When does a glyph earn a registry row?** C-074 is the third glyph row (C-021 GlyphButton, C-072 LinkStatusGlyph), minted under C-072's precedent because D6 admits no unrowed element. The same `user--filled` artwork also sits in the sheet's "Search type" set at a different size on a chip. A rule — or a consolidated glyph row with a `glyph` value set — would stop the count growing one component at a time | No | Owner |
