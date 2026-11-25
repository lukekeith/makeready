# video-polish — spec
> md · no ticket · follow-on to video-recorder and video-editor (both shipped 2026-11-23/24)

## Idea

**Why.** The owner walked the shipped video recorder and editor on their iPhone and found a list of
rough edges. The recorder's control sheets pop in and out instead of behaving like the app's
action modals; Filters is a strip, not a sheet; the teleprompter switches itself on when closed
empty; Length snaps in 10 s steps; Review loops with no pause; and in the editor, trims overshoot
the clip, Deselect is a redundant button, and the text size wedge is not the control the owner
liked in the reference video.

**What success looks like.** On the owner's phone, every sheet slides up with a handle, a dark
overlay and swipe or tap-off dismissal, and slides away; Length offers Any length or a typed,
unsnapped Specify length with an optional end countdown; the teleprompter appears only when it has
text; Review and the editor play and pause on a tap; trims stop at the clip and snap to edges; the
size control is a thin line with a dot in both editors.

**In your words.** "Make sure all the modal controls are consistent with the rest of the app's
action modals in the way they support swipe to dismiss, dark overlay, animated dismissal, etc." →
D1 · "it's just a dot on a 1px white line instead of a triangular shaped scale, and it doesn't
animate to the left" → D11 · "Any length (2 min cap)" → D4 · "the input needs to auto format what
they type and prevent lengths from being entered longer than the max" → D5 · "It should only be
enabled if I actually enter something to the teleprompter." → D3 · end countdown "will be off by
default" → D6.

**The concept.** One house sheet motion for all four recorder sheets (the ActionMenuPresentation
motion), the purple Done check from the page header on the two sheets that need a Done, a Length
panel modelled on edit-options-custom-field, and a set of editor fixes — live-clamped, snapping
trims, tap-to-play, no Deselect, a thin size line shared with the Activities editor.

**How it fits today.** VideoRecorderScreen draws its four sheets inline on a bare surface with no
grabber, drag or transition, and closes them instantly on a scrim tap.[^1] The house action modal,
ActionMenuPresentation, already does the full-screen dim, slide-up, drag-or-flick dismissal and
slide-off.[^2] The purple check is C-040 PageHeader's 32 × 32 `color-accent` Done check.[^3]
Filters is C-150 FilterStrip laid over the record row; the teleprompter is C-151 in a sheet with its
own Done. Length is C-149 LengthSlider (10…120 s, 10 s steps, video-recorder D3), saved under
`videoRecorder.lengthSeconds`.[^4] `Phase.endCountdown` and C-148 CountdownNumerals already exist.
In the editor, C-154 VideoEditorLayerTrack reports unclamped trim intents and the model clamps only
on commit, so a bar draws past the clip start mid-drag.[^5] C-156's first tile is Deselect (glyph
`x`), and tapping empty video already deselects.[^6] C-093 TextSizeSlider (the wedge) is used by
both the video editor and the Activities editor. Review's VideoReviewPlayer loops by default with
no controls.[^7]

**Approaches considered.** No fork: the rulings fix the shape, and every sheet reuses the existing
house motion rather than a new one.

[^1]: iphone/MakeReadyUI/Screens/Library/VideoRecorderScreen.swift:420, :602
[^2]: iphone/MakeReadyUI/ActionMenuPresentation.swift:4-105
[^3]: iphone/MakeReadyUI/PageHeader.swift:132
[^4]: iphone/MakeReady/Services/Video/RecorderSettings.swift:13, :33
[^5]: iphone/MakeReadyUI/VideoEditorLayerTrack.swift:42-46
[^6]: iphone/MakeReadyUI/VideoEditorLayerToolbar.swift:63; VideoEditorScreen.swift:546
[^7]: iphone/MakeReady/Services/Video/VideoReviewPlayer.swift:59

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ⬜ | No change — nothing new is stored or sent; length, countdowns and teleprompter are on-device settings, and the saved video is uploaded exactly as today | — |
| client | ⬜ | No change — the web plays saved videos as any Stream video; no recorder or editor exists on the web | — |
| iphone | ✅ | Recorder sheets, Length panel, end countdown, teleprompter rules, rail labels, record-row layout, Review playback, and the editor's timeline, toolbar, tap-to-play and size control (d2m first) | §iphone |

**Sequencing:** d2m changes the d2m-built views from this spec (phase 1), the owner approves them
(memory: approve screens first), then the containers and models are wired (phase 2).

**Backward compatibility:** the iPhone app is the only consumer. A saved `videoRecorder.lengthSeconds`
is kept and shown as Specify length (D4). No server or contract change, so released builds are
unaffected.

**Blast radius:** C-093 TextSizeSlider is shared with ActivitiesEditorScreen — its captures and
tests change too (D11). The house sheet motion is reused, not edited, so other action modals are
untouched.

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Recorder sheet behaviour | All four recorder sheets — Length, Countdown, Filters, Teleprompter — present with the house action-modal motion (ActionMenuPresentation's): a full-screen `Token.scrim` dim, the sheet slides up from the bottom edge on open, a 36 × 5 `color-white-30` grabber centred `space-step-4` below the sheet's top, a downward drag follows the finger and dismisses past 80 pt or on a flick projected past 160 pt (otherwise springs back), a tap on the dim dismisses, and every dismissal slides the sheet off the bottom edge while the dim fades. The Countdown sheet keeps the rail tappable above the dim. Rejected: today's instant show/hide (pops in and out, unlike every other modal) | Luke 2026-11-24 |
| D2 | Filters as a sheet | Filters opens a slide-up sheet (D1) holding C-150's looks and strength slider, from the rail and from Review; it no longer overlays the record row. The sheet's Done is C-040's purple check: a 32 × 32 `color-accent` circle with a white checkmark, top-trailing. Rejected: the strip over the record row (unlike the other controls) | Luke 2026-11-24 |
| D3 | Teleprompter on only with text | The Teleprompter sheet gets D1's grabber and drag and C-040's purple check in place of its Done. A **Clear** text button sits trailing on the Use a note row, right-aligned to the page margin; it empties the script. The teleprompter is on exactly when the trimmed script is non-empty: the rail tool is accent (purple) and C-151's band shows only then; an empty script means off, no band, and the "Add a script in the Teleprompter" text is never shown. Rejected: on after any Done (an empty band appeared) | Luke 2026-11-24 |
| D4 | Length panel | The Length sheet holds two C-047 radio rows, as on edit-options-custom-field: **Any length (2 min cap)** — "Make it as short or as long as you want, up to 2 minutes." — and **Specify length** — "Recording stops on its own at the length you set." Any length records until stopped or 2:00; the progress bar's full width is 2:00. Specify length reveals, under its row, a length input (D5), then a slider 0:05…2:00 with no snapping and no label over the handle, then the end countdown control (D6). Input and slider drive one value. Default for a new user is Any length; a user with a saved `videoRecorder.lengthSeconds` opens on Specify length with that value. Rejected: the 10 s snapping slider (D3 of video-recorder, disliked); Any length for everyone (loses a saved choice); Specify 1:00 default (cuts recordings at 1:00 unasked) | Luke 2026-11-24 |
| D5 | Length input format | The input shows `m:ss`. Digits typed fill from the right (1 → 0:01, 13 → 0:13, 130 → 1:30); non-digits are ignored; a value over 2:00 is replaced by 2:00 as it is typed; on commit a value under 0:05 becomes 0:05. Seconds 60–99 typed in the last two digits normalise on commit (0:75 → 1:15). Rejected: free text validated on commit (lets an over-max value show) | (assumed at brainstorm) 2026-11-24 |
| D6 | End countdown | Under Specify length only, a segmented control **End countdown: Off · 3 s · 10 s**, default Off, saved on device. When on and the remaining length reaches 3 s or 10 s, C-148 CountdownNumerals counts down the remaining whole seconds in the same place and style as the pre-roll; recording stops at 0 as today. Numerals only — it never plays a sound. Hidden and inactive under Any length. Rejected: a sound with it (walks never play audio; the start beep has its own switch) | Luke 2026-11-24 (sound: assumed at brainstorm) |
| D7 | Rail labels fade | The right-rail tool labels are visible when the camera rail appears, hold 1.0 s, then fade out over 0.3 s; tapping any rail tool fades them back in (0.2 s), holds 2.0 s, and fades out again. Icons stay. Rejected: always-on labels (crowd the preview) | Luke 2026-11-24 |
| D8 | Delete last clip position | The delete-last-clip button is centred horizontally between the screen's leading edge and the record button's leading edge, vertically centred on the record button. Rejected: its current spot beside the record button (too close) | (assumed at brainstorm) 2026-11-24 |
| D9 | Review playback | On Review a tap on the video toggles play and pause. Playback stops at the end of the clip (no loop); a tap at the end plays from the start. A scrub bar (C-004 ScrubTrack, existing) under the video seeks while dragging and pauses while held. Rejected: keep looping (no pause point); Review only (editor tap does nothing) | Luke 2026-11-24 |
| D10 | Editor tap and Deselect | In the editor a tap on the video with a layer selected deselects it; with nothing selected it toggles play and pause. C-156 drops its Deselect tile (Split · Edit · Delete remain). The row under the timeline sits 16 pt below the timeline. Rejected: a Deselect button (redundant with tapping off) | Luke 2026-11-24 |
| D11 | Text size control | C-093 TextSizeSlider becomes a vertical 1 pt `color-white-100` line with a 12 pt white dot at the current size, fixed at the right edge — no wedge and no slide-in animation; dot up = bigger. It replaces the wedge in both the video editor and the Activities editor. Rejected: video editor only (two looks for one shared text tool) | Luke 2026-11-24 |
| D12 | Trim and slide snapping | While a layer's start, end or whole bar is dragged on C-154, its edges are clamped live to the clip (0…duration) — never drawn past it — and snap to the clip's start and end, any other layer's start or end, and the playhead, when within 8 pt on screen; each new snap plays a light haptic (UIImpactFeedbackGenerator .light). Rejected: clip and layers only (no snap to a moment); clip ends only (layers don't line up) | Luke 2026-11-24 |
| D13 | Where settings live | Length mode (`videoRecorder.lengthMode`: `any` / `specify`) and end countdown (`videoRecorder.endCountdownSeconds`: 0 / 3 / 10) are new RecorderSettings keys beside the existing ones; `lengthSeconds` stops being snapped to 10 s and is clamped 5…120. Rejected: storing on the server (nothing else reads them) | (assumed at spec) 2026-11-24 |
| D14 | d2m designs the changed views | Every d2m-built view this touches (VideoRecorderScreen, C-149, C-150, C-151, C-093, C-154, C-156, VideoEditorScreen) changes through a d2m request from this spec; the owner approves before the containers are wired. Rejected: hand-editing the d2m views (d2m owns them) | (assumed at brainstorm) 2026-11-24 |

## Contract

No contract change. The app sends nothing new; `POST /api/videos` is consumed exactly as
video-recorder froze it (`docs/features/_archive/video-recorder/SPEC.md` §Contract).

## Schema & API changes

No schema change (established 2026-11-24).

## iphone

**d2m (phase 1)** — one request carrying this spec as its reference:
- VideoRecorderScreen: the D1 sheet motion for all four sheets; Filters as a sheet (D2); the Length
  panel (D4–D6); D3's Teleprompter chrome and the on-only-with-text rule for the band; rail label
  fade (D7); delete-last position (D8) via the record-row slot geometry; Review tap and scrub bar
  (D9). New state: `lengthMode`, `endCountdown`; new callbacks `onLengthModeChange`,
  `onEndCountdownChange`, `onClearScript`, `onReviewTap`, `onReviewScrub`.
- C-149 LengthSlider: no snapping, no handle label, 5…120 s.
- C-150 FilterStrip: hosted in the sheet, its Done replaced by the purple check.
- C-151 TeleprompterBand: Clear on the Use a note row; purple check; no placeholder text.
- C-093 TextSizeSlider: D11's line and dot (both editors' captures re-taken).
- C-154 VideoEditorLayerTrack: D12's live clamp, snap targets (passed in: clip duration, other
  layers' edges, playhead) and a snap callback for the haptic.
- C-156 VideoEditorLayerToolbar: no Deselect tile.
- VideoEditorScreen: tap-to-play when nothing is selected (D10), 16 pt under the timeline.

**Wiring (phase 2)** — after approval:
- RecorderSettings: D13 keys; `length` unsnapped, clamped 5…120; `lengthMode` defaulting per D4.
- VideoRecorderModel: Any length caps at 120 s; Specify uses the length; end countdown drives
  `Phase.endCountdown` from remaining time; teleprompter on = script non-empty (trimmed); Clear;
  Review play/pause, stop at end, scrub.
- VideoRecorderContainer: the new callbacks; delete-last placement.
- VideoReviewPlayer: `loops = false` on Review; play-from-start at end.
- VideoEditorModel/Container: snap targets into C-154, haptic on snap, tap-to-play.
- ActivitiesEditorScreen's container: nothing beyond C-093's new look.

Follow §Standing traps: no automated walk, test or capture ever plays audio; the end countdown is
silent by rule.

## Testing

**iphone (XCTest, MakeReadyCaptureTests):**
- RecorderSettings: `lengthMode` default `any` with no saved length, `specify` with one; length
  clamps 5…120 unsnapped; end countdown default 0 and persists.
- Length input formatter: 1 → 0:01, 130 → 1:30, 300 → 2:00, 0:75 → 1:15, 0:02 → 0:05 on commit.
- VideoRecorderModel: Any length stops at 120 s; end countdown enters `endCountdown` at 10 s / 3 s
  remaining and shows the right numeral; teleprompter off for empty or whitespace script, on with
  text; Clear empties and turns it off.
- Snap function: clamps to 0…duration; snaps to clip ends, other layers' edges and the playhead
  within 8 pt; reports a new snap once per target.
- Editor: tap with selection deselects; tap without toggles play.
- Review: playback ends without looping; tap at end plays from start.

**d2m captures** of every changed view and state, both editors' size control.

**Human verification (owner's phone):** each item in §Idea — sheets slide and swipe,
Filters and Teleprompter checks, Clear, no empty band, Length panel and input, end countdown at 3 s
and 10 s, rail label fade, delete-last position, Review tap and scrub, editor tap, no Deselect, the
16 pt gap, snapping with haptic, the thin size line in both editors.

## Out of scope

- Any sound for the end countdown.
- Web or server changes.
- Changing other app modals' behaviour (they already have it).
