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
own Done, and the rail tap itself turns the teleprompter on even with an empty script.[^8] Length is
C-149 LengthSlider (10…120 s, 10 s steps, video-recorder D3), saved under
`videoRecorder.lengthSeconds` and snapped in four places.[^4] The end countdown already exists and is
**always on** for the last 10 s of the length (`RecordingTimeline.endCountdownSeconds = 10`).[^9]
In the editor, the session clamps trims live on every drag report, so a bar never draws past the
clip; but C-154's trim handles sit 12 pt outside the bar, so at the clip's start they hang past it —
that is what the owner saw, and why it "sizes back" once deselected (the handles hide).[^5] C-156's
first tile is Deselect (glyph `x`), and tapping empty video already deselects.[^6] C-093
TextSizeSlider (the wedge) is placed by its hosts — both the video editor and the Activities editor
dock it at the leading edge and slide it in and out. Review and Trim share one VideoReviewPlayer,
which loops by default with no controls, though it already supports `loops = false`, an end callback
and seeking.[^7]

**Approaches considered.** No fork: the rulings fix the shape, and every sheet reuses the existing
house motion rather than a new one.

[^1]: iphone/MakeReadyUI/Screens/Library/VideoRecorderScreen.swift:420, :602
[^2]: iphone/MakeReadyUI/ActionMenuPresentation.swift:4-105
[^3]: iphone/MakeReadyUI/PageHeader.swift:132
[^4]: iphone/MakeReady/Services/Video/RecorderSettings.swift:13, :36, :38; RecordingTimeline.swift:43, :63
[^5]: iphone/MakeReady/UI2/Containers/Video/VideoEditSession.swift:132-177; iphone/MakeReadyUI/VideoEditorLayerTrack.swift:108-125
[^6]: iphone/MakeReadyUI/VideoEditorLayerToolbar.swift:63; VideoEditorScreen.swift:546
[^7]: iphone/MakeReady/Services/Video/VideoReviewPlayer.swift:32-37, :59, :188-196; VideoRecorderModel.swift:705-733
[^8]: iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:407-408, :448-452
[^9]: iphone/MakeReady/Services/Video/RecordingTimeline.swift:36-37, :73-77

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ⬜ | No change — nothing new is stored or sent; length, countdowns and teleprompter are on-device settings, and the saved video is uploaded exactly as today | — |
| client | ⬜ | No change — the web plays saved videos as any Stream video; no recorder or editor exists on the web | — |
| iphone | ✅ | Recorder sheets, Length panel, end countdown, teleprompter rules, rail labels, record-row layout, Review playback, and the editor's timeline, toolbar, tap-to-play and size control (d2m first) | §iphone |

**Sequencing:** d2m changes the d2m-built views from this spec (phase 1), the owner approves them
(memory: approve screens first), then the containers and models are wired (phase 2).

**Backward compatibility:** the iPhone app is the only consumer. A saved `videoRecorder.lengthSeconds`
is kept and shown as Specify length (D4). The always-on 10 s end countdown becomes an opt-in setting,
default Off (D6) — a shipped behaviour removed by the owner's ruling. No server or contract change,
so released builds are unaffected.

**Blast radius:** C-093 TextSizeSlider is shared with ActivitiesEditorScreen — its captures and
tests change too, and its leading-edge dock/undock ruling and `sliderDocked` state are retired (D11).
The house motion constants (`ActionMenuMotion`) are reused, not edited, so other action modals are
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
| D1 | Recorder sheet behaviour | All four recorder sheets — Length, Countdown, Filters, Teleprompter — use the house action-modal motion (`ActionMenuMotion`: its slide spring, 80 pt drag / 160 pt projected-flick thresholds and `dragOffset` resistance) on the recorder's existing full-width sheet surface. Open: a `Token.black80` dim fades in and the sheet slides up from the bottom edge. A 36 × 5 `color-white-30` grabber (C-016's) sits centred `space-step-4` below the sheet's top. The dismiss drag is scoped to the grabber and the sheet's top strip only, never the controls inside (sliders, look rail, text editor keep their gestures); it follows the finger down and dismisses past the thresholds, else springs back. A tap on the dim dismisses. Every dismissal slides the sheet off the bottom edge while the dim fades. With the keyboard up, a drag on the grabber first closes the keyboard. Sheets are always drawn in place inside the recorder (never a hosted overlay), so in a lesson the dim covers the recorder's area and the Countdown sheet keeps the rail tappable above its dim; full screen, it covers the screen. Rejected: today's instant show/hide (pops in and out); hosting the sheets as shell overlays (hides the rail and the Use a note picker in a lesson) **Superseded in part 2026-11-24 (owner, phone walk):** the Filters sheet has no dim — the live picture stays fully visible so the look can be judged; Length, Countdown and Teleprompter keep the dim. | Luke 2026-11-24 |
| D2 | Filters as a sheet | Filters opens a slide-up sheet (D1) holding C-150's looks and strength slider, from the rail and from Review; it no longer overlays the record row. The sheet's Done is C-040's purple check: a 32 × 32 `color-accent` circle with a white `.checkmarkCarbon` glyph, top-trailing — C-040's private check is extracted as a shared part so both reuse one drawing. Rejected: the strip over the record row (unlike the other controls) | Luke 2026-11-24 |
| D3 | Teleprompter on only with text | The Teleprompter sheet gets D1's grabber and drag and C-040's purple check in place of its Done. A **Clear** text button sits trailing on the Use a note row, right-aligned to the page margin; it empties the script (through the existing script callback). The teleprompter is on exactly when the trimmed script is non-empty: the rail tool is accent (purple) and C-151's band shows only then, including a script saved from an earlier session; an empty script means off and no band, so the band's empty line ("Add a script in Teleprompter") is never reached. The field's own placeholder ("Type or paste your script") stays. The rail tap only opens the sheet; it no longer turns the teleprompter on. Rejected: on after any rail tap or Done (an empty band appeared) | Luke 2026-11-24 |
| D4 | Length panel | The Length sheet holds two C-047 radio rows, as on edit-options-custom-field: **Any length (2 min cap)** — "Make it as short or as long as you want, up to 2 minutes." — and **Specify length** — "Recording stops on its own at the length you set." Any length records until stopped or 2:00; the progress bar's full width is 2:00. Specify length reveals, under its row, a length input (D5), then a slider 0:05…2:00 with no snapping and no label over the handle, then the end countdown control (D6). Input and slider drive one value. Default for a new user is Any length; a user with a saved `videoRecorder.lengthSeconds` opens on Specify length with that value. Choosing Specify length with no saved value starts at 1:00. Under Any length the rail's Length tool shows `2:00`. Rejected: the 10 s snapping slider (D3 of video-recorder, disliked); Any length for everyone (loses a saved choice); Specify 1:00 default (cuts recordings at 1:00 unasked) | Luke 2026-11-24 |
| D5 | Length input format | The input shows `m:ss`. Digits typed fill from the right (1 → 0:01, 13 → 0:13, 130 → 1:30); non-digits are ignored; a value over 2:00 is replaced by 2:00 as it is typed; on commit a value under 0:05 becomes 0:05. Seconds 60–99 typed in the last two digits normalise on commit (0:75 → 1:15). Backspace removes the last digit (1:30 → 0:13). The input holds a local draft while focused and sends its value only on commit — when the keyboard's Done check is tapped, focus leaves the field, or the sheet is dismissed; the slider then moves to it. Dragging the slider updates the input live. Rejected: free text validated on commit (lets an over-max value show); sending every keystroke (0:01 would clamp mid-typing) | (assumed at brainstorm) 2026-11-24 |
| D6 | End countdown | Under Specify length only, a segmented control **End countdown: Off · 3 s · 10 s**, default Off, saved on device. When on and the remaining length reaches 3 s or 10 s, C-148 CountdownNumerals (`.ending`) counts down the remaining whole seconds in the same place and style as the pre-roll; recording stops at 0 as today. When the length is shorter than the countdown, the numeral shows from the start of recording. Numerals only — it never plays a sound. Hidden and inactive under Any length (no end countdown at the 2:00 cap). This replaces today's always-on 10 s end countdown. Rejected: a sound with it (walks never play audio; the start beep has its own switch) | Luke 2026-11-24 (sound: assumed at brainstorm) |
| D7 | Rail labels fade | The right-rail tool labels are visible when the camera rail appears, hold 1.0 s, then fade out over 0.3 s; tapping any rail tool fades them back in (0.2 s), holds 2.0 s, and fades out again. Icons stay. C-146 CameraRail and C-147 RailTool gain a `labelsVisible` input; the timers run as a `.task(id:)` sleep in the screen, never `asyncAfter`. Review's Edit and Filters tools on the record row keep their labels. Rejected: always-on labels (crowd the preview) | Luke 2026-11-24 |
| D8 | Delete last clip position | The delete-last-clip button is centred horizontally between the screen's leading edge and the record button's leading edge, vertically centred on the record button — container geometry, x = (W/2 − 40)/2 from the leading edge. Rejected: its current spot 98 pt left of centre (too close) | (assumed at brainstorm) 2026-11-24 |
| D9 | Review playback | On Review a tap on the video toggles play and pause. Review playback stops at the end of the clip (no loop); a tap at the end plays from the start. Trim keeps looping its window. A C-004 ScrubTrack (existing, with its elapsed and remaining labels) sits directly above Review's bottom row, full width inside the page margins, in both the full-screen and lesson layouts; it seeks while dragging and holds playback paused while held. Rejected: keep looping (no pause point); Review only (editor tap does nothing) | Luke 2026-11-24 |
| D10 | Editor tap and Deselect | In the editor a tap on empty video with a layer selected deselects it; with nothing selected it toggles play and pause (the container routes the screen's existing empty-tap callback). A tap on a layer always selects it and does not change playback. C-156 drops its Deselect tile (Split · Edit · Delete remain). The toolbar row under the timeline — C-155 or C-156 — sits 16 pt below it (today 8 pt). Rejected: a Deselect button (redundant with tapping off) | Luke 2026-11-24 |
| D11 | Text size control | C-093 TextSizeSlider becomes a vertical 1 pt `color-white-100` line with a 12 pt white dot at the current size; dot up = bigger; it keeps its 44 pt touch strip and the wedge's length (263.5 pt). Both hosts — the video editor and the Activities editor — place it fixed at the trailing edge, shown whenever text is being edited, with no dock/undock slide; this retires the Activities editor's leading-edge docking ruling and its `sliderDocked` state. Rejected: video editor only (two looks for one shared text tool) | Luke 2026-11-24 |
| D12 | Trim and slide snapping | C-154's trim handles are drawn inside the bar's ends, so neither handle extends past the clip's start or end. Trims and slides keep today's live clamp to the clip. While a layer's start, end or whole bar is dragged, the dragged edge snaps (for a slide, whichever edge is nearer) to the clip's start and end, any other layer's start or end, and the playhead, engaging within 8 pt (200 ms at the timeline's 40 pt/s) and releasing past 12 pt — the canvas's hysteresis. The snap is a pure function in `VideoLayerTiming` the session applies; C-154 stays a controlled view reporting intents. Each new snap plays the same selection haptic the editor's canvas snaps use. Rejected: clip and layers only (no snap to a moment); clip ends only (layers don't line up) | Luke 2026-11-24 |
| D13 | Where settings live | Length mode (`videoRecorder.lengthMode`: `any` / `specify`) and end countdown (`videoRecorder.endCountdownSeconds`: 0 / 3 / 10) are new RecorderSettings keys beside the existing ones; `lengthSeconds` stops being snapped to 10 s and is clamped 5…120 — the snapping is removed in all four places (RecorderSettings get/set, RecordingTimeline init and `snappedLength`), `RecordingTimeline.minLength` becomes 5, and draft recovery keeps the unsnapped value. Rejected: storing on the server (nothing else reads them) | (assumed at spec) 2026-11-24 |
| D14 | d2m designs the changed views | Every d2m-built view this touches (VideoRecorderScreen, C-146, C-147, C-149, C-150, C-151, C-093, C-154, C-156, VideoEditorScreen, ActivitiesEditorScreen, and C-040's Done check extracted) changes through a d2m request from this spec; the owner approves before the containers are wired. Rejected: hand-editing the d2m views (d2m owns them) | (assumed at brainstorm) 2026-11-24 |

## Contract

No contract change. The app sends nothing new; `POST /api/videos` is consumed exactly as
video-recorder froze it (`docs/features/_archive/video-recorder/SPEC.md` §Contract).

## Schema & API changes

No schema change (established 2026-11-24).

## iphone

**d2m (phase 1)** — one request carrying this spec as its reference:
- VideoRecorderScreen: D1's sheet motion for all four sheets, drawn in place; Filters as a sheet
  (D2); the Length panel (D4–D6) from C-047 rows; D3's Teleprompter chrome and band rule; D7's label
  fade timers; D9's Review scrub bar. New State: `lengthMode`, `endCountdown`, `reviewPlaying`,
  `reviewElapsed`, `reviewDuration`, `reviewScrubbing`. New callbacks: `onLengthModeChange`,
  `onEndCountdownChange`, `onReviewTap`, `onReviewSeek`, `onReviewScrubbingChange`. Clear uses the
  existing `onScriptChange("")`.
- C-146 CameraRail, C-147 RailTool: a `labelsVisible` input, fading the labels.
- C-149 LengthSlider: 5…120 s, no snapping and no per-stop haptic, no handle label, a 5 s VoiceOver
  step.
- C-150 FilterStrip: hosted in the sheet; its Done is the shared purple check.
- C-151 TeleprompterBand: Clear on the Use a note row; the shared purple check.
- C-040's Done check extracted as a shared part (PageHeader keeps using it).
- C-093 TextSizeSlider: D11's line and dot; VideoEditorScreen and ActivitiesEditorScreen place it at
  the trailing edge with no dock/undock (Activities' `sliderDocked` state and fixture retired).
- C-154 VideoEditorLayerTrack: handles inside the bar's ends (D12).
- C-156 VideoEditorLayerToolbar: no Deselect tile. VideoEditorScreen: 16 pt toolbar gap.

**Wiring (phase 2)** — after the owner approves phase 1:
- RecorderSettings: D13 keys; `length` unsnapped, clamped 5…120; `lengthMode` read as D4 says.
- RecordingTimeline: `minLength` 5, no snapping; the end countdown takes its seconds from the setting
  (0 = none) and is inactive under Any length; Any length caps at 120 s.
- VideoRecorderModel: length mode and end countdown setters; `teleprompterOn` derived from the
  trimmed script, and the rail tap no longer sets it; Review playback — `loops = false` and an end
  callback for Review only, Trim unchanged, play/pause, seek, a 33 ms follow loop for elapsed time
  (the editor container's pattern).
- VideoRecorderContainer: the new callbacks; delete-last at D8's x.
- VideoLayerTiming: a pure `snap` (targets, hysteresis); VideoEditSession applies it to trims and
  slides and reports a new snap; the container fires the selection haptic.
- VideoEditorContainer: route the empty-video tap per D10.

Follow §Standing traps: no automated walk, test or capture ever plays audio; the end countdown is
silent by rule.

## Testing

**iphone (XCTest, MakeReadyCaptureTests):**
- RecorderSettings: `lengthMode` `any` with no saved length, `specify` with one; length clamps 5…120
  unsnapped (94 stays 94); end countdown default 0, persists.
- RecordingTimeline: no snapping, min 5; end countdown off by default, at 3 s / 10 s when set,
  none under Any length; numeral from the start when length < countdown.
- Length input formatter: 1 → 0:01, 130 → 1:30, 2005 → 2:00, 0:75 → 1:15 on commit, 0:02 → 0:05 on
  commit, Backspace 1:30 → 0:13.
- VideoRecorderModel: Any length stops at 120 s; teleprompter off for empty/whitespace script, on with
  text (also a saved one); the rail tap opens without turning it on; Clear turns it off; Review stops
  at the end, a tap there plays from 0; Trim still loops.
- VideoLayerTiming.snap: engages within 200 ms, releases past 300 ms; targets clip ends, other layers'
  edges, the playhead; slide snaps the nearer edge; never outside the clip.
- Editor: empty tap with selection deselects; without selection toggles play.
- Existing tests that assert the old behaviour are updated, not deleted: RecordingTimelineTests
  (10 s snap, always-on end countdown), RecorderSettingsTests (94 → 90), VideoRecorderModelTests
  (end-countdown tests set 10 s explicitly; `makeModel`'s saved length; rail tap turns teleprompter
  on).

**d2m captures** of every changed view and state, including both editors' size control.

**Human verification (owner's phone):** each item in §Idea — sheets slide, swipe on the grabber, tap
off, in full screen and in a lesson; Filters and Teleprompter checks; Clear; no empty band; Length
panel and input; end countdown at 3 s and 10 s; rail label fade; delete-last position; Review tap and
scrub; editor tap; no Deselect; the 16 pt gap; handles inside the clip and snapping with haptic; the
thin size line in both editors.

## Out of scope

- Any sound for the end countdown.
- Web or server changes.
- Changing other app modals' behaviour (they already have it).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | The house action menu dims with `black80`, insets 4 pt and has no grabber; its whole-sheet drag would steal the sheets' sliders and text gestures | D1: reuse `ActionMenuMotion` only, the recorder's full-width surface, C-016's grabber, drag scoped to the grabber strip |
| F2 | In a lesson, a hosted sheet would sit above the rail and hide the Use a note picker (first hosted overlay wins) | D1: sheets drawn in place, always |
| F3 | The editor already clamps trims live; the overshoot the owner saw is the handles sitting 12 pt outside the bar | D12: handles inside the bar; snap added in `VideoLayerTiming` |
| F4 | The end countdown is always on for the last 10 s today | D6 replaces it with an opt-in setting, default Off; §Apps backward compatibility notes it |
| F5 | The teleprompter turns on from the rail tap, not from Done; `setScript` already derives on/off | D3: drop the rail-tap line, derive on from the script |
| F6 | Text size placement is host code in two d2m screens (Activities has its own docking ruling) | D11/D14: both hosts in the d2m request; docking retired |
| F7 | Rail labels belong to C-146/C-147, which have no visibility input | D7/D14: `labelsVisible` added |
| F8 | Review and Trim share one player | D9: `loops = false` for Review only |
| F9 | Typing a length would clamp mid-typing if sent per keystroke | D5: local draft, sent on commit |
| F10 | Snapping is pinned in this spec; its feel (8/12 pt) is only judged on a phone | build-time risk — the owner's walk settles it (Phase 2 · snap task) |

## Plan

The plan, task by task: `docs/features/video-polish/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · Recorder length mode, unsnapped length and the end countdown setting
- Phase 1 · Task 2 · Layer edge snapping on the editor timeline
- Phase 2 · Task 3 · d2m changes the recorder and editor views; the owner approves
- Phase 3 · Task 4 · Recorder model — teleprompter rule, Review playback
- Phase 3 · Task 5 · Recorder container — the new callbacks and delete-last placement
- Phase 3 · Task 6 · Editor container — tap to play, snap haptic

## Fixes

- [x] iphone — Filters sheet: no dark overlay over the preview (D1 superseded in part, owner 2026-11-24)
- [x] iphone — Size line (C-093) in the video and Activities editors: placed by layout, centred vertically on the trailing edge of the free space between the header and the tools (shortened to fit when the space is shorter than the line); the touch maps to the line's real on-screen frame so the dot follows the finger (owner walk 2026-11-24)
- [x] iphone — Activity slides (lesson editor strip, program home rail): a video activity with no poster shows its video's Cloudflare thumbnail (`media[videoId].posterUrl`), never the stream URL (owner walk 2026-11-24)
- [x] iphone — Exported video is upright in its pixels: the export always draws (track transform identity), never leaves the camera's rotation/mirror as track metadata, which played upside down after Cloudflare's transcode (owner walk 2026-11-25)
- [x] iphone — Review: Retake is an icon button (refresh glyph), top centre between the ✕ and the purple check (owner walk 2026-11-25; d2m-walk2-fixes.md 1)
- [x] iphone — Review: the scrubber sits at the bottom of the video frame, with Edit and Filters directly above it (owner walk 2026-11-25; d2m 2–3)
- [x] iphone — Camera phases: the ✕ is vertically centred with the red timecode (owner walk 2026-11-25; d2m 4)
- [x] iphone — Delete-last-clip sits where the photo-library button sits, mirroring the check's inset from the trailing edge (owner walk 2026-11-25; d2m 5)
- [x] iphone — Lesson editor video page (video-activity-basics follow-up): a semi-transparent play glyph centred while paused, and a scrubber at the bottom of the page frame, visible above the activity nav while playing (owner walk 2026-11-25; d2m 6–7)
- [x] iphone — Delete this video? (video-activity-basics follow-up): "Delete video everywhere" is a toggle, off by default, above one destructive Delete; disabled when not allowed; the where-it's-used note sits under the title, left-aligned (owner walk 2026-11-25; d2m 8–9)
- [x] iphone — Library: a video row with a thumbnail shows it on the row's avatar in place of the video glyph (owner 2026-11-25)

