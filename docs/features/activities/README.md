# Activities — Vertical-Paging Member Lesson Experience

**Status:** ANALYSIS / RECOMMENDATION (no code yet — feeds a future `/build-spec-draft activities`)
**Date:** 2026-08-09
**Sources:** two YouVersion screen recordings (Guided Prayer 27s, Guided Scripture 22s), frame-by-frame
analysis (4fps overview + 15fps motion windows + full-res indicator crops), plus a full codebase survey
of the current lesson stack across server/client/iphone.

## What this is

A ground-up redesign of the **member lesson experience**: a full-screen, vertically-paged player where
each page is one activity, content choreographs into view after the page settles, a dot-rail indicator
replaces the scrollbar, completion is celebrated with a drawn checkmark + streak page, and the lesson
dismisses with a swipe-up. The **leader edit experience renders the exact same player** — tap what you
want to edit; the separate preview system is retired.

## Reference behavior (from the recordings)

- **Guided Prayer** (video 1): one shared fixed photographic backdrop for the whole lesson; six text
  pages scroll over it; narration-synced word-by-word reveal on the closing page; checkmark draw
  animation; over-scroll swipe-up dismisses the sheet.
- **Guided Scripture** (video 2): per-page backgrounds (black video → white article → dark quote pages);
  autoplaying video activity that can be swiped past; long scrolling article; Bible verse, encouragement,
  prayer pages; "Add to Prayer List" opens a bottom sheet; completion page shows a streak counter and
  the next lesson.

## Doc suite

| Doc | Contents |
|---|---|
| [01-video-analysis.md](01-video-analysis.md) | Frame-level findings: page inventory, chrome, typography, indicator mechanics, every transition timed |
| [02-current-architecture.md](02-current-architecture.md) | What exists today (server models, web player, iPhone reality, both theme players, preview machinery) and what carries over |
| [03-proposed-architecture.md](03-proposed-architecture.md) | The vertical pager: scroll-snap structure, page lifecycle state machine, data-model changes, progression & completion |
| [04-theming-system.md](04-theming-system.md) | Token-based theme system replacing the timed-slide theme players; lesson backdrop vs per-page backgrounds |
| [05-animations-and-transitions.md](05-animations-and-transitions.md) | The full motion spec with timings/curves: page snap, content entrance, word reveal, checkmark, dismiss |
| [06-activity-types.md](06-activity-types.md) | Catalog of the seven authorable types (video, image, bible, text, write, youtube, exegesis) with content shape + player/editor behavior |
| [07-edit-in-place.md](07-edit-in-place.md) | Editor = player + edit layer; what replaces the preview system; migration path for `PreviewToken`/`PreviewState` |
| [08-open-questions.md](08-open-questions.md) | Decisions needed before speccing (enum migration, streak model, narration, offline video rules) |
| [09-native-ios-player.md](09-native-ios-player.md) | The native SwiftUI/UIKit pager (leader edit canvas + walkthrough): scroll/snap approach, entrance choreography, rail, exegesis reuse, parity discipline with the Vue twin |
| [10-text-editing-analysis.md](10-text-editing-analysis.md) | Instagram post + story text editors, frame-by-frame: the preferred control-row + contextual-options-strip menu pattern, full feature/behavior spec, engineering requirements, and the Figma translation contract |
| [11-notes-editor-analysis.md](11-notes-editor-analysis.md) | iPhone Notes app note-writing UX, frame-by-frame: the full-width no-box canvas, the horizontally scrollable format strip above the keyboard (stateful toggles, popover pickers), list/selection/styling behaviors, and the WRITE-activity translation contract |

## Non-negotiables distilled from the ask

1. Vertical paging, one activity per page, finger-tracked and interruptible.
2. Content **enters after the page settles** (the page arrives empty; content fades/rises in).
3. Bottom-right dot rail: one dot per activity; the current dot stretches into a capsule whose inner
   thumb shows scroll position **within** the activity.
4. Action buttons inside activities (e.g. "Add to Prayer List").
5. Completion: checkmark draws, circle traces around it; streak + up-next page; swipe-up to dismiss.
6. Exegesis abandons the split-screen: tapping a highlight opens a **floating, draggable note card**
   that never blocks scrolling — dozens of highlights on a long passage must stay usable.
7. **No preview feature.** The edit experience *is* the player; tap to edit in place.

## Platform strategy (decided 2026-08-09)

The iPhone app stays **100% native** — UIKit and/or SwiftUI, whichever fits each task — with
WebView avoided wherever possible. **Members will not access their content from the iPhone app
(not anytime soon)** — members live on the web. This feature therefore builds **two player
implementations against one server contract, for two audiences**:

- **Web (Vue)**: the **only member runtime** — where lessons are actually taken and progress is
  recorded. Designed to mimic the native experience's look and motion.
- **iPhone**: a native pager (09) serving **leaders**: the edit-in-place canvas and a faithful
  walkthrough of what members will see. It never records member progress (which also removes
  any need for a `PreviewState`-style synthetic-progress replacement).

Leaders on iPhone keep a **native, management-optimized** experience — they do not edit or view
the Vue player. Edit-in-place (07) applies per platform: the web editor renders the Vue pager;
the iPhone editors render the native pager. Parity between the two pagers is verified with the
existing `/compare` pipeline.
