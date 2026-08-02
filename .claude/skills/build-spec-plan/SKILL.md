---
name: build-spec-plan
description: Turn an audited MakeReady feature suite into per-phase build-guide docs (docs/features/<feature>/10+-phase-N-<name>.md) plus the README Phase status table — ONE APP PER PHASE in dependency order (contract/migrations → server → client ∥ iphone → capture → cross-app E2E), each doc carrying checkbox tasks with their tests, the app's quality gates, and a verification checklist that must be signed off before the next phase opens. Runs only after /build-spec-audit is clean and decisions are resolved. Use when the user asks to plan a spec's implementation.
---

# /build-spec-plan <feature> — audited suite → per-phase build guides

Preconditions (check, don't assume): 09 carries a **current** integrity check (SOUND, and newer
than the last suite edit — run `/build-spec-check` if not; phase docs built on drifted citations
send the implementer to the wrong lines), 09's latest audit pass reports zero new findings, and the
G/D/O/C/X ledgers have no OPEN rows. Not true → stop and route back (`/build-spec-audit` or the
decisions gate). Read the ledger on entry; templates in
[`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md) — every phase doc follows §5 exactly
(goal, companion skills, ordered checkbox tasks with their tests, phase gates, verification
checklist, the VERIFIED sign-off block).

## The two rules that shape the phases

1. **One app per phase.** A phase doc names exactly one of server / client / iphone / capture (the
   final cross-app phase is the only exception). Mixed-app phases are how a "done" server change
   quietly ships with a half-wired consumer.
2. **Contract → server → consumers.** The server phase's VERIFIED sign-off is what FREEZES 03's
   contract (REFERENCE.md §3); consumer phases must not open before it.

## Deriving the phases

Dependency order — the default skeleton. Drop phases 02's scope table says are out of scope; split
any phase too big for one context window into `Na`/`Nb`:

| # | App | Phase | Contents |
|---|---|---|---|
| 0 | server | Schema + migrations | `server/schema/` YAML edits, generated Prisma, Atlas migration, `migrate:apply` + `migrate:status` re-check, seed additions. Verified by a re-apply that is a no-op |
| 1 | server | API + services | Route modules, services, zod schemas, RBAC checks, external integrations, push payloads; unit tests per service task; authorization tests per endpoint. **Signing this phase freezes 03** |
| 2 | client | Web | Laravel routes, Blade, Vue islands/components, Pinia stores, `/admin/api` proxy entries, SCSS; component tests + Feature tests |
| 3 | iphone | iOS | `AppState`/`EntityStore` + Actions first, then Routes/Pages/Components; each overlay/sub-screen/deep link scaffolded with its companion skill |
| 4 | capture | Compare | Fixtures, adapters, twins, ViewRegistry cases, first captures + diff |
| 5 | cross-app | E2E + sweep | 08's cross-app walk, the full gate suite, the human-verification script prepared |

Phases 2 and 3 are independent of each other (the consumers never import each other) — mark them
`∥` in the README so either order is legal, but **each still completes and verifies as a unit**.

Each doc is self-contained: a cold session opens it and knows what to build, what to test, and
what proves the phase done, without reading the conversation that planned it. Task rows name their
files, their spec doc + section, and the tests that ship WITH them (tests are never deferred to a
later phase). Every task that adds an iPhone overlay, sub-screen, deep link, web component, page,
store, or endpoint names its **companion skill** (REFERENCE.md §11) in the task row — the build
step invokes it rather than freelancing.

Phase gates come from 08's gate list, filtered to the app: only the gates that can go red from
this phase's work (REFERENCE.md §7). Every server phase includes `docker restart
makeready-server` in its walk instructions; every capture phase includes the client rebuild and
the host `:8002` route.

The verification checklist is the anti-one-shot device: observable behaviors to walk (an endpoint
returns 03's exact shape, a migration re-applies as a no-op, an island mounts and its store loads,
a modal presents with the right chrome and dismisses correctly), plus the **contract-parity check**
on consumer phases and a spec-parity spot-check of the 1–3 load-bearing claims the phase
implements.

## Sizing check

A phase must complete comfortably in one session. More than ~6 endpoints in phase 1, ~5 views in
phase 2 or 3 → split. When the suite is really several independent subsystems, say so and propose
splitting into multiple feature suites instead of one mega-plan.

## Hand off

Write the README's **Phase status** table (all ⬜, with the app column) + update the Pipeline
snapshot and the ledger (including the empty Contract state row). Present the phase table with
per-phase app + task counts. The next step changes code, so the build go-ahead applies — present
the plan for one explicit approval before recommending `/build-spec-build`, note that the approval
covers running `ios:build-check` as a gate but not launching/archiving/committing the iPhone app,
and record the approval in the ledger.

## Exit handoff (standalone runs too)

End every run — complete, paused, or errored — with the standard handoff (`build-spec` §Step-end
handoff): what happened, copy/paste next commands, and ALWAYS the two-line status block as the
last thing in the response (REFERENCE.md §6):

```
📊 <feature> ~33% ▓▓▓░░░░░░░ — plan: 5 phase docs written, go-ahead recorded
📍 Run `/build-spec <feature>` → starts the BUILD step at phase 0 (server schema)
```
