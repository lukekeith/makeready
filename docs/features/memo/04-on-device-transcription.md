# 04 — On-Device Transcription: how to actually build it

Implementation design for the decision recorded in
[03-makeready-translation.md](03-makeready-translation.md) §2.4: transcribe on the iPhone using
iOS 26's `SpeechAnalyzer` / `SpeechTranscriber`, with server-side Groq Whisper as the fallback.

**API verified against** [`FluidInference/swift-scribe`](https://github.com/FluidInference/swift-scribe)
— a working iOS 26 app doing record-plus-transcribe — read at commit HEAD on 2026-08-31. Every
type and method named below appears in that source. Anything not verified is marked
**[verify on device]**.

---

## 1. The one decision that matters

**Transcription and recording must share a single microphone tap.**

You cannot open the mic twice. And `AVAudioRecorder` — which
[03](03-makeready-translation.md) §2.2 originally proposed — **cannot work here**: it writes a
file and exposes metering, but it never hands you the PCM buffers, and `SpeechAnalyzer` needs
buffers. Using both means two capture paths fighting over one input.

**Correction to §2.2: drop `AVAudioRecorder`. Use `AVAudioEngine` with one input tap that fans out
to three consumers.**

```
                          ┌─→ AVAudioFile.write(from:)         → the .m4a we upload
AVAudioEngine.inputNode   │
  .installTap(onBus: 0) ──┼─→ BufferConverter → AnalyzerInput  → SpeechAnalyzer (transcript)
                          │
                          └─→ RMS/peak reduction               → live waveform + waveformPeaks
```

This is strictly better than the `AVAudioRecorder` design, and it removes work rather than adding
it:

- The **live waveform** no longer needs `isMeteringEnabled` + `averagePower(forChannel:)` — you
  compute RMS off the buffer you already have, with full control over the dB curve
  ([01-video-analysis.md](01-video-analysis.md) §3.1 describes the curve's behavior).
- **`waveformPeaks`** ([03](03-makeready-translation.md) §2.1) falls out of the same reduction, so
  the stored peak array is finished the moment recording stops. No second decode pass.
- Pause/resume is `engine.pause()` / `engine.start()`.

The cost is that you own the file writing. `AVAudioFile(forWriting:settings:)` takes the output
settings, so pass AAC rather than the reference app's raw input format — swift-scribe writes
`.wav` at the mic's native format, which for a 10-minute memo is ~100 MB instead of ~5 MB:

```swift
let settings: [String: Any] = [
    AVFormatIDKey:          kAudioFormatMPEG4AAC,
    AVSampleRateKey:        44_100,
    AVNumberOfChannelsKey:  1,
    AVEncoderBitRateKey:    64_000,   // ~0.5 MB/min mono — matches Voice Memos "Compressed"
]
audioFile = try AVAudioFile(forWriting: url, settings: settings)
```

---

## 2. The transcriber

### 2.1 Setup

```swift
import Speech

let transcriber = SpeechTranscriber(
    locale: Locale(identifier: "en-US"),
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],   // live partial text; drop for finalized-only
    attributeOptions: [.audioTimeRange])    // ← see §4, this is the feature win

let analyzer = SpeechAnalyzer(modules: [transcriber])

try await ensureModel(for: transcriber, locale: locale)          // §3

let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
    compatibleWith: [transcriber])

let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
try await analyzer.start(inputSequence: stream)
```

### 2.2 Feeding it

The mic's native format is almost never the analyzer's preferred format, so every buffer goes
through an `AVAudioConverter`. Build the converter **once** and reuse it — and set
`converter.primeMethod = .none`, which the reference implementation comments as *"sacrifice
quality of first samples in order to avoid any timestamp drift from source."* That comment is
load-bearing: without it, the `audioTimeRange` attributes in §4 drift out of sync with the audio
file, which breaks tap-to-seek.

```swift
let converted = try converter.convertBuffer(buffer, to: analyzerFormat)
continuation.yield(AnalyzerInput(buffer: converted))
```

### 2.3 Consuming results

`transcriber.results` is an `AsyncSequence`. Each result carries an `AttributedString` and an
`isFinal` flag:

```swift
for try await result in transcriber.results {
    if result.isFinal {
        finalized += result.text     // append — finalized results are incremental
        volatile = ""
    } else {
        volatile = result.text       // replace — volatile results supersede each other
    }
}
```

**Append finalized, replace volatile.** Getting this backwards duplicates or drops text, and it
is the single easiest bug to write here.

### 2.4 Finishing

```swift
continuation.finish()
try await analyzer.finalizeAndFinishThroughEndOfInput()
```

`finalizeAndFinishThroughEndOfInput()` flushes any trailing volatile text into a final result —
skip it and you silently lose the last few words of every memo.

---

## 3. Model assets — the operational trap

Language models are **not** guaranteed present on the device. Two separate concerns, both
required:

```swift
// 1. Download/install, if the system doesn't already have the assets.
if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    downloadProgress = request.progress          // drive a UI indicator off this
    try await request.downloadAndInstall()
}

// 2. Reserve the locale. Reserved locales are a LIMITED, app-held resource.
if !(await AssetInventory.reservedLocales).contains(where: {
    $0.identifier(.bcp47) == locale.identifier(.bcp47)
}) {
    try await AssetInventory.reserve(locale: locale)
}
```

Rules we have to honour:

- **Release what you reserve.** `AssetInventory.release(reservedLocale:)` when the memo surface
  goes away. Leaking reservations will eventually fail `reserve` for the whole app.
- **Check both lists.** `SpeechTranscriber.supportedLocales` (what the OS can do) and
  `SpeechTranscriber.installedLocales` (what is on disk right now) are different questions.
- **Compare on `identifier(.bcp47)`, not `identifier`.** The reference implementation compares
  both ways precisely because the formats don't match reliably.
- **The first download is not instant and needs network.** So the very first memo a user records
  may have no transcript available on device. That is a **fallback trigger**, not an error — see
  §6.

---

## 4. `attributeOptions: [.audioTimeRange]` — take this

Each run in the returned `AttributedString` carries the audio time range it came from. That gives
us, for free, the feature the real Voice Memos app has and that pairs directly with the scrubber
in [01-video-analysis.md](01-video-analysis.md) §4:

- **Tap a word in the transcript → seek playback to that moment.**
- **Highlight the current word as playback advances.**
- **Search hits inside a transcript can deep-link to a timestamp**, not just to the memo.

This is why §2.2's `primeMethod = .none` matters, and it is an argument for keeping the ranges:
store them alongside the transcript rather than flattening to a plain string. Concretely, extend
the schema in [03](03-makeready-translation.md) §2.1:

```
transcript          Text?    ← plain text; what search indexes and what the web renders
transcriptSegments  Json?    ← [{ text, startMs, endMs }]; drives tap-to-seek. Nullable —
                               the Groq fallback path can populate it too (Whisper returns
                               segment timestamps), so this is not an iPhone-only field.
```

---

## 5. Live during capture, or from the file afterward?

`SpeechAnalyzer` supports both. **Do both, for different jobs.**

| | Live (stream during capture) | File (analyze after the fact) |
|---|---|---|
| Transcript ready | the instant Done is tapped | seconds-to-minutes later |
| `💬` glyph on the new row | immediately — matches the recording | appears late |
| Live partial text on screen | yes (`.volatileResults`) | no |
| Costs battery/CPU during capture | yes | no |
| Survives an app crash mid-recording | no | yes |
| Works for backfill / re-runs | no | yes |

**Primary: live.** It is what produces the behavior in the recording — finish, land on the list,
`💬` already there. **Recovery: file.** Re-analyze the saved `.m4a` for any memo whose
`transcriptStatus` is `failed` or `none`, and for backfill of anything recorded before this
shipped. Same `SpeechAnalyzer`, same modules; only the input differs. **[verify on device]** the
exact file-input entry point — swift-scribe only exercises the streaming path.

---

## 6. When to fall back to the server

`transcriptStatus` moves to `pending` and the memo uploads without a transcript when any of these
hit. The server then runs Groq Whisper and patches the record:

1. Locale assets not installed and not downloadable (first-run, offline, low storage).
2. `AssetInventory.reserve` fails.
3. The user's language isn't in `supportedLocales`.
4. The analyzer errors mid-stream, or the app is killed before `finalizeAndFinishThroughEndOfInput()`.
5. The memo was recorded on **web**, which has no on-device path at all.

Consumers never branch on which path produced the text — both write `transcript`,
`transcriptSegments`, and `transcriptStatus`. `transcriptSource` exists for diagnostics only.

---

## 7. Permissions and capabilities

| Item | Status in `iphone/MakeReady/Info.plist` | Action |
|---|---|---|
| `NSMicrophoneUsageDescription` | **present** (line 100) — *"…to record audio with your videos."* | Broaden the copy to cover voice memos |
| `NSSpeechRecognitionUsageDescription` | **absent** | **Add it.** Sources say the Speech framework requires it even for on-device work; the reference app requests only mic access and appears to function. Adding the key costs nothing and an App Review rejection costs a release. **[verify on device]** whether `SFSpeechRecognizer.requestAuthorization` must also be called |
| `UIBackgroundModes` → `audio` | **absent** — only `remote-notification` (line 113) | **Add `audio`.** Without it, capture dies when the user leaves the app mid-thought, which is the whole point of a memo |
| Mic authorization call | — | `AVCaptureDevice.requestAccess(for: .audio)` before starting the engine |

---

## 8. Build order

1. `AVAudioEngine` + single tap → `.m4a` file + RMS waveform. **No transcription yet.** This alone
   delivers the recorder in [01-video-analysis.md](01-video-analysis.md) §3 and unblocks the whole
   memo feature.
2. Upload + playback + inline row player. Feature is now shippable end-to-end.
3. Add the third consumer of the existing tap: `SpeechTranscriber` streaming, `transcript` +
   `transcriptSegments` written on finish. Assets/reservation handled here.
4. Server-side Groq fallback + the file-based re-run path.
5. Tap-to-seek and word highlighting off `transcriptSegments`.

Steps 1–2 have no dependency on any of the transcription work, so the transcription decision does
not gate the start of the build.
