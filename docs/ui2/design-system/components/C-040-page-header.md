# C-040 PageHeader — the 56pt bar at the top of a pushed page

Status: new · Specced: 2026-09-01 (members-profile §4) · Set correction: 2026-09-01
(study-program-home §4 amendment) · Full-set contract: 2026-09-05 · Owner-designated:
`/ui2-component page title <url>` pointing at set `3313:7615`, with the owner's
presentation statement recorded in §2 (D10).
This file **relocates** the contract from `screens/members-profile.md` §4 and
`screens/study-program-home.md` §4 (pointers left in both).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3313-7615
  — set `3313:7615` ("Header"), **3 symbols on one variant axis** `style {Default,
  Text buttons, Two icons}` (`3313:7614` / `3313:8252` / `3524:29584`), plus **two boolean
  component properties** `showTitle` and `showIcons` (both default true) and a text
  property `title`.
- Frozen snapshot: `assets/C-040-page-header.png` — captured 2026-09-05 (whole set, @2×).
- The registry originally cited `3524:29584` alone; that node is the `Two icons` symbol
  *inside* this set (correction already landed 2026-09-01 in study-program-home §4, carried
  here).

**Deviations (closed list):**

0. **Glyph slots render beyond what the set designs.** The Figma set designs three symbols
   (`3313:7614` Default, `3313:8252` Text buttons, `3524:29584` Two icons) and exactly one
   glyph combination each — `back` leading, `settings` / `export + settings` trailing
   (re-verified 2026-09-07). `leadingGlyph` and `rightButtons` are owner-ruled props, so a
   render carrying any other glyph has **no counterpart in the frozen snapshot** and the
   snapshot is not evidence for or against it. The designed combinations remain the ones
   §3's matrix pins.
1. "Title" is sample content (a prop). "Cancel" and "Done" are **not** props — they are
   flat text layers, so §3 contracts them as the designed labels of `Text buttons`;
   relabelling is undesigned (OQ-C-040-4).
2. Master symbols are 398pt wide; consumers are width-driven — full device width (408 in
   every specced consumer).
3. The title is placed at `left: calc(50% + 0.5px)`; contracted as optically centred.
4. The title's vertical placement differs by symbol: `Default` centres correctly
   (`top: calc(50% − 10px)` against a 20pt line box) while `Text buttons` and `Two icons`
   sit 2pt low (`− 8px`). Contracted as vertically centred in all three.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A 56pt row — `padding: 16`, `flex-direction: row`, `align-items: center`,
`justify-content: space-between`, fill `color-transparent` (no background, no bottom
hairline; the page ground shows through):

- **Leading slot** — `Default` and `Two icons`: C-021 GlyphButton `back` (chevron-left),
  24×24 visual at leading 16. `Text buttons`: the "Cancel" label instead.
- **Title** — absolutely placed, optically centred, single line (no wrap in the source):
  `type-page-title` (SF Pro Regular 14 / 20) in `color-text-primary`. Gated by `showTitle`.
- **Trailing slot** — per style:
  - `Default`: C-021 `settings`, 24×24. **Not gated by `showIcons`** (source behaviour;
    OQ-C-040-1).
  - `Text buttons`: "Done" in `type-nav-action` (SF Pro Regular 14 / 24, tracking +0.56),
    `color-accent`; "Cancel" uses the same type in `color-white-50`.
  - `Two icons`: a `gap: 24` group (`3524:29588`) of C-021 `export` + C-021 `settings`,
    24×24 each. Gated by `showIcons`.

Height arithmetic: 16 + 24 + 16 = 56. No flagged literals — every colour in the set is
variable-bound (`Purple/100%`, `White/50%`, `Transparent`) except the title's plain white,
which is hex-equal to `color-text-primary`.

**Presentation (owner-stated 2026-09-05).** This bar is the chrome of a **pushed page** —
program home and its siblings **slide in from the trailing edge and sit on top of the
current page**, rather than replacing it or presenting as a sheet. Consequences the
contract fixes: the page below the bar is the pushed page's own scroll surface; the system
status bar sits above it; **C-019 TopNav is absent** on these pages (the two are mutually
exclusive — §5); and the back affordance pops the pushed page, restoring the caller
underneath. The transition itself (duration, curve, interactive edge-swipe) is **shell
chrome, not this component** — it has no Figma source yet and no `motion-*` tokens
(OQ-C-040-2).

## 3. Variant & state matrix

`style` × `showTitle` × `showIcons`. `showIcons` is only honoured by `Two icons`
(OQ-C-040-1), so it is `n/a` elsewhere.

| `style` | `showTitle` | `showIcons` | Renders | Consumption |
|---|---|---|---|---|
| Default | true | n/a | back · title · settings | designed-unconsumed |
| Default | false | n/a | back · settings | designed-unconsumed |
| Text buttons | true | n/a | Cancel · title · Done | designed-unconsumed |
| Text buttons | false | n/a | Cancel · Done | designed-unconsumed |
| Two icons | true | true | back · title · export + settings | **consumed** — study-program-home |
| Two icons | true | false | back · title | **consumed** — members-profile, shared-edit-field, enrollment-home, invite-home, create-study-program |
| Two icons | false | true | back · export + settings | designed-unconsumed |
| Two icons | false | false | back only | designed-unconsumed |
| scrolled / elevated | — undesigned | | | proposed default + OQ-C-040-3: no change — the bar stays transparent with content scrolling under it, since no background, blur or hairline is designed |
| long title | — undesigned | | | proposed default + OQ-C-040-5: single line, tail-truncated with an ellipsis, never wrapping to a second line or shrinking the 56pt bar |
| pressed / disabled buttons | — undesigned | | | owned by C-021, undesigned there too — no proposal made here |

Note for builders: **"back + title, nothing else" is `Two icons` with `showIcons=false`,
not `Default`** — `Default`'s settings icon cannot be switched off. Five of the six
consumers do exactly this (shared-edit-field measured and recorded it on 2026-09-02).

Variants not in this table may not be built without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `style` | `default \| textButtons \| twoIcons` | the variant axis |
| `title` | `String?` | centred title; `showTitle` in Figma is `title != nil` |
| `showTitle` | `Bool` | source-faithful gate for the title (collapses to `title != nil`) |
| `showIcons` | `Bool` | gates the trailing group — **`twoIcons` only** |
| `leadingGlyph` | `C-021 glyph` | the glyph in the leading slot. Designed: `back` (all three styles that show one) |
| `rightButtons` | `[C-021 glyph]` | the trailing glyphs, in order. Designed: `[settings]` for `default`, `[export, settings]` for `twoIcons` |
| `onLeading` | `() -> Void` | leading slot tap — replaces `onBack` (2026-09-07) |
| `onRightButton` | `(glyph) -> Void` | trailing tap, receiving WHICH glyph was tapped — replaces `onExport` / `onSettings` (2026-09-07) |
| `onCancel`, `onDone` | `() -> Void` | `textButtons` only — labelled actions, not glyph slots, so they are unchanged |

**Glyph slots are prop-driven (owner ruling 2026-09-07, resolving OQ-C-040-6).** Both slots
take any of C-021's nine glyphs, and the value set is **delegated** to that contract rather
than restated here — add a glyph to C-021 §3 and this component gains it with no edit
(`preview-build.md` §3 rule 5).

The action shape follows from that: a slot whose glyph is a free prop cannot keep a
glyph-named callback, because `onExport` is a lie the moment the slot holds `calendar`. One
handler per slot, with the trailing one told which glyph was tapped. A `(glyph, action)`
pair per slot was considered and **rejected**: a pair is not a delegable type, so the prop
would lose its resolved value set — and therefore the browser's glyph picker — and a closure
cannot be expressed in a capture fixture at all.

## 5. Composition

- **Consumes:** C-021 GlyphButton — `back`, `export`, `settings`, all rendered at 24pt
  visual inside the 56pt bar. C-021's row states a 44pt hit target; this bar gives the
  glyph 16pt of padding on the outer side only, so the realised target is undesigned
  (OQ-C-040-7, the same tension C-069 raised with its 40pt slot).
- **Anatomy, not components:** the "Cancel" / "Done" labels. They are **not** C-049
  LinkButton (that row is Semibold 14 with a 0.5px underline; these are Regular 14 with
  +0.56 tracking and no underline). If a screen ever needs them outside this bar, that is a
  mint, not a reuse.
- **Consumed by:** members-profile, study-program-home, shared-edit-field,
  enrollment-home, invite-home, create-study-program. Anticipated: every future pushed
  page (program home per the owner's §2 statement, and the rest of the detail tree).
- **Mutually exclusive with C-019 TopNav:** C-019 is the shell's tab row on root pages;
  this bar is the chrome of a page pushed on top of them. No specced screen renders both.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-040-1 | `showIcons` does not gate `Default`'s settings icon, which is why every "back + title" consumer reaches for `Two icons` + `showIcons=false` instead. Fix the boolean in Figma, or retire `Default` as redundant? | No — §3 records the source as-is | owner (Figma cleanup) |
| OQ-C-040-2 | The push transition (slide-in from the trailing edge, over the current page) has no Figma source and no `motion-*` tokens. Which spec owns it — a shell spec alongside `shell-topnav`, or the first consuming build suite? The legacy managed-page chrome in `docs/parity/` carries measured timings that the owner may adopt or reject; they are **not** imported here (D2 forbids blending legacy UI into 2.0) | No for this contract; yes for the first pushed-page build | owner |
| OQ-C-040-3 | Scroll behaviour: does the bar stay transparent with content passing under it (§3 proposal), or gain a background/blur/hairline once scrolled? | No | owner |
| OQ-C-040-4 | `Text buttons`: "Cancel"/"Done" are flat text, so the labels are fixed by design. Should they become text properties (e.g. "Discard"/"Save")? | No — the variant is unconsumed | owner |
| OQ-C-040-5 | Long-title overflow is undesigned — proposed default in §3 (single line, tail ellipsis) | No | owner |
| ~~OQ-C-040-6~~ | **RESOLVED 2026-09-07 (owner).** `rightButtons` is no longer closed to `[export, settings]`: both glyph slots take any C-021 glyph, delegated to that contract. Recorded in §4 and §1 deviation 0 | — | — |
| OQ-C-040-8 | The action shape that follows from prop-driven glyphs — `onLeading` plus `onRightButton(glyph)`, replacing `onBack`/`onExport`/`onSettings` — was **recommended by the agent and adopted by owner delegation** on 2026-09-07, not drawn from any design. The alternative (a `(glyph, action)` pair per slot) was rejected only because a pair cannot be a delegated type and so loses the picker. Confirm, or take the pair and accept plain text fields for glyphs | No | Owner |
| OQ-C-040-7 | Realised hit target for the 24pt glyphs in a 56pt bar (C-021 states 44pt; C-069 raised the same question for its 40pt slot) — one ruling should cover all three | No | owner |
