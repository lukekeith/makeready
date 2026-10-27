# group-cover-image — parked
parked: 2026-10-27 32413b8 · by build phase 7 (before Task 11)
kind: human-step
blocked: "the Edit cover screen is being specced and built in d2m (screen edit-cover, by session d2m-4a) and the build only wires it [F1] — next: when d2m's edit-cover commit lands on main, /builder:agent --path docs/features/group-cover-image"

## What is stuck
Task 11 wires the Edit cover page to the d2m-built SwiftUI screen, and Task 12 (cover tap → picker /
C-066 menu / viewer) routes to `.editGroupCover`, which Task 11 produces. The screen still does not
exist on this branch or on `main`. It is no longer unowned, though: the owner set up a d2m
counterpart session, `d2m-4a`, which has it in flight:
- `/d2m:screen:spec edit-cover` (run cmvqzi9i100dnv0sdpkwcutwm). It reads Figma 4729:53712 (chrome),
  the owner's bundle `~/MakeReady/Design reference/edit-cover/` (README + 12 stills), and SPEC
  D20–D27. Its order: C-040 contract refresh → C-040 code (`trailingLoading` + `leadingEnabled` for
  D13) → spec re-run → `/d2m:screen:build edit-cover`.
- `/d2m:component:update C-087` → 16:9 (D20, F11) (run cmvqzju9f00dsv0sdndz2ihvf).
d2m will send the view path, its State/inputs, the closures (onCancel, onDone, onFlip, onRotate90,
onAuto) and how the app-owned image slot works, and it will commit on makeready `main`.

## What was tried
- 2026-10-27 unpark: F1 re-checked with `grep -rli "edit.\?cover\|4724.53609\|4729.53712"
  iphone/MakeReadyUI docs/ui2` and `git grep` on main — still no match; main had not moved since the park
- Built everything that does not need the screen: Phase 5 closed (Task 10), Phase 6 Task 13 (server
  framing `flipped` + `quarterTurns`, contract re-frozen 2026-10-27, 8e3c3ff), Task 14 (16:9 framing
  math, render 1200×675, model flip/rotate90/auto/rubber-band, a0e3b3e..32413b8, review clean)
- Sent d2m-4a the screen requirements; it took the work (and C-087) per the owner's routine

- 2026-10-27 fleet retry: F1 cause CLEARED — d2m's 8b83f38 `feat(ui2): edit-cover screen` (iphone/MakeReadyUI/Screens/Groups/EditCoverScreen.swift) is on main and merged into this branch (709c6d8); SPEC revised 360f8a4 (Auto dropped, dial added → Task 15). Build resumed at Task 11

## Evidence
- iPhone fast set PASS at 32413b8 (ios:build-check, --test, swiftlint baseline)
- server Phase 6: tsc, fixtures tsc, schema validate/diff green; suite vs makeready_gci_test green
  apart from the 3 base-red files (production, lesson-activities, users)

## Where to dig
- PLAN.md Task 11 — its first step is the F1 grep (now `edit-cover\|4729:53712\|Edit cover`); read the
  d2m screen file and its contract under `docs/ui2/screens/` first. Amendment still binding: the
  `.stored` case passes `hasStoredOriginal: opening.hasOriginal` to `EditGroupCoverModel`; `.newPick`
  passes `true`. Wire Auto's disabled state to `model.horizonAngle == nil`, the readout to
  `isTwisting`/`readoutDegrees`, the grid to `isGestureActive`.
- Merge `main` into `builder/group-cover-image` first (the fleet does this on relaunch).
- SPEC F10 — the agent walk env has no R2 settings, so every cover save on the walk would 500 unless
  `agent_walk.env` gains `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
  `R2_BUCKET_NAME`, `R2_PUBLIC_URL`.
- Walk item to add: Auto on a real tilted photo — Vision's horizon sign and `image.cgImage` ignoring
  `imageOrientation` are unverified (Task 14 review, Minor 5).

## Recommended next step
Nothing for the owner to run: d2m-4a messages this session when edit-cover (and C-087) land on
`main`, then `/builder:agent --path docs/features/group-cover-image` relaunches the fleet, which
merges main in, and Task 11 finds the screen.

## History
- 2026-10-27 parked — Edit cover screen not built in d2m [F1]
- 2026-10-27 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-27 re-parked at Task 11 — Phases 5–6 and Task 14 built; edit-cover in flight in d2m (d2m-4a)
- 2026-10-27 unparked by a person — named to /builder:agent or /builder:fleet
