# C-034 SearchField — the program's search input (glyph + text + clear)

Status: new · Specced: 2026-09-01 (members-home §4) · Full-set contract: 2026-09-05 ·
Owner-designated: `/ui2-component search input <url>` pointing at set `3561:33795` (D10).
This file **relocates** the contract from `screens/members-home.md` §4 (pointer left there)
and **corrects its normative source** — see §1.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3561-33795
  — set `3561:33795` ("Search"), **3 symbols on one axis**: `state {Default, Focus,
  Has value}`. Symbols `3561:33794` / `3561:33796` / `3561:33803`.
- Frozen snapshot: `assets/C-034-search-field.png` — captured 2026-09-05 (whole set, @2×).
- Frame instance verified: `3668:7387` (members-home header) is an instance of this set —
  it carries the search glyph.

**Source correction (2026-09-05).** The 2026-09-01 members-home run cited set
`3561:33757` as this component. That node is a *different* component that happens to also
be named "Search" on the sheet: it has **no search glyph and no clear button**, and its
axes are `state {Default, Has value, Has value + Focus} × lines {Single}` — i.e. the
`Single` column of C-045 TextInput's set (`3524:30063`), duplicated. Everything the old §4
recorded as "C-034 state coverage" was measured off that field. This contract replaces it
wholesale; `3561:33757` is not cited by any UI 2.0 row and is raised as Figma hygiene in
OQ-C-034-5.

**Deviations (closed list):**
1. "Search" (placeholder) and "Value" (entered text) are sample content — every consumer
   sets its own placeholder ("Search members" / "Search groups" / "Search enrollments").
2. Master symbols are 387pt wide; consumers are width-driven — all three specced headers
   render 408×44.
3. The container declares `padding: 16 37` while the glyph, placeholder and clear button
   are absolutely placed (16 / 36 / trailing 7) inside a fixed 44pt height with content
   clipped. §2 contracts the **placed** geometry; the declared padding is a Figma artifact.
4. In `Focus` the caret is a flow child (content row starts at 37) while the placeholder is
   absolutely placed at 36, so the two overlap by ~1pt in the source render. Contracted
   reading: one content row starting at **36**, caret leading the placeholder.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Single-line bordered field, 44pt tall, `radius-card-sm` (4), 1px border, content clipped:

- **Search glyph** — 12×12 vector (`3561:33850`), left 16, top 15. Present in **all three
  states**. Not C-021 GlyphButton: non-interactive, 12pt, no hit target (§5).
- **Content row** — left edge 36 (glyph 16 + 12 wide + 8 gap), vertically centred.
  Text `type-input` (SF Pro Regular 14 / 24).
- **Caret** (`Focus` only) — 2×24, `radius-bar` (2), `color-accent`, leading the content row.
- **Clear button** (`Has value` only) — C-039, 32×32, trailing inset 7, top 5.
- **Fill** — `color-card-background` in `Default` only; `Focus` and `Has value` have **no
  fill** (the page ground shows through).
- **Border** — `color-card-border` in `Default`; `color-text-primary` (white) in `Focus`
  and `Has value`.

Flagged literals (hex-equal to a token but not variable-bound in the source, same pattern as
C-045): fill `#1f2124` = `color-card-background`, border `#2f363a` = `color-card-border`.
Flagged geometry: the clear button's 5-top / 7-bottom placement is not optically centred
(OQ-C-034-4).

## 3. Variant & state matrix

| `state` | Fill | Border | Text | Caret | Clear (C-039) | Consumption |
|---|---|---|---|---|---|---|
| Default | `color-card-background` | `color-card-border` | placeholder in `color-nav-text` | — | — | **consumed** — members-home, groups-home, enrollments-home (all 408×44) |
| Focus | none | `color-text-primary` | placeholder in `color-input-placeholder` | yes | — | designed-unconsumed (no specced screen renders a focused header) |
| Has value | none | `color-text-primary` | value in `color-input-value` | — | yes | designed-unconsumed (behavior contracted by the consuming screens; no frame renders it) |
| Has value **+ focused** | — undesigned | | | | | proposed default + OQ-C-034-1: `Has value` as designed, plus the caret trailing the value — i.e. focus is the white border + caret, content is the value |
| error / disabled | — undesigned | | | | | proposed default + OQ-C-034-3: neither exists — a search field has no invalid input and is never disabled (empty results are a list state, per each screen's `empty`) |

The `state` axis is **not** a free variant: it is derived from `text.isEmpty × focused`
(§4). Note the source gives a valued field the white "focus" border even in the symbol
that is not named focused — read as "a field carrying text is visually active", not as a
second border rule.

The placeholder deliberately **changes colour between `Default` and `Focus`**
(`color-nav-text` #8ea0a7 → `color-input-placeholder` #525d63 — it darkens). Both are
designed in this owner-designated set, so both are normative; OQ-C-034-2 asks the owner to
confirm it is intent rather than drift. This closes the cross-set half of
OQ-members-home-4 residual (a): there is no inconsistency between sets to reconcile — the
two colours are two states of this one component.

Variants not in this table may not be built without a ruling.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `text` | `Binding<String>` | current query; empty → placeholder shows |
| `placeholder` | `String` | consumer-set prompt (deviation 1) |
| `focused` | `Bool` | drives border + caret |
| `onChange` | `(String) -> Void` | live filtering; debounce/min-chars are per-consumer (members-home: ≥300ms, min 0) |
| `onClear` | `() -> Void` | C-039 tap — clears `text`, field **stays focused** |

Figma `state` → props: `Default` = `text.isEmpty && !focused` · `Focus` =
`text.isEmpty && focused` · `Has value` = `!text.isEmpty`.

## 5. Composition

- **Consumes:** C-039 ClearSearchButton (instance `3561:33861` of `3561:33857`), rendered
  only while `text` is non-empty.
- **Anatomy, not components:** the 12pt search glyph and the caret. The glyph is
  deliberately not C-021 GlyphButton (that row is the 44pt tappable-button family with a
  9-glyph closed set); this is a 12pt decoration.
- **Consumed by:** members-home, groups-home, enrollments-home. Anticipated: any future
  search surface (library-home, media, a shell-level search).
- **Sibling:** C-045 TextInput — the glyph-less general input, deliberately separate
  (C-045 §5 already records the pairing). Shared anatomy: 44pt, r4, Regular 14/24, white
  focus border, 2×24 `color-accent` caret. Divergence: C-045 `Default` has **no fill**
  where this row's `Default` is filled `color-card-background`.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-034-1 | `Has value` + focused is undesigned (typing into a field that already has text) — proposed default in §3: white border + value + trailing caret + clear button | No | owner |
| OQ-C-034-2 | Placeholder darkens on focus (`color-nav-text` → `color-input-placeholder`). Intent, or drift to be unified on one placeholder colour? | No — §3 contracts both as designed | owner |
| OQ-C-034-3 | Keyboard dismissal has no designed affordance — proposed default: dismiss on scroll or return, no Cancel button, no disabled/error states (carried from OQ-members-home-4 residual (b)) | No | owner |
| OQ-C-034-4 | Clear button sits 5 from the top of a 44pt field (5/7, not centred) — deliberate or a nudge to fix in Figma? | No — contracted as measured | owner (Figma cleanup) |
| OQ-C-034-5 | Figma hygiene: set `3561:33757`, also named "Search", is a glyph-less duplicate of C-045 TextInput's `Single` column (and differs from C-045 by a `#1f2124` Default fill). Delete, or rename to whatever it actually is? | No — no 2.0 row cites it | owner (Figma cleanup) |
| OQ-C-034-6 | Naming: this row is `SearchField` while its anatomical sibling (C-045 `TextInput`) uses `-Input`, and `-Field` is not one of the registry's declared family suffixes. Rename to `SearchInput` for family consistency, or keep? Kept this run — the 2026-09-02 full audit reviewed all 57 rows and left the name standing, so a rename wants an owner call, not a spec-run judgment | No | owner |
