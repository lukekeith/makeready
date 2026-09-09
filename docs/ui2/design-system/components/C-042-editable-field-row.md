# C-042 EditableFieldRow — tappable field row that opens its single-field edit screen

Status: new · Specced: 2026-09-01 (members-profile §4) · Full-set contract: 2026-09-03 ·
Owner-designated: `/ui2-component field-row <url>` (D10). This file **relocates** the
contract from `screens/members-profile.md` §4 (pointer left there); the behavior rule —
tap opens the field's `shared-edit-field` instantiation — is owned by
`screens/shared-edit-field.md` and unchanged.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3517-29304
  — set `3517:29304` ("Field", 6 symbols on one `state` axis)
- Sub-component: Tag set `3526:30837` ("Tag", `style {Default, Solid}`) → C-068 TagChip
- Frozen snapshot: `assets/C-042-editable-field-row.png` — captured 2026-09-03

**Deviations (closed list):**
1. All labels, values, tag texts, and indicator strings ("Published", "Something") are
   per-instance content.
2. Set symbols are 376pt wide; consumers render at their content width (members-profile:
   408) — width-driven, not a variant.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

74pt row (76 for Tags), py16, gap 8, full-width tappable:

- **Left column** (flex, gap 8): label Regular 14 `color-text-secondary` (single line) over
  the state's content (see §3).
- **Trailing**: optional indicator text Regular 12/20 (state color) + chevron-right 18pt
  (all six states carry the chevron).

Value text (where present): Regular 14/20 white. Tags row: gap `space-chip-gap` (2) of
C-068 TagChips.

## 3. Variant & state matrix

| `state` | Delta vs Default | Consumption |
|---|---|---|
| `Default` | label over single-line ellipsized value + chevron | consumed — members-profile (×5 of its 8 rows) |
| `Green indicator` | + trailing indicator text in `color-positive` before the chevron | consumed — members-profile ("Verified") |
| `Red indicator` | + trailing indicator text in `color-negative` | consumed — members-profile ("Unverified") |
| `Tags` | value replaced by a C-068 TagChip row (gap 2); row 76pt | designed-unconsumed |
| `Age` | **zero structural delta** — Default with age content ("Age"/"All ages") | designed-unconsumed; proposed: build as `Default`, not a distinct variant (OQ-C-042-1) |
| `Multiline` | value not height-clamped/ellipsized (wraps) | designed-unconsumed; wrap bound undesigned (OQ-C-042-2) |
| pressed / disabled | — undesigned | proposed defaults: system highlight on press; no disabled rows (omit instead) — OQ-C-042-3 |

Variants not in this table may not be built without a ruling.

## 4. Props contract

`label: String` · `value: String?` (Default/Green/Red/Age/Multiline) · `tags: [String]?`
(Tags state) · `indicator: (text: String, tone: positive|negative)?` (Green/Red) ·
`multiline: Bool` · `onTap` (→ the field's `shared-edit-field` instantiation, per that
pattern spec). The `state` axis maps onto `indicator`/`tags`/`multiline` — `Age` is
content, not a prop.

## 5. Composition

- **Consumes:** C-068 TagChip (Tags state) · chevron-right glyph (asset, part of anatomy).
- **Consumed by:** members-profile (×8 rows; Default/Green/Red) · every future C-042 host
  per the shared-edit-field pattern (group home fields via `groups-detail`, program
  settings, member home — owner-confirmed scope 2026-09-02).

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-042-1 | `Age` is a zero-delta content exemplar — ratify "build as Default" (else define its delta) | No — default proposed | owner |
| OQ-C-042-2 | `Multiline` wrap bound: unbounded (proposed) or clamped at N lines? | No — default proposed | owner |
| OQ-C-042-3 | Pressed/disabled undesigned — proposed defaults in §3 | No | owner |
| OQ-C-042-4 | The Tags state implies a **tags editor**, but the shared-edit-field pattern designs no tags input arrangement (text/multiline/radio/range/toggle only) — a pattern gap that must be designed before any Tags-state field ships | No here; **gates the first Tags-state consumer** | owner (frames) |
