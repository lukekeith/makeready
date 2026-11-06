# staging-fixtures — parked
parked: 2026-11-05 f23d62d8 · by build phase 2
kind: human-step
blocked: "config change needed — the Staging and Release app builds have never been run, and the check that runs them is not in the verifier's config — next: apply the diff in PARKED.md to .claude/builder.md on main, then /builder:agent"

## What is stuck

The feature's code is finished and reviewed, and the verifier's tests are green. One required proof is missing: nobody has built the `MakeReady Staging` scheme, the `MakeReady` scheme in Release, or `MakeReadyCapture` since the project gained its third configuration, and nobody has read the built `Info.plist` values. SPEC §Testing *iphone (Staging build)* makes this part of the phase's gate. It is what shows the staging app gets its own bundle id and that a store build has `DEV_MODE` NO and no fixture key.

The verifier suites build Debug only, so they cannot show this. The check that does is a line in `.claude/builder.md`, and that file is the owner's to change.

Nobody has waived this gate. Leaving the config alone was the build agent's ruling, not an owner decision.

## What was tried

- Task 5 as planned edits `.claude/builder.md`. Ruled out before dispatch, for three reasons: agent mode forbids editing the config, the verifier reads the main checkout's copy so the edit would do nothing, and the fleet parks a branch that changes the file.
- The `staging-build` mode was committed in `scripts/builder-verify.mjs`. It has passed `node --check` and code review but has never been executed.
- Running the mode from this agent was ruled out: `iphone/.claude/CLAUDE.md` requires an explicit yes for any `xcodebuild` outside its named carve-outs, and this mode is not one of them.

## Evidence

- Phase tier verdict at f23d62d8: `GREEN · 4 flakes · 1 known · 68 reused`, selection server-vitest 54 files, iphone-xctest 1 file. Request mw4aevmu-9f42b6.
- `StagingBuildConfigTests` checks the configuration by reading files (`Staging.xcconfig`, `project.pbxproj`, the scheme, `Info.plist`). It does not build anything.
- Final review, by reading the code: the target's `Staging` config, `Staging.xcconfig` and the plist keys give the expected values, and no conditional code is unique to `STAGING` compared with Release. Review only, not a build.

## Where to dig

- `scripts/builder-verify.mjs`, the `staging-build` branch — first execution may find a defect in the mode itself, for example the `plutil` paths or the scheme name.
- `iphone/MakeReady.xcodeproj/project.pbxproj` — the six `Staging` configurations.
- Not yet ruled out: a compile failure in the Staging or Release configuration, or a capture target broken by the third configuration.

## Your choices
1. Take what you want of the config change yourself and drop it from the branch (the next step says how), then rebuild — `/builder:agent --path docs/features/staging-fixtures`
2. Leave it for now

## Recommended next step

Add this line to `.claude/builder.md` on `main`, under `verify.checks`, then run `/builder:agent`:

```diff
     iphone-swiftlint: { cwd: iphone, run: node ../scripts/builder-verify.mjs swiftlint, compare: lines, needs: [verify-safe], tiers: [phase, merge] }
+    iphone-staging-build: { cwd: iphone, run: node ../scripts/builder-verify.mjs staging-build, needs: [verify-safe], tiers: [phase] }
```

The next run must:

1. Request the phase tier on this branch before any merge, and read `iphone-staging-build` itself: it must be `pass`. `main` has no `staging-build` mode, so a failure here can be filed as already failing on the target instead of as a regression. Treat that as a failure.
2. Dispatch any defect it finds as a fix against Task 5.

**Timing:**

- Do this before the merge. After the merge, the mode's merge-base diff is empty, so it prints `staging-build: nothing to check` and passes without building, which proves nothing.
- Until this branch lands, `main`'s config names a mode `main`'s script does not have, so the check throws `Unknown verifier operation` on other in-flight branches at their phase tier. It should read as failing on the target too, but that has not been tried.

Alternatives:

- Say yes to one run on this branch, `cd iphone && node ../scripts/builder-verify.mjs staging-build`, and ledger the result. It avoids the window for other branches but leaves no lasting gate.
- Waive the gate. The first staging archive would prove the Staging half, but nothing would prove the Release values or the capture build.

## History

- 2026-11-05 parked — the Staging build gate needs a config line only the owner can add
- 2026-11-05 owner chose one build over the config line. `cd iphone && node ../scripts/builder-verify.mjs staging-build` ran at 0c8b58cd in a throwaway worktree and exited 0: MakeReady Staging (Staging), MakeReady (Release) and MakeReadyCapture (Debug) all BUILD SUCCEEDED, and the built Info.plist values passed. The gate is discharged: do not edit .claude/builder.md and do not park on it again; a later code change to the build files needs this run again. Owner also said nothing in the staging database needs keeping, so F3's data question is closed.
