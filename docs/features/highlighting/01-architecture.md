# Architecture

## Overview

Today three native surfaces let a user select text and turn it into a highlight, and each one
implements the whole stack itself — gesture lifecycle, snapping, rendering, persistence. They
disagree on every axis. This feature extracts one service, converges the stored shape onto one
table, and has all three surfaces adopt it.

### What exists today (the divergence, measured)

| | **Read activity editor** | **Exegesis activity editor** | **Bible reader** |
|---|---|---|---|
| Files | `EditReadActivityPage.swift` + `SelectableLockedBlockView.swift` | `EditExegesisActivityPage.swift` + `ExegesisVerseView.swift` | `BibleReaderOverlay.swift` (2,165 lines) |
| Gesture | hand-rolled tap: verse → extend → tap inside to commit | native `UITextView` long-press drag | native drag + verse-circle taps |
| Granularity | whole verses | character → word (`c8a0311`, today) | word |

> **The Read column's "whole verses" describes the BEFORE state and is still accurate as history.**
> The target state changed on 2026-08-04: the Read editor is now `word` too (09 §X-q, and D4 below
> is superseded).
| Snapping impl | none | `ExegesisVerseView.snappedToWordBoundaries` | inline copy, `BibleReaderOverlay.swift:1796-1825` |
| Stored shape | `ReadBlockSelection{start,end,style}` in a JSON array | `ExegesisHighlight` rows + `noteMarkdown` | `HighlightRange{startElementId,startOffset,…}` |
| Coordinates | absolute char offsets | absolute char offsets | verse-relative |
| Saved colour | `#6c47ff` solid | `#F4FF76 @0.35` | `#6c47ff @0.2` ("used") |
| Live colour | `#F4FF76 @0.55` | `#F4FF76 @0.55` | system tint |
| Commit | explicit confirm tap | 0.5s/0.8s timers → finger-lift (`c8a0311`) | selection → passage reference |
| Notes | ✗ | ✓ | ✗ |

**Three word-snappers, and the canonical one is dead.**
`Utilities/VerseSelectionLogic.swift:100` defines `snapToWordBoundaries` with **zero callers**;
the Bible reader carries an inline duplicate; `c8a0311` added a third. Two of them disagree on real
input — the shared/Bible version treats all punctuation as a word break, so "Lord's" snaps to
"Lord", while the `c8a0311` version treats `'` `’` `-` as intra-word and keeps "Lord's" whole.

**Five colours mean "a highlight"** (listed above), and brand purple does double duty as both the
app's accent colour (buttons, active borders, the highlight-mode card outline) and the highlight
itself.

### The target

Five layers in `iphone/MakeReady/Services/Highlighting/` (new), in dependency order:

| Layer | Responsibility | Replaces |
|---|---|---|
| `HighlightRange` | one position type + absolute ↔ verse-relative conversion | `HighlightRange` (bible), raw `NSRange` juggling in both editors |
| `HighlightSnapping` | `.verse` / `.word` / `.character` policy, one implementation | 3 copies (one dead, two divergent) |
| `HighlightRenderer` | attributed-string painting for `live` / `saved` / `active` / `used` states | 3 colour schemes, and the paint-vs-clip-mask class of bug |
| `TextSelectionController` | the gesture lifecycle: touch-observer, live-until-real-lift, snapping injected | the timer commit (`12708759849`) and the hand-rolled tap logic |
| `HighlightStore` | persistence behind the existing `*ActivityActionProvider` seams | 8 near-identical Action methods across program/enrollment |

`HighlightableTextView` is the single `UIViewRepresentable` the surfaces mount.

## Decisions

| # | Decision | Rationale | Decided by |
|---|---|---|---|
| D1 | All four apps are in scope — converge the stored data model, not just the client layer | A client-only service leaves two stored shapes and the next person still meets both | **Luke** |
| D2 | Promote `exegesis_highlights` → `content_highlights` (**not** `highlights` — taken by the Bible reader's verse highlights; 09 §X-g, decided 2026-08-04), add a `style` column, keep absolute character offsets | Smallest migration that genuinely converges; the merge/note logic already lives in this table; no consumer re-codes coordinate math | **Luke** |
| D3 | Migration is **additive-only**. `ActivityReadBlock.selections` is never dropped by this feature — it becomes a server-derived projection. Dropping it is a separate, later, gated change | Shipped TestFlight builds read `selections` and must keep working; retaining it also makes rollback trivial. The projection mechanism already exists (`syncExegesisSelectionsForBlock`, `programs.ts:2894`) | Claude, elevated to a hard constraint by **Luke** |
| D4 | ~~One service; **granularity is injected per surface** — `.verse` for Read, `.word` for Exegesis and the Bible reader~~ **SUPERSEDED 2026-08-04 (09 §X-q, Luke): every editing surface is `.word` with tap-and-hold drag.** Granularity stays injected — `.verse` is still used by the non-native Exegesis path — but no surface chooses it any more. The original rationale below turned out to be the wrong call: Read's verse-tap model was not worth preserving, because it could not express a phrase inside a verse. Luke, reversing it: *"I dont' want the verse tapping, I want consistent highlighting."* | ~~Consistency belongs in the mechanism (where every bug was), not in forcing Read's deliberate verse-tap model into a drag~~ | **Luke** (reversed by **Luke**, 2026-08-04) |
| D5 | The Bible reader adopts the **full interaction service** — same controller, snapping and renderer — while its commit still produces a *passage reference*, not a Highlight row | Adopting the service and authoring a highlight record are different things; conflating them was an error in the first draft | **Luke** (revised) |
| D6 | A saved highlight renders `#F4FF76 @0.35`; the live drag stays `@0.55` | One colour family, so what you see while dragging is what you get; frees brand purple to mean only "accent / active state" | **Luke** |
| D7 | Web gets **normative rules in `03`**, not a mirrored TypeScript module. The LeaderApp's deferred highlight authoring stays deferred and implements these rules when built | Keeps the standard authoritative without doubling the build; web currently only *renders* highlights | **Luke** |
| D8 | **Sub-issue A of monday#12708759849 is a prerequisite** — reproduced, fixed and verified before any backfill runs | The merge path deletes absorbed rows (`programs.ts:3058`). Migrating Read data into a table with an open data-loss report is unacceptable given D3's constraint | Claude |
| D9 | One snapper: `VerseSelectionLogic.snapToWordBoundaries`. The `c8a0311` semantics win — `'` `’` `-` are intra-word, so "Lord's" stays whole. Both duplicates are deleted | The two live copies disagree on real Bible text; the dead canonical one is the natural home | Claude |
| D10 | The commit-on-lift lifecycle from `c8a0311` (touch-observer recognizer, never a timer) becomes the shared controller | It is the fix for the loudest reported defect and generalises unchanged | Claude |
| D11 | `HighlightStore` plugs into the existing `ReadActivityActionProvider` / `ExegesisActivityActionProvider` seams rather than replacing them | Those seams already solve the program-vs-enrollment duplication correctly; replacing working abstractions is churn | Claude |
| D12 | Read-editor note UI and a per-highlight colour picker are new capabilities, deliberately excluded | Neither is a highlight surface declining to use the service; both are additions nobody requested | Claude, confirmed by **Luke** |

## Baseline patterns (cited)

- **Gesture lifecycle to generalise** — `ExegesisVerseView.swift`: `TouchObserverGestureRecognizer`
  (end of file), `handleActiveTouchCountChanged(_:)`, `commitNativeSelectionAfterLift(reason:)`.
  Note the entangled scroll-lock machinery (`freezeEnclosingScroll`, `nativeSelectionScrollAnchor`,
  `preserveScrollWorkItems` and ~7 more state vars) — it exists to fight the same UIKit behaviour
  and must be carried or consciously dropped.
- **Verse parsing already shared** — `Utilities/VerseSelectionLogic.swift`
  (`parseVersePositions`, `versesOverlapping`, `rangeForVerses`, `circleStates`).
- **Text layout already shared** — `Components/Content/BibleVerseTextLayout.swift`
  (`baseAttributedText`, `paragraphStyle`, `layoutVerseBadges`).
- **Persistence seams** — `ExegesisActivityActionProvider` (`EditExegesisActivityPage.swift:22`,
  factories `.program` / `.enrollment(lessonId:)` at `:96`) and `ReadActivityActionProvider`
  (`EditReadActivityPage.swift:14`).
- **Server merge + projection** — `server/src/routes/programs.ts:2997` (create + merge),
  `:3033-3045` (note concatenation), `:3056-3069` (transactional absorb), `:2894-2907`
  (`syncExegesisSelectionsForBlock`, the projection this feature reuses for D3).
- **Schema source of truth** — `server/schema/schema.yaml` (`ContentHighlight`, renamed from
  `ExegesisHighlight` 2026-08-04), `ActivityReadBlock.selections`
  (`ActivityReadBlock.selections`). Never edit `prisma/schema.prisma` or `atlas/.schema.hcl`.

## Permissions / RBAC

Highlights are leader-authored content on a study activity. Authorisation is inherited unchanged
from the existing exegesis endpoints — `requireAuth` plus the activity's org/creator scoping. This
feature introduces **no new permission tier** and must not widen access as a side effect: the
migration moves Read selections from a JSON column on a block the leader could already edit into
rows on the same block.

> ⚠️ Known adjacent issue: `group-leader-org-authorization` (memory) records that many endpoints
> authorize by `creatorId` only, locking out org leaders. This feature inherits that behaviour
> as-is and must not be the place it is silently changed. If the audit finds the new endpoints
> widen or narrow access, that is an `X#` row.

## Out of scope (deliberate)

| Cut | Why |
|---|---|
| Notes in the Read editor UI | The converged model makes `noteMarkdown` available to Read; nothing exposes it and nobody asked. Every surface still uses the service. |
| Per-highlight colour picker | New capability; `style` stays `highlight \| bold`. |
| Bible reader **authoring** highlight rows | The reader adopts the full interaction service (D5) but its output remains a passage reference. Making it a fourth writer of highlight data is a separate feature. |
| A mirrored TypeScript highlight module | D7 — web gets normative rules in `03` and implements them when its authoring UI is built. |
| Dropping `ActivityReadBlock.selections` | D3 — a separate, later, explicitly-gated change once adoption is proven. |
| Search-term emphasis (`GlobalSearchPage`, `CardSearchResult`) | Transient rendering of a query match, not a user-authored highlight. Different lifecycle, no persistence. |
| `MarkdownEditor` / `RichTextInput` formatting | Rich-text authoring, not highlighting. |
