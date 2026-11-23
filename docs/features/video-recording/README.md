# video-recording — analysis

A YouTube-Shorts-style recorder and editor, in MakeReady's UI 2.0 styling, for two contexts: a
**video activity** in a study-program lesson, and **Record a video** from the shell's + menu (saved
to the Library). Videos recorded on the device are transcribed and the transcript is saved with the
video. Status: analysis — the design conversation is in `.builder/video-recording/brainstorm.md`.

| Doc | What it covers |
|---|---|
| [01-youtube-1-analysis.md](01-youtube-1-analysis.md) | `youtube-1.MP4` (134.9 s): camera, Timer sheet, pre-roll countdown, segmented recording and auto-stop, review, timeline editor, text tool and text layers, finish flow |
| [02-youtube-2-analysis.md](02-youtube-2-analysis.md) | `youtube-2.MP4` (49.3 s): pre-record camera only — duration toggle, Timer sheet, the expanded right rail (10 tools), Effects sheet, Filters sheet (20 filters + strength) |
| [03-figma-design.md](03-figma-design.md) | Figma `nVva9a2WvYmcWQo6zlHupO` node `4806:34871` "Recording": two frames (Record video, Recording) inside the lesson editor; component and token mapping; coverage gaps |
| `assets/` | Keyframes `y1-*`, `y2-*` and Figma screenshots `fig-*` |

## Owner rulings (2026-11-22)

- **Drop:** the AI and other recording tools to the right of the record button · effects · lighting · retouch.
- **Keep:** filters · the edit mode with styled, movable text layers over the video (primarily text).
- **Change:** video length is set with a slider that snaps to 10 s steps, maximum 2:00, optimised for
  storage, with a countdown as recording nears the end.
- **Add:** a teleprompter in the right-side control rail (icon to be chosen) · on-device transcription
  saved with the video.
