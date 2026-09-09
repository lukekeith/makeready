# C-021 GlyphButton — the program's single-glyph tappable control

Status: new · Specced: 2026-09-07 · Owner-designated: `/ui2-component GlyphButton <set url>`
— owner pasted the set link to obtain the full glyph inventory and its **vector artwork**,
so C-040's icon slots can become prop-driven and the capture browser can preview them
(D10; designation makes the set normative per D9's refinement).

**Contract relocated here 2026-09-07** from `../../screens/home-dashboard.md` §4 (which
carried a 3-glyph closed list: `plus`, `arrowRight`, `ellipsis`) and the
`../../screens/members-profile.md` §4 amendment (which identified the set and named all
nine). Both are superseded by this file; the older glyph names are carried forward as an
alias table in §3.

## 1. Normative source

- Variant set **"Button"** — node `3499:27547` (component sheet),
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3499-27547
  — a 64×416 frame holding **nine** 24×24 symbols on a single `button` axis, laid out at
  20pt padding and a **44pt vertical pitch**:

  | Glyph | Symbol node | Figma layer | y |
  |---|---|---|---|
  | `export` | `3499:27546` | `button=Export` | 20 |
  | `settings` | `3499:27548` | `button=Settings` | 64 |
  | `back` | `3499:27558` | `button=Back` | 108 |
  | `add` | `3499:27601` | `button=Add` | 152 |
  | `send` | `3499:27615` | `button=Send` | 196 |
  | `arrow-forward` | `3516:29142` | `button=Arrow forward` | 240 |
  | `three-dots` | `3622:5809` | `button=Three dots` | 284 |
  | `search` | `3767:11504` | `button=Search` | 328 |
  | `calendar` | `3836:7805` | `button=Calendar` | 372 |

- Frozen snapshot: `assets/C-021-glyph-button.png` (whole set, 64×416, captured 2026-09-07).
- **Vector artwork (new this run):** each glyph is exported to
  `assets/C-021-glyph-<glyph>.svg`, 24×24 viewBox, fill `#6c47ff` (= `color-accent`).
  These are the first 2.0 glyph assets on disk; before this run the artwork existed only
  in Figma, which is why `UI2Preview/PageHeader.swift` substituted SF Symbols and flagged
  the substitution in its header.

**Deviations (closed list):**

1. **The exported SVGs are trimmed to the glyph subtree.** Figma's export wraps each
   symbol in page furniture that is not part of the icon: a 24×24 `#1E1E1E` canvas rect,
   the design file's full-page `#030405` background path (spanning x −3275…6191), and the
   parent frame's dashed `#8A38F5` annotation border. Each saved asset keeps only the
   `<g id="button=…">` subtree, re-wrapped in a 24×24 `viewBox`. The glyph geometry itself
   is byte-identical to the export.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A single vector glyph, nothing else — no label, no container, no background.

- **Visual size:** 24×24 (`assets/C-021-glyph-*.svg` viewBox; every symbol in the set).
- **Tint:** `color-accent` (`Purple/100%` #6c47ff) — the only colour any glyph uses. The
  exported assets carry the hex directly; a consumer applying the token re-tints the whole
  path set.
- **Background:** none — `color-transparent` (`Transparent` #ffffff00 is the set's only
  other bound variable).
- **Hit target:** 44pt minimum, extending **beyond** the 24pt visual bounds. Carried
  forward from the home-dashboard §4 contract and corroborated by the sheet's own 44pt
  vertical pitch between symbols. Consumers that render the glyph in a smaller slot are
  tracked in §6 (OQ-C-021-2).

No new tokens; no flagged literals — every value here is a token or a stated dimension.

## 3. Variant & state matrix

The `button` axis is the only designed axis. All nine values are drawn; the set designs no
interaction state.

| Axis | Value | Geometry delta | Consumption |
|---|---|---|---|
| button | `export` | tray + upward arrow (3 purple paths) | **consumed** — C-040 (`Two icons` right slot) → study-program-home |
| button | `settings` | gear | **consumed** — C-040 (`Default` + `Two icons` right slot) → study-program-home |
| button | `back` | chevron-left | **consumed** — C-040 (leading slot) → members-profile, shared-edit-field, enrollment-home, study-program-home |
| button | `add` | plus | **consumed** — home-dashboard + study-program-home section headers; C-069 NavTabButton's 40pt expanded slot (2026-09-05) |
| button | `send` | paper plane | **designed-unconsumed** — no screen spec renders it |
| button | `arrow-forward` | rightward arrow | **consumed** — home-dashboard, enrollments-home |
| button | `three-dots` | horizontal ellipsis | **consumed** — home-dashboard |
| button | `search` | magnifier | **designed-unconsumed** — no screen renders it. C-034 SearchField is *not* a consumer: its leading magnifier is a 12×12 non-interactive decoration (`3561:33850`) which C-034 §5 explicitly distinguishes from this 24pt tappable row (verified 2026-09-07) |
| button | `calendar` | calendar frame + two ticks | **consumed** — enrollment-home (2026-09-02) |
| — | pressed / disabled | undesigned | proposed defaults + OQ-C-021-1: pressed = system highlight on the glyph, no geometry change; **no disabled state exists** — a consumer with nothing to do omits the button rather than dimming it |

**Alias table** (older spec prose → this contract's names; `C-###` citations stay valid):
`plus` → `add` · `arrowRight` → `arrow-forward` · `ellipsis` → `three-dots`.

Variants not in this table may not be built without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `glyph` | `export / settings / back / add / send / arrow-forward / three-dots / search / calendar` | which of the nine designed vectors renders — the closed set of §3 |
| `action` | `() -> Void` | invoked on tap; carries no render effect |

**Sizing:** the glyph renders at its designed 24×24 and does not scale with its container;
the container supplies the 44pt hit target around it (§2).

## 5. Composition

- **Consumes:** no registry sub-components — a glyph is leaf vector artwork.
- **Consumed by:** C-040 PageHeader (`back`, `export`, `settings`), C-069 NavTabButton
  (`add`), and directly by home-dashboard (`add`, `arrow-forward`, `three-dots`),
  members-profile, shared-edit-field, study-program-home, enrollments-home
  (`arrow-forward`), enrollment-home (`calendar`).
- Not a sibling of C-034 SearchField's leading magnifier, which is drawn inside that
  component rather than instanced from here.

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-021-1 | `pressed` / `disabled` are undesigned. Proposed: pressed = system highlight on the glyph with no geometry change; **no disabled state at all** — a consumer with no action omits the button. Confirm, particularly the "no disabled state" half | No | Owner |
| OQ-C-021-2 | §2 states a 44pt minimum hit target, but two consumers render smaller slots: C-069 puts `add` in a **40pt** slot (OQ-C-019-3) and C-040 renders 24pt visuals in a **56pt** bar with 16pt padding, giving a 24pt tappable box unless the target is expanded (OQ-C-040-7). Is 44pt normative — making both consumers deviations — or is it a guideline the consumer may narrow? | No | Owner |
| OQ-C-021-3 | The exported assets hard-code `#6c47ff`. Should the shipped artwork be tint-neutral (`currentColor`) so a consumer can apply `color-accent` — or any future token — at the call site, or does the glyph stay purple by definition? Only matters once a non-purple consumer exists | No | Owner |
