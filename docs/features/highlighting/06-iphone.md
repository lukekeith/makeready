# iPhone

The app where the service actually lives, and where all three native highlight surfaces converge.

## The service — `iphone/MakeReady/Services/Highlighting/` (new)

| File | Contents |
|---|---|
| `HighlightRange.swift` | the position type + absolute ↔ verse-relative conversion (absorbs `HighlightRange` from `StudyModels.swift:943`) |
| `HighlightSnapping.swift` | `enum Granularity { case verse, word, character }` + one snapping implementation |
| `HighlightRenderer.swift` | attributed-string painting for `.live` / `.saved` / `.active` / `.used`, using 03 §5's colours |
| `TextSelectionController.swift` | the gesture lifecycle: `TouchObserverGestureRecognizer`, commit on genuine release, granularity injected |
| `HighlightStore.swift` | `protocol HighlightStore` + the program/enrollment implementations |
| `HighlightableTextView.swift` | the single `UIViewRepresentable` the surfaces mount |

### Snapping — one implementation, two deletions

`Utilities/VerseSelectionLogic.swift:100` already defines `snapToWordBoundaries` and has **zero
callers**. It becomes the single implementation (moved into `HighlightSnapping` or called by it),
with the `c8a0311` semantics winning per D9: `'` `’` `-` are intra-word, so "Lord's" stays whole.

Delete on adoption:
- `ExegesisVerseView.snappedToWordBoundaries` (added by `c8a0311` today — this spec's own cleanup)
- the inline copy at `BibleReaderOverlay.swift:1796-1825`

### Selection lifecycle — generalised from `c8a0311`

Commit fires when the touch count reaches zero — a genuine release — never on a timer, never on
`touchesCancelled` (which UIKit delivers while the finger is still down, the cause of
monday#12708759849). `TouchObserverGestureRecognizer` never recognizes and stays `.possible`
forever so UIKit keeps delivering it the whole sequence.

> **Carry-over risk:** `ExegesisVerseView` entangles selection with ~10 scroll-lock/anchor state
> vars (`freezeEnclosingScroll`, `nativeSelectionScrollAnchor`, `preserveScrollWorkItems`,
> `ignoresEmptySelectionUntilScrollFreezeRelease`, …) that exist to stop the enclosing ScrollView
> jumping during a native selection. The controller must carry this behaviour or drop it
> deliberately — silently losing it reintroduces scroll jump, which is not currently reported and
> must not become newly broken.

## Adopting surfaces

| Surface | Granularity | Adopts | Keeps |
|---|---|---|---|
| **Read editor** — `EditReadActivityPage` + `SelectableLockedBlockView` | `.verse` | renderer, store, controller (verse policy = today's tap-to-select behaviour expressed through the shared controller) | its verse-tap UX, the highlighter-glyph entry point, the hint row, the style picker |
| **Exegesis editor** — `EditExegesisActivityPage` + `ExegesisVerseView` | `.word` | everything | notes UI, the highlight action menu, `ExegesisNoteEditorPage` |
| **Bible reader** — `BibleReaderOverlay` | `.word` | `HighlightRange`, snapping, renderer, controller (D5) | its overlay chrome, verse circles, and **its output: a passage reference, not a Highlight row** |

`SelectableLockedBlockView` and `ExegesisVerseView` either become thin wrappers over
`HighlightableTextView` or are replaced by it. Prefer wrappers first so the capture
`ViewRegistry` cases keep resolving.

## AppState & Actions

- **Model**: `ExegesisHighlight` → `Highlight` in `Pages/Manage/Program/Models/StudyModels.swift:380`,
  gaining `style`. `ReadBlockSelection` (`:372`) is retained — it still decodes the derived
  projection that older payloads carry.
- **Storage**: highlights are server data keyed by id and readable by more than one screen →
  `EntityStore<Highlight>` on `AppState`, not view `@State`. Add to `clearInMemory()` — org-scoped
  data left behind leaks into the next session. The SwiftLint rule
  `server_collection_in_view_state` enforces the storage half of this.
- **Actions**: the eight near-identical methods
  (`ProgramActions+Activities.swift:312-384`, `EnrollmentActions.swift:886-958`) collapse behind
  `HighlightStore`, which plugs into the **existing** `ReadActivityActionProvider` /
  `ExegesisActivityActionProvider` seams (D11 — those already solve program-vs-enrollment
  correctly; don't replace them). Actions still mutate `AppState` and return `Void`.
- **Note keying** — `EditExegesisActivityPage.highlightNoteKey` is `"location:length"`, which every
  merge invalidates. Re-key by **highlight id**. This is the likely resolution of
  monday#12708759849 sub-issue A (04 §Prerequisite).

### Disk cache

`AppState` persists to disk. A build upgrading mid-flight must not decode a cached old-shape
payload into `Highlight`. Bump the persisted-state version (or make `style` optional with a
`"highlight"` default) so an old cache degrades rather than fails.

## Component coverage

| View element | Component | Status |
|---|---|---|
| Verse text + highlights, all surfaces | `HighlightableTextView` | **(new)** — contract above |
| Style chooser | `StylePickerMenu` | exists (`Components/Overlays/StylePickerMenu.swift`) |
| Highlight action menu | `ExegesisHighlightModal` | exists |
| Note editor | `ExegesisNoteEditorPage` | exists |
| Highlight-mode hint row | plain `Text` + `Typography.s12Medium` | exists |
| Card chrome around blocks | `SwipeableCard` | exists — **shared by 14 screens**, do not modify |

Spec approval is approval to build the **(new)** rows.

## Gates

```
npm run ios:build-check                 # from repo root
cd iphone && swiftlint
```
Launching the app, archiving and committing iPhone code remain explicit user calls.
