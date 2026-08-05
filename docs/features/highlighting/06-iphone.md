# iPhone

The app where the service actually lives, and where all three native highlight surfaces converge.

## The service — `iphone/MakeReady/Services/Highlighting/` (new)

| File | Contents |
|---|---|
| `HighlightRange.swift` | the position type + absolute ↔ verse-relative conversion (absorbs `HighlightRange` from `StudyModels.swift:943`) |
| `HighlightSnapping.swift` | `enum Granularity { case verse, word, character }` + one snapping implementation |
| `HighlightRenderer.swift` | attributed-string painting for `.live` / `.saved` / `.active` / `.used`, using 03 §5's colours — **plus `.editing` and `.preview`** (see below) |
| `TextSelectionController.swift` | the gesture lifecycle: `TouchObserverGestureRecognizer`, commit on genuine release, granularity injected |
| `HighlightStore.swift` | `protocol HighlightStore` + the program/enrollment implementations |
| `HighlightableTextView.swift` | the single `UIViewRepresentable` the surfaces mount |

### Rendering — six appearances, four of them normative

*(added 2026-08-04 while building 4.3 — the four-case list would have silently dropped two shipped
appearances when the surfaces are wrapped at 4.11/4.12. Recorded as 09 §G-n; `03` is untouched.)*

| Appearance | Value | Scope |
|---|---|---|
| `.saved` | `#F4FF76` @ 0.35 | **cross-app** (03 §5) |
| `.live` | `#F4FF76` @ 0.55 | **cross-app** (03 §5) |
| `.active` | white @ 0.25 | **cross-app** (03 §5) — the *transient tap-selection* wash (`ExegesisVerseView.swift:113`), not the being-edited highlight |
| `.used` | `#6c47ff` @ 0.2 | **cross-app** (03 §5) — Bible reader only, and it does not mean "highlight" |
| `.editing` | opaque white + black text | **iOS editor chrome** — the highlight open in the note editor (`ExegesisVerseView.swift:586`, `SelectableLockedBlockView.swift:150`) |
| `.preview` | white @ 0.9 + black text | **iOS editor chrome** — the read-only preview rendering (`usePreviewHighlightStyle`; live caller `ExegesisNoteEditorPage.swift:271`) |

The web player has no state corresponding to the last two, which is why they are app-local rather
than contract rows. `style: "bold"` is font weight only, no wash, on every appearance (03 §5).

**The Read editor's saved spans change colour** — they are opaque `#6c47ff` today
(`SelectableLockedBlockView.swift:139` `editMarker`), not lime. That is the intended member-visible
change, tracked as 09 §G-o so it is not "fixed" back.

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

> **DECIDED (Luke, 2026-08-04): carry it.** The shared controller absorbs the scroll-lock
> machinery rather than dropping it — nobody loses working behaviour, at the cost of a heavier
> controller. Budget for it in the phase estimate: it is 10 of the view's 22 lifecycle state vars.
>
> **Carry-over detail:** `ExegesisVerseView` entangles selection with those ~10 scroll-lock/anchor
> state vars (`freezeEnclosingScroll`, `nativeSelectionScrollAnchor`, `preserveScrollWorkItems`,
> `ignoresEmptySelectionUntilScrollFreezeRelease`, …) that exist to stop the enclosing ScrollView
> jumping during a native selection. The controller must carry this behaviour or drop it
> deliberately — silently losing it reintroduces scroll jump, which is not currently reported and
> must not become newly broken.

## Adopting surfaces

| Surface | Granularity | Adopts | Keeps |
|---|---|---|---|
| **Read editor** — `EditReadActivityPage` + `SelectableLockedBlockView` | `.word` *(was `.verse` until 2026-08-04 — 09 §X-q)* | renderer, store, controller, **and the same `.nativeDrag` input model as the Exegesis editor** | the highlighter-glyph entry point, the hint row, the style picker. **NOT its verse-tap UX — that is removed**, so a tap now only reopens an existing highlight |
| **Exegesis editor** — `EditExegesisActivityPage` + `ExegesisVerseView` | `.word` | everything | notes UI, the highlight action menu, `ExegesisNoteEditorPage` |
| **Bible reader** — `BibleReaderOverlay` | `.word` | `HighlightRange`, snapping, renderer, controller (D5) | its overlay chrome, verse circles, and **its output: a passage reference, not a Highlight row** |

**DECIDED (Luke, 2026-08-04): wrap first, replace later.** `SelectableLockedBlockView` and
`ExegesisVerseView` become thin wrappers over `HighlightableTextView`, so the capture
`ViewRegistry` cases keep resolving and the harness never breaks mid-phase. Replacing them
outright is a follow-up, not part of this feature.

## AppState & Actions

- **Model**: `ExegesisHighlight` → `ContentHighlight` in `Pages/Manage/Program/Models/StudyModels.swift:380`,
  gaining `style`. `ReadBlockSelection` (`:372`) is retained — it still decodes the derived
  projection that older payloads carry.
- **`blockIds[]` (03 §2.1)**: the Read editor is the multi-block consumer — an activity can hold
  several locked verse blocks, so it resolves each highlight to its block via
  `highlight.readBlockId` and uses `blockIds` for ordering/empty-state. **Never read the deprecated
  singular `readBlockId` off the response** — it names only the first block.
  *(added 2026-08-04 — the integrity check found 03 introduced this field with no consumer doc
  explaining who reads it.)*
- **Storage**: highlights are server data keyed by id and readable by more than one screen →
  `EntityStore<ContentHighlight>` on `AppState`, not view `@State`. Add to `clearInMemory()` — org-scoped
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
payload into `ContentHighlight`. Bump the persisted-state version (or make `style` optional with a
`"highlight"` default) so an old cache degrades rather than fails.

## Component coverage

| View element | Component | Status |
|---|---|---|
| Verse text + highlights, all surfaces | `HighlightableTextView` | **(new)** — contract above |
| Style chooser | `StylePickerMenu` | exists (`Components/Overlays/StylePickerMenu.swift`) |
| Highlight action menu | `ExegesisHighlightModal` | exists |
| Note editor | `ExegesisNoteEditorPage` | exists |
| Highlight-mode hint row | plain `Text` + `Typography.s12Medium` | exists |
| Card chrome around blocks | `SwipeableCard` | exists — referenced by **13 files: 10 production screens, 2 demo pages, 1 layout wrapper** (`SwipeableScrollView`). Do not modify *(corrected 2026-08-04 — "14 screens" counted the component's own file and did not separate demos)* |

Spec approval is approval to build the **(new)** rows.

## Gates

```
npm run ios:build-check                 # from repo root
cd iphone && swiftlint
```
Launching the app, archiving and committing iPhone code remain explicit user calls.
