# Memo — Normative Decisions & Requirements

**This file is the contract.** Every other doc in this directory is analysis or reference; if any
of them disagrees with this file, this file wins. An implementer starts here. Rows marked
*(default)* were adopted 2026-08-31 from the readiness review without explicit user sign-off and
may be vetoed; until vetoed they are decisions, not options.

---

## 1. What ships in v1

Voice-memo capture, storage, playback, and transcription in the **iPhone leader app**,
replicating the iPhone Voice Memos app's recorder and list. Owned by the signed-in leader
(`User`). Web is **out of v1 scope** (no playback surface, no capture). Members: out of v1.

## 2. Requirements → acceptance criteria

Ship-gating (in priority order):

| # | Requirement | Passes when |
|---|---|---|
| R1 | Record an audio memo | Tapping the record button starts capture in < 200 ms perceived (session pre-armed on surface appear); recording survives app background/lock, an incoming call (auto-pause, auto-resume per F2), and detent drags without a glitch in the file |
| R2 | Audio is saved | A finished memo exists as one mono AAC `.m4a` (~64 kbps) in R2 under the `pending → ready` lifecycle (§3 M9); a memo recorded offline uploads on reconnect; no orphaned R2 objects (failed uploads = sweepable `pending` rows) |
| R3 | Transcription generated and saved | ≤ 5 s after Done on-device (normal path), `transcript` + `transcriptSegments` + `transcriptStatus: ready` are stored; when on-device fails for any reason in §3 M4's trigger list, the server fallback produces the same fields with no consumer-visible difference |
| R4 | Instant playback + scrubbing | On Done, the list shows the new memo at top, already expanded into its inline player, ≤ 1 s after the sheet dismisses; drag on the scrub track seeks; ±15 s buttons seek; elapsed/remaining render as `0:00` / `−0:16` |

## 3. Decision register

| ID | Decision | Exact ruling |
|---|---|---|
| M1 | Data model | New `VoiceMemo` Prisma model — exact field list in §6. **Not** `Media` (requires `organizationId` + `User` uploader; wrong shape for personal data) |
| M2 | Ownership | `userId` (leader) in v1, via a `requireAuth` `/api/memos` route family. Schema keeps nullable `memberId` for the future member surface, mirroring `StudyNote` |
| M3 | Upload transport | Presigned R2 PUT minted by the server (`@aws-sdk/s3-request-presigner` against the existing `S3Client`), signed with the exact `ContentLength` the client declares |
| M4 | Transcription | On-device `SpeechTranscriber` (iOS 26), live during capture, is the primary path. Server fallback: **Groq Whisper Large v3 Turbo**, triggered when: assets not installable, locale unsupported, analyzer error, app killed mid-recording, or `transcriptStatus` still `pending`/`failed` at server sweep. Both paths write identical fields; `transcriptSource` is diagnostics-only. Claude is never a transcription candidate (no audio input) |
| M5 | Naming | Title is **required and user-supplied**. The expanded sheet's centered title is an editable field, pre-filled with a suggestion (linked context name if a link exists, else `Memo {n}` where n disambiguates within the owner's memos). Done validates non-empty (trimmed); the pre-fill guarantees validity, so Done never blocks on typing. No location-derived naming, ever |
| M6 | Limits & retention | Max duration 3 h (recorder hard-stops with the memo intact); presign refuses `ContentLength` > 100 MB; delete = `isActive: false`; a purge job hard-deletes rows + R2 objects after 30 days; trash button needs no confirmation dialog *(default)* |
| M7 | Fidelity standard | See §5 |
| M8 | Audience | Leader-only v1 *(default — assumed to match notes' confirmed "leader's account"; veto if memos are member-facing day one)* |
| M9 | Upload lifecycle | Create-first: `POST /api/memos` (metadata, `status: pending`) → response carries presigned URL → client PUTs bytes → `PATCH /api/memos/:id/complete`. Sweep job expires `pending` rows > 24 h old and deletes their keys |
| M10 | Capture engine | `AVAudioEngine`, one input tap fanning out to (a) `AVAudioFile` AAC write, (b) converted `AnalyzerInput` stream, (c) RMS/peak reduction for live waveform + stored `waveformPeaks`. **Never `AVAudioRecorder`** (no PCM access). Full mechanics: `04-on-device-transcription.md` |
| M11 | Waveform data | `waveformPeaks`: array of 0–1 floats, one per 100 ms of audio, computed on device during capture, stored on the record at complete-time. All scrubber rendering uses it; clients never decode audio to draw |
| M12 | Interruptions & salvage | Phone call/Siri: auto-pause on `interruptionNotification .began`, auto-resume on `.ended` + `.shouldResume`. A local draft manifest (file URL, startedAt, title draft) is written at capture start; on next launch an unsaved draft is offered for recovery, transcribed via the file path *(default)* |
| M13 | Search | `q` param on `GET /api/memos` matching `title` and `transcript`, case-insensitive *(default)* |
| M14 | Links | v1 memos are standalone (no link table rows written). `MEMO` is added to `LINK_TYPES` so a *note* may reference a memo (notes N8). Memo→lesson/group linking: deferred |
| M15 | Component manifest | §4b is the exhaustive UI + supporting-unit list; the build renders nothing outside it (REFERENCE.md §3 rule 7) |

## 4. The recorder surfaces — exact v1 scope

Normative geometry, layouts, and timings: `01-video-analysis.md` §3 (compact detent §3.1,
expanded §3.2, finish transition §4). v1 builds:

1. **Floating record button** on the memo list (56 pt red circle, bottom-center, no bar).
2. **Compact detent** (~319 pt card): title text, `mm:ss.SS` timer, live right-anchored waveform,
   red stop square. Stop = finalize (same as pause + Done).
3. **Expanded detent** (full height): editable title field (M5), `⋯` **omitted in v1**, blue
   Done ✓, center-playhead waveform with per-second ruler, large timer, red pause/resume capsule.
   The `⊕` layered-recording button, transcript button, and audio-settings button from the
   reference are **not built** — no placeholders.
4. **Inline row player** on the list: title/time/`💬` row, flat scrub track with
   elapsed/`−remaining`, `⟲15 ▶ 15⟳`, trash. Transport is functional; the leading
   waveform-edit button is **not built**.
5. Detents are interactively draggable with recording unaffected — built inside the app's typed
   `Route`/`presentModal` overlay system (never SwiftUI `.sheet`), via `/present-overlay` +
   `/transition-review`.

## 4b. Component manifest — nothing exists; every row is (new)

**Premise (user-stated, verified in code):** no memo UI, audio capture, or playback code exists
anywhere in the iPhone app. Everything below is created from scratch. **This manifest is
exhaustive by construction** (REFERENCE.md §3 rule 7): the build step renders only these units,
with these parameters, at these paths; needing anything not listed is a spec defect resolved by a
dated amendment + delta audit *before* code — never an inline invention. Paths follow the app's
directory conventions (`iphone/MakeReady/Components/{Button,Card,Display,Input,Overlays}`,
`Pages/<Domain>/`, `Services/`).

### Pages

| Component (new) | Path | Parameters | Usage |
|---|---|---|---|
| `MemosListPage` | `Pages/Memos/MemosListPage.swift` | none — reads `AppState.voiceMemos` | The memo list: large title, rows newest-first, floating `RecordButton`; owns which row is expanded into the inline player; presents `RecorderSheet` on record |

### Components

| Component (new) | Path | Parameters | Usage |
|---|---|---|---|
| `MemoListRow` | `Components/Card/MemoListRow.swift` | `title: String`, `dateLabel: String`, `durationLabel: String`, `hasTranscript: Bool`, `isExpanded: Bool`, `onTap: () -> Void` | Collapsed row (title / date + `💬` when `transcriptStatus == ready` / duration); tap expands in place (R4); consumed only by `MemosListPage` |
| `MemoInlineRowPlayer` | `Components/Card/MemoInlineRowPlayer.swift` | `memoId: String`, `playback: PlaybackState`, `onPlayPause: () -> Void`, `onSkip: (Int) -> Void` (±15), `onScrub: (Double) -> Void`, `onRename: () -> Void`, `onDelete: () -> Void` | §4 item 4: the expanded row — `ScrubTrack` + `TransportControls` + trash; rendered inside the expanded `MemoListRow` |
| `RecordButton` | `Components/Button/RecordButton.swift` | `isEnabled: Bool`, `action: () -> Void` | 56 pt red circle with dark bezel, floating bottom-center over list content; tap = capture start (R1, session pre-armed by `MemoRecorderEngine`) |
| `RecorderSheet` | `Components/Overlays/RecorderSheet.swift` | `detent: Binding<RecorderDetent>`, `session: RecorderSession` | The two-detent, undimmed, finger-tracked overlay built inside the typed `Route` system (F4 — never `.sheet`); hosts the two content views; list stays live behind compact |
| `RecorderCompactView` | `Components/Overlays/RecorderCompactView.swift` | `title: String`, `elapsed: TimeInterval`, `samples: [Float]`, `onStop: () -> Void` | §4 item 2: title · `mm:ss.SS` timer · `LiveWaveformView(.rightAnchored)` · red stop square (stop = finalize) |
| `RecorderExpandedView` | `Components/Overlays/RecorderExpandedView.swift` | `title: Binding<String>`, `elapsed: TimeInterval`, `samples: [Float]`, `isPaused: Bool`, `onPauseResume: () -> Void`, `onDone: () -> Void` | §4 item 3: M5 editable title field · `PlayheadWaveformView` · large timer · red pause/resume capsule · blue Done ✓ (validates non-empty title) |
| `LiveWaveformView` | `Components/Display/LiveWaveformView.swift` | `samples: [Float]`, `style: .rightAnchored` | Live bars, newest at the right edge, ring-buffer driven at ~20 Hz |
| `PlayheadWaveformView` | `Components/Display/PlayheadWaveformView.swift` | `samples: [Float]`, `elapsed: TimeInterval` | Center red playhead + per-second tick ruler; content scrolls beneath the fixed line |
| `ScrubTrack` | `Components/Input/ScrubTrack.swift` | `progress: Binding<Double>`, `elapsedLabel: String`, `remainingLabel: String` (`−0:16` form) | Flat capsule seek bar for the inline player; drag = seek (R4) |
| `TransportControls` | `Components/Button/TransportControls.swift` | `isPlaying: Bool`, `onPlayPause: () -> Void`, `onSkipBack15: () -> Void`, `onSkipForward15: () -> Void` | `⟲15 ▶ 15⟳` white glyph row; consumed by `MemoInlineRowPlayer` |

### Supporting non-UI units (same no-invention rule)

| Unit (new) | Path | Contract | Usage |
|---|---|---|---|
| `MemoRecorderEngine` | `Services/Audio/MemoRecorderEngine.swift` | `prepare() / start() / pause() / resume() / stop() -> RecordingResult`; publishes `samples`, `elapsed` | M10: one `AVAudioEngine` tap fanning to AAC `AVAudioFile` + `AnalyzerInput` stream + peak reduction; M12 interruption handling + draft-manifest salvage; pre-armed on `MemosListPage` appear (R1) |
| `MemoTranscriber` | `Services/Audio/MemoTranscriber.swift` | `startLive(stream:) / finish() -> Transcript`, `transcribeFile(URL) -> Transcript` | M4: `SpeechAnalyzer`/`SpeechTranscriber` wrapper incl. `AssetInventory` ensure/reserve/release; produces `transcript` + `transcriptSegments` |
| `MemoUploadController` | `Services/Audio/MemoUploadController.swift` | `upload(RecordingResult) async` | M9 lifecycle: `POST /api/memos` → presigned PUT → `PATCH complete`; offline queue (F7) |
| `MemoActions` | `State/Actions/MemoActions.swift` | `loadMemos / createAndUpload / rename / softDelete` against `/api/memos` | Sole API surface; refreshes `AppState` per house rule |
| `AppState.voiceMemos` | `State/AppState.swift` | `EntityStore<VoiceMemo>` | Disk-cached list source; new-memo insert-at-top on Done (R4) |
| `RecorderDetent`, `RecorderSession`, `PlaybackState`, `VoiceMemo` | `State/Models/MemoModels.swift` | `compact/expanded`; session state machine (`recording/paused/finishing`); playback progress | Shared vocabulary across sheet, engine, and rows |

The **web** manifest is written when that phase is drafted (out of v1 per §1) — same rule. A
draft-time inventory pass may swap an existing primitive into a row only via a **dated manifest
amendment**, never silently.

## 5. Fidelity standard (what "mimic Voice Memos" means, operationally)

- Target values = the measurements in `01-video-analysis.md`; colors from MakeReady tokens
  (record-red may stay red).
- **Enumerated deviations** (complete list — anything else that differs is a defect):
  1. Title is an editable, required field in the expanded header (M5) instead of a
     location-derived label.
  2. Controls listed as "not built" in §4 are absent, without placeholders.
  3. No Siri tip banner, folders, favorites, `Select` mode, Edit Recording, Enhance, or playback
     settings in v1.
  4. List rows show a relative date + duration; `💬` appears only when `transcriptStatus: ready`.

## 5b. Measured motion & reference values (30 fps re-analysis, 2026-08-31)

Normative targets for every transition the video demonstrates. All values re-measured at 30 fps
(±0.03 s) from `memo.MP4`; implement via Motion tokens and check with `/transition-review`.

| Transition | Measured behavior |
|---|---|
| Record tap → compact sheet | Tap ≈ ripple on the button; sheet rises over **0.35–0.40 s, ease-out** (most travel in the first third). The red circle morphs into the stop square **during the first ~150 ms of the rise**, in place. Waveform sliver appears at the right edge ~0.4 s after start; auto title fades in ~0.8 s after start (ours is the pre-filled field, same timing) |
| Detent drag | Fully interactive — sheet tracks the finger at arbitrary heights. On release, settles to the nearer detent in **~0.15–0.25 s, ease-out**. Layout is **height-driven, not settle-driven**: the compact/expanded content cross-fades during the drag (expanded chrome already visible at partial height), and the square⇄pause-bars morph completes at settle |
| Done → list | Timer freezes on tap (recording stops first). Sheet then **collapses upward into the top-of-list row position over ~0.25–0.30 s** — it reads as sheet-morphs-into-row — while the stop control morphs back into the floating record circle. New row is fully rendered as the expanded inline player by **~0.45 s** after tap |
| Recording continuity | Across every detent drag: timer, waveform, and capture visibly unaffected (verified through six drags) |

**Reference palette** (sampled from full-res frames; per §5 our build maps these to MakeReady
tokens — record here so the mapping is grounded, not guessed):

| Element | Sampled |
|---|---|
| List background | `#010101` |
| Record button / stop square / waveform red | `#FD383C` |
| Compact sheet fill & expanded header band | `#1A191C` |
| Expanded waveform pane | `#26252A` |
| Done ✓ blue | `#0083FE` |

**Waveform geometry** (live view, @3×): bar width ≈ 2–4 px (~1 pt), pitch ≈ 10–12 px
(~3.5–4 pt), ~20–24 new bars/s — matches the ~20 Hz metering cadence in M10/M11.

**Not derivable from the video — normative source is THIS FILE, not the recording:** playback was
never started (play, scrub, ±15 skip all undemonstrated — transport stayed dimmed), pause was
never tapped, the compact stop square was never tapped, delete/rename/`⋯`/transcript view/search/
Select were never opened, and light mode never appears. Their behaviors are specified by §2–§4
and standard platform conventions; no implementer should hunt the video for them.

## 6. Server: schema + endpoints (v1 complete list)

```prisma
model VoiceMemo {
  id                 String    @id @default(uuid())
  userId             String?           // v1 owner
  memberId           String?           // future member surface; exactly one owner set
  title              String
  key                String            // R2 object key
  url                String?           // public URL, set at complete
  mimeType           String    @default("audio/mp4")
  fileSize           Int?
  durationMs         Int?
  waveformPeaks      Json?             // float[0..1][], 10/sec (M11)
  transcript         String?   @db.Text
  transcriptSegments Json?             // [{text, startMs, endMs}]
  transcriptStatus   String    @default("none")   // none|pending|ready|failed
  transcriptSource   String?           // on_device|server
  uploadStatus       String    @default("pending") // pending|ready
  recordedAt         DateTime
  isActive           Boolean   @default(true)
  createdAt          DateTime  @default(now())
  updatedAt          DateTime  @updatedAt
  @@index([userId, recordedAt])
  @@index([memberId, recordedAt])
  @@map("voice_memos")
}
```

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /api/memos` | `requireAuth` | Create `pending` row from metadata (`title`, `durationMs`, `fileSize`, `recordedAt`, `waveformPeaks`, optional `transcript`+`transcriptSegments` from on-device); returns row + presigned PUT URL (M9) |
| `PATCH /api/memos/:id/complete` | `requireAuth` | Marks `uploadStatus: ready`, sets `url`; if no transcript arrived, sets `transcriptStatus: pending` and enqueues Groq fallback |
| `GET /api/memos?q=&limit=&offset=` | `requireAuth` | Owner-scoped list, `recordedAt` desc, `q` per M13 |
| `GET /api/memos/:id` | `requireAuth` | One memo |
| `PATCH /api/memos/:id` | `requireAuth` | Rename (`title` only) |
| `DELETE /api/memos/:id` | `requireAuth` | Soft delete (M6) |

New service `memos.service.ts`; fallback transcription in a `transcription.service.ts` calling
Groq (`GROQ_API_KEY` env; chunk with ffmpeg at silence boundaries when the file exceeds the
provider's upload cap, offsetting returned segment timestamps).

## 7. iPhone capabilities (v1 complete list)

`Info.plist`: broaden `NSMicrophoneUsageDescription` copy; add
`NSSpeechRecognitionUsageDescription`; add `audio` to `UIBackgroundModes`. Verification tasks
marked `[verify on device]` in `04-on-device-transcription.md` §7 are part of phase 1, not
optional.

## 8. Implementation environment notes

Same as notes `DECISIONS.md` §7 (Docker restart for server edits, `/rebuild-iphone`,
`/present-overlay`, `/push-page`, `/transition-review`, `/ios-error-surface`, iOS 26.0 target).

## 9. Genuinely open (nothing else is)

- M8 assumption (leader-only v1) awaits explicit confirmation.
- When web playback/capture ships (capture requires server-side transcode of `MediaRecorder`
  output to `.m4a` — recorded in `05-implementation-readiness.md` F6).
- Groq's current per-request upload cap (verify at implementation time; chunking design in §6
  covers any answer).
