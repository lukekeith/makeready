# C-045 TextInput — the program's general text input (single and multiline)

Status: new · Specced: 2026-09-01 (shared-edit-field §4) · Full-set contract: 2026-09-03 ·
Owner-designated: `/ui2-component text-input <url>` (D10). This file **relocates** the
contract from `screens/shared-edit-field.md` §4 (pointer left there).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3524-30063
  — set `3524:30063` ("Text input"): **one set of 6 symbols**, `state {Default, Has value,
  Has value + Focus} × lines {Single, Multi}`. (Citation correction: `3547:31813` — cited
  by the registry as a second set — is the Default/Multi symbol *inside* this set.)
- Frozen snapshot: `assets/C-045-text-input.png` — captured 2026-09-03

**Deviations (closed list):**
1. "Placeholder"/"Value" strings are sample content.
2. Set symbols are 387pt wide; consumers are width-driven (408 full / 196 compact per
   C-046).
3. The `Has value + Focus` symbols render the placeholder with the caret and no value —
   the variant name and its content disagree; §3 contracts focus as an overlay state
   (OQ-C-045-1 records the mismatch for owner cleanup).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Bordered field, `radius-card-sm` (4), no fill:

- **Single:** 44pt, p16, content vertically centered, single line.
- **Multi:** 88pt, px16 py9, content top-aligned, wrapping.
- Border: 1px `color-card-border`; focused: 1px `color-text-primary` (white).
- Text: Regular 14/24 — placeholder `color-input-placeholder`, value `color-input-value`.
- Caret (focused): 2×24, r2, `color-accent`, leading the content row.

## 3. Variant & state matrix

| `state` × `lines` | Renders | Consumption |
|---|---|---|
| Default × Single | placeholder, card-border | consumed — shared-edit-field (C-046), create-study-program, enrollment-home (C-060-adjacent min/max via C-046) |
| Default × Multi | placeholder top-left, card-border | consumed — shared-edit-field (description fields) |
| Has value × Single | value, card-border | consumed — shared-edit-field ("ready to save" frames), age-range min/max |
| Has value × Multi | value wrapping, card-border | consumed — shared-edit-field (Group description) |
| Has value + Focus × Single | white border + caret; symbol samples EMPTY content (deviation 3) | consumed — shared-edit-field (C-046 style=Focus) |
| Has value + Focus × Multi | white border + caret, top-aligned; same sampling | consumed — shared-edit-field |
| error / disabled | — undesigned | proposed defaults + OQ-C-045-2: error = 1px `color-negative` border (no other delta); no disabled inputs (fields that can't be edited don't render this component) |
| Multi growth beyond 88pt | — undesigned | proposed default + OQ-C-045-3: 88pt minimum, grows with content |

Contracted reading of focus (per deviation 3): `focused` is an **overlay state** — white
border + caret — combinable with either empty (placeholder) or valued content; the set
samples the empty case.

Variants not in this table may not be built without a ruling.

## 4. Props contract

`text: String` (empty → placeholder shows) · `placeholder: String` · `lines: single |
multi` · `focused: Bool` (drives border + caret). The Figma `state` axis maps onto
`text.isEmpty` × `focused`.

## 5. Composition

- **Consumes:** nothing (leaf component; the caret is anatomy).
- **Consumed by:** C-046 FieldGroup (its only designed host — label + this input) →
  shared-edit-field pattern screens, create-study-program, and every future pattern
  instantiation. C-034 SearchField (`C-034-search-field.md`) is the glyph-bearing sibling,
  deliberately separate — note it fills its `Default` state where this row does not.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-045-1 | Figma hygiene: the `Has value + Focus` symbols show placeholder+caret, not a value — rename the variant (`Focus`) or fill in valued content so name and render agree | No — §3's overlay reading stands | owner (Figma cleanup) |
| OQ-C-045-2 | Error and disabled states undesigned — proposed defaults in §3 (error = `color-negative` border; disabled = don't render) | No | owner |
| OQ-C-045-3 | Multi growth: fixed 88pt or grow-with-content (proposed: 88 min, grows) | No | owner |
