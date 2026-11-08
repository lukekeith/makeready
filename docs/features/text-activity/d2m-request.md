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

Change id: (filled when d2m returns)
Returned names: (filled when d2m returns)
