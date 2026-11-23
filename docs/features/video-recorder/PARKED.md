# video-recorder — parked
parked: 2026-11-23 23eba0bb · by build phase 1 (unpark retry after the owner added the two Figma refs)
kind: human-step
blocked: "the video recorder and video detail screens are fully built in d2m and wait on the owner's approval before any iPhone code (P2) — next: review and commit the d2m output on main, approve the screens, then /builder:agent"

## What is stuck
Nothing in d2m now. The d2m phase (phase 1) is complete: every part of Video Recorder is specced
and built, and the screen is built with 12 states captured. Video Detail was already built. What
stands is the SPEC's own gate: "Phase 1 is d2m (P2): no app code until the owner approves the
screens", plus the owner's 2026-11-20 rule. No agent can give that approval, so phase 4 (iPhone)
cannot start.

The d2m output is also **uncommitted in the main checkout on `main`** (`/Users/lukekeith/www/makeready`),
not on this branch. That covers the new views (CameraPreview, CameraRail, CountdownNumerals,
FilterStrip, LengthSlider, RailTool, RecordButton, SegmentedProgressBar, TeleprompterBand,
TimerPill, VideoRecorderScreen, VideoDetailScreen), Tokens.swift, and the earlier phase-1 edits
(library-home, activity-new, activities-editor, C-132, C-142, CaptureFixture/ViewRegistry). It is
the owner's working tree; this run did not commit it.

## What was tried
- Last park's three owner steps: the owner added the C-143 ref (3322:31523) and the C-144 ref
  (3322:31629) at 07:16 UTC. The video-recorder run stop cleared (`runStop: null`).
- Retried cmwsur3f5… → no-op: that change already read `done`, so a retry reruns nothing. Filed new
  requests instead.
- cmwsxqfj3… → d2m found that C-143 duplicates C-013 RecordButton. Ruling: merged C-143 into C-013
  (OQ-C-143-001, option 0). Why: the owner's C-143 description says "reconcile with C-013 (extend it
  if it already covers this)", and SPEC §iphone says the same. Cost if wrong: C-143 is struck
  (history kept), so splitting the video size out again would take a new row. Its leftover "Build
  C-143" step then failed on the struck row (moot).
- cmwsy3ioh… → answered OQ-C-013-008: keep the two-source merge (memo from C-017's build, video
  from Figma), per the owner rule that memo hosts keep C-013 unchanged. C-013 re-specced and built,
  clearing its old "unexplained" stop: its build had refused on an open question and stale
  references. C-144 TimerPill specced and built. The "Spec/Build C-145" step reported done but did
  nothing (false-done again).
- **Root cause of the false-done:** C-145…C-152 carried no reference of any kind, so their spec
  step refused on its hard requirement "Referenced or specced". The OQ-video-recorder-043 "no-Figma"
  answer lives on the screen and never attached anything to the rows. Fix: request cmwsz3wvb…
  attached SPEC.md and the 01/02/03 analyses as markdown references per row. The spec step went
  `ready`, although that chat filed no card.
- cmwsz4m2c… → spec+build of C-145, C-147, C-146, C-148, C-149, C-150, C-151, C-152, then the screen
  build: **all done and verified on the rollcall** (every row `specced: true, built: true`).
  Answered ~45 questions. Design questions took d2m's recommended option. Linked-but-not-uploaded
  images were answered "ignore the link", because the channel carries markdown only.
- Rulings that avoid owner-only Typography-tab steps: the countdown numeral (SF Pro Light 180/180)
  and the teleprompter sizes (SF Pro Medium 20/28, 24/32, 30/40) ship as FLAGGED LITERALs
  (OQ-C-148-001, OQ-C-151-002). Cost if wrong: the owner promotes them to type tokens later.
- Ruling: the teleprompter rail glyph is `file-text` (OQ-C-147-004, D1 says d2m picks it and the
  owner approves it). The owner approves or changes it at the screen approval.

## Evidence
- `get_screen video-recorder` rollcall: C-152, C-013, C-144, C-145…C-151, C-132, C-040, C-081 all
  `"specced":true,"built":true`. C-143 has left the roll-call (merged into C-013).
- `get_screen video-recorder` frames: 12 states, each `"hasBuiltRender":true`: ready-to-record,
  pre-roll, recording, paused, end-countdown, permission-denied, review, trim, length-sheet,
  filters, teleprompter-panel, ready-full-screen. All 0 unresolved comments.
- Change cmwsz4m2c… result: "Ran: Spec C-145 … Build C-152 CameraPreview, Build video-recorder
  screen. d2m's edits and builds are in the project checkout (/Users/lukekeith/www/makeready),
  uncommitted — check the diff there and commit."
- `git status` in the main checkout: 11 modified, 13 new files under `iphone/MakeReadyUI/` and
  `iphone/MakeReadyCaptureTests/`.

## Where to dig
- Nothing is left to dig in d2m for this feature. For d2m itself (worth tickets): (1) a component
  step reports done when its spec step refused for lack of a reference; (2) a screen-level "no
  Figma" ruling does not attach references to the parts it covers, so `references` must be passed
  per row; (3) `retry_project_change` on a `done` change is a silent no-op.
- Not yet ruled out: whether the flagged-literal type sizes and the 64 pt video record disc (d2m
  measured it from Figma; SPEC said ~80 pt) read right on device. The owner sees both at approval.

## Recommended next step
1. In `/Users/lukekeith/www/makeready` (on `main`): review the d2m diff and commit it (all files).
2. In d2m, review and approve the screens: video-recorder (12 states), video-detail, library-home,
   activity-new, activities-editor. Check the `file-text` teleprompter glyph and the flagged type
   sizes.
3. `/builder:agent --path docs/features/video-recorder`. Phase 4 (iPhone) wires VideoRecorderScreen
   and VideoDetailScreen against the frozen contract.

Why this and not the alternatives:
- Starting phase 4 now: SPEC P2 forbids iPhone code before the owner's approval.
- Committing the d2m output from this run: it sits in the owner's main checkout on `main`, outside
  this worktree. Under --agent-walk that is a side effect outside the branch, and P2 puts the
  owner's review first.

## History
- 2026-11-22 parked — d2m screens missing and not yet owner-approved (P2)
- 2026-11-23 parked — new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2)
- 2026-11-23 unparked by the fleet — automatic retry 1 of 2
- 2026-11-23 parked — root cause found: d2m requests cannot create screens (its chain tool takes one quoted string; the create skill needs two and exits 0 when it stops); owner creates both in the app, then approves (P2)
- 2026-11-23 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-23 parked — owner created both screens; video-detail built; video-recorder specced, but its nine new parts need two Figma refs and a type token only the owner can add, then screen approval (P2)
- 2026-11-23 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-23 parked — d2m phase complete: C-143 merged into C-013, all parts + video-recorder screen built (root cause of the false-done: parts had no reference); waits on the owner's commit of the d2m output and screen approval (P2)
- 2026-11-23 unparked by a person — named to /builder:agent or /builder:fleet

- 2026-11-23 park resolved — D29 owner approval; phases 4–5 built
