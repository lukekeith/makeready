# Enforcement

A rule nobody can violate accidentally beats a rule written in a doc. This is Phase D — **it runs
last**, after the Phase B and C migrations.

## Why last

`iphone/.swiftlint-baseline.json` is regenerated **wholesale** (currently **1,118 entries**). If
the rule below lands before the migrations, the violations Phases B and C are about to delete get
written into the baseline — enshrining exactly what was just fixed, and leaving stale entries
behind forever. Regenerate against post-migration code so the baseline grandfathers only the sites
[audit.md](audit.md) deliberately defers.

## The existing gate

`iphone/.swiftlint.yml` already runs `custom_rules` as a build phase, with regex rules and path
scoping. Two current examples to copy the shape from:

```yaml
custom_rules:
  no_print_or_nslog:
    name: "No print/NSLog in new code"
    regex: '(?<![\w.])(?:print|NSLog)\('
    message: "New logging goes through the Log wrappers (os.Logger — audit 5.2). Existing call sites are baselined; don't add more."
    severity: error

  color_hex_outside_tokens:
    name: "Inline Color(hex:) outside Colors.swift"
    regex: 'Color\(hex:'
    excluded: '.*Colors\.swift'
```

Note `excluded:` takes a **path regex** — that is the mechanism for scoping a rule to `Pages/`.

## The new rule

```yaml
  server_collection_in_view_state:
    name: "Server collection held in view @State"
    regex: '@State\s+(?:private\s+)?var\s+\w+\s*:\s*\[[A-Z]\w*\]\s*='
    included: '.*/MakeReady/(Pages|Components)/.*'
    message: "Server-derived collections live in AppState (EntityStore, or an @Observable property like textThemes) — see docs/features/state-management/README.md. In-flight edit buffers and pure UI state are exempt: baseline them deliberately."
    severity: error
```

### Verified working (2026-08-01)

This rule was **empirically tested** against the codebase before being written down — run with a
throwaway config via `swiftlint --config`, not just reasoned about:

- **`included:` is supported in `custom_rules`** and correctly scopes the rule to `Pages/` +
  `Components/`. (The existing rules only demonstrate `excluded:`, so this was worth confirming.)
- The regex fired on **21 sites** when measured: the 19 real ones in [audit.md](audit.md) **plus 2
  `#Preview` mock fixtures** — `mockRequests` and `mockMembers` in `GroupMembersPage.swift`.

  **Re-measured after the builds (2026-08-01): 11 sites — 9 real + the same 2 mocks** (now at
  `GroupMembersPage.swift:520`, `:537`). Phases B, C-a and C-b deleted 8, and G11's join-request
  fix deleted 2 more — **21 → 13 → 11**. Both numbers are kept
  because the *drop* is the evidence: Phase D's grandfathering check (`14-phase-d` § Verification)
  diffs the regenerated baseline expecting the sites those phases fixed to be **gone**, and that
  diff is meaningless against a stale expected count. **11 is what D should expect** — 9 if the
  two mocks are excluded rather than baselined.

  The 9 real survivors are **exactly** the ones [audit.md](audit.md) dispositioned as legitimately
  screen-local: `editTags`, `originalEditTags`, `draggedItems`, `suggestions`, `tags`,
  `orderedBlocks`, `orderedLessons`, `exegesisHighlights`, `activityLogs`. The two join-request
  forks that were on this list are **gone** — they were never legitimately local (a store already
  existed and both pages forked it), and G11 fixed them rather than baselining them. The baseline
  now grandfathers only deliberate, reviewed cases.
- The regex is intentionally broader than the audit's `grep` (which required `= []`), so it also
  catches `@State var x: [Model] = someSeedValue` — **exactly the shape a Mode 2 forked copy takes**.
  Do not narrow it to `= []`.

**On the preview mocks:** `.swiftlint.yml` already excludes the `MakeReady/Preview Content`
directory, but these mocks are declared inline inside a page file, so that exclusion does not reach
them. Baseline them like any other deliberate exception — but expect them, and do not mistake them
for real findings.

**This regex is deliberately blunt.** It cannot tell a server model from a UI struct, so it will
flag legitimate cases (`Dragula.draggedItems`, `ProgramHomePage.editTags`). That is acceptable and
intended: those become **explicit baseline entries** — a reviewer had to look at each one — rather
than silent omissions. A rule that tried to enumerate model type names would rot the moment someone
adds a model.

## Procedure

1. Land Phases B and C first. Confirm with `git log` that the migrations are committed.
2. Add the rule to `iphone/.swiftlint.yml`.
3. Run `cd iphone && swiftlint lint` (no baseline) and read the violation list. Every hit should be
   either a known-deferred site from [audit.md](audit.md) or something the audit missed — if it is
   the latter, **classify it before baselining it**.
4. Regenerate: `cd iphone && swiftlint lint --write-baseline .swiftlint-baseline.json`
5. **State in the commit message that the regeneration was deliberate and why.** The standing rule
   in `iphone/.claude/CLAUDE.md` is: *never regenerate the baseline to silence a new violation; fix
   the code, or regenerate deliberately and say so.*
6. Verify the gate works: add a throwaway `@State private var junk: [StudyProgram] = []` to a page,
   confirm the build fails, remove it.

## Review checklist (the human half)

The regex catches storage. It cannot catch an Action with the wrong *shape*. Add to review:

- **Does this Action return a collection?** If so, why does the caller need to own it? Default is
  that the Action writes `AppState` and returns `Void`.
- **Does this mutation invalidate anything derived?** Adding a tag changes the tag list; adding a
  member changes counts. The mutating Action refreshes them in the same call.
- **Is this new `@State` collection genuinely screen-local?** Apply the test in
  [audit.md](audit.md) § "The classification test". If another screen can read or mutate it, it
  does not belong in the view.

## What this does not enforce

- **Mode 2 forked copies that use a non-array shape** (a dictionary, or a single model held in
  `@State`). The regex targets arrays because that is where the audit found the problem; widen it
  only if a real case appears.
- **The web client.** It is conformant and out of scope — see README § Scope. ESLint equivalents
  are not warranted today.
