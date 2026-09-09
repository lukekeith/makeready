# Memo — Native-iPhone-Voice-Memos-style audio recording

**Status:** ANALYSIS (no code yet — feeds a future `/build-spec-draft memo`)
**Date:** 2026-08-31
**Source:** one screen recording of the iPhone **Voice Memos** app — `~/Makeready/Memo/memo.MP4`,
21.72 s, 60 fps, 1320×2868 (3×), dark mode, iOS 26 generation.
**Method:** 4 fps contact sheets end-to-end, a 10 fps window over the record-tap transition, and
full-resolution crops of the list bottom bar, both recorder detents, and the inline player row.

## What this is

The goal is to give MakeReady users voice recording that feels like the recorder they already
know — the iPhone Voice Memos app. This suite documents that app precisely enough to rebuild it:
every control and its geometry, what happens underneath at the audio-session and file level, and
what it would take across our four apps.

## The pattern in one paragraph

Voice Memos is **one list and one two-detent sheet**. A floating red circle at the bottom of the
list starts recording on a single tap with no confirmation and no intermediate screen; the button
morphs into the stop control inside a card that rises to meet it. That compact card holds only
what you need mid-thought — an auto-assigned title, a hundredths-precision timer, a live
right-anchored waveform, and one control — while the list stays fully visible and undimmed
behind it. Drag the card up and it becomes a full sheet with a scrubbable waveform on a time
ruler, transport controls, and an explicit Done; drag it back down and nothing about the
recording notices. Done drops you back on the list with the new recording at the top, already
expanded in place into a player. Playback never leaves the list.

## Doc suite

| Doc | Contents |
|---|---|
| **[DECISIONS.md](DECISIONS.md)** | **THE NORMATIVE CONTRACT — read first.** Requirements with acceptance criteria (record / save / transcribe / instant playback), the decision register (M1–M14), exact v1 surface scope with built/not-built control lists, the fidelity standard with enumerated deviations, the full `VoiceMemo` schema + endpoint table, iPhone capability changes, and the **§4b component manifest** — every UI unit with parameters, file path, and usage; nothing exists today and the build may render nothing outside it |
| [01-video-analysis.md](01-video-analysis.md) | Frame-level findings: the list, the record button, both sheet detents with measured geometry, the finish transition, the inline row player, a full timestamped outline, and an explicit list of what the video does *not* show |
| [02-under-the-hood.md](02-under-the-hood.md) | How it really works: `AVAudioRecorder` + pre-armed audio session, metering-driven waveforms, why pause and stop are different controls, location-based auto-naming with numeric disambiguation, on-device transcription, trim/replace/enhance, CloudKit asset sync, the undimmed two-detent sheet — with a cost table for reproducing each piece |
| [03-makeready-translation.md](03-makeready-translation.md) | The monorepo reality (zero audio anywhere today), a proposed `VoiceMemo` schema, capture/upload/transcription design, a ranked copy list, the convergence with notes, and eight open questions |
| [05-implementation-readiness.md](05-implementation-readiness.md) | Gap/feasibility review: **proposed answers to every remaining open question** (M1 new model — `Media` structurally can't hold personal memos; M2 dual-owner mirroring notes; M8 leader-first; M3 presign confirmed; M6 3 h/100 MB/30-day purge), plus ten findings — create-record-first upload lifecycle, interruption handling, crash salvage, the detent-sheet-vs-house-overlay build item, Groq size limits, web format normalization |
| [04-on-device-transcription.md](04-on-device-transcription.md) | **How to actually build the on-device path.** The single-tap `AVAudioEngine` architecture (and why `AVAudioRecorder` can't work), verified `SpeechAnalyzer`/`SpeechTranscriber` API, the model-asset/locale-reservation traps, `audioTimeRange` → tap-to-seek, live-vs-file transcription, fallback triggers, the exact `Info.plist` gaps, and a build order |

## Headline findings

1. **The two-detent recorder sheet is the whole design.** Compact gives you exactly one control
   while a recording is in flight; expanded gives you everything else. The list stays live and
   **undimmed** behind both, and dragging between them never perturbs the capture.
2. **The primary control changes meaning with the detent** — a red *square* (stop, finalizing)
   when compact, red *pause bars* plus an explicit *Done ✓* when expanded — finalizing vs.
   reversible, surfaced honestly in the UI. (Apple gets this from `AVAudioRecorder.stop()` vs
   `.pause()`; **our** build uses `AVAudioEngine` instead — see the decisions table.)
3. **Zero-latency start.** One tap on a floating circle, no confirmation, no new-recording
   screen. This requires pre-arming the audio session before the tap, not on it.
4. **Naming is our one deliberate divergence.** Apple auto-names from location (`Harbor Dr` →
   `Harbor Dr 2`); we are not copying that — location-naming a church member's memo with their
   street address is a privacy problem. The title stays in exactly the same place in the layout
   but becomes a **required, user-supplied field**, seeded with a suggestion and validated on
   Done, never during capture.
5. **Transcription is the sleeper feature.** It is invisible except for a `💬` glyph on each row,
   and it makes the entire library searchable by content. **Claude has no audio input and cannot
   do it.** Our floor is genuinely iOS 26, so on-device `SpeechTranscriber` covers the iPhone for
   free; server-side Groq Whisper v3 Turbo ($0.04/hr of audio) covers everything else.
6. **We have no audio anywhere.** Unlike notes, where the server domain is already live, this is
   greenfield — nothing exists yet on the server, the iPhone, or the web — across all three.

## Decisions & requirements

All normative content lives in **[DECISIONS.md](DECISIONS.md)** — it overrides any other doc here
on conflict. Open items are only its §9 (the leader-only-v1 assumption M8, web timing, and the
Groq upload-cap verification).

## Pipeline gate

**GATE: INCOMPLETE (2026-08-31)** — `/build-spec-verify memo` run on explicit request. Root cause
is singular: **the feature has not entered the build pipeline, and no artifact of it exists in
any app.** Verified fresh this run: no `01-architecture`…`09` pipeline suite (numbered files here
are analysis docs), no phase docs; no `VoiceMemo` model, route, or service on the server; no
`AVAudioEngine`/`AVAudioRecorder`/`SpeechTranscriber` code in `iphone/`; no Groq/whisper
integration; `@aws-sdk/s3-request-presigner` not installed; `Info.plist` still lacks
`NSSpeechRecognitionUsageDescription` and the `audio` background mode. Checklist: items 1, 2, 3,
6, 8, 9, 10, 11 **FAIL** on absent artifacts; items 4, 5, 7 are vacuously true and carry no
force toward READY. Clearing step for every item: `/build-spec-draft memo` → `/build-spec memo`
(audit → plan → build), then re-run this gate.

## Related

- [`docs/features/notes/`](../notes/README.md) — the companion note-taking analysis. **These two
  should be specced together**: a memo attached to a note (or a transcript that *becomes* a note)
  is the real product, and it decides the notes content-format question either way.
- `iphone/MakeReady/Pages/Video/` — the existing custom video recorder with teleprompter; the
  precedent for a capture surface in the app.
- `server/src/services/storage.ts` — R2 upload, the natural home for `.m4a` objects.
