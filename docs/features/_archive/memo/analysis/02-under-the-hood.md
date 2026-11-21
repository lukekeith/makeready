# 02 — How Voice Memos Actually Works

Platform mechanism behind the behaviors in [01-video-analysis.md](01-video-analysis.md). Items
marked **[inferred]** are deduced from behavior or from the platform rather than documented.

---

## 1. Capture

- **`AVAudioRecorder`** writing an **`.m4a` (AAC)** file. Voice Memos ships two quality settings
  (Settings → Voice Memos → Audio Quality): *Compressed* ≈ mono AAC at a low bitrate, and
  *Lossless* ≈ Apple Lossless. Compressed is the default and is why hour-long memos in the
  library (`2:16:41`) are practical.
- **`AVAudioSession`** is configured `.playAndRecord` and activated on the record tap. This is
  what makes the record button start capture with **zero perceptible latency** — the session is
  pre-armed and the file is opened as recording begins, not after a round-trip.
- Recording continues in the **background**: the session keeps the mic alive when the app is
  backgrounded or the screen locks (this is why the system shows a recording indicator). It
  survives the app being scrolled, the sheet being dragged, and the list being interacted with —
  all of which the video demonstrates.
- **Pause is real, stop is final.** `AVAudioRecorder.pause()` keeps the file open and appends on
  resume; `stop()` finalizes it. That is exactly the compact-vs-expanded control split observed
  in §3.2 of the analysis: the compact detent only offers the finalizing action, the expanded one
  offers the reversible one plus an explicit Done.

## 2. The live waveform

- Driven by **metering**: `recorder.isMeteringEnabled = true`, then a display-link or timer at
  ~10–30 Hz calls `updateMeters()` and reads `averagePower(forChannel: 0)` (dBFS, typically −160
  to 0).
- Each sample becomes one bar; dB is mapped to bar height on a **non-linear curve** (a linear dB
  → pixel map makes speech look flat, which is why the observed bars have such lively dynamics).
- The compact detent renders it **right-anchored** — a fixed-length ring buffer of the most
  recent N samples, newest at the right edge. Nothing scrolls; the buffer shifts. That is why it
  "grows" from the right edge for the first ~3.4 s and then appears to scroll.
- The expanded detent renders the **same buffer against a time ruler with a fixed center
  playhead** — the content translates under a stationary line. Same data, different transform.
- The **saved** waveform (used in Edit Recording and in the scrubber) is a different artifact: it
  is computed once from the finished file by reading samples and reducing them to per-pixel
  min/max peaks, then cached. Live metering is too coarse and too lossy to reuse. **[inferred]**

## 3. Playback

- `AVAudioPlayer` (or `AVPlayer`) over the local file. Skip ±15 s is a seek, not a scrub.
- `−0:16` in the inline player is remaining time rendered negatively — a deliberate choice so the
  right-hand number is stable in width and reads as "time left".
- The row-level scrubber is a plain track, not a waveform. The waveform is reserved for capture
  and for editing, where sample-level precision matters.

## 4. Automatic naming

- Titles like `Harbor Dr`, `2301 Plastic Surgery`, `Windhaven Pkwy 5` come from
  **Location-based naming** (Settings → Voice Memos → Location-based Naming), which reverse-
  geocodes the device's current location at record time via **Significant Locations**. Rows
  named `Recording`, `Recording 2`, `Recording 3` in the same library are from before that
  setting was on, or from locations that could not be resolved.
- **Disambiguation is a numeric suffix against existing names**: because a `Harbor Dr` already
  existed (May 27, 2025), the new one became **`Harbor Dr 2`** — matching `Windhaven Pkwy 4`,
  `Windhaven Pkwy 5` elsewhere in the list.
- The title appears ≈1.1 s into recording, not at t=0 — consistent with the geocode being an
  async lookup that lands shortly after capture begins. **[inferred]**
- The name is editable afterward via the `⋯` menu; renaming renames the underlying file.

## 5. Transcription

- The `💬` glyph on a row means a transcript exists. Voice Memos transcribes **on device** using
  the Speech framework (`SFSpeechRecognizer` with on-device recognition; iOS 26 uses the newer
  `SpeechAnalyzer`/`SpeechTranscriber` path), so it works offline and never uploads audio.
- Transcription starts as soon as the recording is finalized — the glyph is present on the new
  row immediately on return to the list.
- The transcript is **searchable**: the list's search covers transcript text, not just titles.
  This is the single highest-leverage feature in the app and it is invisible in the UI except for
  that one glyph.

## 6. Editing

Behind the `⋯` menu and the blue waveform button in the inline player:

- **Edit Recording** opens a waveform editor supporting **trim** (keep a range) and **replace**
  (re-record over a selected range in place) — both are `AVAssetExportSession`/`AVMutableComposition`
  operations against the source file.
- **Enhance Recording** is a one-tap audio filter (noise reduction + room-echo reduction). It is
  non-destructive and toggleable — the original is retained.
- The audio-settings glyph in the expanded recorder's bottom row is the playback/monitoring
  settings entry (Enhance, skip silence, playback speed) surfaced during capture. **[inferred —
  never opened in the recording]**
- The dimmed blue `⊕` in the waveform pane is disabled during capture; in iOS 26 Voice Memos this
  is the layered-recording affordance (record a second take over an existing one, aimed at
  musicians). **[inferred]**

## 7. Storage and sync

- Files live in the app container; metadata (title, date, duration, transcript, favorite, folder)
  in a Core Data store beside them.
- Sync is **iCloud (CloudKit)** with the audio file as a `CKAsset`. Because the asset is the
  whole file, sync is all-or-nothing per recording — there is no partial or streaming sync, and a
  long recording is a large upload.
- Deleted recordings go to a **Recently Deleted** folder with a retention window rather than
  being destroyed, which is why the trash button needs no confirmation dialog.

## 8. The two-detent sheet

- Standard `UISheetPresentationController` with two detents (a custom ~319 pt compact detent and
  `.large()`), `prefersGrabberVisible = true`, and **no dimming view** — hence the list stays
  fully legible and interactive behind the compact detent.
- Detent changes are **interactive**: the sheet tracks the pan gesture continuously and settles
  to the nearest detent on release. The video shows arbitrary intermediate heights, confirming
  this is not a two-state animation.
- The content swaps its layout by detent (`selectedDetentIdentifier`), which is why the primary
  control morphs square ↔ pause-bars a beat after the height changes: the layout change is driven
  by the settle, not by the drag.
- The record-button-to-stop-button morph across the presentation boundary is a matched-geometry
  transition between two views that share a position and size. **[inferred]**

## 9. Cost table for reproducing this elsewhere

| Behavior | iOS mechanism | Reproduction cost |
|---|---|---|
| Zero-latency capture start | pre-armed `AVAudioSession` | low on iOS; **web `getUserMedia` has a real permission + warm-up delay** |
| Background / lock-screen recording | background audio mode | low on iOS; **impossible on web** |
| Live waveform | `updateMeters()` + `averagePower` | low on iOS; on web, `AnalyserNode` from the Web Audio API |
| Saved waveform peaks | offline sample reduction | medium, both platforms |
| Pause / resume append | `AVAudioRecorder.pause()` | free on iOS; on web, `MediaRecorder.pause()`/`resume()` |
| Trim / replace | `AVMutableComposition` | medium on iOS; high on web (server-side ffmpeg is the realistic path) |
| On-device transcription | Speech framework | low on iOS, **on device and free**; on web, a server round-trip |
| Location naming | Significant Locations + reverse geocode | low, but a privacy decision |
| Two-detent undimmed sheet | `UISheetPresentationController` | low on iOS with UIKit; **custom in SwiftUI-only and on web** |
| Enhance Recording | private audio unit | not reproducible; nearest equivalent is a server-side filter |
