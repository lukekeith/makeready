# video-recording — program
> ✅ SHIPPED 2026-11-24 — every child shipped · last: video-editor
> tier: program · design: Figma `nVva9a2WvYmcWQo6zlHupO` section "Recording" `4806:34871` (2 frames) + the analyses in this folder; d2m era 2.0 specs every screen (P2)

## Overview

Leaders record short videos in the iPhone app in MakeReady's own UI 2.0 style, modelled on the
YouTube Shorts camera and editor the owner recorded (`01-youtube-1-analysis.md`,
`02-youtube-2-analysis.md`). There are two entry points. In a study-program lesson, a **video
activity** records into the Edit lesson page as the Figma frames draw it (`03-figma-design.md`). From
the shell's **+ menu**, "Record a video" opens the same recorder full screen and saves to the
**Library**. Every recorded video is transcribed on the device, and the transcript is saved with it.
The editor adds timed, styled text layers and captions, which are drawn into the video file.

It is cut into two children, each usable on its own. **video-recorder** makes recording, transcribing
and using videos work end to end. **video-editor** adds text layers and captions over a recorded
video. Neither touches the web client: it plays the finished videos as it plays any Cloudflare
Stream video today.

Brainstorm record: `.builder/video-recording/brainstorm.md` — 20 settled by the owner, 9 assumed.

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | video-recorder | lg | server+iphone | A leader records a video of up to 2:00. They can set its length, use a pre-roll countdown, flip the camera, apply a filter, read a teleprompter, record in segments with undo, or import a clip from Photos. The video is transcribed on the device, uploads in the background, and appears in their Library with a detail screen (play, rename, transcript, delete). From a lesson's video activity it is also attached to that activity | — |
| 2 | video-editor | lg | iphone | Before saving a recorded or imported video, a leader adds styled text layers (font, size, colour, background, alignment). They drag, pinch, rotate and delete each layer, with guides, and trim and slide it on a timeline. They can turn the transcript into editable captions. The text, captions and filter are drawn into the saved video | 1 |

Order: child 1 first. It adds the `Video` transcript fields, the Library video list and the
`video-recorder` review step that child 2's editor opens from. The editor cannot be used, or
walked, until there is a recorded video to edit.

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | What is dropped | From the YouTube reference, MakeReady does **not** build: the AI tools and effect/lens carousel right of the record button, the top-right AI button, Effects, Lighting, Retouch, Speed, Green screen, Stickers, Voiceover, Music / Add sound, and the Video/Short/Live/Post mode tabs. Rejected: background music (needs a licensed music source) | Luke 2026-11-22 |
| P2 | Design source | d2m specs and builds every new screen and component of both children (`/ui2-screen`, `/ui2-component`, from doc source) from the two Figma frames plus `01`–`03` in this folder, in UI 2.0 tokens. Each child's first phase is that d2m handover. The owner approves each screen in d2m before any app wiring starts. Builder reads the resulting contracts and never writes them. Rejected: the owner drawing the missing frames in Figma first (everything waits on Figma); a mix where the editor waits on Figma | Luke 2026-11-22 |
| P3 | Layouts | In a lesson, the camera sits inside Edit lesson exactly as Figma `3567:34892` / `3567:34787` draw it. The C-040 header and the activity strip are visible before recording and hidden while recording, and the right rail and recording controls sit over the camera area. From the + menu, the same recorder content fills the screen, with a close button in place of the lesson chrome. Both layouts share one recorder view and its state. Rejected: one full-screen recorder for both (reinterprets the Figma); the lesson layout for both (no room for the rail from +) | Luke 2026-11-22 |
| P4 | Length | Before recording, a length slider runs 0:10–2:00 in 10 s steps and starts at 1:00. The progress bar's full width is the chosen length. Over the last 10 s a 10…1 countdown shows over the preview, and recording stops by itself at the chosen length. Imported clips longer than 2:00 are trimmed to a window of 2:00 or less before editing. Rejected: a 2:00 default (stores more); a 5 s countdown; refusing long imports | Luke 2026-11-22 |
| P5 | Text, filters and captions are drawn into the file | On save, the app exports one video file with the chosen filter, every text layer and every caption composited into the pixels. Cloudflare Stream stores that file. Neither the server nor any player stores or draws overlays. Rejected: a separate overlay layer drawn at playback (two renderers to keep identical, the server stores the layers); both (a re-export and re-upload on every edit) | Luke 2026-11-22 |
| P6 | Transcription | The app transcribes the recorded audio on the device with the speech stack memos already use (`MemoTranscriber`, SpeechAnalyzer / SpeechTranscriber) and sends `transcript` plus timed `transcriptSegments` when it creates the video. When the device cannot transcribe, the server does it, as memos fall back today. The `Video` fields mirror `VoiceMemo`'s (`transcript`, `transcriptSegments`, `transcriptStatus`, `transcriptSource`) | Luke 2026-11-22 (ask) · mechanism (assumed at brainstorm) |
| P7 | One Library | Every video a leader records, from either entry point, is in their Library. A lesson's video activity references that same video. Library videos are private to the leader, like notes and memos; members see a video only through an activity they can open. Rejected: activity-only videos | Luke 2026-11-22 |
| P8 | Who records | The leader roles that already see the + menu and the activities editor. Members never see the recorder | (assumed at brainstorm) 2026-11-22 |
| P9 | Web client | ⬜ in both children. The web lesson player plays the new videos as it does any Cloudflare Stream video, with text already in the pixels. The web video picker keeps reading `GET /api/videos/me` unpaged. There is no web recorder, editor or Library change | (assumed at brainstorm) 2026-11-22 |
| P10 | Reuse, don't relearn | Every recorder task reads `iphone/.claude/VIDEO_RECORDING.md` (orientation through `preferredTransform`) and the legacy `CustomVideoRecorder.swift` / `TeleprompterOverlay.swift` before writing capture or teleprompter code. Overlays go through the typed `Route` system, never `.fullScreenCover`, except the camera capture surface itself (hardware access, per the iPhone house rules) | (assumed at spec) 2026-11-22 |

## Out of scope

- Recording or editing on the web, and members recording videos.
- Editing a video's text after it is saved (P5), clips over 2:00, and joining several clips.
- Sharing or publishing outside MakeReady.
- Searching videos by transcript in master search (a natural follow-on, not in this program).
- The large-lists program (`.builder/large-lists/`, parked). video-recorder's Library video rows
  follow the list as it stands, and large-lists will re-home them with notes and memos.
