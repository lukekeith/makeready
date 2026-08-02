---
name: build-spec-check
description: Integrity check for a MakeReady feature suite — the fast mechanical pass that proves a spec holds together before anyone builds from it. Verifies every file:line citation actually points at what it claims, every gate command and script path exists and is invoked correctly, every internal link resolves, the suite's required docs are all present, the app-impact scope table agrees with the rest of the suite, the ledger agrees with the artifacts and with the code, and no claim is stamped verified without evidence. Complements /build-spec-audit (which hunts for gaps and pattern violations) — this one hunts for the spec being WRONG about itself. Runs read-only in minutes, at any point in the pipeline. Use when the user asks to sanity-check, integrity-check, or double-check a spec before implementing.
---

# /build-spec-check <feature> — does this spec hold together?

Read-only, mechanical, fast. Runs at **any** point: after `/build-spec-draft`, before
`/build-spec-plan`, before `/build-spec-build`, or as a pre-flight before `/build-spec-verify`.
Conventions in [`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md).

**How this differs from `/build-spec-audit`** — and why both exist:

| | `/build-spec-audit` | `/build-spec-check` (this) |
|---|---|---|
| Question | *Does the plan match the codebase, and what's missing?* | *Is the spec telling the truth about itself?* |
| Method | Judgment, adversarial reading, parallel agents | Mechanical verification of every claim, path, and command |
| Finds | Gaps, contested decisions, coverage holes, pattern violations | Wrong line numbers, dead paths, commands that don't run, stale counts, unverifiable "verified" stamps, internal contradictions |
| Cost | Long | Minutes |

A spec can pass the audit and still be wrong about itself — a citation that drifted, a gate command
nobody ever ran, a count scoped to a subdirectory. Those defects survive review because they *look*
like evidence. This pass exists to catch them cheaply, and it is worth re-running whenever the suite
changes.

**Output:** a dated **Integrity check** section appended to `09-gaps-and-decisions.md`, plus dated
in-place corrections to whatever it found wrong, plus a verdict: **SOUND** or **DEFECTS (n)**.
Corrections are doc edits only — this skill never touches app code.

## Check 1 — Suite completeness

Every required doc exists: `README.md`, `01`–`09`, and `10+` phase docs if the plan step has run
(REFERENCE.md §1). **An app with no doc is a defect even when it's out of scope** — `04`/`05`/`06`/
`07` must exist, carrying at minimum `**Not affected** — <why>`. A missing file is an oversight; a
one-line file is a decision.

## Check 2 — Every citation, verified by opening it

The load-bearing check, and the one most likely to find something. For **every** `file:line`
citation in the suite:

1. The file exists at that path (record the real path when the suite cites a bare filename — that's
   fine per the convention, but the check must resolve it).
2. `sed -n '<line>p'` actually shows what the suite says is there. Line numbers drift; a citation
   that has slid is a defect even when the underlying claim is still true.
3. Symbols cited by name (`ThemeActions.loadThemes()`, `StudyActivity.isConfigured`) still exist
   with that name.

**Do not trust a `**verified in code (date)**` marker** — that is exactly the claim under test.
Inherited markers (copied from an earlier doc, a ticket, or a prior spec) are the most common source
of a false one; re-verify them or downgrade them to `(claimed — unverified)`.

## Check 3 — Counts and sweeps, re-run

Any numeric claim ("19 sites", "14 stores", "zero components fetch", "1,118 baseline entries") gets
its grep re-run now. Two failure modes, both defects:

- **Stale** — the number was right and drifted.
- **Silently scoped** — the number is right for a narrower set than the sentence implies (a count
  over `components/` presented as a count over the whole island). Report the real denominator; a
  conclusion resting on a partial sweep is not yet established even when it happens to be true.

## Check 4 — Every command actually runs

For every gate, script, or command the suite names (`08-testing.md`, phase docs, REFERENCE.md §7):

- the binary exists (`which swiftlint`), the npm script exists in the right `package.json`, the
  script path exists on disk;
- **the invocation is correct from the directory the doc tells you to run it in** — the repeat
  offender here. `swiftlint` must run from `iphone/` because the config's `included:` paths are
  relative; `phpunit` is `client/vendor/bin/phpunit`; server `tsc` needs `src/generated/prisma`;
  capture web shots need the host `:8002`, not docker `:8001`.
- Verify by existence and by reading, **not by executing.** Never run a build, `xcodebuild`, a
  simulator command, a migration, or anything that mutates state. If a command's correctness can't
  be established without running it, say so and leave it flagged.

## Check 5 — Internal consistency

- Every intra-suite markdown link resolves.
- `02`'s scope table agrees with reality elsewhere in the suite: an app marked ⬜ has no work
  described for it in any other doc, and every ✅ app has an owner doc with actual content.
- Consumer docs (`05`, `06`) consume only fields `03` defines — same names, same types.
- Phase docs name exactly one app each, and their preconditions chain (phase N requires N-1).
- The Decisions table (`01`) and the `D#` table (`09`) don't contradict each other, and nothing
  appears as both settled and open.
- No placeholder text, `TODO`, `TBD`, or unfilled template scaffolding survives.

## Check 6 — Ledger ↔ artifacts ↔ code

- The ledger's step statuses match what's actually on disk (a step marked ✅ has its artifact).
- The ledger's phase table matches the README's Phase status table.
- **"Nothing built" / "phase N done" claims are re-verified in code**, not inherited: grep for the
  symbols each phase is supposed to add or remove.
- The recomputed progress % matches what the ledger and README record (REFERENCE.md §6). A drifted
  number is a defect — the whole point is that it's reproducible.
- OPEN `D#`/`X#` rows are consistent with the step status (an open blocker with the plan step marked
  ✅ is a contradiction).

## Check 7 — Unverifiable-claim sweep

- `(claimed — unverified)` markers: fine before the audit, a **blocker at verify time**. Report the
  count and where they sit relative to the current step.
- Claims phrased with certainty but carrying no evidence at all ("the endpoint returns the full
  list", "this is a one-file change") — each becomes a `G#` if it matters to the build. The "this is
  a one-file change" family is worth singling out: it is the most expensive kind of wrong, because
  the implementer discovers it mid-phase.

## Recording the result

Append to `09-gaps-and-decisions.md`:

```markdown
## Integrity check — YYYY-MM-DD

**Verdict: SOUND** (or **DEFECTS (n)** — n corrected in place / n needing a decision)

| # | Check | Result |
|---|---|---|
| 1 | Suite completeness | ✅ all docs present |
| 2 | Citations (N checked) | ✅ / ❌ <what drifted, and its real location> |
| … | | |

<Per-defect: what the suite said, what is actually true, what was corrected, and — when the
correction changes scope or cost — the G#/D#/X# row it became.>
```

Corrections go in the affected doc immediately, dated, in the same shape the audit uses. A defect
that changes the *work* (not just the wording) also gets a ledger row — a citation fix is a doc
edit; "this is 7 sites, not 1" is a `G#`.

## Verdict rules

- **SOUND** — every check passed, or the only findings were corrected in place without changing
  scope, cost, or a decision.
- **DEFECTS (n)** — anything that changes what gets built, how long it takes, or what someone must
  decide. Not a failure: it is the cheapest possible moment to learn it. List each with the step
  that clears it.

Report honestly which checks were *skipped* and why (a command that couldn't be safely verified, a
sweep that needs a running stack). A silent skip reads as a pass and is worse than a flagged gap.

## Exit handoff (standalone runs too)

End every run with the standard handoff (`build-spec` §Step-end handoff): the verdict in plain
language, the defect list as file+correction rows, and ALWAYS the two-line status block as the last
thing in the response (REFERENCE.md §6):

```
📊 <feature> ~NN% ▓▓░░░░░░░░ — integrity: SOUND (37 citations, 9 commands, 12 links checked)
📍 Run `/build-spec <feature>` → runs the AUDIT step next: the suite vs the codebases
```
