# video-editor — parked
parked: 2026-11-23 52da3079 · by build phase 1 (Task 1)
kind: human-step
blocked: "d2m built the video editor and Review Edit; your approval of the screens is needed before any app code (D5) — next: review video-editor and video-recorder in d2m, add your approval to SPEC §Decisions, then /builder:agent"

## What is stuck
The spec says the owner approves the d2m-built screens before any app wiring (D5). d2m has specced and
built them; no approval is recorded. Tasks 2–14 have not started.

## What was tried
- d2m requests: the editor (cmwtz6fx80010v0rrhc4ezbpp, done), its parts C-154…C-158
  (cmwtzzqey0046v0rr59bssx7w, done), Review's Edit (cmwtz39vb0001v0rrwx730bsx: code written, then
  cancelled over a preview step with no slug or name). cmwtzc6aw0039v0rrvr24pc76 finished its spec text,
  but its two extra previews have not started since 2026-11-24 00:52 UTC.
- d2m left its edits uncommitted in the main checkout; they are copied here as commit 52da3079 (without
  the Info.plist build number change 1869 → 1930). Verifier phase tier on 52da3079: green, 71 iPhone test files, 1 known failure.
- 2026-11-23 retry: cause gone — D31 approves the screens; d2m's commit still verifies (only docs changed since 52da3079). Phase 1 closed, build continues at Task 2. The 16 copies in the main checkout are byte-identical to this branch; Info.plist is the only extra change there.

## Evidence
- d2m, `video-editor`: 14 captured states — empty, layer-selected, split-disabled, text-tool-new,
  text-tool-edit, manipulating, transcribing, captions-added, captions-unavailable, remove-captions,
  layer-limit, cancel-confirm, playing, landscape. `video-recorder`: review (440 pt, inline) only.
- Answers given on your behalf, from the spec or d2m's recommendation — check these:
  - Review: Edit is a labelled C-147 tool with the `edit` glyph, leading, beside Filters.
  - Captions: Inter bold 24 wu, white on dark, centred at 78 % of the height; new text 38 wu bold white.
  - Timeline: fixed 267 pt, three tracks then scroll, no coasting. Text bars accent, caption bars neutral.
  - Toolbar glyph for Captions is `message-circle`; while transcribing, a spinner replaces it.
  - Split disabled dims only glyph and label. Undo is the centred `undo-2` icon; Cancel is full white.
  - Background style is None · Dark · Light. The colour well opens SwiftUI's ColorPicker.
  - The unsafe band is on all four edges (d2m recommended left and right only).
  - Messages are a dark pill on the preview; the confirm wording is in VideoEditorScreen's constants.
- Not captured: Review full screen, and Review at 343 pt with Retake and Save. d2m measured Edit + Filters
  at about 167 pt; whether the app's Retake and Save fit beside them is proven in Task 14, not by a picture.

## Where to dig
- SPEC §Decisions has no approval row. SPEC D5: "The owner approves them before any app wiring."
- 🔴 The main checkout (`/Users/lukekeith/www/makeready`) still holds d2m's uncommitted copies. Landing
  fast-forwards `main` and git refuses while those files are there. Keep them until approval in case
  d2m rebuilds; before the merge, discard the copies (they are in this branch) and decide on Info.plist.
- If you ask d2m for changes, its new edits land in the main checkout too and must be copied here again.

## Recommended next step
Review both screens in d2m, then add a row to SPEC §Decisions on this branch
("D31 | Screen approval | The video-editor screen and video-recorder's Review are approved as built …"),
and run /builder:agent. Starting app code first was rejected: the spec forbids it.

## History
- 2026-11-23 parked — owner approval of the d2m screens
- 2026-11-23 unparked by Luke — screens approved ("the video editor looks fantastic! Love the screens"), D31
- 2026-11-24 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-24 built through phase 5; text tool keyboard fix on d2m fast lane (cmwudljq70001v0wl9pghmn1p); awaiting the walk lane
- 2026-11-24 walk lane: cause gone — D31 approves the screens; readiness passed, walk starts
- 2026-11-24 walk lane retry: D5 stays settled (D31); an earlier walker died before reporting. Round 1 walked at 1b70fe95: 2 fixes owed (SPEC §Fixes). The round 1 walker ran `xcrun simctl shutdown all`, outside the rule to touch only its own simulator; the next walk must shut down by UDID only
- 2026-11-24 fixes lane: park cause still gone (D31). Both round 1 fixes landed (e1e36e55, f4569b7e), phase tier green at f4569b7, C-153 change reported to d2m (cmwv2rkxl0001v0s352bdtk1q). Next: round 2 re-walks track tap, trim, slide, scroll, Split disabled at 20 layers, filmstrip scrub, and the trimmed import's start
