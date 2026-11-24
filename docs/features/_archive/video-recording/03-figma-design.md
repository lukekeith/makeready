# Video recording: the Figma design

**Source:** Make-Ready-Mobile (`nVva9a2WvYmcWQo6zlHupO`), section **`4806:34871` "Recording"**
(1105×1053 at canvas 22718, -1664).
**Read on:** 2026-11-22, using the `figma` MCP server: `get_metadata`, `get_screenshot`,
`get_design_context` (with Swift/SwiftUI framing), `get_variable_defs` and `get_comments`.
This was a read-only pass. Nothing was written to Figma.

**Bottom line:** the section has **two frames**: a ready-to-record camera inside the lesson
editor, and the same camera while it is recording. None of the owner's larger asks are designed
yet: the right-side rail, teleprompter, length slider, filters, text layers, Library entry and
transcription. Neither are the screens that come after recording: paused, review/trim, save or
attach.

| # | Frame | Node | Size | State | Screenshot |
|---|---|---|---|---|---|
| 01 | Record video | `3567:34892` | 440×956 | Ready to record, inside the lesson editor | `assets/fig-01-record-video.png` |
| 02 | Recording | `3567:34787` | 440×956 | Recording in progress (timer running) | `assets/fig-02-recording.png` |

Both frames are iPhone 16 Pro Max size (440 pt wide) and dark. The camera feed is a sample photo
(a man at a podcast mic), filled to the frame and cropped.

**Prototype links:** none of the read tools return prototype connections, and the section has no
comments, so the flow below comes from the frame order and their contents, not from wiring.
Someone should check the prototype in Figma for any links.

---

## Frame 01: "Record video" (`3567:34892`)

**State:** the camera is open and ready to record. It sits *inside the lesson editor*: the header
reads "Edit lesson", and the editor's activity strip stays visible at the bottom. This shows that
the recorder is one of the editor's activity slides, not a separate full-screen modal.

**Background:** `layout/background` #030405 (variable bound) → `color-layout-background`.

### Anatomy, top to bottom (y in frame coordinates)

| y | Element | Node | Size (pt) | Detail |
|---|---|---|---|---|
| 0 | StatusBar (iOS, dark) | `3567:34907` | 440×47 | Time "9:41" in SF Pro Text Semibold 16/21, −0.32 tracking, white (`Callout / Bold` → `type-callout-bold`). Signal, Wi-Fi and battery on the right. System chrome. |
| 47 | **Content** (vertical stack, scrolls vertically, clips horizontally) | `3567:34901` | 440×912 | Holds everything below. Its 47 + 912 = 959 overruns the 956 frame by 3 pt. That looks like a drawing slip; the home indicator is not drawn. |
| 47 | Header: instance of the **Header** set, symbol `3313:7614` (`style=Default`, `showTitle=true`) | `3567:34902` | 440×56, padding 16 | Leading: **back chevron** 24×24 (Button `Back`, `3499:27558`). Trailing: **settings gear** 24×24 (Button `Settings`, `3499:27548`). Both are purple (#6c47ff → `color-accent`). Centred title **"Edit lesson"** in SF Pro Regular 14/20, white (→ `type-page-title`). |
| 103 | Hairline divider | `3567:34903` | 440×0 (1 px) | `layout/border` stroke. |
| 103 | **Slide**: the camera preview | `3567:34983` | 440×780 | Full-width live camera image (aspect-fill: the sample is drawn at 177.5% width, offset −38.75%, so it is centre-cropped). No overlays apart from the record button. |
| 797 | **Record button**, `style=Record` | symbol `3322:31523` | 80×80 | Centred horizontally, 6 pt above the bottom of the slide. A solid red disc inside a thin translucent grey ring (a single SVG in Figma). Tap to start recording. |
| 883 | Hairline divider | `3567:34905` | 440×0 | Same `layout/border` stroke. |
| 883 | **Activity navigation**: the editor's activity strip | `3567:34906` (inner row `I3567:34906;3499:27818`) | 440×76, padding 16, gap 4 | A row of **4 activity slides**, each 33×44 with an 8 pt radius and a gap of 4 (`space-meta-gap`), clipped horizontally: 2× **Empty** (`#2e2e2e` fill, symbol `3312:1430`), 1× filled with a thumbnail, and 1× **filled + active** (the current video slide: thumbnail plus a 1 px white border, symbol `3312:1472`). Trailing: an **Add** "+" 24×24 (Button `Add`, `3499:27601`) in purple. |

### Colour / type / spacing

- Variables bound in the section: `layout/background` #030405, `layout/border` **#2f3639**,
  `Purple/100%` #6c47ff, `Label Color/Dark/Primary` #ffffff, `Transparent` #ffffff00, and the
  `Callout / Bold` text style.
- **Drift:** `layout/border` resolves to **#2f3639** here, but `tokens.md` records
  `color-layout-border` = **#1c2124**. #2f3639 is within one step of `color-card-border` #2f363a.
  Either the Figma variable changed after the tokens were taken, or this file binds a different
  mode. Open question Q9.
- The `#2e2e2e` empty-slide fill is an unbound literal, the same one C-061 already flags.
- Spacing: header and strip padding 16 (`space-page-margin`); slide gap 4 (`space-meta-gap`).

---

## Frame 02: "Recording" (`3567:34787`)

**State:** recording is in progress, about one second in. The editor chrome is **gone**: no
header, no activity strip. The camera stays the same size, and the area around it is black.

**Background:** #030405 as a **literal** (not variable-bound here, unlike frame 01) →
`color-layout-background`.

### Anatomy, top to bottom

| y | Element | Node | Size (pt) | Detail |
|---|---|---|---|---|
| 0 | StatusBar (iOS, dark) | `3567:34793` | 440×47 | As in frame 01. |
| 47–88 | Empty black band | (none) | 440×41 | This is where the header was. The slide is pushed down to y 88, not 103, so the camera moves up 15 pt between frames. Undocumented; see Q8. |
| 0 | Content (scroll container) | `3567:34788` | 440×956 | Holds only the slide. |
| 88 | **Slide**: the camera preview | `3567:34789` | 440×781 | Same live image, object-fit cover. |
| 108 | **Timecode** pill | symbol `3322:31629` (`property1=Default`) | about 88×33 (hugs content) | Centred (+0.5 pt), 20 pt below the top of the slide. Red fill **#ff022d**, radius 4, padding 8 h / 4 v. Text **"00:00:01"** (HH:MM:SS) in SF Pro Regular 18, line height 1.4 (25.2), tracking +0.72, white. It counts **up**; nothing shows a limit or count-down. |
| 795 | **Pause button**, RecordButton `style=Pause` | symbol `3322:31557` | 54×54 | Bottom-left: its centre is 175 pt left of the frame's centre (x 18–72), 20 pt above the bottom of the slide. A frosted, translucent circle with a white pause glyph (single SVG). |
| 782 | **Stop button**, RecordButton `style=Recording` | symbol `3322:31531` | 80×80 | Centred, 7 pt above the bottom of the slide. A circle filled White/10% (`color-white-10`), radius 100, padding 6, around a red **#ff022d** rounded square 36×36, radius 8 (the "stop" glyph). Same spot as the frame 01 record button, so record turns into stop in place. |
| 869–956 | Empty black band | (none) | 440×87 | This is where the activity strip was. |

### Colour / type

- **#ff022d** (the timecode pill and the stop square) is **not** a token. The nearest reds in
  `tokens.md` are `color-negative` #ff4759 and `color-error` #fb2c36. Neither matches, and in
  Figma it is an unbound literal. It needs a ruling (Q7): a new `color-record` token, or snap it to
  an existing red.
- The timecode type (Regular 18 / 25.2, +0.72 tracking) matches no `type-` row. The nearest is
  `type-action-item` (Regular 18/24), but its leading and tracking differ. If it is kept, it is a
  new token, for example `type-timecode` (it should also use monospaced digits so the pill does
  not jitter; the design uses proportional SF Pro).

---

## Flow between the frames (inferred, no prototype wiring found)

```
Lesson editor ─(video activity slide selected)─▶ 01 Record video
01 ─(tap record, 80 pt red disc)─▶ 02 Recording   [header + activity strip hide; timer starts]
02 ─(tap pause, 54 pt, bottom-left)─▶ (paused state: NOT DESIGNED)
02 ─(tap stop, 80 pt red square)─▶ (review / trim / save: NOT DESIGNED)
01 ─(settings gear)─▶ (camera/recording settings: NOT DESIGNED)
01 ─(back chevron)─▶ leaves the lesson editor (standard C-040 behaviour)
01 ─(+ in the strip)─▶ add another activity (editor behaviour, not part of recording)
```

---

## Component mapping (vs `docs/ui2/design-system/registry.md`)

| Element | Figma source | Registry match | Notes |
|---|---|---|---|
| Status bar | `29:1493` (iOS kit) | system, no row | System chrome; never drawn by the app. |
| Header "Edit lesson" + back + settings | set `3313:7615`, symbol `3313:7614` (`style=Default`) | **C-040 PageHeader** | This is the first consumer of the `Default` style **with its settings icon showing**. Every current consumer uses `Two icons` + `showIcons=false`, so this adds weight to OQ-C-040-1 (`showIcons` does not gate `Default`'s gear). **C-019 TopNav does not apply**: this is a pushed page, not a tab root. |
| Back chevron / settings gear / add "+" | set `3499:27547`, symbols `3499:27558` / `3499:27548` / `3499:27601` | **C-021 GlyphButton** (`back`, `settings`, `add`) | All three glyphs are already in C-021's designed set. 24 pt artwork; 44 pt touch target per C-021. |
| Hairline dividers | vectors `3567:34903`, `3567:34905` | no row (inline divider) | Stroke `layout/border`; see the colour drift Q9. |
| Camera preview "Slide" | frames `3567:34983`, `3567:34789` | **NEW**: `CameraPreview` (Media section) | A live AVCaptureVideoPreviewLayer surface, aspect-fill. Geometry differs between frames (440×780 at y 103 vs 440×781 at y 88). |
| Record button (idle, red disc) | symbol `3322:31523` (`style=Record`) | **NEW**, with a consolidation flag against **C-013 RecordButton** | C-013 is the memo recorder's no-Figma 56 pt red circle. This is an 80 pt Figma-designed set with three styles (Record / Recording / Pause). Either C-013 gains a `style` axis and an 80 pt size, or a new `VideoRecordButton` row is minted. Owner ruling needed (Q6). The set's own node id was not resolved; the three symbol ids are listed here. |
| Stop button (red square in a glass ring) | symbol `3322:31531` (`style=Recording`) | same NEW set as above | Ring fill `color-white-10`. |
| Pause button (54 pt glass circle) | symbol `3322:31557` (`style=Pause`) | same NEW set as above | Not to be confused with **C-014 TransportControls** (memo playback). |
| Timecode pill "00:00:01" | symbol `3322:31629` | **NEW**: `RecordingTimecode` | Red pill, radius 4 (`radius-card-sm`), padding 8/4. Red is an untokenised literal. |
| Activity strip (4 slides + add) | instance `3567:34906` (main component not resolved) | **NEW**: `ActivityNavigation` (Activities section) | The editor's slide rail. The registry's Activities section says rows like this get minted when `activities-editor` is specced. |
| Activity slides 33×44 (Empty / Fill / Fill+active) | set `3312:1429`, symbols `3312:1430`, `3312:1472` | **C-061 ActivitySlide** | This is the first consumer of `state=Empty` and of `active=true`, both "reserved for `activities-editor`" in the row. The size here is **33×44**, compared with the 112×244 consumed on enrollment-home, so C-061 needs a size axis or is width-driven. |

### Token mapping

| Figma value | Where | Token |
|---|---|---|
| #030405 `layout/background` | both backgrounds | `color-layout-background` ✓ |
| #6c47ff `Purple/100%` | back, settings, add glyphs | `color-accent` ✓ |
| #ffffff `Label Color/Dark/Primary` | title, timecode text, status bar | `color-text-primary` ✓ |
| #2f3639 `layout/border` | dividers | ✗ token says #1c2124. **Drift (Q9)**; the nearest is `color-card-border` #2f363a |
| #ffffff1a | stop button ring | `color-white-10` ✓ |
| #2e2e2e | empty slide fill | none (the existing C-061 literal flag) |
| #ff022d | timecode pill, stop square, (record disc) | **none: NEW token candidate** (Q7) |
| SF Pro Regular 14/20 | header title | `type-page-title` ✓ |
| SF Pro Text Semibold 16/21 −0.32 | status bar time | `type-callout-bold` ✓ (system chrome) |
| SF Pro Regular 18/25.2 +0.72 | timecode | **none: NEW** (`type-timecode`) |
| padding 16 | header, strip | `space-page-margin` ✓ |
| gap 4 | slide strip | `space-meta-gap` ✓ |
| radius 8 | slide thumbnails, stop square | `radius-card` ✓ |
| radius 4 | timecode pill | `radius-card-sm` ✓ |
| radius 100 | stop ring | `radius-circle` ✓ |

---

## Coverage vs. the owner's asks

| Ask | Designed? | What the frames show |
|---|---|---|
| Right-side control rail | **No** | No rail in either frame. The only controls are bottom-centre (record/stop) and bottom-left (pause), plus the settings gear in the header. The gear may be the stand-in for camera options. |
| Teleprompter (in the right rail) | **No** | Not shown. Note that the iPhone app already has `iphone/MakeReady/Pages/Video/CustomVideoRecorder.swift` + `TeleprompterOverlay.swift`; the design does not reference either. |
| Length slider (10 s steps up to 2:00) + end countdown | **No** | No slider and no limit anywhere. The timecode counts **up** in HH:MM:SS, a format with room for hours, which goes against a 2:00 cap. There is no countdown. |
| Filters | **No** | Not shown. |
| Text layers editor (add/style/move/scale/rotate/delete) | **No** | Not shown. No post-record screen exists at all. |
| Entry: video activity inside a lesson | **Partly** | Frame 01 is clearly this context: the "Edit lesson" header plus the activity strip with the active slide. *How* the user gets there (choosing "video" as the activity type) is not drawn. |
| Entry: Record video from the Library tab's + menu (save to Library) | **No** | Not designed. Without the lesson editor chrome, frame 01's header and strip have no equivalent in this context. |
| Transcription of speech | **No** | No captions, transcript or status indicator. |
| Also missing (implied by the flow) | **No** | Paused state; review/playback; trim; retake/discard; save/upload progress; attach-to-activity confirmation; camera flip, flash and mic permission/denied states; front vs back camera. |

**Shown:** idle (pre-record) inside the lesson editor, and recording with timer, pause and stop.
That is all.

---

## Open questions the design leaves

1. **Pause:** what does the paused state look like? Does the timer pill change colour or blink?
   Does resume reuse the same 54 pt button? Are paused segments stitched into one clip?
2. **Stop → then what:** does stopping go straight to a review/trim screen, back to frame 01 with
   the take attached to the slide, or into the (undesigned) text-layer editor?
3. **The settings gear:** in frame 01, is it lesson settings (the usual C-040 meaning) or camera
   settings (length, teleprompter, filters)? If camera, it conflicts with the owner's wish for a
   right rail.
4. **Chrome while recording:** the header and activity strip disappear in frame 02. Should that
   animate, and can the user leave mid-recording (with a discard prompt)?
5. **Timer format and limit:** the design shows HH:MM:SS counting up, but the owner wants a
   ≤ 2:00 limit set by a slider with an end countdown. Which display wins: count-up MM:SS, or
   count-down remaining?
6. **Record button component:** extend **C-013 RecordButton** (memo, 56 pt, no Figma) with a
   `style` {Record, Recording, Pause} axis and an 80 pt size, or mint a separate video
   record-button row?
7. **Recording red #ff022d:** mint `color-record`, or snap to `color-negative` #ff4759 /
   `color-error` #fb2c36? The program already carries two near-duplicate reds.
8. **Camera geometry:** the preview sits at y 103 (780 tall) idle and y 88 (781 tall) while
   recording. Is the 15 pt shift intentional? What is the recorded video's aspect (9:16 full
   sensor vs. the 440×780 crop shown)?
9. **`layout/border` drift:** Figma now resolves it to #2f3639, but `tokens.md` has #1c2124.
   Which is correct?
10. **Library entry:** what chrome replaces "Edit lesson" + the activity strip when recording from
    the Library + menu, and where does the user name the clip and confirm the save?
11. **C-061 at 33×44:** a new size for ActivitySlide. Is it a `size` axis, or is the strip a
    separate thumbnail component (compare the existing C-056/C-061 consolidation question)?
12. **Permissions and errors:** camera/mic denied, out of storage, upload failure. Nothing designed.
