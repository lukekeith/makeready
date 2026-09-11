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

- [ ] 4.1 `capture/src/lib/hit-test.js` — extracted from `Ui2Layout.jsx:200-208`, returns `ref`
      (07 §4.1); `Ui2Layout` keeps a one-line `useCallback` wrapper · tests: H-1, H-2, H-3, H-8
- [ ] 4.2 `capture/src/lib/ui2-url.js` — `withSearch(path, search)` (07 §5.5) · tests: H-6
- [ ] 4.3 `ZoomPane.jsx` — non-comment-mode `onHoverTarget`, unconditional `onClearTarget`,
      click-vs-drag `onSelectTarget` on mouseup (≤4px, primary button, fractions from `vpRef`)
      per 07 §4.2 · tests: H-7
- [ ] 4.4 `RenderPane.jsx` — the four props passed through; `componentBox` added to `commentProps`
- [ ] 4.5 `CommentLayer.jsx` — the `--component` box + label, below the comment boxes, never
      pointer-eating (07 §4.5)
- [ ] 4.6 `Ui2Layout.jsx` — screen `elements` source, `componentTarget` state, comment-mode
      forcing, `?c=` read/write, `variantPath` through `withSearch`, tree navigation drops `c`
      (07 §4.3, §5.5)
- [ ] 4.7 `capture/src/styles.css` — `.cmp-target-box--component`, `.cmp-target-box__label`
      (+ `--inside`) (07 §6)
- [ ] 4.8 The screen-comment consequence (07 §4.4): screen comment targets label from the live
      registry as `C-### Name`

## Phase gates

- [ ] `cd capture && npm test`
- [ ] `cd capture && npx vite build`
- [ ] Browser console clean on `/components/2.0/home-dashboard/default` (08 §1)

## Verification checklist

- [ ] Human script steps 1, 2, 3 (R1, R2, nesting), 11 (comment-mode isolation), 12
      (degradation), 13 (**1.0 regression**), 14 (selection survives navigation)
- [ ] A drag over 4px pans and selects nothing; a click ≤4px selects
- [ ] Zero DOM at rest: no `.cmp-target-box--component` in the DOM until the pointer is over a
      mapped rect
- [ ] Human script step 15 — a pin dropped on a mapped screen carries `C-### Name`
- [ ] Spec parity: R1's "exactly one box, none at rest" and D8's smallest-rect rule, traced in the
      shipped `hit-test.js`

## VERIFIED

⬜ Not yet — do not open the next phase doc.
