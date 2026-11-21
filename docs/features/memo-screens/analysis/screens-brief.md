# memo-screens — screens brief for d2m

**What this is.** This is the MakeReady version of the iPhone Voice Memos reference video. d2m builds every memo view from it, with no Figma. The measurements come from `docs/features/_archive/memo/analysis/01-video-analysis.md` on `feature/memo` (the same video, `memo.MP4`, 21.7 s). This brief records only where MakeReady differs from that video, and the states each view must capture. The owner's rulings are dated 2026-11-21. The design rulings live in `docs/features/memo-screens/SPEC.md`.

## How MakeReady differs from the video

1. **No memo list and no memo section.** Recording starts from the TabBar Add (+) menu's **Voice memo** item, on any tab. So there is no floating record button: C-013 RecordButton is not built, and the + menu is the record button.
2. **The recorder opens already recording.** There is no "tap to record" step. The sheet appears at the compact detent with the timer running.
3. **Saved memos appear in Library** (screen `library-home`, the Home tab's Library section). They sit mixed in with notes, newest first, under the existing date-section headings. They don't go in a list of their own.
4. **Tapping a memo pushes a new `memo-detail` screen**, the same way a note pushes `note-editor`. There is no player inside the row, so C-007 MemoInlineRowPlayer is not built; its player parts move to memo-detail.
5. **Colours and type come from UI 2.0 tokens**, not from the video's sampled palette. Voice Memos red maps to the error/record token d2m picks; Voice Memos blue maps to the accent token.
6. **Left out because the video never shows them working:**
   - the expanded detent's dimmed ⊕ (layered take);
   - the 💬 transcript button and the EQ/audio-settings button;
   - the Siri tip banner;
   - the Select mode;
   - Edit Recording.

## Views

### C-016 RecorderSheet: two-detent container

- **Presentation:** presented over the whole UI 2.0 shell, on any tab. It is undimmed and has no scrim; the content behind it stays visible at the compact detent.
- **Dragging:** the finger moves the sheet between the compact and expanded detents. Dragging never stops or resets the recording.
- **Grabber:** at the top centre.
- **No swipe-to-dismiss:** recording ends only with stop, Done or Discard. A swipe down from compact snaps back.
- **States to capture:** `compact`, `expanded`, and `dragging` (the sheet between the two detents).

### C-017 RecorderCompactView: compact detent (about ⅓ of the screen)

- **Layout, top to bottom:**
  - the title (auto `Memo {n}`, bold, centred);
  - the elapsed timer `00:02.25` (hundredths, secondary colour);
  - C-011 LiveWaveformView;
  - a **stop** button: a record-red rounded square inside a ringed circle, bottom centre.
- **Stop saves the memo:** stop does exactly what Done does.
- **States to capture:**
  - `recording-start`: elapsed 00:00.4, the waveform a small cluster at the right edge;
  - `recording`: elapsed 00:02.25, the waveform reaching the centre;
  - `recording-long`: elapsed 01:12:05.40, the waveform full width.

### C-018 RecorderExpandedView: expanded detent (full height)

- **Header band:**
  - `⋯` in an outlined circle (leading), with a menu: **Discard recording**;
  - the title, with a subtitle of start time · whole-second duration (`7:43 PM  0:09`);
  - **Done**: a filled accent circle with a white checkmark (trailing).
- **Waveform pane:** C-012 PlayheadWaveformView, with a fixed playhead at centre and a per-second ruler.
- **Big timer:** `00:09.25`.
- **Pause/resume:** a wide capsule with a record-red pause (two bars) that becomes a resume glyph (record-red dot) while paused.
- **States to capture:**
  - `recording`;
  - `paused`: the timer frozen and the waveform still;
  - `discard-confirm`: an action menu "Discard this recording? · Discard (destructive) · Keep recording";
  - `mic-denied`: in place of the waveform and timer, a message "MakeReady needs microphone access to record" with an **Open Settings** button.

### C-011 LiveWaveformView

- **Drawing:** right-anchored record-red bars, newest at the right edge, older ones scrolling left.
- **Input:** `samples` in the range 0–1 at about 20 Hz.
- **States to capture:** `start` (a few bars), `half`, and `full`.

### C-012 PlayheadWaveformView

- **Drawing:** a fixed centre playhead (a hairline with a dot cap), the waveform scrolling left beneath it, and a time ruler with per-second labels.
- **States to capture:** `recording` and `paused`.

### C-004 ScrubTrack, used on memo-detail

- **Drawing:** a flat capsule track with the elapsed fill and a thumb. Labels: elapsed on the left, remaining (negative) on the right (`0:04 … −0:12`).
- **Dragging:** dragging seeks.
- **States to capture:** `start`, `mid`, and `dragging`.

### C-014 TransportControls

- **Controls:** ⟲15 · play/pause · 15⟳, centred as a group.
- **States to capture:** `paused`, `playing`, and `disabled` (audio not yet available).

### C-006 MemoListRow: a memo row in the Library list

- **Matching notes:** it sits beside C-005 NoteListRow in the same list, so it uses the same height rhythm, insets and separators.
- **Line 1:** a mic glyph, the title (one line, truncating), and the duration right-aligned (`m:ss` / `h:mm:ss`).
- **Line 2:** the date label (the notes rule: time today, weekday within 7 days, short date older) · then the transcript preview, one line.
- **The preview slot depends on the transcript state:**
  - ready: the first transcript words;
  - pending: **Transcribing…** (secondary, italic);
  - failed or none: **Audio only**;
  - uploading or offline: **Waiting to upload** (secondary).
- **States to capture:** `ready`, `transcribing`, `audio-only`, `waiting-to-upload`, and `long-title`.

### library-home: change to the existing screen

- **Memo rows join the list:** C-006 rows are interleaved with C-005 note rows in the existing date sections, ordered by `recordedAt` for memos and `updatedAt` for notes, newest first.
- **Search** covers both kinds.
- **`empty`:** says the Library has no notes or memos yet.
- **States to capture:** `populated-mixed` (notes and memos in the Today and Previous 7 Days sections, including one memo `transcribing` and one `waiting-to-upload`), and `search-mixed` (a query matching one note and one memo).

### memo-detail: new pushed screen

- **Chrome:** the same nav chrome family as note-editor: back (leading), `⋯` (trailing), with the menu **Rename · Delete (destructive)**.
- **Header:** the title (tap to rename in place, one line) and below it the date and time (`Today 7:43 PM`) · the duration.
- **Player block:** C-004 ScrubTrack above C-014 TransportControls.
- **Transcript:** the full text in paragraphs, each led by its timestamp (`0:00`, `0:09`, …, from transcript segments). Tapping a paragraph seeks the audio there and plays. While the memo plays, the current paragraph is highlighted.
- **States to capture:**
  - `ready-paused`;
  - `playing`: mid-play, a paragraph highlighted;
  - `transcribing`: the player works, and the transcript area shows "Transcribing…";
  - `audio-only`: "No transcript for this memo";
  - `waiting-to-upload`: the player works from the local file, and the transcript shows if it was made on the phone;
  - `renaming`: the title field focused;
  - `delete-confirm`: "Delete this memo? · Delete · Cancel".

### New component: SavedToast

- **Look:** a small floating capsule above the TabBar: **Saved to Library**, with a trailing **View** text button.
- **Timing:** it auto-hides after 4 s. View pushes memo-detail.
- **States to capture:** `visible`.
