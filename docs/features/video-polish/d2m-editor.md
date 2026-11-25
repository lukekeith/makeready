# Video editor polish — d2m requirements (video-polish, owner 2026-11-24)

Change to screen `video-editor`, screen `activities-editor`, and parts C-093 TextSizeSlider, C-154
VideoEditorLayerTrack, C-156 VideoEditorLayerToolbar. Full rulings: `docs/features/video-polish/SPEC.md`
§Decisions D10–D12.

## 1. Thin size line (D11) — both editors
- C-093 TextSizeSlider becomes a vertical **1 pt `color-white-100` line** with a **12 pt white dot** at the
  current size; dot up = bigger. No wedge. Keep its 44 pt touch strip and the wedge's length (263.5 pt);
  same `(value 0…1, onChange)` props.
- Both hosts place it **fixed at the trailing edge**, shown whenever text is being edited, with **no
  dock/undock slide animation**: video-editor (VideoEditorScreen.swift:943-1098) and activities-editor
  (ActivitiesEditorScreen.swift:165, 527, 1093-1183). This retires the activities editor's leading-edge
  docking ruling (§15.2 / D30) and its `sliderDocked` state, fixture and preview. Check the trailing edge
  doesn't clash with the activities editor's rail stack.

## 2. Toolbar (D10)
- C-156 drops its **Deselect** tile; Split · Edit · Delete remain.
- The toolbar row under the timeline (C-155 or C-156) sits **16 pt** below the timeline (today the
  `.padding(.top, elementGap)` 8 pt, VideoEditorScreen.swift:217).
- No change to the empty-video tap callback; the container decides deselect vs play.

## 3. Trim handles inside the bar (D12)
- C-154's trim handles today sit 12 pt outside the bar (VideoEditorLayerTrack.swift:108-125), so at the
  clip's start or end they hang past the clip. Draw them **inside the bar's ends** so neither handle ever
  extends past the bar. C-154 stays a controlled view reporting intents; snapping is done by the app.

## Captures
Video editor selected/unselected and text editing with the new size line; activities editor text editing
with the new size line. 🔴 No capture or fixture may play any audio.
