# Phase 4 — The highlight service and its three surfaces  ·  app: iphone

> Part of docs/features/highlighting/. Preconditions: **Phase 2 VERIFIED and 03 FROZEN.**
> Parallelizable with Phase 5 (client) — they never import each other.

## Goal

One service in `iphone/MakeReady/Services/Highlighting/` owns selection, snapping, rendering,
commit and persistence, and all three native surfaces use it. The three word-snappers become one,
the five highlight colours become one policy, and no surface commits a highlight on a timer.

## Companion skills

`/transition-review` on the diff — it touches gesture and animation surfaces · `/animation-debug`
if a transition misbehaves · `/ios-error-surface` for every new catch block · **not**
`/present-overlay` (no new modal).

## Tasks

**Service (build bottom-up — each layer is testable alone)**

- [ ] 4.1 `HighlightRange.swift` — the position type + absolute ↔ verse-relative conversion,
      absorbing `HighlightRange` (`StudyModels.swift:943`) · spec: 06 §The service
- [ ] 4.2 `HighlightSnapping.swift` — `Granularity { verse, word, character }`, one implementation.
      Fold in `VerseSelectionLogic.snapToWordBoundaries` (`:100`, currently **zero callers**) with
      the `c8a0311` semantics: `'` `’` `-` intra-word, grow-only.
      · spec: 03 §5, 06 §Snapping · tests: "Lord's" stays whole; a verse-terminating newline does
      not walk into the next verse; never trims the user's range
- [ ] 4.3 `HighlightRenderer.swift` — `.live` / `.saved` / `.active` / `.used` using 03 §5's exact
      values, **including `bold` = weight only, no wash** · spec: 03 §5
- [ ] 4.4 `TextSelectionController.swift` — the gesture lifecycle from `c8a0311`:
      `TouchObserverGestureRecognizer`, commit only on genuine release, granularity injected.
      **Carry the scroll-lock machinery** (DECIDED — 10 of the view's 22 lifecycle state vars).
      · spec: 06 §Selection lifecycle · tests: no commit while a finger is down, at any elapsed
      time; a cancelled touch does not commit; release commits exactly once
- [ ] 4.5 `HighlightStore.swift` — the protocol + program/enrollment implementations, plugged into
      the **existing** `ReadActivityActionProvider` (`EditReadActivityPage.swift:14`) and
      `ExegesisActivityActionProvider` (`EditExegesisActivityPage.swift:22`) seams — do not replace
      them · spec: 06 §AppState & Actions
- [ ] 4.6 `HighlightableTextView.swift` — the single `UIViewRepresentable`

**Model & state**

- [ ] 4.7 `ExegesisHighlight` → `Highlight` + `style` (`StudyModels.swift:380`); keep
      `ReadBlockSelection` (`:372`) for decoding the legacy projection · spec: 06
- [ ] 4.8 `EntityStore<Highlight>` on `AppState`, cleared in `clearInMemory()`. Bump the persisted
      state version so an old disk cache degrades rather than failing to decode
      · spec: 06 §Disk cache · **SwiftLint `server_collection_in_view_state` enforces the storage half**
- [ ] 4.9 Collapse the eight Action methods (`ProgramActions+Activities.swift:312-384`,
      `EnrollmentActions.swift:886-958`) behind `HighlightStore`; Actions still mutate AppState and
      return `Void` · spec: 06
- [ ] 4.10 Consume `blockIds[]`, never the deprecated singular `readBlockId` · spec: 03 §2.1, 06

**Adoption (one surface at a time — verify each before the next)**

- [ ] 4.11 **Read editor** at `.verse` — `SelectableLockedBlockView` becomes a thin wrapper over
      `HighlightableTextView` (DECIDED: wrap, don't replace). Keep the verse-tap UX, the highlighter
      glyph, the hint row and the style picker · spec: 06 §Adopting surfaces
- [ ] 4.12 **Exegesis editor** at `.word` — same wrapping; keep the notes UI, the action menu and
      `ExegesisNoteEditorPage`
- [ ] 4.13 **Bible reader** — adopt `HighlightRange`, snapping, renderer and the controller; **its
      commit still produces a passage reference, not a Highlight row**. Delete the inline snapper at
      `BibleReaderOverlay.swift:1796-1825` · spec: 06, D5
- [ ] 4.14 Delete `ExegesisVerseView.snappedToWordBoundaries` (the `c8a0311` duplicate) — closes
      09 §C-a
- [ ] 4.15 Tests per 08 §iPhone

## Phase gates

```
npm run ios:build-check          # from repo root
cd iphone && swiftlint
```
Launching the app and committing iPhone code remain explicit user calls.

## Verification checklist

- [ ] Exactly **one** word-snapper exists in the app (grep: `snapToWordBoundaries`,
      `snappedToWordBoundaries` → one definition, three callers)
- [ ] `grep` finds no `asyncAfter`-driven selection commit anywhere in the three surfaces
- [ ] Read editor: tap-a-verse still selects, extend still works, style picker still opens
- [ ] Exegesis editor: drag-and-hold commits **only** on release; notes still open and save
- [ ] Bible reader: selection still yields a passage reference; verse circles still work; **no
      scroll jump** during a drag (the carried machinery is doing its job)
- [ ] Saved highlights render lime `@0.35`, live drag `@0.55`, on every surface
- [ ] `/transition-review` → PASS
- [ ] Contract parity: every field consumed here is in 03's frozen table, same names

## VERIFIED

*(unsigned)*
