# program-lesson-add-activity — parked
parked: 2026-11-06 388a908d · by build phase 1
kind: stuck
blocked: "the server phase can't close: the baseline cached for the web style check is truncated, so untouched files read as new failures — next: rm the cached file named in PARKED.md, then /builder:agent"

## What is stuck

Phase 1 (server) should close green. It stays red on `check::client-tokenization`, a check on web SCSS,
although this branch changes nothing under `client/`. The verifier compares the check's output with a
list of lines cached for the target commit. That cached list is truncated, so real, old violations
look new. Every run against this target commit reads the same cached list, so re-running cannot clear
it. A red producer phase blocks the iPhone phase, so Tasks 2–6 have not started.

## What was tried

- Fixed the one real regression in the same verdict: `home-dashboard.test.ts` layer discovery now lists `activity-new` (388a908d), re-reviewed clean.
- Requested the phase tier again (`mw4qqgm7-9acd30`) — the same false regression, with everything else green.
- Did not delete the cached baseline. It is the verifier's own record in the main checkout, and the build has no instruction allowing it to change what a gate compares against. The owner decides.
- Did not edit `client/scripts/tokenization-guard.mjs` on this branch. Complete output against the truncated baseline would keep the check red, and the file is outside this feature's apps.

## Evidence

- `.builder/verify/lines-v2/e20f2c61182c9d1765e25e3a35091862b26a3f33/client-tokenization.txt` (main checkout) — 483 lines, 64,495 bytes. The guard really prints 853 at that commit.
- Measured on this worktree, reading the guard through a pipe:
  - normal reader, 6 runs: `853` every time
  - reader that sleeps 1s first: `483`, exactly the cached count
  - redirected to a file: `853`
- Other cached baselines hold 853 (`74d1638c`, `8f82508f`, `9c2a9a4e`, `b3d84562`), and `9bc0bf7d` holds 310, so truncation has happened before.
- `git diff --stat e20f2c61 HEAD -- client` prints nothing: no client change on this branch.
- Verdict lines begin: `✗ check::client-tokenization — introduced by 9495a43` / `resources/css/components/card/group-members-page.scss:37  raw hex → use a color token`. That file's last commit is `9694cb22`, long before this feature. "Introduced by" only names the first commit in the range.

## Where to dig

- `client/scripts/tokenization-guard.mjs:85-90` — prints violations with `console.error`, then calls `process.exit(1)`. On a macOS pipe that write is asynchronous, so a slow reader loses everything past the 64 KB pipe buffer. This is the root cause.
- `targetLines` in the plugin's `scripts/verify/run.mjs:410` — caches the target's lines per sha. It refuses to cache a timed-out or aborted run for this exact reason ("would make every later run against this sha a false red"), but a run that exits normally with truncated output looks complete.
- Not yet ruled out: whether other features at this commit are affected. `main` and `feature/program-lesson-add-activity` were both at `e20f2c61` when this branch was checked, and the cache is keyed by sha, so any feature targeting that commit reads the same file. It was not tested.

## Recommended next step

From the main checkout, remove the one bad cache entry, then run `/builder:agent`:

    rm .builder/verify/lines-v2/e20f2c61182c9d1765e25e3a35091862b26a3f33/client-tokenization.txt

The verifier rebuilds it on the next run from the target commit, so nothing is lost and the check itself stays as strict. The rebuild is racy until the guard is fixed, but a normal read gave 853 in 6 of 6 runs.

The automatic fleet retry will not clear this without the `rm`.

Alternatives:
- Fix the guard for good (`process.exitCode = 1` in place of `process.exit(1)`) on `main`. Worth doing separately so this stops recurring. A commit landing on the target also moves its sha, which gets a fresh baseline, but the delete is still the immediate step if the target stays put.
- Close the phase by ruling the check false. Rejected: a red phase does not close, and the merge tier would stop on the same baseline anyway.

## History

- 2026-11-06 parked — false regression from a truncated verifier baseline, after the phase tier ran twice
