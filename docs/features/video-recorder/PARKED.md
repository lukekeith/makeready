# video-recorder — parked
parked: 2026-11-23 f9ff51a3 · by build phase 1 (unpark retry after the owner created both screens)
kind: human-step
blocked: "the video recorder's nine new parts need two Figma links and a timer text style that only the owner can add in d2m, and the owner approves the screens before iPhone code (P2) — next: do the 3 steps in PARKED.md, then /builder:agent"

## What is stuck
The cause of the last park is gone: the owner created both screens in d2m. Video Detail is now
specced and built. Video Recorder's screen spec is written (all 43 questions closed), but its nine
new parts (C-143 RecordButtonSet, C-144 TimerPill, C-145 SegmentedProgressBar, C-146 CameraRail,
C-147 RailTool, C-148 CountdownNumerals, C-149 LengthSlider, C-150 FilterStrip, C-151
TeleprompterBand) are minted but **neither specced nor built**, so the screen cannot build. d2m
stopped the screen (run stop `cmwsxcl1i0005v0w8orswh600`) on manual steps that the request channel
cannot do. They are app actions for the owner:

1. Add a Figma reference to **C-143 RecordButtonSet**: node `3322-31523` (variants `3322:31531`
   Recording, `3322:31557` Pause).
2. Add a Figma reference to **C-144 TimerPill**: node `3322-31629` (the Timecode symbol).
3. On the **Typography tab**, add `type-timecode`: SF Pro Regular 18 / 25.2, tracking +0.72,
   monospaced digits. This is the OQ-video-recorder-003 ruling, and type tokens are owned by that
   tab, so no run can mint one.

After that comes the owner's approval of every d2m screen in this feature before any iPhone code
(SPEC §iphone: "Phase 1 is d2m (P2): no app code until the owner approves the screens"; also the
owner's 2026-11-20 rule).

The server half is done: phases 2–3 closed, verify phase GREEN at 7952fbf1, and the contract froze
on 2026-11-22.

## What was tried
- Earlier runs: the root cause of the missing screens was that d2m requests cannot create screens
  (see History). The owner then created both in the app (video-recorder at 05:53 UTC with Figma
  3567:34892 / 3567:34787; video-detail from the suggested requirements).
- This run filed **video-detail** `cmwsuqyfn0001v0xuwomy9lv9`: it settled OQ-video-detail-001..003
  with d2m's recommended options (SPEC D16 "built like memo-detail"; F9 lets the d2m phase settle its
  states before approval). **Done**: `VideoDetailScreen.swift` built, 10 previews captured.
- This run filed **video-recorder** `cmwsur3f5000gv0xuyph9rezu` (spec + build) and answered all 43
  questions. 001–004 took the recommended options. 005–042 (reference images not uploaded) were
  answered "ignore the link", because the channel carries markdown only; the images are committed at
  `docs/features/video-recording/assets/`. 043 (no-Figma parts) was answered with the D71–D73
  ruling: spec from SPEC.md and the analyses, then freeze the first accepted capture. The screen
  spec landed. The chain reported "Ran: Spec/Build" for all nine parts, but `get_screen` rollcall
  shows every one `specced: false, built: false` (the same false-done pattern as the last park). I
  retried once after the stop; it holds on the three manual steps.
- Retried **C-013** `cmwsm155r…`: it stopped "unexplained" again (run cmwsur60u…). It is left open.
  C-143 RecordButtonSet covers the 80 pt video button, and memo hosts keep C-013 unchanged.

## Evidence
- `get_screen video-recorder` (part summary): `"questions":{"open":0,"closed":43}`; the rollcall has
  C-143…C-151 all `"specced":false,"built":false`; runStop steps s3 "Add C-143's Figma reference",
  s4 "Add C-144's Figma reference" and s5 "Add type-timecode on the Typography tab" are
  `"met":false`. s2 (answer OQ-043) also reads unmet, although the question is closed: "report_stop
  refused it as an `answer` step although get_screen lists it open".
- Change cmwsur3f5… `next`: "d2m settled what it could and left 4 steps for you on video-recorder".
- Change cmwsuqyfn… result: "Built video-detail for the first time at
  iphone/MakeReadyUI/Screens/Library/VideoDetailScreen.swift … Created 10 previews and captured all
  of them (10/10)".
- Phase-1 output is all **uncommitted in the main checkout on `main`** (`/Users/lukekeith/www/makeready`):
  library-home, activity-new, activities-editor, C-132, C-142, video-detail and the minted parts.
  It is never on this branch.

## Where to dig
- d2m: a component's "Build" step reports done when the spec step was refused for lack of a
  reference ("lifecycle: Referenced or specced unmet"). That is the same exit-0-after-a-stop defect
  as `screen:create` in the last park. It is worth a d2m ticket.
- d2m: the stop's s2 step cannot be met by `answer_project_change` once the question is closed (a
  race between the chat's answer and `report_stop`). Closing the stop in the app should clear it.
- Not yet ruled out: whether C-145…C-151 spec cleanly from SPEC.md once the stop closes, since
  OQ-043 is answered no-Figma.

## Recommended next step
In the d2m app (Library namespace):
1. Add Figma reference `3322-31523` to C-143 and `3322-31629` to C-144.
2. Add `type-timecode` on the Typography tab (SF Pro Regular 18 / 25.2, +0.72, monospaced digits).
3. Close video-recorder's stop and retry change `cmwsur3f5000gv0xuyph9rezu`, or let the next run do
   it. Then review and commit the phase-1 output on `main` and approve the screens (video-recorder,
   video-detail, library-home, activity-new, activities-editor).
4. `/builder:agent --path docs/features/video-recorder`. The rerun waits on cmwsur3f5…, records
   d2m's names in `d2m-api.md`, and builds phases 4–5.

Why this and not the alternatives:
- Retrying through the channel: d2m names these as owner steps. No channel tool adds a Figma ref or a
  type token (`set_color_token` is colour only).
- Starting phase 4 early: the SPEC forbids iPhone code before approval.

## History
- 2026-11-22 parked — d2m screens missing and not yet owner-approved (P2)
- 2026-11-23 parked — new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2)
- 2026-11-23 unparked by the fleet — automatic retry 1 of 2
- 2026-11-23 parked — root cause found: d2m requests cannot create screens (its chain tool takes one quoted string; the create skill needs two and exits 0 when it stops); owner creates both in the app, then approves (P2)
- 2026-11-23 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-23 parked — owner created both screens; video-detail built; video-recorder specced, but its nine new parts need two Figma refs and a type token only the owner can add, then screen approval (P2)
