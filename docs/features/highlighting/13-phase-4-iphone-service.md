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

- [x] 4.1 `HighlightRange.swift` — the position type + absolute ↔ verse-relative conversion,
      absorbing `HighlightRange` (`StudyModels.swift:943`) · spec: 06 §The service
- [x] 4.2 `HighlightSnapping.swift` — `Granularity { verse, word, character }`, one implementation.
      Fold in `VerseSelectionLogic.snapToWordBoundaries` (`:100`, currently **zero callers**) with
      the `c8a0311` semantics: `'` `’` `-` intra-word, grow-only.
      · spec: 03 §5, 06 §Snapping · tests: "Lord's" stays whole; a verse-terminating newline does
      not walk into the next verse; never trims the user's range
- [x] 4.3 `HighlightRenderer.swift` — `.live` / `.saved` / `.active` / `.used` using 03 §5's exact
      values, **including `bold` = weight only, no wash** · spec: 03 §5

> **4.1–4.3 DONE 2026-08-04 — gate run fresh, output recorded.**
> `npm run ios:build-check -- --test` → **TEST SUCCEEDED**, iPhone 17 Pro / iOS 26.5:
> **132 passed, 0 failed, 0 skipped** (suite was 85 — the 47 new cases are
> `HighlightSpanTests` 7 · `VerseCoordinateTests` 3 · `VerseCoordinateSpaceTests` 9 ·
> `HighlightSnappingWordTests` 7 · `HighlightSnappingVerseTests` 4 · `HighlightGranularityTests` 2 ·
> `HighlightAppearanceTests` 5 · `HighlightRendererTests` 10, all confirmed present in the xcresult
> rather than assumed). `swiftlint`: **zero violations in all three new files.**
>
> **Falsification: OWED THEN DONE — see 4.4's block below.** Two of these tests were proven able to
> fail by injecting a deliberate apostrophe regression on 2026-08-04.
>
> - `MakeReady/Services/Highlighting/HighlightRange.swift` — `HighlightSpan` (absolute, half-open,
>   cannot be constructed empty or inverted), the moved `HighlightRange` (verse-relative, wire shape
>   unchanged), `VerseCoordinate` (element-id parsing), and `VerseCoordinateSpace` (the conversion,
>   built from the `verseRanges` a surface already computes).
>   **Found while writing it:** every `HighlightRange` this app has ever written stores
>   `startOffset: 0, endOffset: 0` for a whole-verse selection (`EditDay.swift:786`,
>   `EditReadActivityPage.swift:1119`), and nothing on iPhone ever reads those offsets back. A real
>   exclusive end offset is never 0, so `endOffset == 0` is read as "through the end of that verse"
>   — documented as a legacy sentinel and pinned by a test.
> - `HighlightSnapping.swift` — `HighlightGranularity` + one entry point. Word snapping is the
>   `c8a0311` semantics verbatim; verse snapping reuses `VerseSelectionLogic.versesOverlapping` /
>   `rangeForVerses` rather than a fourth copy, and unions with the input so it stays grow-only even
>   against a malformed verse map.
> - `HighlightRenderer.swift` — six appearances, not four (09 §G-n), plus the bounds clamp every
>   surface open-codes today. Tests assert the four contract colours **as values**, so an iOS/web
>   divergence fails a test rather than a screenshot review.
> - Tests: `HighlightRangeTests.swift` (19), `HighlightSnappingTests.swift` (13),
>   `HighlightRendererTests.swift` (15) in `iphone/MakeReadyCaptureTests/` — 47 cases, counted from
>   the xcresult, not estimated.
- [x] 4.4 `TextSelectionController.swift` — the gesture lifecycle from `c8a0311`:
      `TouchObserverGestureRecognizer`, commit only on genuine release, granularity injected.
      **Carry the scroll-lock machinery** (DECIDED — 10 of the view's 22 lifecycle state vars).
      · spec: 06 §Selection lifecycle · tests: no commit while a finger is down, at any elapsed
      time; a cancelled touch does not commit; release commits exactly once

> **4.4 DONE 2026-08-04 — gate green, and the tests were PROVEN able to fail.**
> `npm run ios:build-check -- --test` → **TEST SUCCEEDED, 143 passed / 0 failed / 0 skipped**
> (132 → 143; `SelectionCommitPolicyTests` adds 11). `swiftlint` clean on all new files.
>
> **Shipped as TWO files, not one.** The spec named `TextSelectionController.swift`; the carried
> scroll machinery is ~180 lines with its own lifecycle and belongs beside it, not inside it:
> - `TextSelectionController.swift` — `SelectionCommitPolicy` (a state machine with **no UIKit and
>   no clock**), the shared `TouchObserverGestureRecognizer` moved here verbatim from
>   `ExegesisVerseView.swift`, and the controller that feeds the policy, snaps at the injected
>   granularity and de-duplicates commits.
> - `ScrollLockCoordinator.swift` — the freeze / preserve / selection-anchor machinery, carried
>   verbatim (same offsets, same device-tuned delays, same ordering).
>
> **Why the policy has no clock.** "Does not commit while a finger is down, **at any elapsed
> time**" (08 §iPhone) is unprovable against a timer-based design — you can only test the delays you
> think of. With time removed as an input, the only route to `.commit` is a hop scheduled by the
> touch count reaching zero that still sees zero touches when it runs, and the property holds by
> construction. The test asserts it over 50 synthetic hops mid-drag.
>
> **The falsification check that was owed from 4.1–4.3, run here.** Two regressions were injected
> deliberately and the suite was run against them:
> 1. `selectionChanged` made to schedule a commit — the original monday#12708759849 shape →
>    `testASelectionChangeNeverSchedulesACommit` and `testViewLevelTouchesCancelledIsInert` **failed**.
> 2. `isWordCharacter` made to reject `'` `’` `-` →
>    `testApostropheIsIntraWordSoLordsStaysWhole`, `testTypographicApostropheIsAlsoIntraWord` and
>    `testHyphenIsIntraWord` **failed**.
>
> 5 failures, all in the right places, then both reverted and the suite re-run clean. **Worth
> recording: under regression 1 the "finger still down" test kept PASSING** — because the commit is
> guarded twice, once by not scheduling on selection change and once by the touch-count check at hop
> time. The tests distinguish the two layers rather than collapsing them, which is why the injected
> bug produced a precise failure set instead of a broad one.
>
> **One convention accepted, not skipped (09 §C-c):** the carried retry ladders trip SwiftLint's
> `async_after_choreography`, a build-phase error. All call sites were funnelled through a single
> `dispatch(_:after:)` helper first, so the exemption is one line for one file in `.swiftlint.yml` —
> chosen over baselining (which hides it) and over restructuring (which risks reintroducing the
> scroll jump, unverifiable without a human on a device).

- [x] 4.5 `HighlightStore.swift` — the protocol + program/enrollment implementations, plugged into
      the **existing** `ReadActivityActionProvider` (`EditReadActivityPage.swift:14`) and
      `ExegesisActivityActionProvider` (`EditExegesisActivityPage.swift:22`) seams — do not replace
      them · spec: 06 §AppState & Actions

> **4.5 + 4.7 + 4.8 DONE 2026-08-04 — one gate, 143 → 159 tests, 0 failed.**
>
> **Task order deviated, deliberately: 4.7 (the model) ran BEFORE 4.5 (the store).** The store's
> every signature returns the model type 4.7 renames, so building 4.5 first would have meant writing
> the file and immediately rewriting it. No task was skipped and nothing outside this phase was
> touched.
>
> **4.5 — `HighlightStore.swift`.** `protocol HighlightStore` + `APIHighlightStore`, with the
> program/enrollment difference reduced to **one stored enum** (`HighlightRouteContext`) supplying a
> path prefix. The contract guarantees identical shapes across the two contexts (03 §2), so a second
> implementation would only be a second thing to forget to update — which is exactly how the eight
> hand-written Action methods drifted. `APIClient` is injected, so the create/update/delete
> round-trip 08 §iPhone asks for is **tested against a stub through both contexts**, not reasoned
> about. `HighlightListResult` exposes `blockIds` and deliberately **does not expose** the
> deprecated singular `readBlockId`, so 4.10 is unfailable by construction; `HighlightCreateResult`
> carries `absorbedIds`, which is what 4.8b needs for merge succession.
>
> **4.7 — `ExegesisHighlight` → `ContentHighlight` + `style`.** Hand-written `init(from:)` so a
> payload with no `style` key decodes to `"highlight"` instead of failing — Swift's synthesised
> decoder treats a missing key as an error *even when the property has a default*, so this could not
> be left to synthesis (09 §X-f).
>
> **4.8 — `EntityStore<ContentHighlight>` on `AppState`, cleared in `clearInMemory()`.**
> **Deviation from the spec, dated:** the doc says "bump the persisted state version so an old disk
> cache degrades rather than failing to decode". The store is **not persisted at all**, so there is
> no bump to make. Highlights are fetched when an editor opens, and a stale cached span paints a
> wash over the wrong words — worse than refetching. 06 §Disk cache offered the model-level default
> as the alternative to a version bump, and that is now in place too, so X-f is covered twice over.
>
> **The lint gate forced 4.8's timing, and was right to.** After the rename, SwiftLint's
> `server_collection_in_view_state` fired on `EditExegesisActivityPage.swift:186` — the baseline
> entry was keyed to the old type name, so the grandfathered violation stopped matching and the rule
> saw new code. The `@State` array is now a computed property derived from `AppState`, and all four
> mutation sites go through the store. **Baselining it instead would have been hiding a bug**: the
> data is server-owned and read by three screens, which is precisely what the rule exists to catch.
>
> **Recorded as 09 §G-p — I undercounted the rename's call sites, the third time this suite has
> caught that class.** My sweep reported 5 files because the grep filtered out anything whose *file
> name* matched `Modal`, which silently excluded `ExegesisHighlightModal.swift` — a genuine consumer
> with 6 references. The build caught it; the sweep should have.
- [x] 4.6 `HighlightableTextView.swift` — the single `UIViewRepresentable`

> **4.6 DONE 2026-08-04 — 159 → 173 tests, 0 failed, and the new tests were proven able to fail.**
>
> **The insight that made this small: the two views differ in ONE thing — the input model.** The
> Read editor selects by tapping verses and never becomes first responder (so UIKit draws no
> selection and there are no grab handles to desync — monday#12668695071); the Exegesis editor
> selects by dragging through UIKit's native text interaction. Everything downstream — snapping,
> painting, committing, verse badges, menu suppression — was already duplicated prose. So `mode` is
> injected (`.verseTap` / `.nativeDrag`) and the rest is shared.
>
> - `HighlightableTextView` (`UIViewRepresentable`) + `HighlightTextView` (the `UITextView` subclass
>   with verse badges and no edit menu — both surfaces subclass for exactly these two reasons today).
> - `VerseTapPolicy` in `TextSelectionController.swift` — **the Read editor's selection model as a
>   pure function**, the sibling of `SelectionCommitPolicy`. Tap a verse → select; tap another →
>   extend across both; tap inside → commit. Previously reachable only through a gesture handler,
>   so it could only be checked by hand.
> - `HighlightRenderer.attributedText(…)` — the composition both surfaces open-code today, with the
>   paint order made explicit: **the live selection is painted LAST** so dragging across an existing
>   highlight is visible. That ordering is behaviour, and it now has a test.
>
> **Falsification, again (2 injected, 3 caught):** painting the live selection *before* the saved
> spans failed `testTheLiveSelectionWinsOverASavedSpanItOverlaps`; making an inside-tap extend
> instead of commit failed both `testTappingInsideTheSelectionCommitsIt` and
> `testCommittingReturnsTheWholeSelectionNotJustTheTappedVerse`. Reverted, re-run clean.
>
> **Not yet adopted by anything** — that is 4.11–4.13, and deliberately separate. The two existing
> views are untouched and still ship their own copies; nothing a user can reach has changed.

**Model & state**

- [x] 4.7 `ExegesisHighlight` → `ContentHighlight` + `style` (`StudyModels.swift:380`); keep
      `ReadBlockSelection` (`:372`) for decoding the legacy projection · spec: 06
- [x] 4.8 `EntityStore<ContentHighlight>` on `AppState`, cleared in `clearInMemory()`. ~~Bump the persisted
      state version~~ — **not persisted, so no bump; see the note above** (deviation recorded 2026-08-04)
      · spec: 06 §Disk cache · **SwiftLint `server_collection_in_view_state` enforces the storage half**
- [x] 4.8b **Entity-keyed note state + the identity-succession seam** *(design decided 2026-08-04)*.
      Today three parallel dictionaries (`noteDrafts`, `attributedNoteDrafts`,
      `savedNoteMarkdownByHighlight`) are keyed by a string derived from the span — mutable data, so
      the key dies whenever the span moves. Replace all three with **one** map keyed by stable
      identity:

      ```swift
      @State private var drafts: [Highlight.ID: HighlightDraft]   // markdown + attributed + isDirty
      ```

      **`savedNoteMarkdownByHighlight` is deleted outright, not re-keyed** — it is a mirror of
      server state that only exists because the view doesn't treat the entity as the source of
      truth. Once highlights live in `EntityStore<ContentHighlight>` (4.8), the saved note *is*
      `state.highlights[id].noteMarkdown`.

      `ExegesisNoteEditorPage` navigates `[Highlight.ID]`, not `[NSRange]` — the thing being edited
      is an entity, not a location; ranges are derived for display.

      **The load-bearing piece — `applyMerge`.** Keying by id is not sufficient on its own: a merge
      *destroys* entities and creates a new one, so id-keyed state is orphaned exactly as
      range-keyed state was. The server already reports what happened (`absorbedIds` + the created
      row); the client must treat that as an identity event in ONE place:

      ```swift
      func applyMerge(created: Highlight, absorbedIds: [Highlight.ID])
      ```

      — updates the store, folds the absorbed drafts into the survivor, and is the only site where
      succession is handled. This is what makes the bug class impossible rather than merely moved.
      · spec: 06 §Note keying · replaces the Phase 1 stop-gap (09 §C-b)
      · tests: a draft survives a merge; an absorbed highlight's draft is folded, not orphaned

> **4.8b HALF DONE 2026-08-04 — the seam exists and is proven; nothing uses it yet. NOT ticked.**
> 173 → **188 tests**, 0 failed, lint clean.
>
> **Done: `HighlightDraftStore.swift`** — one map keyed by highlight id, replacing the three
> span-keyed dictionaries, with `applyMerge(created:absorbedIds:)` as the single succession site.
> `savedNoteMarkdownByHighlight` is **deleted rather than re-keyed**, as the spec asks: now that
> highlights live in `AppState.contentHighlights` (4.8), the saved note *is*
> `state.contentHighlights[id]?.noteMarkdown`, and a second copy could only disagree with it.
>
> **The design point worth keeping:** re-keying by id is necessary but not sufficient. A merge does
> not *move* an entity, it destroys entities and creates a new one — so id-keyed state is orphaned
> by a merge exactly as range-keyed state was. `applyMerge` is where that is handled, once.
>
> **A case a plain re-key still loses, now covered:** text the user typed but had not saved when the
> merge landed. The server concatenates the absorbed rows' *saved* notes, so it cannot have carried
> unsaved typing — the store folds any dirty absorbed draft in after the server's text and leaves
> the survivor dirty so it still gets saved. Clean drafts are dropped, because their content is by
> definition already inside the merged note.
>
> **Falsification:** making `applyMerge` drop unsaved drafts (the phase-1 behaviour) failed
> `testUnsavedTypingInAnAbsorbedHighlightIsCarriedIntoTheSurvivor` and nothing else. Reverted, green.
>
> **ADOPTION DONE 2026-08-04 — the app now runs the seam; the phase-1 stop-gap is deleted.**
> 188 tests still pass, lint clean, and the repo-wide violation count went DOWN 990 → 988.
>
> - `EditExegesisActivityPage`: the three dictionaries are one `@State HighlightDraftStore`. The
>   hand-written re-key at the merge site is now a single `draftStore.applyMerge(created:absorbedIds:)`.
> - `ExegesisNoteEditorPage` navigates **`[ContentHighlight]`**, not `[NSRange]`, as the spec asks —
>   the thing being edited is an entity, and its span is derived for display. `selectedRange`
>   became `selectedId`, bridged at the page boundary by `selectedHighlightIdBinding` because the
>   page still *renders* by span.
> - `highlightNoteKey(for:)` and `rangeFromHighlightNoteKey(_:)` — the span-derived key and its
>   inverse — **are deleted**. The bug class has no representation left.
>
> **Two things fell out that are worth naming:**
>
> 1. **`HighlightActionMenuContent` was passed all three dictionaries and never read any of them** —
>    including `savedNoteMarkdownByHighlight`, which carried an eight-line comment explaining why it
>    had to be a `Binding`. Dead plumbing, now removed. Recorded as 09 §G-q.
> 2. **`savePendingNotes` had a CREATE branch that should never have existed.** It created a
>    highlight when a draft's span matched no highlight — which could only happen when the
>    span-derived lookup MISSED. It was papering over the very bug this keying removes, so it is
>    gone; every draft now belongs to a highlight by construction.
>
> The two `NSLog` trace lines this touched lost their baseline entries when their text changed, so
> the gate correctly flagged them as new code; both were converted to `Log.ui`.

- [x] 4.9 Collapse the eight Action methods (`ProgramActions+Activities.swift:312-384`,
      `EnrollmentActions.swift:886-958`) behind `HighlightStore`; Actions still mutate AppState and
      return `Void` · spec: 06
- [x] 4.10 Consume `blockIds[]`, never the deprecated singular `readBlockId` · spec: 03 §2.1, 06

> **4.9 + 4.10 DONE 2026-08-04 — 188 tests still pass, lint clean.**
>
> **4.9** — the eight hand-written methods are four apiece delegating to `APIHighlightStore`, with
> no request-building or response-decoding left in either Actions file. `loadHighlights` returns
> **`Void`** and writes `AppState`, per the house rule that an Action handing back a collection
> gives the caller a copy nothing can invalidate. `createHighlight` deliberately does NOT return
> Void: a merge is an *event*, not a collection, and the caller needs the created row plus
> `absorbedIds` to carry note succession. Recorded here so the exception reads as considered rather
> than as the rule being forgotten.
>
> **4.10** — the deprecated singular `readBlockId` is not merely unused, it is **undecodable**:
> `APIHighlightStore.ListBody` does not declare the field, and `HighlightListResult` does not expose
> it. There is no way for a consumer to read it by accident. The Action scopes its wholesale
> replace by the response's `blockIds`, which is the multi-block-correct answer.
>
> **A house-rule violation removed on the way through (09 §G-r):** the create path was re-deriving
> which highlights the server had absorbed, locally, with its own overlap test — a second copy of
> the server's merge rule living in the client, which 03 §5 forbids in as many words ("consumers
> never merge locally"). It now uses the `absorbedIds` the server returns.

**Adoption (one surface at a time — verify each before the next)**

- [x] 4.11 **Read editor** at `.verse` — `SelectableLockedBlockView` becomes a thin wrapper over
      `HighlightableTextView` (DECIDED: wrap, don't replace). Keep the verse-tap UX, the highlighter
      glyph, the hint row and the style picker · spec: 06 §Adopting surfaces

> **4.11 DONE 2026-08-04 — the first surface is on the service. 188 tests pass, lint clean.**
> `SelectableLockedBlockView` went **366 → 99 lines**: it keeps its exact public shape (same
> properties, same order, so the memberwise init is unchanged) and both call sites — the production
> one in `EditReadActivityPage` and the capture `ViewRegistry` case — compile untouched, which is
> what the "wrap, don't replace" decision was for.
>
> Deleted with it: the file's private `SelectionTextView` subclass (verse badges + edit-menu
> suppression — `HighlightTextView` does both for every surface now) and its whole tap-selection
> coordinator. `ReadBlockSelectionStyle` stays; the renderer uses it.
>
> **Two behaviours preserved deliberately, because they look like noise and are not:** the commit
> defers `pendingRange` by one runloop turn (the parent presents the style picker from its
> `onChange`, and assigning inside the gesture's own turn landed mid-update), and a tap on an
> existing highlight clears `pendingRange` before setting it so `onChange` fires when the SAME span
> is tapped twice — otherwise re-opening a highlight's style picker silently does nothing.
>
> **The visible change shipped here (09 §G-o): saved spans are lime @0.35, not opaque purple.**
> Verified by construction rather than by eye — the `editMarker` constant and every hardcoded purple
> are gone from the file, and the paint now goes through `HighlightRenderer`, whose four contract
> colours are asserted as values in `HighlightAppearanceTests`. **Nobody has SEEN it.** The page-level
> capture fixture for this screen renders an editable block with no highlights, so it cannot show the
> change; the `/compare` component fixture that would (`SelectableLockedBlockView.json`, variant
> `WithHighlight`) is phase 6's job. Visual confirmation is owed to phase 6 and the human walk.
- [x] 4.12 **Exegesis editor** at `.word` — same wrapping; keep the notes UI, the action menu and
      `ExegesisNoteEditorPage`

> **4.12 DONE 2026-08-04 — `ExegesisVerseView` 1,025 → 93 lines.** Same public shape, so all three
> call sites and the capture registry are untouched. Everything it owned is now the service: the
> gesture lifecycle and its touch observer, the scroll lock, snapping, colours, verse badges,
> edit-menu suppression. No colour changes on this surface — it was already the contract-correct one.
>
> **This forced the last piece of the shared view: a native-drag live preview.** `HighlightableTextView`
> only painted a live span for the TAP model. The drag model needs the wash painted into the text
> view's own storage while the finger is down, because routing it through SwiftUI state would
> re-enter `updateUIView`, reassign `attributedText`, and reset `selectedRange` mid-drag — the exact
> shape of monday#12668695071. `HighlightTextView` now owns `setBase` / `applyLivePreview` /
> `clearLivePreview` with a re-entry flag and selection preservation, carried from the original.

- [x] 4.13 **Bible reader** — adopt `HighlightRange`, snapping, renderer and the controller; **its
      commit still produces a passage reference, not a Highlight row**. Delete the inline snapper at
      `BibleReaderOverlay.swift:1796-1825` · spec: 06, D5

> **4.13 DONE 2026-08-04, with ONE part deliberately not done — see 09 §X-m.**
> - **Snapping: adopted.** The inline copy is deleted; the reader calls `HighlightSnapping`. This is
>   the one that mattered — its copy treated apostrophes as boundaries, so "Lord's" split in the
>   reader and stayed whole in the Exegesis editor. Same text, two answers.
> - **Renderer: adopted.** The used-passage wash and the selection tint now come from
>   `HighlightAppearance`. That also fixed a silent drift: the reader's selection tint was `0.5`
>   where both editors used `0.55`.
> - **`HighlightRange`: available, not forced.** The reader still emits book/chapter/verse through
>   `onPassageConfirmed` and its two call sites build the range themselves. `VerseCoordinateSpace`
>   can do it, but converting is a refactor with no behaviour change, so it is left alone.
> - **The controller: NOT adopted, deliberately.** The reader does not commit on release — it holds
>   the selection until the user taps **Select**. `TextSelectionController` exists to commit on
>   genuine release, so adopting it here would change this surface's UX rather than unify it.
>   Recorded as 09 §X-m rather than silently skipped.

- [x] 4.14 Delete `ExegesisVerseView.snappedToWordBoundaries` (the `c8a0311` duplicate) — closes
      09 §C-a

> **4.14 DONE 2026-08-04 — and it went further than the row asks.** The row names one duplicate;
> there were **three** implementations. All three are gone: `ExegesisVerseView`'s went with 4.12's
> rewrite, `BibleReaderOverlay`'s inline closure with 4.13, and
> **`VerseSelectionLogic.snapToWordBoundaries` was deleted too** — the "canonical" copy with zero
> callers, which disagreed with both of the ones actually in use. `grep 'func snap.*WordBoundaries'`
> now returns exactly one definition.
- [x] 4.15 Tests per 08 §iPhone

> **4.15 DONE 2026-08-04 — 188 → 196 tests.** 08 §iPhone's list was already covered by the
> per-task tests except two items, which shipped here as `HighlightActionsTests`:
> *"AppState reflects the mutation without a manual refetch"* (load / create+merge / update / delete
> all asserted against a private `AppState` through the stub client, in **both** route contexts) and
> *"`clearInMemory()` clears highlights"*.
>
> **Writing them exposed a testability hole I had introduced in 4.9:** the Actions' `highlightStore`
> was built from `APIClient.shared` rather than the **injected** client, so the Actions' DI seam did
> not reach the new code and none of this was testable. Fixed — the store is now built from `api`.

## Phase gates

```
npm run ios:build-check          # from repo root
cd iphone && swiftlint
```
Launching the app and committing iPhone code remain explicit user calls.

- [x] `npm run ios:build-check -- --test` — **TEST SUCCEEDED**, iPhone 17 Pro / iOS 26.5:
      **196 passed, 0 failed, 0 skipped** (baseline before this phase: 85). Run fresh 2026-08-04.
- [x] `cd iphone && swiftlint` — **zero violations in any file this phase added or rewrote.**
      Repo-wide total 985, DOWN from 990 at the phase's start (dead code removed). One conscious
      rule exemption, `ScrollLockCoordinator.swift` in `async_after_choreography` (09 §C-c).

## Verification checklist

- [x] Exactly **one** word-snapper exists in the app — ✅ one definition
      (`HighlightSnapping.swift:77`). **Two callers, not three, and that is correct:**
      `TextSelectionController.commit` (Exegesis) and `BibleReaderOverlay` (reader). The Read editor
      never asks for word snapping — it is verse-granular via `VerseTapPolicy`. The checklist's
      "three callers" assumed otherwise. Consequence recorded as **09 §G-s**: verse granularity has
      two implementations, so the injection is real for `.word` and vestigial for `.verse`. No
      behaviour bug; a design question left open deliberately.
- [x] No `asyncAfter`-driven selection commit anywhere in the three surfaces — ✅ zero `asyncAfter`
      in all three surface files and in `TextSelectionController` (its only mention is the comment
      saying a timer here would be the bug). The commit path cannot be timer-driven by construction:
      `SelectionCommitPolicy` takes no time input at all.
- [x] ~~Read editor: tap-a-verse still selects~~ — **THIS ROW WAS STALE and is corrected, not
      ticked as written (found by the verify sweep, 2026-08-05).** Tap-a-verse selection was
      **deliberately removed** by §X-q on 2026-08-04, at Luke's request, when the Read editor moved
      to tap-and-hold **word** selection to match Exegesis. A tap now only re-opens an existing
      highlight. Corrected expectation, confirmed in his walk: tap-and-hold selects a word, extend
      works, the style picker still opens
- [x] Exegesis editor: drag-and-hold commits **only** on release; notes still open and save —
      human-walked (Luke, 2026-08-05); also the exact behaviour §X-p/§X-p2/§X-p3 were fixed for, and
      he separately confirmed on a device that it no longer commits early or jumps
- [~] Bible reader: selection still yields a passage reference; verse circles still work; **no
      scroll jump** during a drag (the carried machinery is doing its job) — **covered only by a
      blanket "everything works", not by a narrated observation of this surface.** The Bible reader
      is the least-exercised of the three and the one whose scroll-lock machinery was carried over
      wholesale (D-b). Left `[~]` rather than ticked, because claiming a specific observation here
      would be inventing one
- [x] Saved highlights render lime `@0.35`, live drag `@0.55`, on every surface — the saved value is
      measured in pixels on two surfaces (phase 6.2/6.3) and the live `@0.55` in 6.8, distance 0
      from the contract; Luke confirmed the rendering by eye in his walk
- [x] `/transition-review` → **PASS** 2026-08-04. No failures in sections A–D or G. Two WARNs, both
      pre-existing behaviour carried verbatim and each evidenced against `HEAD`: the one-runloop
      defer before assigning `pendingRange` (C2 — it is not animation choreography, and removing it
      re-introduces a mid-update assignment), and `ScrollLockCoordinator`'s `asyncAfter` (E1 — the
      accepted exemption). B2 came out *stronger* than before: the note editor's drafts now seed
      from `AppState` rather than a view-local dictionary.
- [x] Contract parity — ✅ traced field-for-field against 03 §2. `ListBody` decodes
      `success / blockIds / highlights / error`; `CreateBody` adds `absorbedIds`; `ContentHighlight`
      carries `id, readBlockId, orderNumber, start, end, style, noteMarkdown, createdAt, updatedAt`,
      the frozen table's names exactly. POST sends `readBlockId / start / end / style / noteMarkdown`;
      PATCH sends only the fields given. **The deprecated singular `readBlockId` is not declared on
      any response type**, so it cannot be consumed by accident.

**The four unticked rows are behavioural and need a human on a simulator.** No agent can tap a verse
or drag and hold. They are the phase-4 half of 08's human-verification script, and they are the
reason this phase is signed on agent evidence rather than called done.

## REOPENED — 2026-08-04

⚠️ **The VERIFIED sign-off below is withdrawn.** Luke used the Exegesis editor and hit **09 §X-p**:
the first long press commits a highlight *before the finger lifts*, and a second attempt is needed
— monday#12708759849, re-created by the refactor built to remove it.

The sign-off's first non-claim was "nobody has used it". That turned out to be the load-bearing
sentence: one line of gesture wiring (`observer.delegate = self`) was lost when 4.4 moved the touch
observer into `TextSelectionController`, and no gate could see it, because every test drives the
commit policy directly and never involves a gesture. The policy was correct the whole time; what
broke was which events reached it.

Then two more of exactly the same kind turned up — **09 §X-p2** (the page jumps back to the previous
highlight's scroll position when you start a second one) and **09 §X-p3** (re-highlighting a span
you already highlighted once does nothing, silently, forever). All three are one signature: 4.4
moved the behaviour's *code* and left its *call* behind. §X-p3 was found by sweeping for the
pattern rather than by a human hitting it; the method is written up as **09 §C-d**.

**Build evidence, 2026-08-04** (Luke approved a build-check, no simulator launch): `BUILD SUCCEEDED`
including the baseline-gated SwiftLint phase — zero new violations, none in any touched file — and
**200 tests, 0 failures** (196 + 4 new). The touch observer's delegate is asserted at runtime and
passes.

### RE-VERIFIED — 2026-08-04, and this time by a human

**Luke, on a real device: "it's working without jumping right now."**

That settles **§X-p2** directly (the jump was the reported symptom) and **§X-p** by implication —
the create-highlight flow works, so it is no longer committing under the finger. It is also the
**first human confirmation of anything in this phase**: the original sign-off's leading non-claim
was "nobody has used it", and three regressions were living behind that sentence.

**Still not confirmed, and not to be quietly folded into the above:**

- **§X-p3** — needs the specific sequence *highlight → delete → highlight the same words again*.
  Fixed and unit-covered; nobody has performed it.
- **§G-o** — the purple → lime change on the **Read** editor. The Exegesis editor was already lime,
  so using it proves nothing about the surface that actually changed.
- **§X-m** — the Bible reader still commits via its Select button, deliberately.

### Amendment — 2026-08-04, Read editor granularity (09 §X-q)

Luke: *"I should be able to tap + hold to highlight just like exegesis… All I can do is tap a verse
to highlight the entire verse."* Not a regression — `.verseTap`/`.verse` was what `03 §5` specified
and what the pre-refactor view did — but the settled design could not express a phrase inside a
verse. Now `.nativeDrag`/`.word`. `03 §5` amended in place, dated. BUILD SUCCEEDED, 200 tests / 0
failures; **the gesture itself is untested by hand.** Whole-verse tap-to-select is removed rather
than kept alongside, and the scroll lock runs on this surface for the first time. **09 §X-r — the
web Read pane diverging — was raised and RESOLVED the same day:** Luke chose consistency, and the
web twin was ported to the identical drag model.

## VERIFIED

✅ **2026-08-04 (agent evidence — NOT human-tested).**

**Gates, run fresh:** `ios:build-check --test` → TEST SUCCEEDED, **196 passed / 0 failed / 0
skipped** on iPhone 17 Pro / iOS 26.5 (85 before this phase). `swiftlint` → **zero violations in
every file this phase added or rewrote**; repo-wide 985, down from 990.

**What exists now that did not before.** One highlighting service — `iphone/MakeReady/Services/Highlighting/`,
8 files — owning positions, snapping, colours, the selection lifecycle, the scroll lock, the store,
the shared text view and note drafts. All three native surfaces use it. The three word-snappers are
one. The five highlight colours are one policy. No surface commits a highlight on a timer, and that
is true *by construction* rather than by tuning: the commit policy takes no time input.

**Net effect on the two views this replaced:** `ExegesisVerseView` 1,025 → 93 lines,
`SelectableLockedBlockView` 366 → 99. Both keep their public shape, so every call site and the
capture `ViewRegistry` compile untouched.

**Tests were checked for the ability to FAIL, on every batch** — 4 injected regressions across the
phase (selection-change scheduling a commit; apostrophes dropped from the word set; live selection
painted before saved spans; an inside-tap extending instead of committing; unsaved drafts dropped on
merge), each caught by exactly the right tests, each reverted.

**Signed with four non-claims, stated plainly:**

1. **No human has used any of it.** Four checklist rows — verse tap, drag-and-hold, the reader's
   passage flow, and the colours on screen — are behavioural and unticked.
2. **The one member-visible change has not been seen by anyone.** The Read editor's saved spans are
   lime instead of opaque purple; verified only by construction (09 §G-o). The capture fixture that
   would show it is phase 6's.
3. **Scroll-jump behaviour is unverified.** The carried machinery compiles and is wired; whether it
   still prevents the jump needs a device (09 §C-c).
4. **The Bible reader adopted three of the four things 4.13 listed.** The selection controller was
   deliberately not adopted — that surface commits on a Select button, not on release (09 §X-m).

Open rows this phase leaves behind: **09 §G-s** (verse granularity has two implementations —
design question, no bug) and **09 §G-o** (the colour change, awaiting eyes). Nothing is committed;
iPhone commits need explicit approval.
