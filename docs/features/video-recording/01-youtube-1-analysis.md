# 01 — YouTube recording 1: Shorts camera, segmented recording, review, timeline editor and text layers

## Source

| | |
|---|---|
| File | `~/MakeReady/youtube-1.MP4` (not in the repo) |
| Format | 1320×2868 (440×956 pt @3x), 60 fps, 134.93 s, 8,084 frames, AAC audio |
| Reference app | YouTube iOS app, **Create → Short**: camera, timer, two-segment recording, review, timeline editor, text tool, Add details |
| Companion | `02-youtube-2-analysis.md` covers what this recording never opens: the rail's overflow, the effects sheet and the **filters sheet** |

## Method

1. 2 fps timestamped contact sheets across the whole recording, for the outline.
2. 15–30 fps windows on every transition: timer sheet in/out, the countdown, record start/stop, the
   15 s auto-stop, swipe-up-to-edit, text editor open/close, the layer drag/pinch, layer selection.
3. Native 3× crops of the top bar, the camera rail, the bottom row, the text editor's top bar, swatch
   row and size slider, the timeline and the selected-layer toolbar. Positions are px ÷ 3 = pt.
4. Audio: `silencedetect` (−45 dB) for event timing, then a zero-crossing pitch estimate on single
   beeps.

**Limits:**

- **The finger isn't visible.** Tap moments are inferred from the first frame that changes, so
  they're ±1 frame (17 ms) at best.
- **Never opened here:** the rail's chevron overflow, Effects, Filters, Stickers, Captions, Voiceover,
  Music, Add sound, the top-right AI button, speed (1x), the person-in-frame tool, the gallery, and
  the mode tabs. Labels for camera-rail icons never appear in this recording, so names given for
  them are *(inferred)*. See `02` for the overflow and the filters sheet.
- **Text styling demonstrated:** typing, the size slider and one colour change only. The font chip
  ("Classic"), the alignment button, the background-style button and the top-left voice icon were
  never tapped. Their behaviour is *(inferred)* wherever it's described.
- **Not shown:** a trash target, layer delete, re-editing a layer by tapping it on the canvas, tapping
  **Edit** in the layer toolbar, **Split**, undoing a segment, cancelling a countdown, or a second
  overlay layer (so layer order is unknown).
- **The trimmed text layer's final range isn't legible** in the stills. From when the text shows on
  the canvas, it's roughly 0:03–0:12 (±1 s).
- **Audio:** the recording's own microphone isn't audible during capture (silent from 22.9 to
  48.45 s). Clip playback is audible from 48.45 s.
- The Add details page shows the owner's account name and handle. They're left out of this doc and its
  stills.

## Timestamped outline

± 0.25 s, except **bold** rows, which were measured at 15–30 fps.

| t (s) | What it shows |
|---|---|
| 0.0–3.2 | Camera at rest (front camera): top bar, 7-slot right rail, record button, effect carousel, mode tabs |
| **3.27–3.47** | **Flip camera to the rear: one blurred frame, then the new feed. No flip animation** |
| 3.5–4.85 | Rear camera; the rail's chevron badge dot fades in and out |
| **4.87–4.93** | **Flip back to the front camera** |
| **5.93–6.13** | **Timer tapped: chrome fades (≈70 ms), sheet rises (≈0.15 s, slight overshoot)** |
| **6.40–6.53** | **Scrim dims the camera *after* the sheet lands** |
| **7.10–7.17** | **Countdown 3s → 10s: selected pill slides across** |
| 7.2–13.6 | Timer sheet at rest: 10s countdown, stop at 15s |
| **13.63–13.80** | **START: sheet drops, the "10" fades in, scrim clears by 14.13** |
| **13.69–22.64** | **Countdown 10 → 1. Ten beeps at 1.0 s spacing; the last one is higher-pitched** |
| **23.60–23.93** | **Recording starts: button morphs to stop, carousel and tabs fade, elapsed timer appears** |
| 23.9–31.3 | Recording segment 1: red progress fills, timer 0:00 → 0:07 |
| **31.40–31.93** | **Stop tapped: camera chrome fades back in; undo and ✓ appear beside the button** |
| 31.9–38.1 | Paused with one segment |
| **38.17–38.37** | **Record tapped again: white disc → red disc → stop square; chrome fades** |
| 38.4–45.2 | Segment 2; white divider tick on the bar at the segment boundary |
| 40.0–45.2 | Last 5 s: **no warning of any kind** (no colour, haptic cue, sound or countdown) |
| **45.20–45.47** | **Bar full at 0:15: auto-stop; chrome flashes back, then cut to review** |
| 45.5–48.4 | Review: clip plays on the full canvas; right rail with labels; Edit / Next |
| **48.47–49.60** | **Swipe up: canvas shrinks into a card, timeline and toolbar rise** |
| 49.6–60.3 | Timeline editor: playback, scrubbing by dragging the timeline |
| **60.43–61.17** | **Text tapped: card grows back to full canvas (≈0.3 s), then text editor fades in with keyboard** |
| 61.2–63.2 | Empty text editor, caret only |
| 63.3–67.6 | Typing "Adding text to video" |
| 68.4–71.5 | Size slider dragged down (small) then up (large, wraps to 2 lines) |
| **75.40** | **Colour changed white → blue** |
| **77.93–78.17** | **Done: keyboard and toolbar drop, scrim clears, text settles to the canvas centre** |
| **78.43–78.70** | **Auto-return to the timeline editor; a salmon text track spans the whole clip** |
| 79.4–84.0 | One-finger drag of the text on the card; guide overlay while touching |
| 84.0–88.8 | Two-finger pinch/rotate: text grows and tilts; pushed half off the right edge at 86.9 |
| 89.0–97.5 | Timeline scrubbed back and forth (0:03 ↔ 0:14) |
| **97.70–97.95** | **Text track tapped: selected; toolbar becomes Deselect / Split / Edit / Delete** |
| 98.0–101.0 | End handle dragged left: layer shortened |
| 102.5–108.5 | Start handle dragged right; Split greys out while the playhead is outside the layer |
| 111.0–117.0 | Layer body dragged: slides in time, length unchanged |
| 117.0–124.5 | Scrubbing and small adjustments |
| **≈124.7** | **→ (top right) tapped** |
| 125.0–127.3 | Review screen with a "Processing / This may take a moment" HUD |
| 127.4–129.3 | Add details page |
| 129.4–134.9 | Back to review; text baked into the preview; rail labels show again |

## 1. Camera screen (pre-record)

`assets/y1-t000.5-camera.jpg`, `assets/y1-t000.5-rail-3x.jpg`

**Canvas.** The live feed fills a rounded card, full width, y 62 → 843 pt (781 pt tall, exactly
9:16), with corners of about 20 pt. Below it is a black band holding the mode tabs.

**Progress track.** It's present before recording: a capsule from x 16 to 424 pt at y ≈ 81, about
6 pt tall, in translucent white.

**Top row** (centre y ≈ 118):

| Element | Look | Tag |
|---|---|---|
| Close | 40 pt circle in translucent dark grey, white ✕ glyph, x 16–56 | **Keep** |
| Add sound | 131 × 40 pt dark translucent pill: ♫ glyph + "Add sound" (≈15 pt medium), centred | No ruling (open) |
| AI button | 40 pt circle with a purple → red gradient ring and a white four-point sparkle, x 384–424 | **Drop** (AI tool) |

**Right rail.** A 40 pt-wide capsule (x 384–424, y 280–620) in translucent dark grey (≈ #3C3A36 at
≈ 80 %). It has 7 slots at a 50 pt pitch, with white glyphs of about 22 pt. No labels are shown in this
recording.

| # | Glyph | Meaning | Behaviour seen | Tag |
|---|---|---|---|---|
| 1 | Two circular arrows | Flip camera | Tap: one blurred frame (≈0.1 s), then the other camera. No 3D flip | **Keep** |
| 2 | Stopwatch | Timer | Tap: opens the Timer sheet (§2) | **Keep**, used for the pre-roll countdown |
| 3 | "15s" as text | Clip length | Not tapped here (see `02` §2) | **Change**, see §8 |
| 4 | Four-point sparkle with a small star | Effects *(inferred)* | Not tapped | **Drop** |
| 5 | "1x" as text | Speed *(inferred)* | Not tapped | No ruling (open) |
| 6 | Person inside corner brackets | Green screen *(inferred)* | Not tapped | No ruling (open; effect-like) |
| 7 | Chevron ˅ | More tools (overflow) | Not tapped. A blue badge dot (≈8 pt) fades in at its top-right (2.7 s) and out again (4.6 s) | Overflow holds lighting and retouch: **Drop** those |
| new | *(to choose)* | **Teleprompter** | — | **Add** (§8) |

**Bottom row** (centre y ≈ 762):

| Element | Look | Tag |
|---|---|---|
| Gallery | 38 pt rounded-square thumbnail of the last clip (radius ≈ 8), "Add" label (≈13 pt semibold) under it, x 17–55 | No ruling (open) |
| Record button | 72 pt outer white ring (≈4 pt stroke), a dark gap, then a 60 pt white disc, centred x 220 | **Keep** |
| Effect / lens carousel | 40 pt circular thumbnails at a 48 pt pitch from x ≈ 292, running off the right edge, horizontally scrollable *(inferred)* | **Drop** (the tools right of the record button) |

**Mode tabs** (y ≈ 882): "Video · Short · Live · Post". The selected tab, "Short", sits in a dark-grey
capsule (≈ 68 × 40 pt), and the others are grey text. *No ruling. YouTube-specific; likely not needed
(inferred).*

## 2. Timer sheet

`assets/y1-t006.5-timer-sheet.jpg`

A dark (≈ #212121) bottom sheet whose top edge sits at y ≈ 580. Its top corners are rounded about
12 pt. There is no grabber.

| y (pt) | Element |
|---|---|
| 607 | "Timer" (17 pt semibold, left 16); ✕ at right 16 |
| 656 | "Countdown" (15 pt regular, grey-white) |
| 680–724 | Segmented control, 408 × 44 pt capsule in dark grey. Options **3s / 10s / 20s**; the selected one is a black pill. The default is 3s |
| 748 | "Drag to change where recording stops" |
| 778 | "0s" at the left; "15s" in blue (≈ #3EA6FF) at the right, above the knob |
| 805 | Slider: 6 pt blue track, 20 pt blue knob, with a thin vertical marker at the stop point. Its maximum equals the clip length (15 s) |
| 858–905 | **START**: full-width (408 pt) blue (#3EA6FF) button, ≈4 pt radius, caps label in dark text |

**Motion.**

- On open, the camera chrome fades in about 70 ms. The sheet then rises in about 0.15 s, overshooting
  by roughly 10 pt *(spring, inferred)*. The camera scrim dims **after** the sheet lands
  (6.40–6.53 s).
- Changing the segment slides the black pill across in about 0.07–0.1 s.
- **START** drops the sheet in about 0.17 s. The first numeral fades in as it goes, and the scrim
  clears by 14.13 s.

**Owner tag.** **Keep** the countdown (pre-roll). **Change** the stop slider: it becomes the length
setting itself (§8).

## 3. Countdown (pre-roll)

`assets/y1-t018.0-countdown.jpg`

- **Visuals.** A large white numeral (≈130 pt glyph height, thin-to-regular weight, soft shadow) sits
  at the canvas centre (y ≈ 456). Each numeral fades in over about 0.2 s; the previous one is gone
  about 70 ms before the next appears. There is no scale pulse.
- **Chrome.** The top row and the rail are hidden throughout. The record button, carousel and mode
  tabs stay visible; they fade in from a dim state during 13.8–14.1 s.
- **Audio.** There are ten beeps, one on each numeral, at a 1.0 s pitch (onsets 13.69, 14.63, 15.64 …
  22.64 s). Each beep is about 0.27 s of a ≈1.1 kHz tone. The beep on **"1" is higher, at ≈1.66 kHz**
  and ≈0.30 s, which marks "go".
- **Hand-off.** Recording starts about 0.95 s after the "1" beep (23.60 s).
- **Not shown:** cancelling the countdown.

## 4. Recording, pause, segments, auto-stop

`assets/y1-t023.6-record-morph.jpg`, `y1-t028.0-recording.jpg`, `y1-t033.0-paused-segment.jpg`,
`y1-t038.2-record-press.jpg`, `y1-t044.5-recording-near-end.jpg`

**Start morph** (≈0.2 s, 12 frames). Tapping record gives this sequence:

1. The white disc turns to a filled red disc (38.17 s).
2. A grey ring appears around it.
3. The red shrinks to a ≈22 pt rounded square inside a 72 pt red ring (≈3 pt stroke) (38.37 s).

After the countdown, the button passes through a red ring with a ✕ for about 2 frames before it
settles on the stop square. *(This is likely the same morph caught mid-cross-fade.)*

**While recording**, everything fades out in about 0.2–0.3 s except:

- **the progress bar**, filling red (≈ #E8132F) left → right in proportion to the 15 s length;
- **the elapsed timer** "0:07", ≈13 pt semibold white with a shadow, centred at y ≈ 118;
- **the stop button**.

**Stop (tap)** fades the camera chrome back in over about 0.25 s, and the paused row changes:

| Position | Element | Tag |
|---|---|---|
| left, x 17–55 | Gallery thumbnail (its "Add" label is gone) | open |
| left of the button, x ≈ 122 | **Undo last segment**: 40 pt ghost circle with ↶. Not tapped here | **Keep** |
| centre | Record button, white again | **Keep** |
| right, x ≈ 404 | **✓ done**: 40 pt white disc, black check. Ends recording early → review *(inferred; not tapped here)* | **Keep** |

The effect carousel is hidden while paused.

**Segments.** Segment 1 ran about 7.8 s and segment 2 about 7.0 s. The bar keeps segment 1's red and
draws a **white divider tick** (≈1 pt × bar height) at the boundary, about 53 % along. Recording
resumes from the tick.

**Auto-stop.** When the bar is full (0:15, at 45.2 s), recording stops without a tap. The camera
chrome flashes back for about 0.15 s, then the screen cuts to Review (45.47 s).

**End-of-length warning.** There is **none**: the last seconds look exactly like the rest
(`y1-t044.5`). The owner's ruling adds one (§8).

## 5. Review screen

`assets/y1-t046.5-review-rail-labels.jpg`, `y1-t131.0-final-preview.jpg`

- **Canvas.** Same frame as the camera; the clip loops with its audio.
- **Top row:**
  - ← back: 40 pt dark circle. Returns to the camera *(inferred)*. **Keep.**
  - "Add sound" pill. *Open.*
  - Speaker glyph in a 40 pt circle: clip volume *(inferred)*. *Open.*
- **Right rail.** No capsule behind it. Six 22 pt glyphs at a 50 pt pitch (y 340–590, x ≈ 403), each
  with a blue "new" dot. Grey-white labels (≈13 pt, shadowed) sit right-aligned to their left. The
  labels fade in about 0.5 s after entry and out about 2.5 s later; they show again each time the
  screen is entered (130.5–132.5 s). On entry the rail briefly shows only Aa, Captions and Voiceover,
  then grows to six within about 0.13 s.

| Label | Glyph | Tag |
|---|---|---|
| Text | "Aa" | **Keep, primary** |
| Effects | Sparkle | **Drop** |
| Filters | Three overlapping circles | **Keep** (picker: see `02` §6) |
| Stickers | Smiling sticker square | No ruling ("primarily text"); open |
| Captions | Speech bubble with lines | No ruling; open |
| Voiceover | Microphone | No ruling; open |

- **Bottom.**
  - A "⌃ Swipe up to edit" hint (≈11 pt) at the canvas bottom.
  - Two 195 × 40 pt pills, 17 pt apart:
    - **Edit**: dark grey, with a layout glyph. Opens the timeline editor, like the swipe.
    - **Next**: white, black label. Goes to Add details.

## 6. Timeline editor (edit mode, owner's favourite)

`assets/y1-t049.1-swipe-up-to-edit.jpg`, `y1-t050.5-timeline-editor.jpg`

**Entering it** (swipe up, 48.47–49.60 s, ≈1.1 s including the drag). The full canvas shrinks into a
card (287 × 510 pt, x 76, y 62), tracking the finger *(inferred)*. The top row and rail fade, and the
timeline and toolbar rise from below. Playback continues.

**Leaving it.** The ↙↗ button (top-left) or the Text tool grows the card back to the full canvas in
about 0.3 s (60.43–60.77 s).

**Anatomy** (pt):

| y | Element |
|---|---|
| 97 | **↙↗ collapse** (40 pt dark circle, x 32) · **→** (40 pt white circle, black arrow, x 408): finish editing |
| 62–572 | **Card**: the composed preview (video + layers), ≈16 pt radius |
| 593 | **Transport**: play/pause in a 37 pt dark circle (x 36). Ruler with "1s, 2s…" labels and dots between, ≈40 pt per second. Centre label "0:05 / 0:15" (13 pt bold) |
| ≈622–667 | **Overlay track(s)**: one 44 pt bar per layer, salmon (≈ #F4A08A), radius ≈ 6, "Aa" + the layer's text (13 pt). Above the video track |
| ≈685–740 | **Video track**: 55 pt filmstrip, radius ≈ 8. A 48 pt white rounded-square **+** at its end adds a clip *(inferred; open)* |
| playhead | A 1 pt white vertical line fixed at x = 220, from the ruler down to the toolbar. **The timeline moves, not the playhead**: drag it horizontally to scrub |
| ≈885 | **Toolbar**: four 84 × 56 pt dark tiles (radius ≈ 10), glyph over a 12 pt label. **Text** (Keep) · **Effects** (Drop) · **Music** (open) · **Stickers** (open) |

**Selected-layer state** (`y1-t098.5-layer-selected.jpg`). Tapping a track bar selects it:

- the fill turns dark brown (≈ #5A3A34);
- a 2 pt salmon border appears;
- salmon **end-cap handles** (≈12 pt wide, a dark grip line in each) sit just outside the ends;
- the toolbar cross-fades in about 0.2 s to **✕ Deselect · ✂ Split · ✎ Edit · 🗑 Delete**.

| Gesture / control | What happens |
|---|---|
| Drag the end handle | Trims the layer's out point; the bar shortens |
| Drag the start handle | Trims the in point |
| Drag the bar body | Slides the layer in time; its length is kept |
| Playhead outside the layer | **Split greys out** (≈40 %); the layer isn't drawn on the card (`y1-t105.5-split-disabled.jpg`) |
| Deselect | Back to the Text / Effects / Music / Stickers toolbar *(inferred; not tapped)* |
| Edit | Reopens the text editor for this layer *(inferred; not tapped)* |
| Delete | Removes the layer *(inferred; not tapped)* |

**Default timing.** A new text layer spans the **whole clip** (0:00–0:15).

**Owner tag.** **Keep** and emphasise: the card + timeline + layer tracks + selection toolbar.
Drop Effects; Music and Stickers are open.

## 7. Text tool: editor and layers on the video

`assets/y1-t061.5-text-editor-empty.jpg`, `y1-t070.0-text-size-slider.jpg`,
`y1-t070.0-text-chrome-3x.jpg`, `y1-t076.0-text-colour.jpg`, `y1-t078.7-text-track-added.jpg`

### 7.1 Opening

Tapping Text grows the card back to the full canvas (≈0.3 s). Then, over about 0.35 s:

- a ≈60 % black scrim fades over the paused frame;
- the keyboard rises with the style toolbar on top;
- a blinking blue caret appears at the canvas centre-top (y ≈ 345).

### 7.2 Anatomy

**Top bar** (y ≈ 90):

| Position | Element | Behaviour |
|---|---|---|
| left, x ≈ 27 | Person-with-sound-waves glyph | Text-to-speech *(inferred)*. Dimmed (≈40 %) while the text is empty, full white once there's text. Not tapped |
| centre | **"Classic"**: the font chip. 79 × 24 pt, white 1.5 pt outline, ≈6 pt radius, 15 pt label | Cycles or opens fonts *(inferred; not tapped)* |
| right | **"Done"**, 17 pt semibold | Commits the edit |

**Size slider.** A vertical slider at the right edge: x ≈ 424, from y ≈ 138 to ≈ 555. It has a 2 pt
track, a 12 pt white thumb, white **below** the thumb and grey above. **Thumb up = bigger.** Text
resizes live and re-wraps.

**Style toolbar** above the keyboard (y ≈ 608), horizontally scrollable *(inferred: the 10th swatch
is cut off)*. Left to right:

1. **Alignment**: centred-lines glyph, 26 pt (x ≈ 26). Cycles left/centre/right *(inferred)*.
2. **Text background style**: "A" in a square outline, 19 pt box (x ≈ 74). Cycles none / filled /
   outline-type styles *(inferred)*.
3. A thin vertical divider.
4. **Colour swatches** at a 36 pt pitch: white · black · red · coral · amber · green · blue · purple ·
   pink · magenta (cut off). The **selected swatch is a 25 pt solid disc with no ring**; the others
   are 19 pt discs with a 2 pt white ring. Selection snaps with no visible animation.

**Text.** A bold rounded sans (YouTube Sans-like, white by default), centred, wrapping at about the
canvas width minus 40 pt. No background in this recording.

**Keyboard.** The standard system keyboard in its dark appearance.

### 7.3 What was demonstrated

| t | Action | Result |
|---|---|---|
| 63.3–67.6 | Typing | Live text, caret follows |
| 68.4–69.2 | Size thumb down | Text shrinks to ≈200 pt line width, one line |
| 69.5–71.5 | Size thumb up | Text grows to ≈390 pt, wraps to "Adding text to / video" |
| 75.40 | Tap the blue swatch | Text turns blue (≈ #3EA6FF), applied to the whole layer |
| 77.93 | Done | See §7.4 |

### 7.4 Commit

On **Done**:

1. The keyboard and toolbar slide down and the scrim fades (≈0.15 s).
2. The text animates from its editing position (y ≈ 345, raised above the keyboard) **to the canvas
   centre** (y ≈ 450) in about 0.2 s.
3. The editor returns automatically to the timeline (78.43–78.70 s), with a new salmon track for the
   layer.

### 7.5 Manipulating the layer on the card

`y1-t080.0-drag-guides.jpg`, `y1-t085.0-pinch-rotate.jpg`, `y1-t086.9-off-canvas.jpg`

- **One-finger drag** moves the layer freely (79.4–84 s).
- **Two-finger pinch + rotate** scale and rotate the layer together (84–88.8 s): about ×1.3 and about
  −12° here.
- **Guide overlay**, shown only while a finger is down:
  - **diagonally hatched strips** (≈6 pt) down the left and right edges, marking unsafe margins;
  - **ghost Shorts UI** in translucent grey: a column of 4 action circles at right, caption lines and
    an avatar square at the bottom, showing what the player will cover;
  - **thin blue guide lines**: a vertical centre line, plus a horizontal line at about 71 % of the
    card height. *They appear to be snap or alignment guides, but snapping strength can't be measured
    without seeing the finger.*

  The overlay disappears on lift.
- **Off-canvas.** A layer can be pushed partly off the card; it is clipped, not clamped (86.9 s).
- **Not observed:** a selection box or handles on the canvas layer, a trash drop target, layer
  reordering, or a second overlay type in use. Stickers is the only other overlay entry point.

**Owner tag.** **Keep and emphasise.** Styled text layers (font, colour, background style, alignment,
size) that move, pinch-scale and rotate on the video, with timing on the timeline. MakeReady should
also specify the parts YouTube didn't show here: a delete gesture (e.g. a trash target while
dragging), tap-to-re-edit, and layer order. *These are owner decisions, not source behaviour.*

## 8. Owner rulings for MakeReady

| Area | Ruling | Applies to |
|---|---|---|
| Tools right of the record button | **Drop** | The effect/lens carousel (§1). The top-right AI sparkle button is treated as an AI tool too and dropped *(inferred from the ruling)* |
| Effects | **Drop** | Rail sparkle (§1 #4), review rail Effects (§5), timeline Effects (§6) |
| Lighting, Retouch | **Drop** | The camera rail overflow (not opened here; see `02`) |
| Filters | **Keep** | Review rail Filters (§5); picker as in `02` §6 |
| Edit mode | **Keep and emphasise** | §6 and §7, primarily text layers |
| Length | **Change** | Replace YouTube's "15s" toggle and its separate "where recording stops" slider with **one length slider, snapping in 10 s steps, maximum 2:00**, set before recording. Optimised for storage. The progress bar's full width = the chosen length |
| End-of-length countdown | **Add** (YouTube has none, §4) | A countdown as recording nears the chosen length. *Proposal, not in source:* reuse the pre-roll language: centred numerals and the 1.1 kHz / 1.66 kHz beeps |
| Teleprompter | **Add** | A new slot in the right camera rail. The icon is to be chosen; *candidates (not decided):* SF Symbols `text.viewfinder`, `scroll`, `text.alignleft` |
| Pre-roll countdown (Timer) | **Keep** | §2 and §3 |
| Flip, undo segment, ✓ done, close, back | **Keep** | §1, §4, §5 |
| Speed (1x), green screen, Add sound, gallery, mode tabs, Stickers, Captions, Voiceover, Music, + add clip, volume | **No ruling; open for the owner** | — |

## 9. Motion summary

| Transition | Duration | Character |
|---|---|---|
| Camera chrome fade (sheet open, record start) | 70–300 ms | Linear/ease fade |
| Timer sheet in | ≈0.15 s + settle | Spring, ≈10 pt overshoot *(inferred)* |
| Scrim dim after sheet lands | ≈0.13 s, 0.27 s after the sheet starts | Fade, delayed |
| Segmented pill slide | ≈70–100 ms | Ease |
| Timer sheet out (START) | ≈0.17 s | Ease-in |
| Countdown numeral | ≈0.2 s fade-in, every 1.0 s | No scale |
| Record → stop button morph | ≈0.2 s | Ease, colour then shape |
| Chrome return on stop | ≈0.25 s | Fade |
| Auto-stop → review | ≈0.27 s | Brief chrome flash, then a cut |
| Review rail labels | in ≈0.5 s after entry, out ≈2.5 s later | Fade |
| Swipe up to edit | ≈1.1 s including the drag | Interactive; card follows the finger *(inferred)* |
| Card → full canvas (Text) | ≈0.3 s | Ease |
| Text editor in | ≈0.35 s | Scrim fade + keyboard |
| Done → text settles to centre | ≈0.2 s | Ease |
| Editor → timeline after Done | ≈0.27 s | Ease |
| Layer selection toolbar swap | ≈0.2 s | Cross-fade |
| Flip camera | ≈0.1–0.2 s | Blurred frame, no 3D flip |

**Haptics** can't be seen or heard. Likely candidates are record start/stop, the auto-stop, the
segmented change and snapping to a guide *(inferred)*.

## 10. Finish flow (for context)

`y1-t126.0-processing.jpg`

- **→** (top right of the editor) returns to Review. A centred HUD (≈180 × 140 pt, dark translucent,
  ≈16 pt radius) shows a spinner, "Processing" and "This may take a moment" for about 2.3 s.
- YouTube's **Add details** page then slides in. It has:
  - a back button and "Add details" title;
  - a thumbnail with ✎ and a "0:15" badge;
  - a "Caption your Short" field;
  - "Get feedback before you publish" with a button;
  - an account row;
  - Visibility "Public" ›, "Select audience" › and "Show more ˅";
  - a COPPA notice;
  - **Save draft** and **Upload Short** buttons.
- Back returns to Review, with the text layer composited into the preview.
- *YouTube-specific. MakeReady's post-record flow is its own; this page is out of scope.*

## Stills

`assets/`, 440 pt wide unless marked 3x:

| File | Moment |
|---|---|
| `y1-t000.5-camera.jpg` · `y1-t000.5-rail-3x.jpg` | Camera at rest · rail at 3x |
| `y1-t006.5-timer-sheet.jpg` | Timer sheet |
| `y1-t018.0-countdown.jpg` | Pre-roll numeral |
| `y1-t023.6-record-morph.jpg` | Record button mid-morph |
| `y1-t028.0-recording.jpg` | Recording: bar, timer, stop |
| `y1-t033.0-paused-segment.jpg` | Paused: undo, ✓, one segment |
| `y1-t038.2-record-press.jpg` | Second segment start |
| `y1-t044.5-recording-near-end.jpg` | 0:14, no end warning |
| `y1-t046.5-review-rail-labels.jpg` | Review with rail labels |
| `y1-t049.1-swipe-up-to-edit.jpg` | Swipe-up transition |
| `y1-t050.5-timeline-editor.jpg` | Timeline editor |
| `y1-t061.5-text-editor-empty.jpg` | Text editor, empty |
| `y1-t070.0-text-size-slider.jpg` · `y1-t070.0-text-chrome-3x.jpg` | Large text, slider · top bar and toolbar at 3x |
| `y1-t076.0-text-colour.jpg` | Blue selected |
| `y1-t078.7-text-track-added.jpg` | Back on the timeline with a text track |
| `y1-t080.0-drag-guides.jpg` | Drag overlay: hatching, ghost UI, guides |
| `y1-t085.0-pinch-rotate.jpg` | Scaled and rotated |
| `y1-t086.9-off-canvas.jpg` | Clipped off the edge |
| `y1-t098.5-layer-selected.jpg` | Selected layer + toolbar |
| `y1-t105.5-split-disabled.jpg` | Playhead outside the layer |
| `y1-t126.0-processing.jpg` | Processing HUD |
| `y1-t131.0-final-preview.jpg` | Final review |

Any other moment can be re-extracted:

```
ffmpeg -ss <t> -i ~/MakeReady/youtube-1.MP4 -frames:v 1 -vf scale=440:-1 out.jpg
```
