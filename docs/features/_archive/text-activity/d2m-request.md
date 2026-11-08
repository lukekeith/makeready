# d2m request: editor and player changes (text-activity, SPEC D33)

Subjects: `ActivitiesEditorScreen`, `ActivitiesPlayerScreen`. Branch: `builder/text-activity`.
Why: the editor keeps its draft in private `@State` (`ActivitiesEditorScreen.swift:161-176`) and holds
swatch names, so a container cannot build a document on Done. The container carries every document field
the screen does not edit through unchanged (SPEC D33), so nothing below asks the screen to hold them.

## The four D33 items

1. **Object-edit callback (D33 item 1; SPEC §iphone Editor wiring).** `ActivitiesEditorScreen` reports each
   object edit through one callback carrying the object index and the changed fields: text, font, weight,
   size, color, alignment, width, transform.
2. **Colors as hex (D33 item 2; D18 fonts unchanged).** `State` and the callback carry colors as hex strings
   (`#RRGGBB`), not swatch names. C-094 swatches stay as presets that resolve to hex.
3. **Play glyph (D33 item 3; D22).** A play glyph in the editor's Idle header with its callback; the
   container opens the viewer on the current activity.
4. **Load-failed state (D33 item 4).** A load-failed state on both `ActivitiesEditorScreen` and
   `ActivitiesPlayerScreen`: an error banner, then pop (the screen calls its back/close closure).

Out of scope: `showsHighlightTool`, `showsEffectsTool`, `showsEyedropper` stay as they are (D17).

## Result

Change ids: editor `cmw73admc0003v05pnqf5e0ki` (done), player `cmw73vfxl000ov05pfs8ktiv6` (done; the
first request did not touch the player, so a second request covered it). d2m wrote its edits into the
main checkout, uncommitted; they were copied into this branch (same base) with the test.

Returned names, for Tasks 24-27:

- `ActivitiesEditorScreen.onEditObject: (ObjectEdit) -> Void`, replacing `onTransformObject`.
  `ObjectEdit { index: Int; text: String?; font: String? (display|sans|serif|mono); weight: Int? (400|500|700);
  size: CGFloat? (wu); color: String? (#RRGGBB); alignment: String? (center|left|right); width: CGFloat?;
  transform: Transform? { x, y, scale, rotation } }`, only changed fields non-nil. Add and delete are not edits.
- `State`: parallel arrays `objectTexts/Fonts/Colors/Weights/Sizes/Alignments/ListStyles/StartNumbers/Xs/Ys/
  Scales/Rotations/Widths/Heights`; `objectColors` are `#RRGGBB` ("" = default); `editingIndex: Int` (-1 none)
  replaces the `draft*` fields; `loadFailed: Bool`. Preview states: `.idlePopulated`, `.idleEmpty`, `.idleLong`.
- `onPlay: () -> Void`: C-102 play glyph in the Idle header.
- Load-failed: `onLoadFailed: (String) -> Void` called with "Couldn't load this activity.", then `onBack`
  after 2 s (editor). `ActivitiesPlayerScreen.State.loadFailed` + `onLoadFailed`, then `onClose` after 2 s.
