# C-046 FieldGroup — one labelled field: a name over its input

Status: new · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-046 <set url>` with
the set `3524:30092` pasted by the owner 2026-09-11 (D10). The paste **confirms** the ref the
registry already carried rather than replacing it — same node, now with every symbol pinned,
its existing frozen snapshot re-verified, and the axis mapping written down. This file **relocates** the contract
from `screens/shared-edit-field.md` §4 (pointer left there).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3524-30092
  — frame `3524:30092` ("Field group"), 967×562, two axes (`field` × `style`), **4** symbols,
  a full cross product with no sparse cell:

  | Figma symbol | node | size |
  |---|---|---|
  | `Field=Text,style=Default` | `3524:30091` | 387×70 |
  | `Field=Text, style=Focus` | `3524:30093` | 387×70 |
  | `Field=Multiline Text, style=Default` | `3553:32088` | 387×114 |
  | `Field=Multiline Text, style=Focus` | `3553:32091` | 387×114 |

- Frozen snapshot: `assets/C-046-field-group.png` (2901×1686, 3×) — frozen by the
  `shared-edit-field` run and **re-verified 2026-09-11**: this run exported the same node
  again and the four symbols are identical to the frozen artifact, so Figma has not drifted
  and no re-spec event is recorded. The existing higher-resolution capture is kept rather
  than replaced with a fresh lower-resolution one.
- Sub-component set: `3524:30063` ("Text input") → **C-045 TextInput**, whose own contract
  (`C-045-text-input.md`) binds everything inside the box.

**Deviations (closed list):**
1. The label "Field name" and the inner placeholder "Placeholder" are per-instantiation
   content, not part of the contract.
2. The symbols are **387 wide**; consumers are width-driven — 408 full-bleed, 196 compact in
   a 2-up row (`shared-edit-field`'s age range). Width is not a variant (§3b).
3. The sheet frame is 967×562, laying the four symbols out in two columns on 20pt gutters;
   the component is the symbol, not the frame.
4. In `style=Focus` the inner input still shows its **placeholder**: the set samples empty
   content while drawing the focus treatment. That is C-045's deviation 3 / OQ-C-045-1, and
   it is why focus reads as an overlay state here too (§3a).
5. The inner input's resting border is raw `#2f363a` — hex-equal to `color-card-border` and
   not variable-bound. It is C-045's anatomy and is recorded in C-045's contract; this row
   inherits it unchanged.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A two-part vertical stack. There is no third part: no helper text, no error line, no
required marker — see §3c.

| Part | Geometry |
|---|---|
| Root | column, leading-aligned, width from the consumer; gap **12** between label and input |
| Label | SF Pro **Bold 14 / 14**, `color-text-primary`, single line, `nowrap` — identical in all four symbols |
| Input | **C-045 TextInput**, full width of the group, `radius-card-sm` (4), 1px border |

Heights are the sum and nothing else: **70** = 14 + 12 + 44 (`field=Text`), **114** = 14 + 12
+ 88 (`field=Multiline Text`).

**Flagged literals (D7):**
- The **12pt label↔input gap** has no row in the spacing family (2 / 4 / 8 / 16 / 24 / 32).
  Carried as a per-component literal rather than a unilateral token mint — see OQ-C-046-5,
  which belongs with the program's pending `10` ruling.
- The label's **Bold 14/14** is the program's third Bold-14 leading, beside `type-title-card`
  (Bold 14/20) and `type-nav-label` (Bold 14/16). No token is minted for a single component;
  OQ-C-046-6 asks for the ruling, and this is now the **second independent site** of 14/14
  (the first was found in the C-059 run, 2026-09-10).

**No new tokens.** `get_variable_defs` on the set returns `Input/placeholder`, `Purple/100%`
and `Color/Base/White` — all three already bound in `../tokens.md`.

## 3. Variant & state matrix

### 3a. The closed matrix

Both axes are **pass-throughs into C-045** — this component adds the label and the gap, and
delegates every pixel inside the box:

| `field` × `style` | Inner C-045 state | Height | Consumption |
|---|---|---|---|
| `Text` × `Default` | `lines=Single, state=Default` | 70 | **consumed** — shared-edit-field (`text-single`; also both compact 196 age fields), create-study-program (program title) |
| `Text` × `Focus` | `lines=Single, state=Has value + Focus` | 70 | **consumed** — shared-edit-field (focused single-line frames) |
| `Multiline Text` × `Default` | `lines=Multi, state=Default` | 114 | **consumed** — shared-edit-field (`text-multi`, description fields) |
| `Multiline Text` × `Focus` | `lines=Multi, state=Has value + Focus` | 114 | **consumed** — shared-edit-field (focused description) |

Every designed variant is consumed; this row has no designed-unconsumed cell.

Variants not in this table may not be built without a ruling.

### 3b. Width is not a variant

The group stretches its input to its own width, so 408 (full-bleed field page) and 196 (the
2-up age range on `shared-edit-field`) are the same four symbols at two widths. Nothing in
the anatomy changes with width — which is also why the `nowrap` label at 196 is a question
(OQ-C-046-4) rather than a designed behaviour.

### 3c. Undesigned states (proposed defaults + OQ)

The set designs no error, no disabled, no required marker and no helper text. Proposed
defaults, **not fact**: error = delegate entirely to C-045's proposed error border
(OQ-C-045-2) with no group-level message line; disabled = not offered, following C-045's
reading that a field which cannot be edited does not render this component; required marker
= none. Each is OQ-C-046-2 / -3.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `label` | `String` | The field name above the input. Single line |
| `field` | `Text \| Multiline Text` | Selects the inner input's line count (§3a) |
| `style` | `Default \| Focus` | Selects the inner input's state (§3a) |
| *(input content)* | per **C-045 TextInput** | Text, placeholder and value belong to C-045's contract and are **not** restated here |

The two axes map onto C-045 one-for-one and nothing else varies. Note what that mapping
**cannot** express: C-045 owns three states and this group reaches only two of them —
OQ-C-046-1.

## 5. Composition

**Consumes:** C-045 TextInput — this component is its only designed host.

**Consumed by:** `shared-edit-field` (5 instances across its frames — all four variants) ·
`create-study-program` (1, `Text`/`Default`).

**Anticipated:** every future field-editing pattern; `shared-edit-field` is explicitly a
shared pattern screen, so new fields consume this row rather than minting one.

**Sibling, deliberately separate:** C-034 SearchField is a labelled-input lookalike that is
not this — it carries a glyph and its own clear button, and it fills its `Default` state
where C-045 does not.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-046-1 | **The `style` axis cannot express "filled, but not focused."** `Default` maps to C-045 `state=Default` (placeholder), yet `shared-edit-field`'s "ready to save" frames render filled, unfocused inputs — a state its own consumer draws and this group has no variant for (C-045's matrix records `Has value` consumed there). Either add a third `style` value, or contract `style` as *focus only*, with content orthogonal to it — the latter matches C-045's overlay reading of focus and needs no new symbol | No — but a build must pick one | Owner |
| OQ-C-046-2 | No **error** treatment designed: no message line, no group-level border change. §3c proposes delegating to C-045's border and rendering no message — confirm, or design the message slot | No | Owner |
| OQ-C-046-3 | No **required / optional** marker designed. Are all fields effectively required, or does the marker simply not exist in 2.0? | No | Owner |
| OQ-C-046-4 | The label is `nowrap` at every width, including the **196 compact** column. Long labels have no designed overflow. Proposed default: single line, ellipsis | No | Owner |
| OQ-C-046-5 | The **12pt** label↔input gap has no spacing token. Mint `space-field-gap` (12), or keep it a flagged literal? Pairs with the pending `10` ruling — one spacing-scale decision should settle both | No | Owner |
| OQ-C-046-6 | The label's **Bold 14/14** is the third Bold-14 leading in the program (beside 14/20 and 14/16) and now the second independent site. Three styles, or one with drift? | No | Owner |
