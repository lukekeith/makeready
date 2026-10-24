# Activity editor — reference behavior spec

**What this folder is.** A feature-by-feature reference spec of the text-editing experience in the
screen recording `Activity editor.MP4`, written so the same behaviors can be rebuilt inside
MakeReady's own lesson/activity editor (the `activities-editor` row in `../README.md`) with a
different visual skin. The reference app is Instagram's story composer; the four PNGs in
`assets/design/` are the MakeReady design frames that will host these features.

**What it is not.** Not a screen spec of the MakeReady editor (that is `activities-editor`, still
`pending-figma`), and not a pixel spec of Instagram. It is the behavior contract: what each tool
does, what state it reads and writes, how each mode is entered and left, and how long every
transition takes.

## Source material

| File | Where | Facts |
|---|---|---|
| `Activity editor.MP4` | `~/MakeReady/Design reference/Activity/` | 1320×2868 (iPhone 16 Pro Max, 440×956 pt @3x), 60 fps, 63.5 s |
| `Blank canvas.png`, `Edit text.png`, `Edit fonrt.png`, `Edit highlights.png` | same folder; copies in `assets/design/` | MakeReady target-UI frames (880×1912) |
| `assets/reference-frames/NN-*.jpg` | this folder | 21 stills from the recording, named by what they show; indexed in `09-timestamped-outline.md` |

Analysis method: 4 fps contact sheets over the whole recording (±0.25 s timestamps), then 30 fps
windows (±33 ms) over every mode transition. Values marked **measured** come from the 30 fps
windows; everything else is ±0.25 s. Point values are converted from the 3x recording and are
±4 pt. The earlier Instagram analysis in `../../features/activities/10-text-editing-analysis.md`
covers the same editor from two other recordings; where this spec and that one differ, this one
states the difference inline.

## How the files are organized

The spec is organized by **what the user is doing**, not by UI region. Each file is self-contained
and cross-links the others.

| # | File | Covers |
|---|---|---|
| 01 | [`01-editor-model.md`](01-editor-model.md) | The text object (every property a text object carries), the four editor modes, the chrome that exists in each mode |
| 02 | [`02-adding-and-editing-text.md`](02-adding-and-editing-text.md) | Tapping the blank canvas, placeholder, typing, caret, the size slider, Done, re-editing an existing object |
| 03 | [`03-fonts.md`](03-fonts.md) | The font chip strip: the chips, the always-centered selection mechanic, self-rendered chips, the fonts observed |
| 04 | [`04-color.md`](04-color.md) | Swatch row, eyedropper well, palette paging, live recolor |
| 05 | [`05-alignment-and-label.md`](05-alignment-and-label.md) | The two instant-action tools: alignment cycle and label-background cycle |
| 06 | [`06-animations-and-effects.md`](06-animations-and-effects.md) | The two chip categories that share the strip with fonts; every option observed and what it does |
| 07 | [`07-canvas-manipulation.md`](07-canvas-manipulation.md) | Drag, pinch-scale, two-finger rotate, the center guide, drag-to-delete, chrome hiding during gestures |
| 08 | [`08-transitions.md`](08-transitions.md) | **Every mode transition, measured**: canvas tap → editor, Done → committed object, tap object → editor, category switch, gesture start/end |
| 09 | [`09-timestamped-outline.md`](09-timestamped-outline.md) | t-range → what is demonstrated, for re-extraction; reference-frame index |
| 10 | [`10-target-ui-mapping.md`](10-target-ui-mapping.md) | Reference feature → MakeReady design frame control, what the design frames add, and the open questions the mapping raises |

## Reading order for a builder

1. `01` for the object model and modes — everything else assumes them.
2. `08` for the transitions — these are the part most likely to be built wrong.
3. `02`–`07` for the tool you are building.
4. `10` before deciding where a tool lives in the MakeReady chrome.

## Scope boundary

In scope: everything a user does to a **text object** on the canvas, from the blank canvas to a
committed, transformed object. Out of scope, even though the recording shows them: Instagram's
composer chrome (POST/STORY selector, Your stories / Close Friends bar, right-hand sticker/music/@
rail, "Add a caption…", the @Mention/Location keyboard accessory, the AutoFill tooltip) and the
story-preview header that flashes during gestures. `10-target-ui-mapping.md` names what the
MakeReady frames add beyond this scope (background image tool, page strip, scripture block).

## Relationship to the UI 2.0 program

- `../README.md` screen table: `activities-editor` (iphone, pending-figma). This folder is the
  behavioral input for that spec's text tool; the screen spec still owns layout, registry rows and
  the Figma frame once one exists.
- `../../features/activities/07-edit-in-place.md` §6 (iPhone native edit-in-place) and
  `09-native-ios-player.md` own the page/pager surface this editor sits on.
- `../../features/activities/10-text-editing-analysis.md` is the prior analysis of the same
  reference editor; `09-timestamped-outline.md` here follows its §7 format.

## Open questions

Each file carries its own `Open questions` section with ids `OQ-<file>-<n>`. `10-target-ui-mapping.md`
collects the ones that need an owner ruling before the `activities-editor` screen spec can close.
