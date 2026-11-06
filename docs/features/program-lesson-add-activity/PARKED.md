# program-lesson-add-activity — parked
parked: 2026-11-06 17ad725e · by build phase 1 (retry 1 of 2)
kind: human-step
blocked: "the server phase can't close: the web style check's cached baseline holds 483 of its 853 lines, so old violations read as new — next: delete the file named in PARKED.md from the main checkout, then /builder:agent"

## What is stuck

Phase 1 (server) should close green. It stays red on `check::client-tokenization`, a check on web SCSS,
although this branch changes nothing under `client/`. The verifier compares the check's output with a
list of lines cached for the target commit, and that list is truncated, so real, old violations read
as new. A red producer phase blocks the iPhone phase, so Tasks 2–6 have not started.

Nothing a build run may do clears it. The bad list is read back on every run against this target commit.
It is `human-step` rather than `stuck` because another automatic retry would hit the same file and spend
retry 2 of 2 for nothing: the one remaining step is the owner's call.

## What was tried

- First run: fixed the one real regression in the same verdict, `home-dashboard.test.ts` layer discovery (388a908d), re-reviewed clean. Phase tier re-run (`mw4qqgm7-9acd30`): same false regression, everything else green.
- This retry: checked whether the cause still holds. It does. The cached file is unchanged at 483 lines, the target is still `e20f2c61`, and the `run.mjs` diff between builder 6.2.0 and 6.2.1 is empty, so no verifier fix has landed.
- This retry: phase tier at HEAD (`mw4qtq7f-f1838c`, 17ad725) — RED on this check only, 20 results reused.
- This retry: compared complete guard output on the branch and target without touching the cache (below). There is no hidden real regression.
- Did not delete the cached baseline, and did not add the check to `known-failures.json` or `flakes.json`. Each changes what a gate compares against, in the verifier's own records outside this worktree. The automatic retry carries no owner decision on that.
- Did not edit `client/scripts/tokenization-guard.mjs` here. Complete output against the truncated baseline stays red, and `client/` is outside this feature's apps.
- Did not move `feature/program-lesson-add-activity` or edit the check in `.claude/builder.md`. Each would get past the gate rather than repair its input, and the config is the owner's.

## Evidence

- Guard output in full, each side read through a file (`client/scripts/tokenization-guard.mjs`, on this worktree and on the verifier's `e20f2c61` checkout `co/t0`):
  - branch 853 lines · target 853 lines · cached 483 lines
  - in branch, not target: 0 · in target, not branch: 0
  - in branch, not cached: 370 · in cached, not target: 0
- So the cached list is a strict subset of the target's real output. A correct baseline would turn this check green.
- `.builder/verify/lines-v2/e20f2c61182c9d1765e25e3a35091862b26a3f33/client-tokenization.txt` (main checkout, git-ignored) — 483 lines, 64,495 bytes, written 02:54.
- Earlier measurement, reading the guard through a pipe: normal reader 853 in 6 of 6 runs; a reader that sleeps 1s first 483, the cached count; redirected to a file 853.
- Other cached baselines: 853 at `74d1638c`, `8f82508f`, `9c2a9a4e`, `b3d84562`; 310 at `9bc0bf7d`, so truncation has happened before.
- Verdict begins: `✗ check::client-tokenization — introduced by 9495a43` / `resources/css/components/card/group-members-page.scss:37  raw hex → use a color token`. That file's last commit is `9694cb22`, long before this feature. "Introduced by" only names the first commit in the range.

## Where to dig

- `client/scripts/tokenization-guard.mjs:85-90` — prints violations with `console.error`, then calls `process.exit(1)`. On a macOS pipe that write is asynchronous, so a slow reader loses everything past the 64 KB pipe buffer. This is the root cause.
- `targetLines` in the plugin's `scripts/verify/run.mjs:410` — caches the target's lines per sha. It refuses to cache a timed-out or aborted run, but a run that exits normally with truncated output looks complete.
- `runShell` in `run.mjs:22` — reads the check's pipes on the verifier service's own event loop, so anything blocking that loop could make it the slow reader. Not tested.
- The same truncation on the branch side would fail the opposite way: lines missing from the branch output cannot read as new, so a real new violation could pass. Not observed, but it follows from `run.mjs:435`.
- Not yet ruled out: `image-fixtures` and `video-captures` have no verifier verdicts yet, so they have not read this file. Any feature whose target tip is `e20f2c61` would read the same list, and `main` is at that commit now.

## Recommended next step

From the main checkout, remove the one bad cache entry, then run `/builder:agent`:

    rm .builder/verify/lines-v2/e20f2c61182c9d1765e25e3a35091862b26a3f33/client-tokenization.txt

The verifier rebuilds it on the next run from the target commit, so nothing is lost and the check stays as strict. The rebuild is racy until the guard is fixed, but a normal read gave 853 in 6 of 6 runs.

Alternatives:
- Fix the guard for good (`process.exitCode = 1` in place of `process.exit(1)`). Worth doing separately so this stops recurring. Landing it on `main` alone does not clear this feature: its target is `feature/program-lesson-add-activity`, which stays at `e20f2c61` until something lands on it, so the delete is still the step.
- Close the phase by ruling the check false. Rejected: a red phase does not close, and the merge tier would stop on the same baseline.

## History

- 2026-11-06 parked — false regression from a truncated verifier baseline, after the phase tier ran twice
- 2026-11-06 unparked by the fleet — automatic retry 1 of 2
- 2026-11-06 parked again — cause confirmed unchanged at 17ad725e; complete output shows branch and target identical; the delete awaits the owner
