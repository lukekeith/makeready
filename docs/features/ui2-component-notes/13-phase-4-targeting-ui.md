# Phase 4 — Hover, click and the box  ·  app: capture (frontend)

> Preconditions: Phase 3 **VERIFIED** — targeting cannot be verified without real maps.
> Every change to a shared viewer component is **additive**: the 1.0 era renders through the same
> `RenderPane` / `ZoomPane` / `CommentLayer` and must be byte-for-byte unaffected.

## Goal

Hovering a mapped screen render draws exactly one labelled box under the pointer; clicking selects
that component into the URL; comment mode is untouched and still owns the pointer when it is on;
panning still pans. R1, R2, R3 and the comment-mode isolation are demonstrable.

## Companion skills

None (capture is not in the `/component` family). The manifest in [07](07-capture.md) §8 is the
binding list — no unit outside it may be created or extended.

## Tasks (in order)

- [x] 4.1 `capture/src/lib/hit-test.js` — extracted from `Ui2Layout.jsx:200-208`, returns `ref`
      (07 §4.1); `Ui2Layout` keeps a one-line `useCallback` wrapper · tests: H-1, H-2, H-3, H-8
- [x] 4.2 `capture/src/lib/ui2-url.js` — `withSearch(path, search)` (07 §5.5) · tests: H-6
- [x] 4.3 `ZoomPane.jsx` — non-comment-mode `onHoverTarget`, unconditional `onClearTarget`,
      click-vs-drag `onSelectTarget` on mouseup (≤4px, primary button, fractions from `vpRef`)
      per 07 §4.2 · tests: H-7
- [x] 4.4 `RenderPane.jsx` — the four props passed through; `componentBox` added to `commentProps`
- [x] 4.5 `CommentLayer.jsx` — the `--component` box + label, below the comment boxes, never
      pointer-eating (07 §4.5)
- [x] 4.6 `Ui2Layout.jsx` — screen `elements` source, `componentTarget` state, comment-mode
      forcing, `?c=` read/write, `variantPath` through `withSearch`, tree navigation drops `c`
      (07 §4.3, §5.5)
- [x] 4.7 `capture/src/styles.css` — `.cmp-target-box--component`, `.cmp-target-box__label`
      (+ `--inside`) (07 §6)
- [x] 4.8 The screen-comment consequence (07 §4.4): screen comment targets label from the live
      registry as `C-### Name`

## Phase gates

- [x] `cd capture && npm test` — **100 / 99 pass / 1 pre-existing** (+8 this phase: H-1…H-3, H-6…H-8)
- [x] `cd capture && npx vite build` — clean
- [x] Browser console clean on `/components/2.0/home-dashboard/default` **and** on a 1.0 component
      — zero errors after the full interaction walk

## Verification checklist

- [x] Human script steps 1, 2, 3 (R1, R2, nesting), 11 (comment-mode isolation), 12
      (degradation), 13 (**1.0 regression**), 14 (selection survives navigation)
- [x] A drag over 4px pans and selects nothing; a click ≤4px selects
- [x] Zero DOM at rest: no `.cmp-target-box--component` in the DOM until the pointer is over a
      mapped rect
- [x] Human script step 15 — a pin dropped on a mapped screen carries `C-### Name`
- [x] Spec parity: R1's "exactly one box, none at rest" and D8's smallest-rect rule, traced in the
      shipped `hit-test.js`

## VERIFIED

✅ **2026-09-10** — walked live in Chrome against the real backfilled maps.

| What | Result |
|---|---|
| **R1** hover | One box, exactly under the pointer, tracking it. Zero `.cmp-target-box` in the DOM at rest, and zero once the pointer leaves the render |
| **R2** label | `C-023 KpiCard` above the box; at the top of the frame `C-019 TopNav` **flips inside** the box's top edge |
| **Nesting (D8)** | Hovering the `+` inside the Overview header selects `C-021 GlyphButton` (24×24), not the 440-wide `C-020 SectionHeader` containing it |
| **R3** click | `?c=C-023` appears, the render, state and version timeline are untouched, and the page does not navigate |
| **Click vs drag** | A 60px drag pans and selects nothing; a 2px press selects. A click on an unmapped part of the render **clears** the selection |
| **Comment-mode isolation** | Pressing `c`: zero component boxes, comment placement behaves as before. Leaving comment mode brings hover back |
| **Screen comments (09 §G-8)** | A pin dropped on a mapped screen shows `◎ C-023 KpiCard` in its composer — the same string the hover box shows, because both read one `hit()` |
| **Selection survives navigation (09 §G-9)** | `/components/2.0/invite-home?c=C-034` canonicalises to `…/default?c=C-034`; switching to the `linked` frame keeps it; selecting a different screen drops it |
| **1.0 regression (09 §C-3)** | A 1.0 component render draws no boxes at rest or on hover outside comment mode, and its comment-mode behaviour is untouched. `CompareDetail` and `ComponentsLayout` pass none of the four new props |

**Two corrections the live UI forced**, both written back into 07 the same session:

1. **The comment chip and the hover box disagreed.** The chip read `KpiCard` (the map's stored
   name) while the box read `C-023 KpiCard` (the live registry). 07 §4.4 requires one string, so
   the label resolution moved into the single `hit()` wrapper both readers call.
2. **The label-flip rule was unimplementable as written.** The draft had the host decide from the
   rect's `y` fraction; whether a label fits above its box is a pixel question that changes with
   zoom. `CommentLayer` now measures its own height (it is `inset: 0` over the render) and flips
   under 24px of clearance. Verified at the same zoom on both a top-edge and a mid-render box.
