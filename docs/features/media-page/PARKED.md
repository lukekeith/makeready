# media-page — parked
parked: 2026-10-31 c76decd3 · by build (Task 8, agent mode)
kind: human-step
blocked: "d2m needs you to confirm its proposed MediaBrowser (C-129) box on media-home's Design 4 before it will finish speccing media-home [Task 8] — next: in d2m confirm that box, then /builder:agent (it retries change cmvwp1b9k001hv0xl2hvwidk7)"

## What is stuck
Task 8 (Phase 4) is d2m's: it specs and builds the new MediaBrowser grid component (now registry row
**C-129**) and the media-home screen; Task 11 (the last task) wires the app container against both.
On this attempt d2m got most of the way through change **`cmvwp1b9k001hv0xl2hvwidk7`** on its own:
it attached the reference, specced and **built C-129** (`MediaBrowser.swift` sits untracked in the owner's
checkout), and wrote media-home's spec with no open question. It stops at step 3/4 every time with the
same message: *"the roll-call cannot close until the proposed C-129 MediaBrowser box on design-4 is
confirmed."* d2m drew that box on Design 4 itself and holds it as a proposal. Confirming a drawing is
an owner action in d2m's designer, and no d2m-channel tool does it (the tools are request, wait, answer,
retry, cancel, check, report, get_*, list_*, set_color_token).

## What was tried
- 2026-10-31 (this attempt): the old cause no longer held. The channel now runs mint, references and specs itself. The old change `cmvw0fg4m0001v00ab4dxfwv1` had moved to `carded` and asked 8 questions (OQ-media-home-001…008), which I answered from D6–D9/D13 (004, 005, 007 and 008 took d2m's recommendation). Its media-home spec then stopped twice on the proposed C-129 box (one retry).
- Root cause of that stop: the old change predated `references`. It minted C-129 with `markdownRefs: []`, so C-129's spec was blocked ("Referenced or specced") and its box stayed a proposal. A re-request carrying the old `changeId` was a no-op.
- New request `cmvwp1b9k001hv0xl2hvwidk7` with `references: [docs/ui2/references/media-browser.md → C-129, media-home]`. d2m asked OQ-C-129-001…005, which I answered (001: build from the reference doc per D11; 002–005 took d2m's recommendation; Rulings in the ledger). It specced C-129, and the build failed once; `get_component` then showed it built with no stop, so I retried. media-home spec then stopped on the proposed box, and one more retry stopped at the same place with the spec "complete with no open question".
- The intent asked d2m to confirm the box itself. It did not, so the chat can't do it either.
- Not done: carrying `MediaBrowser.swift` into this branch, or touching the owner's checkout. The change is still in flight, and its step 4 (build media-home) reads the files d2m wrote there.

## Evidence
- `wait_project_change cmvwp1b9k001hv0xl2hvwidk7` → `status: carded`, `next: "Stopped at step 3/4 (Spec media-home): The spec is complete with no open question, but the roll-call cannot close until the proposed C-129 MediaBrowser box on design-4 is confirmed. — retry_project_change resumes it."`
- `get_component C-129` → `specced: true, built: true`, markdownRefs `media-browser.md`, 5/5 questions closed.
- Owner checkout `git status`: `?? iphone/MakeReadyUI/MediaBrowser.swift` (d2m's), plus modified `project.pbxproj`, `CaptureFixture.swift`, `ViewRegistry.swift`, `Info.plist`, `EnrollSelectProgramContainer.swift`, `EnrollmentSelectProgramScreen.swift`. Only the last one was dirty in the snapshot `d2m-before.txt`. Which of the others are d2m's and which are the owner's own work since then is for Task 8 Step 5 to sort out by hunk.

## Where to dig
- In d2m: media-home → Design 4 → the proposed C-129 MediaBrowser box (the grid area below the chips). Confirm it.
- Then `retry_project_change cmvwp1b9k001hv0xl2hvwidk7` → `wait_project_change` until done (step 4 = build media-home), then PLAN.md Task 8 Steps 5–8. Carry the files by hunk against `d2m-before.txt`; the owner's checkout has picked up non-d2m edits since that snapshot, so leave any hunk that isn't d2m's. Then Task 11, phase 5's gate and the final review.
- The old change `cmvw0fg4m0001v00ab4dxfwv1` is superseded; it can be cancelled (`cancel_project_change`) once the new one is done.
- Workspace ledger `.builder/media-page/progress.md` has every task, ruling and env note.

## Recommended next step
In d2m, confirm the proposed C-129 MediaBrowser box on media-home's Design 4, then run
`/builder:agent --path docs/features/media-page`. The next run retries `cmvwp1b9k001hv0xl2hvwidk7`
and finishes Tasks 8 and 11.

## History
- 2026-10-31 parked — MediaBrowser reference doc uncommitted in the owner's checkout (B1)
- 2026-10-31 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-31 retry — B1 cleared (doc committed in 2c807640); carried on to the plan
- 2026-10-31 parked — build reached Task 8; d2m needed owner Apply + reference attachment + spec runs
- 2026-10-31 owner: the d2m channel now takes `references` and runs the whole chain itself
- 2026-10-31 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-31 retry — channel cause cleared; C-129 minted, specced and built; media-home spec stops on d2m's proposed C-129 box on Design 4 (owner confirm) — parked again
