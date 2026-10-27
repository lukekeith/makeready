# group-cover-image — parked
parked: 2026-10-27 f128302 · by build phase 5 (Task 11)
kind: human-step
blocked: "the Edit cover screen (Figma 4724:53609) is not specced or built in d2m yet, and the build only wires it [F1] — next: run the d2m screen spec + build for Edit cover, then /builder:agent"

## What is stuck
Task 11 wires the Edit cover page (zoom · rotate · pan, then Save) to the d2m-built SwiftUI screen.
That screen does not exist: nothing under `iphone/MakeReadyUI/` or `docs/ui2/screens/` names
Edit cover or Figma node 4724:53609, on this branch or on `main`. SPEC D4 says the build wires that
screen and never writes it, and §Findings F1 reads: "Edit cover is not in d2m yet (Figma
4724:53609); the iPhone phase needs the d2m-built screen — build-time risk — the owner runs the d2m
screen spec + build before the iPhone phase; an agent run reaching it first parks as a human step".
Task 12 (the cover tap → picker / C-066 menu / viewer) routes to `.editGroupCover`, which Task 11
produces, so it waits too.

## What was tried
- `grep -rli "edit.\?cover\|4724.53609" iphone/MakeReadyUI docs/ui2` — no match (this branch)
- `git grep -il "4724:53609" main -- docs iphone` — only this feature's own SPEC
- `ls docs/ui2/screens` — only `groups-home.md` among group screens

## Evidence
Built and committed, phases 1–4 closed with green gates, Task 10 done (Phase 5 open):
- server: `Group.coverOriginalUrl` + `Group.coverFraming` (migration `20261027164451_group_cover_image`),
  one `toGroupPayload`, `saveGroupCover` service, the cover upload route on it + PATCH clearing —
  §Contract frozen 2026-10-27 (fda47e4)
- iphone: `UserGroup` fields + `CoverFraming`, `GroupActions.saveCover`, `CoverFramingMath`,
  `CoverImageRendering`, `EditGroupCoverModel`, `CoverViewerOverlay` (f128302)

## Where to dig
- PLAN.md Task 11 — its first step is the F1 check; once the screen exists the task runs as written,
  with one amendment the build ruled: the `.stored` case must pass
  `hasStoredOriginal: opening.hasOriginal` to `EditGroupCoverModel` (the init has no default now, so it
  will not compile otherwise); `.newPick` passes `true`.
- SPEC F10 — the agent walk env has no R2 settings, so every cover save on the walk would 500; that is
  the next human step after this one unless `agent_walk.env` gains `R2_ACCOUNT_ID`,
  `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_URL`.

## Recommended next step
Run the d2m screen spec + build for Edit cover (Figma 4724:53609) — `/ui2-screen` then the d2m
build — on `main`, then `/builder:agent --path docs/features/group-cover-image`: the fleet merges main
in, Task 11 finds the screen, and the build carries on from the ledger. The alternative — the build
writing the screen itself — is ruled out by D4 (UI 2.0 screens belong to `/ui2-*` and `/d2m-*`).

## History
- 2026-10-27 parked — Edit cover screen not built in d2m [F1]
