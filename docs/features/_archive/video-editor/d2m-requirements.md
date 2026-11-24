# Video Editor — screen requirements

iPhone, full screen. Condensed from `docs/features/video-editor/SPEC.md`, which wins on any difference
(D-numbers are its §Decisions rows). Look and motion: `docs/features/video-recording/01-youtube-1-analysis.md`
§6–§7, drawn in UI 2.0 tokens. No Figma.

## Purpose

From the video recorder's Review, a leader adds timed, styled text layers and captions over the clip.
Done returns to Review; Save (on Review) later draws the layers into the file.

## Layout

- **Top bar** (D14): Cancel · Undo · Done. Undo is dimmed with nothing to undo.
- **Preview** (D20, D9): the whole frame, aspect-fit (letterboxed for landscape). Takes the video as a
  `feed` CALayer, as VideoRecorderScreen does. Layers are drawn in the frame's own rect with C-092;
  1 wu = the frame's short side / 440. A layer may extend past the frame and is clipped. A layer is
  drawn only while the playhead is inside its window. Order: captions first, then text layers oldest
  to newest (D25).
- **Timeline** (D3, D24): play/pause, ruler in seconds, one 44 pt track per text layer (newest on
  top), one shared track for all captions, a filmstrip of the video, a fixed centre playhead.
  Dragging the timeline scrubs. The selected track shows end handles: dragging one trims that end,
  dragging the bar slides the window.
- **Toolbar**: Text · Captions. With a layer selected: Deselect · Split · Edit · Delete (D13). Split
  is at 40 % opacity when disabled.

## Behaviour

- Text layers: drag moves, pinch scales, twist rotates, drag to the delete target deletes (D1). While
  moving: C-091's centre guide and snap guides, a hatched unsafe band at the frame edges, the delete
  target (D9). Gestures, snapping and guides live in the screen.
- Text and a layer's Edit open the activities editor's text tool over the paused frame: dimmed
  backdrop, keyboard, C-093, C-094 with C-095, and its font, align and background panels, editing a
  C-092 object (D8). Done commits; empty text deletes. Text 1–200 characters (D15).
- Captions (D4, D24): one house style, lower third. Not moved, scaled or rotated on the canvas; Edit
  opens the text only, no style panels. The field allows max(200, its current length) characters.
- Captions tool (D4, D11): tap → "Transcribing…" in the toolbar → captions, or a one-line reason when
  unavailable. Tapped with captions present → offers Remove captions.
- 21st text layer: "Up to 20 text layers" (D15).
- Cancel with changes confirms with C-066, drawn in place (D14, D29).
- The limits, timing rules, undo history and transcription are the app's; the screen reports intents.

## States to capture

1. empty (no layers) · 2. layers, one selected · 3. selected, Split disabled · 4. text tool open from
Text · 5. text tool open from Edit · 6. manipulating (guides, unsafe band, delete target) ·
7. Transcribing… · 8. captions added · 9. captions unavailable (reason) · 10. Remove captions offer ·
11. 20-layer limit · 12. Cancel confirm · 13. playing · 14. landscape clip, letterboxed

## Inputs and callbacks

`State`, all as values: layers (id, kind text|caption, text, style {font key, weight, size wu, colour
hex, label none/solidDark/solidLight, alignment}, centre unit point, scale, rotation radians, startMs,
endMs), selected id, playhead ms, duration ms, playing, frame aspect, filmstrip images, canUndo,
canSplit, captions state and reason, limit message, text tool (text, style, style panels or not).

Callbacks: cancel, undo, done, play/pause, scrub, select, deselect, text, captions, remove captions,
split, edit, delete, trim start, trim end, slide, place (centre, scale, rotation), gesture ended,
text commit.

Public constants: caption house style and placement, default text style, edit slot width in wu, all
copy.

## Parts to mint

Editor timeline · layer track (text and caption looks, selected with handles) · editor toolbar ·
selected-layer toolbar · editor top bar · unsafe-band overlay. Reuse C-091–C-095 and the panels; make
video variants only where the activities page shape gets in the way (F4).

## Accessibility

Every track and toolbar control has a label naming the layer's text and window ("Title, 0:00 to 0:12").

## Not here

Reordering, restyling captions one by one, music, sound, stickers, effects, speed, voiceover, adding
clips (D6, D25). No roles: anyone who can record can edit. No server data.
