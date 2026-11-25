# Video recorder polish — d2m requirements (video-polish, owner 2026-11-24)

Change to screen `video-recorder` and its parts C-146 CameraRail, C-147 RailTool, C-149 LengthSlider,
C-150 FilterStrip, C-151 TeleprompterBand, and C-040 PageHeader's Done check. Full rulings:
`docs/features/video-polish/SPEC.md` §Decisions D1–D9, D11 is the editor's (other request).

## 1. Every sheet behaves like the app's action modals (D1)
Applies to Length, Countdown, Filters and Teleprompter.
- Open: a `Token.black80` dim fades in over the recorder and the sheet slides up from the bottom edge.
  Use `ActionMenuMotion` (ActionMenuPresentation.swift:22-43): its slide spring, the 80 pt drag / 160 pt
  projected-flick dismiss thresholds and `dragOffset` resistance. Keep the recorder's full-width sheet
  surface (`sheetSurface`, `color-modal-background`, `radius-modal` top corners).
- A grabber: 36 × 5 `color-white-30` capsule, centred, `space-step-4` below the sheet's top (C-016's,
  RecorderSheet.swift:95-97, 276-288).
- The dismiss drag is scoped to the grabber and the sheet's top strip only (as C-016 does,
  RecorderSheet.swift:174, 306) — never the sliders, look rail or text editor inside.
- A tap on the dim dismisses. Every dismissal slides the sheet off the bottom edge while the dim fades.
  Never an instant show/hide. With the keyboard up, a grabber drag first closes the keyboard.
- Sheets are drawn **in place** inside the recorder — never a hosted overlay — so in the lessonInline
  layout the dim covers the recorder's area, and the Countdown sheet keeps the rail tappable above its
  dim (as today). Animation via state-driven offsets, never `asyncAfter`, never `.sheet`.

## 2. Filters is a sheet (D2)
- Filters (from the rail and from Review) opens a D1 sheet holding C-150's looks and strength slider.
  It no longer lays over the record row.
- Its Done is the **purple check**: extract C-040 PageHeader's private Done check (PageHeader.swift:132-146,
  32 × 32 `color-accent` circle, white `.checkmarkCarbon`) into a shared part; PageHeader keeps using it.
  Top-trailing on the sheet.

## 3. Teleprompter (D3)
- The Teleprompter sheet gets D1's grabber/drag and the purple check in place of its Done.
- A **Clear** text button, trailing on the "Use a note" row, right-aligned to the page margin. It calls the
  existing `onScriptChange("")`.
- The band shows only when `teleprompterOn` is true (the container derives it from the script). The band's
  empty line "Add a script in Teleprompter" is then never reached; the field placeholder
  "Type or paste your script" stays.

## 4. Length panel (D4–D6) — replaces the bare C-149 sheet
Modelled on `edit-options-custom-field` (C-047 RadioOptionRow, EditOptionsCustomFieldScreen.swift:116-122):
- Row **Any length (2 min cap)** — description "Make it as short or as long as you want, up to 2 minutes."
- Row **Specify length** — description "Recording stops on its own at the length you set."
- When Specify is selected, under its row:
  1. A length input showing `m:ss`. Digits typed fill from the right (1 → 0:01, 13 → 0:13, 130 → 1:30);
     non-digits ignored; anything over 2:00 shows 2:00 as typed ("2005" stays 2:00); Backspace removes the
     last digit (1:30 → 0:13). It keeps a local draft and sends its value through `onLengthChange` only on
     commit — keyboard Done check, focus leaving, or the sheet dismissed. On commit: seconds 60–99 in the
     last two digits normalise (0:75 → 1:15), under 0:05 becomes 0:05. Put this in a pure helper
     `LengthEntry` (`digits(_ raw: String) -> String`, `commit(_ text: String) -> Int`) so it can be unit tested.
  2. C-149 LengthSlider: 5…120 s, **no snapping**, no per-stop haptic, **no label above the handle**; a 5 s
     VoiceOver step. Dragging it updates the input live.
  3. **End countdown** — a segmented control Off · 3 s · 10 s (copy the Countdown panel's segmented
     control, VideoRecorderScreen.swift:632-705). Default Off.
- Under Any length the rail's Length tool value reads `2:00`.
- New State: `lengthMode: String` ("any" | "specify", default "any"), `endCountdown: Int` (0 | 3 | 10, default 0).
  New callbacks: `onLengthModeChange(String)`, `onEndCountdownChange(Int)`.
- The end-countdown numerals (C-148 `.ending`) keep showing whenever the container puts the screen in
  `endCountdown(n)` — no sound, ever.

## 5. Rail labels fade (D7)
- C-146 CameraRail and C-147 RailTool gain `labelsVisible: Bool = true`; labels fade with opacity, icons stay.
- The screen shows labels when the rail appears, holds 1.0 s, fades out over 0.3 s; tapping any rail tool
  fades them in (0.2 s), holds 2.0 s, fades out. Timers as a `.task(id:)` sleep in the screen, never
  `asyncAfter`. Review's Edit and Filters tools on the record row keep their labels.

## 6. Review tap and scrub (D9)
- In `review`, a tap on the video calls `onReviewTap()`.
- A C-004 ScrubTrack (ScrubTrack.swift:19-31, with elapsed and remaining labels) sits directly above Review's
  bottom row, full width inside the page margins, in both layouts. Precedent: VideoDetailScreen.swift:300-308.
- New State: `reviewPlaying`, `reviewElapsed`, `reviewDuration`, `reviewScrubbing`. New callbacks:
  `onReviewTap()`, `onReviewSeek(TimeInterval)`, `onReviewScrubbingChange(Bool)`.

## Captures
Fixtures for each sheet open, the Length panel in both modes, the teleprompter with/without text, labels
visible/hidden, Review with the scrub bar. 🔴 No capture or fixture may play any audio.
