# video-recorder — parked
parked: 2026-11-22 365d4dc0 · by build phase 1 (d2m handover), after server phases 2–3 closed
kind: human-step
blocked: "the new Video Recorder and Video Detail screens don't exist in d2m yet, and the owner has to approve every d2m screen before iPhone code starts (P2) — next: create both screens in d2m, approve the six d2m changes, then /builder:agent --path docs/features/video-recorder"

## What is stuck
Phase 1 is the d2m handover (P2). Under P2 and SPEC §iphone ("no app code until the owner approves
the screens"), the owner approves each screen before any iPhone app code starts. Two things block that:

1. **The two new screens can't be requested.** `request_project_change` refuses `video-recorder` and
   `video-detail` as unknown subjects. Two requests asked d2m to create them. Both answered "done —
   Ran: Create screen …", but `list_screens` / `get_screen` still return NOT_FOUND for both, so their
   spec and build were never filed.
2. **The owner's approval.** The six changes that were filed (below) were still building at park time.
   d2m writes its edits **uncommitted into the main checkout** (`/Users/lukekeith/www/makeready`, on
   `main`), not onto this branch. Its main checkout already showed uncommitted d2m edits to
   `iphone/MakeReady/Info.plist`, `ActivityNewContainer.swift` and `ActivityNewContainerTests.swift`.
   The build doesn't commit on `main` and doesn't merge unapproved d2m views into a feature branch
   (owner rule, 2026-11-20).

What is done: phases 2–3 (server, Tasks 2–7) are built, reviewed and green
(verify phase `mwspcw6o-2c4ff1` at 7952fbf1), and **the contract is frozen** (2026-11-22). Phases 4–5
(iPhone, Tasks 8–18) haven't started.

## What was tried
- d2m requests filed 2026-11-23 01:51 UTC on branch `builder/video-recorder`, with the SPEC and the program's 01–03 docs as references:
  - library-home `cmwsm0v3h0001v0tzy3pfybs0` (video rows, Videos type, D15/D17/D20)
  - activity-new `cmwsm0x14000gv0tz8csbish2` (Video tile enabled, D18). Its capture failed once and was retried.
  - activities-editor `cmwsm0ywy000vv0tzmwz9e7w0` (inline recorder, pending activity, Replace video, D18)
  - C-132 `cmwsm10sp001av0tz4lpxhpbd` (EmptyState action, D19)
  - C-142 `cmwsm1347001pv0tz7kkupdgr` (`removesRow: false`, D17)
  - C-013 `cmwsm155r0024v0tzsp65n3nj` (RecordButton 80 pt video size). d2m asked 7 questions, all answered on the owner's delegation (see Evidence).
- Screen creation: `cmwsm1ny5002pv0tzqbh2f3rn` (on memo-detail) and `cmwsp258b004kv0tz9jna6yz7` (on library-home). Both reported done, but neither screen exists.

## Evidence
- C-013 answers I gave (the owner should review them):
  - OQ-001: build from the 03 doc text, measuring Figma symbols 3322:31523/31531/31557 if they can be read. Any unknown value gets a token-bound default, recorded as a deviation.
  - OQ-002: the memo size stays C-017's 58/46/24 pt.
  - OQ-003: pressed = 0.6 dim at both sizes.
  - OQ-004: drop `isEnabled`.
  - OQ-005: video size morphs disc→square over a new `motion-record-morph` token of about 200 ms; memo swaps instantly.
  - OQ-006/007: the PNGs are committed at `docs/features/video-recording/assets/`.
- `list_screens search:"video"` → "No screen matched" after both create requests reported done.

## Where to dig
- Why d2m's "Create screen" step reports done without a record: the d2m chat run for cmwsp258b004kv0tz9jna6yz7.
- Not yet ruled out: the screen record exists only in the main checkout's uncommitted files, and d2m indexes screens from committed state.

## Recommended next step
In d2m, create the `video-recorder` and `video-detail` screens in the Library namespace (or commit
d2m's uncommitted screen records). Then file their spec+build: the intents are in the Task 1 block of
PLAN.md, and change cmwsm1ny5002pv0tzqbh2f3rn's intent has both texts. Review and approve all eight
subjects in d2m, and bring d2m's commits onto `builder/video-recorder`. Then `/builder:agent --path
docs/features/video-recorder` resumes at Task 1's step 4 (record `d2m-api.md`), then phase 4.
Starting the iPhone state/services work (phase 4) now was rejected: SPEC §iphone and the owner's rule
both hold all iPhone app code until the screens are approved.

## History
- 2026-11-22 parked — d2m screens missing and not yet owner-approved (P2)
