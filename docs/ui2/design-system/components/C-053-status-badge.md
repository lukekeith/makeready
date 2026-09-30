# C-053 StatusBadge — a small pill that says what publish state a thing is in

Status: existing-modified · Specced: 2026-09-11 (re-specced 2026-09-11 from a NEW set) ·
Owner-designated: `/ui2-component C-053 <node url>` with the **set** `4147:8257` pasted by the
owner 2026-09-11 (D10). This is the row's **second** designation in one day: the first
confirmed the lone frame `3524:29722`, this one **replaces** it with a real two-symbol variant
set. A D5 re-spec event — the design moved, visibly.

**What the new set changes.** The 2026-09-11 morning contract recorded this row as "**one
designed state, `published`**… a lone frame, NOT a variant set: no `state=` axis, no sibling
symbol". That is no longer true. `4147:8257` is a `state=` set with two symbols, and the second
one is `Draft` — **which answers OQ-C-053-1**, the question the row has carried since
2026-09-01.

**Closed change list vs. the (superseded) morning contract:**
1. **The source is now a set, not a lone frame.** `4147:8257` "StatusBadge", 114×110, holding
   `state=Published` (`4147:8256`, 74×25) and `state=Draft` (`4147:8258`, 47×25). The old node
   `3524:29722` is superseded as the normative ref (§1).
2. **`draft` is DESIGNED** — OQ-C-053-1 is closed by the design, not by a ruling.
3. **The proposed default for `draft` was WRONG on both counts** and is struck. The 2026-09-01
   proposal was "Draft" on `color-white-20` with `color-text-primary`; the design is
   `color-neutral-600` with `color-neutral-50` at 70% (§3a). Recorded because the proposal was
   carried as a plausible default for ten days and a build shipped against it — the lesson is
   §3c's, not this row's alone.
4. **The 70% label opacity is a property of the COMPONENT, not of the `published` state.** Both
   symbols carry `opacity-70` on the text node. The morning contract's deviation 4 read it as a
   `published` fact; it generalises (§2).
5. **One token minted:** `color-neutral-50` (#f5f6f7), the `draft` label colour, from Figma
   variable `Color/Neutral/neutral-50`. `color-neutral-600` already had a row and gains its
   first consumer.
6. **The `published` symbol has NOT drifted.** Re-exported this run and diffed against the
   morning's frozen snapshot: **byte-identical in the pill's interior** (max channel delta 0),
   differing only in the pixels behind the rounded corners, where the new frame's ground
   (#1e1e1e) shows instead of the old `color-layout-background`. So the re-spec adds a state; it
   does not restate the one that existed.
7. **The frozen snapshot is re-frozen as the whole set** (§1), replacing the published-only
   crop. This matches every other set-sourced row (C-021, C-045) and is what `syncUi2Row`
   registers per state.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=4147-8257
  — set `4147:8257` ("StatusBadge"), 114×110, ingested 2026-09-11. Two symbols on one `state`
  axis:

  | Symbol | Node | Size | Text node |
  |---|---|---|---|
  | `state=Published` | `4147:8256` | 74×25 | `4147:8255` "Published" |
  | `state=Draft` | `4147:8258` | 47×25 | `4147:8259` "Draft" |

- **One axis, two values, no third.** `state` is the only variant property the set declares.
- **Supersedes `3524:29722`**, the frame-local lone component on the superseded
  study-program-home frame `3524:29600`, which is what this row pointed at until this run. That
  node still resolves and still renders the same pill (change-list item 6); it is simply no
  longer the contract's source.
- The component sheet (`3632:4502`, D9) carried **no** badge entry when searched on 2026-09-11;
  this set sits outside it. The sheet is not the source and is not claimed to be.
- Frozen snapshot: `assets/C-053-status-badge.png` — the whole set at 3×, captured 2026-09-11.

**Deviations (closed list):**
1. The label string is **not** per-instantiation content — it is the state's name ("Published"
   for `published`, "Draft" for `draft`). A consumer does not pass a label (§4).
2. The `published` pill's fill is the raw literal **`#6cff73`**, hex-equal to `color-positive`
   (Figma variable `green`) but **not variable-bound** — `get_variable_defs` on the set returns
   `Color/Base/Black`, `Color/Neutral/neutral-50` and `Color/Neutral/neutral-600` and no green.
   The `draft` pill's fill, by contrast, **is** bound. So the two states disagree about whether
   a badge fill is a token, within one set. OQ-C-053-2.
3. Widths differ per state (74 vs 47) because the labels do. Width is content-driven (§3b).
4. **Both** labels carry **70% opacity** on the text node, not on the pill — so each pill's
   fill is full-strength and only the lettering is softened. Verified from the exports: the
   `published` ink measures (33,77,35) against a predicted (32,76,34) for black@70% over
   `#6cff73`, and the `draft` ink measures (194,198,203) against an exactly-predicted
   (194,198,203) for `color-neutral-50`@70% over `color-neutral-600`.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

A pill and a word, in either state. There is no icon, no dot, no border and no shadow, and the
two states share every measurement except the width their labels produce.

| Part | Geometry |
|---|---|
| Pill | content-hugging row, contents centred both axes; **px 8 / py 4**; `radius-card-sm` (4); fill per state (§3a). Height **25**, width content-driven |
| Label | SF Pro Text **Bold 12**, leading **1.4** (= 16.8, a 17pt box), tracking **−0.24**, colour per state at **70%** opacity, `nowrap` |

**The height is the sum and nothing else:** 25 = 4 + 17 + 4, in both states. The 17 is the
label's line box (12 × 1.4 = 16.8), so the pill's height follows from the type and the padding —
it is not set.

**Flagged literals (D7):**
- The **`#6cff73` `published` fill**, per §1 deviation 2. It is emitted as the literal the
  source states, not silently promoted to `color-positive`, because promoting it would assert a
  binding Figma does not have — and the whole point of the flag is that the next Figma edit can
  move one and not the other. Sharpened by this run: the sibling state's fill **is** bound, so
  the two are no longer even consistent with each other. OQ-C-053-2.
- **The 70% label opacity.** `tokens.md` has `color-white-70` but no 70% row for either
  `color-black` or `color-neutral-50`, so the opacity is applied at the call site rather than
  named. Generalised from the morning contract, which scoped this to black. OQ-C-053-4.
- The **px 8 / py 4** are recorded as measured paddings rather than as `space-element-gap` (8)
  and `space-meta-gap` (4). Both are hex-equal, but both are *gaps between siblings* in the
  spacing family, and this is an inset inside a pill; citing them would assert that a badge's
  padding and a card stack's rhythm are one decision. Same reasoning as C-038 §2's glyph inset.

**Type — one row to reconcile.** The label is **Bold 12 / 16.8, tracking −0.24**. `tokens.md`
carries `type-caption-bold` as "SF Pro Bold 12" with **no measured leading and no tracking**, so
this is either that token finally measured, or a second Bold-12. The tracking is the
discriminator and it is not nothing: the program's only other negative tracking is
`type-callout-bold`'s −0.32. Not resolved here — OQ-C-053-3. The set does not settle it either:
both states share the identical type, so there is one style in question, not two.

**Tokens.** `get_variable_defs` on the set returns exactly `Color/Base/Black`,
`Color/Neutral/neutral-50` and `Color/Neutral/neutral-600`. One was missing from `tokens.md`
and is minted this run:

| Token | Value | Figma variable | Used by |
|---|---|---|---|
| `color-neutral-50` | #f5f6f7 | `Color/Neutral/neutral-50` | **minted this run** — the `draft` label |
| `color-neutral-600` | #4a5565 | `Color/Neutral/neutral-600` | already present; **first consumer** is the `draft` pill |
| `color-black` | #000000 | `Color/Base/Black` | the `published` label |

## 3. Variant & state matrix

### 3a. The closed matrix

| `state` | Pill | Label | Width | Consumption |
|---|---|---|---|---|
| `published` | raw `#6cff73`, `radius-card-sm` | "Published", `color-black` @ 70% | 74 | **designed-unconsumed** — its only consumer was the study-program-home cover, removed 2026-09-10 (OQ-C-053-6) |
| `draft` | `color-neutral-600`, `radius-card-sm` | "Draft", `color-neutral-50` @ 70% | 47 | **designed-unconsumed** — designed 2026-09-11, no consumer has ever existed |

Variants not in this table may not be built without a ruling.

### 3b. Width is not a variant

The pill hugs its label: 74 is what "Published" measures at Bold 12 / −0.24 plus px 8 either
side, and 47 is what "Draft" measures the same way. The set now demonstrates this rather than
asserting it — two states, same construction, two widths. Measured ink: 56.0pt for "Published"
inside a 58pt advance box, 28.67pt for "Draft" inside 31.

### 3c. Undesigned states (proposed defaults + OQ)

- **Any third state** (archived, scheduled, error). Not designed and **not proposed**: the row's
  2026-09-02 rename from `PublishStateBadge` to `StatusBadge` generalised the *name* without any
  design widening the *state list*, and inventing one here would make that rename retroactively
  true. OQ-C-053-5.
- **Interaction.** No pressed or disabled symbol, and no action prop — the badge is a read-out.
  Proposed default: non-interactive.

**A proposed default was wrong here once.** `draft` sat in this section from 2026-09-01 to
2026-09-11 as "Draft" on `color-white-20` with `color-text-primary`, and the design that landed
matched **neither** the fill nor the label colour. The proposal was correctly marked "not fact"
and correctly skipped by the preview build (`preview-build.md` §3 rule 7), which is the process
working — but it is a concrete measure of how far a plausible default can sit from the design,
and an argument for rule 7's refusal to render one.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `state` | `published \| draft` | Selects the pill fill and the label together (§3a). The label is **not** a prop — it is the state's name (§1 deviation 1) |

One prop, and the closed list above is its whole vocabulary. **Both values are now designed**, so
both are buildable — which is the substantive difference this re-spec makes to
`/ui2-component-build`.

## 5. Composition

**Consumes:** nothing. A pill and a text run resolve to no other registry row.

**Consumed by:** **nothing, since 2026-09-10.** The study-program-home cover was its only
consumer and the current frame draws no badge.

**Anticipated:** wherever publish state gets a 2.0 surface. `study-program-home` §7 records that
the publish/publish-updates flow "has no 2.0 home yet", so this row and that capability are
waiting on the same ruling (OQ-study-program-home-14). The owner designing a **second** state
for a consumerless row on 2026-09-11 is fresh evidence that the capability is coming back, not
going away (OQ-C-053-6).

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| ~~OQ-C-053-1~~ | ~~**`draft` is undesigned.**~~ **CLOSED 2026-09-11 by the design.** The owner's set designs `draft` outright: `color-neutral-600` pill, `color-neutral-50` @ 70% label, 47 wide. The 2026-09-01 proposal it supersedes was wrong on both colours (§3c) | — | closed |
| OQ-C-053-2 | **The `published` green is raw, and its sibling's fill is not.** `#6cff73` is hex-equal to `color-positive` but binds no variable, where `draft`'s `color-neutral-600` **does** — so one set disagrees with itself about whether a badge fill is a token. Bind it, or is the badge's green deliberately independent of the status green? This is the fifth component showing the raw-hex pattern (C-034, C-045, C-033, C-046's inherited border), and the first where a bound sibling sits beside it | No | Owner |
| OQ-C-053-3 | **Is this `type-caption-bold`?** The label is Bold 12 / 16.8 with tracking **−0.24**; that token is recorded as "SF Pro Bold 12" with no leading and no tracking. Either this measurement completes it, or the tracking makes it a second Bold-12. Pairs with the program's pending Bold-leading ruling. Unchanged by the new set — both states share one style | No | Owner |
| OQ-C-053-4 | **The 70% label opacity has no token, in either state.** `color-white-70` exists; there is no `color-black-70` and no `color-neutral-50-70`. Mint them, mint a generic opacity token, or keep the opacity at the call site? Generalised 2026-09-11: this is a component-level property, not a `published` one (§1 deviation 4) | No | Owner |
| OQ-C-053-5 | **Does the name still fit?** The 2026-09-02 audit renamed this row `PublishStateBadge` → `StatusBadge` to generalise it. It has now gained a second state — but `Published` and `Draft` are both **publish** states, so the generalisation is still a bet on states no design has drawn (§3c). Narrow it back, or hold the bet? (Registry rule 2 renames in place; `C-053` is stable either way) | No | Owner |
| OQ-C-053-6 | **Orphan disposition — defers to OQ-study-program-home-14**, which asks whether C-053/C-054/C-055/C-056 are struck through, re-homed, or consolidated. This run adds a second piece of evidence and no ruling: the owner both **designated** this row and **designed a new state for it** on 2026-09-11, which is not what one does with a component being struck through | No — but gap analysis cannot classify the row until 14 is answered | Owner |
