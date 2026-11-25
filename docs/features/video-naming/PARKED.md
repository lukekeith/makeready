# video-naming — parked
parked: 2026-11-25 4c552db4 · by build phase 2 (Task 3)
kind: human-step
blocked: "the naming page screen isn't built: d2m's queue stopped on a question its channel can't answer, and the owner must approve the screen's captures — next: answer C-051's AIProcessing question in d2m's Contract tab, then /builder:agent"

## What is stuck
The "Name your video" page must be built by d2m and approved by the owner before any wiring (D12, F8).
d2m has built part of it and stopped. The AI Suggestions block (C-051) still needs its empty state and
pair rows, and the screen itself does not exist. Tasks 1 and 2 are finished and green on this branch.

## What was tried
- Task 3's agent requested the screen (change cmwwl8jvw0001v0ojmpsaj1i3). It took d2m's recommended answers to OQ-C-078-004/005/006: C-050 gains an optional description, drawn body-sm secondary with a 4pt gap, and rows wrap in full. d2m built C-050 and C-078. The C-051 rebuild failed 3 times on open question OQ-C-051-8.
- Answered OQ-C-051-8 with its recommended option (keep AIProcessing C-160), twice, once by the agent and once by the controller. Both refused: "OQ-C-051-8 is cited by C-051 but owned by another document — answer it there".
- Requested the same decision again on C-051 (change cmwwmt2zp001rv0ojj9hf0eh3, subject to the owner). Carded, but about 40 minutes of waiting left it at "Spec C-160 AIProcessing (0/2 steps) — starts on the next check". retry_project_change refused it: not_retryable.

## Evidence
- C-051 lists OQ-C-051-8 twice: as an open reference to OQ-shared-edit-field-5 and as the real blocking question. That collision is the likely reason the answer is refused (not proven).
- The first change's next: "d2m is waiting on a question before it carries on — answer with answer_project_change (codes: OQ-C-051-8)".
- d2m writes to the MAIN checkout, uncommitted, not this worktree. On 2026-11-25 these were modified there: iphone/MakeReadyUI/SuggestionRow.swift, SuggestionRows.swift, iphone/MakeReadyCaptureTests/CaptureFixture.swift, ViewRegistry.swift. iphone/MakeReady/Info.plist is also modified. Nobody in this build touched them.
- The test testTheBlockHasAnEmptyState was run and failed as expected (4 is not 5). It is not committed, since it would turn the branch red. Its text is in PLAN.md Task 3; the file and the pbxproj patch are in .builder/video-naming/ on this machine (git-ignored).
- The d2m brief: docs/features/video-naming/d2m-requirements.md, committed as 4c552db4.

## Where to dig
- d2m: C-051 Contract tab, OQ-C-051-8 ("Keep or drop AIProcessing (C-160)?"). The build agent's pick is keep: it is d2m's recommendation and follows the drawing d2m calls the owner's confirmed drawing. The owner may choose drop.
- d2m: whether its runner is picking up carded changes (a 2026-11-24 change, cmwtzc6aw0039v0rrvr24pc76, shows the same "starts on the next check").
- Not yet ruled out: the runner is busy or stopped; either d2m change may still move by itself, so read both with get_project_change first.
- When d2m is done: carry its edits from the main checkout to builder/video-naming, check that no existing shared-edit-field capture changed, add the test and §As built, then the owner approves the captures.

## Recommended next step
Answer OQ-C-051-8 in d2m's Contract tab, then /builder:agent. If the second change has not moved, retry the first (cmwwl8jvw0001v0ojmpsaj1i3); cancel whichever of the two is then a duplicate.
Building the screen by hand here would break the rule that d2m owns MakeReadyUI; wiring first would break D12. The resumed run stops again at Task 3 for the owner's approval of the captures.

## History
- 2026-11-25 parked — d2m could not record an answer, and its queue did not advance
