# state-management — spec

> Converted to the builder layout 2026-09-24 from the numbered `/build-spec` suite. **The numbered
> docs are still on disk and are still the detail** — this file is the index the `/builder:*` pipeline
> reads, not a rewrite. See `plugins/builder/skills/resume/REFERENCE.md` §Condense, *Legacy layouts*.

## Overview

Standardize how MakeReady's client apps hold server data. Written 2026-08-01 from the codebase audit in
`docs/monday/tickets/12668501065.md` § "State-management analysis", prompted by sub-issue **J** of that
ticket ("Newly added tags don't show up on the tag filter"). Full overview: [README.md](README.md) and
[01-architecture.md](01-architecture.md).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server  | ⬜ | Nothing. This feature changes where the client holds data it already fetches — no schema, endpoint, service or permission change | §Server |
| client  | ⬜ | Nothing. Audited 2026-08-01 and conformant — 14 Pinia domain stores, zero of 31 LeaderApp components make their own API calls. A second working exemplar, not a target | §Client |
| iphone  | ✅ | `AppState` gains `allProgramTags` + `groupLeaders` (+ `allMediaTags`); tag/leader Actions write instead of return; four pages read through to existing stores instead of forking; SwiftLint custom rule + baseline; the rule documented in `iphone/.claude/CLAUDE.md` | §iPhone |
| capture | ✅ | Added by `X1` (DECIDED 2026-08-01; originally claimed out of scope, audit pass 1 disproved it). `CaptureEnvironment` seeds the stores + posts cursor the read-throughs now read; the affected `ViewRegistry` cases re-captured and diffed | §Capture |

Detail: [02-app-impact.md](02-app-impact.md).

**Backward compatibility:** no wire change, so a shipped iPhone build is unaffected — the work moves
where the app holds data it already fetches.

## Decisions

The full decisions table is [01-architecture.md](01-architecture.md) §Decisions, and the `D#` rows
settled during the build are [09-gaps-and-decisions.md](09-gaps-and-decisions.md). **No OPEN rows** at
conversion.

<!-- The one place rulings live. Record the DECISION, not the conversation: a stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation. NEVER quote the user's prompt as the ruling — operationalize
     it into a closed list, a measured value, or an enumerated set of deviations.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

## Contract

**No contract change** — server out of scope. [03-data-and-api.md](03-data-and-api.md) records that
explicitly.

## Schema & API changes

No schema change (established 2026-08-01, [03-data-and-api.md](03-data-and-api.md)).

## Server

Not affected — see §Apps. [04-server.md](04-server.md).

## Client

Not affected — audited conformant, see §Apps. [05-client.md](05-client.md).

## iPhone

See [06-iphone.md](06-iphone.md) for the `AppState` entities, the Actions, the four read-through pages
and the SwiftLint rule.

## Capture

See [07-capture.md](07-capture.md) for the `CaptureEnvironment` seeding and the re-captured
`ViewRegistry` cases.

## Testing

See [08-testing.md](08-testing.md), including the cross-app walk and the human-verification script.

## Findings & risks

The `G#` / `D#` / `O#` / `C#` / `X#` ledger is [09-gaps-and-decisions.md](09-gaps-and-decisions.md),
with its dated audit pass log. `X1` — capture wrongly claimed out of scope — is the row that changed
§Apps.

## Walk status (why `walk: none`)

🔴 **All five phases are VERIFIED and every gate is green, but this feature has never been walked by a
human.** On 2026-08-02 the owner *closed* it with three behaviours still unexercised by anyone — the
multi-page posts append, the cross-org sign-out walk, and the media-tag repro — a deliberate
acceptance recorded in the README's § Verify verdict, and, in the README's own words, **"not a human
sign-off that the feature works."**

That is why the converted manifest reads `walk: none` and `verify: none` rather than `signed-off`. A
`/builder:signoff` record's authority comes from the human typing the command
(`plugins/builder/skills/signoff/SKILL.md`), and a sign-off written any other way is void. The three
behaviours above are the walk script; the work itself is done and committed.

## Plan

The plan is this folder's existing phase docs, left in place by the conversion:
[10-phase-a-the-rule.md](10-phase-a-the-rule.md) ·
[11-phase-b-homeless-domains.md](11-phase-b-homeless-domains.md) ·
[12-phase-c1-read-throughs.md](12-phase-c1-read-throughs.md) ·
[13-phase-c2-paginated-posts.md](13-phase-c2-paginated-posts.md) ·
[14-phase-d-enforcement.md](14-phase-d-enforcement.md) — all five carrying `## VERIFIED ✅`.
