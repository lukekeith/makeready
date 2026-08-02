---
name: build-spec-help
description: Help card for the MakeReady feature-spec build pipeline — explains what the /build-spec-* commands do, which one to run for a given situation, how a single spec safely changes multiple apps (server, client, iphone, capture), where the artifacts live, and how resuming after a context clear works. Use when the user asks how the build pipeline works, what the build-spec commands are, which build skill to use, or for help getting started with speccing or building a feature.
---

# /build-spec-help — how the feature-spec build pipeline works

Render the parts of this card relevant to what the user asked (all of it if they asked generally).
Answer follow-ups from the family SKILL.md files (`.claude/skills/build-spec*`) and
`.claude/skills/build-spec/REFERENCE.md` — they are the source of truth; this card is the map.

## The idea in one paragraph

Every feature starts as a **spec suite** in `docs/features/<feature>/` — numbered docs + a README
tracker — written conversationally, **audited** against all four codebases before any code is
written (patterns, schema, component coverage, gaps, and the cross-app contract), turned into
**per-phase build-guide docs**, and built **one phase at a time, one app per phase**, each phase
gated, verified live, and signed off before the next opens. One-shotting a feature is forbidden by
construction; every state change lands in a file, so `/clear` never loses work.

## What makes this pipeline monorepo-shaped

MakeReady is four apps in one repo (server, client, iphone, capture) and most specs touch more than
one. Three rules carry that weight:

- **`02-app-impact.md`** — every app is either in scope with a reason or out of scope with a
  reason. There is no silence. The audit checks the "not affected" claims and turns wrong ones into
  `X#` rows.
- **`03-data-and-api.md` is the contract** — both consumers code against one written endpoint
  table. When the server phase signs VERIFIED, the contract **freezes**; changing it afterwards
  costs a dated amendment plus a server re-verify, which is exactly the friction that stops the two
  consumers from drifting apart.
- **One app per build phase, server before its consumers** — so a "done" server change can never
  ship alongside a half-wired iPhone app.

## Which command do I run?

| You are… | Run |
|---|---|
| **Anyone, any time — "where are things / what next?"** | `/build-spec` (no argument: lists every incomplete feature + status, continues the one you pick) |
| Starting a brand-new feature idea | `/build-spec-draft <feature>` — the spec conversation: recon across the apps, one-question-at-a-time design, writes the suite |
| Taking an existing spec toward the apps | `/build-spec <feature>` — detects where it stands and drives everything below in order |
| Wanting to sanity-check a spec before trusting it | `/build-spec-check <feature>` — minutes; opens every cited line, re-runs every count, proves every gate command exists and is invoked from the right directory |
| Running one step by hand | `/build-spec-audit` (verify the suite vs code) · `/build-spec-plan` (emit phase docs) · `/build-spec-build` (implement — the only app-changing step) · `/build-spec-verify` (READY/INCOMPLETE gate) |
| Asking "is feature X done?" | `/build-spec-verify <feature>` — fresh evidence, no memory |

`<feature>` is the kebab-case folder name under `docs/features/` (e.g. `state-management`).

## The pipeline order

`spec → audit → [decisions] → plan → build (phase by phase) → verify → [human sign-off]`.
Spec/audit/plan are read-only against the apps and re-runnable; the decisions gate pauses for OPEN
`D#`/`O#`/`C#`/`X#` rows; build opens only the lowest-numbered phase doc without a signed VERIFIED
block; verify issues `GATE: READY` or the blocking list. **READY is agent evidence, not sign-off** —
the pipeline ends by handing you the app to test. Deploying stays outside the pipeline: `/deploy`
is always your explicit call, and so are launching/archiving/committing the iPhone app.

## How resuming works (the part everyone asks)

State persists to disk at every checkpoint — a per-feature ledger in the project state store's
`build-spec/` folder (git-free; survives branch switches and `/clear`) plus the committed suite
(README snapshot tables, phase-doc checkboxes, VERIFIED blocks). So after ANY interruption:

```
/build-spec <feature>
```

picks up exactly where things stopped — mid-audit, mid-phase, even mid-task. On a machine with no
ledger, the same command rebuilds it from the suite's README snapshot.

## The loop, and the status block

Each invocation drives as far as it can and stops only at a **real gate** (decisions, build
go-ahead, sign-off), a **real question** the work raised, or a context edge. It does not stop to
ask "continue?" — so the rhythm is: run `/build-spec <feature>`, answer whatever it genuinely
asks, run it again. Repeat until verify is READY and you've tested it.

**Every response ends with two lines**, recomputed from the ledger with a fixed formula. Line 2
always says **what the command will do next** — because `/build-spec <feature>` is the only command
you ever need to type, and it runs whichever step comes next itself:

```
📊 group-goals ~64% ▓▓▓▓▓▓░░░░ — build 3/5: server ✅ client ✅, iphone open (4/9 tasks)
📍 Run `/build-spec group-goals` → resumes the iphone phase at its next unchecked task
```

**You never need to type `/build-spec-plan`, `/build-spec-audit`, or any other step command.** They
exist for running a single step deliberately in isolation. If the status line says the next thing is
the plan step, `/build-spec <feature>` is what runs it.

That includes every turn of the spec conversation — the spec step's 10 points are sub-divided
(recon, design approved, each doc written) so the number moves while you're still designing.

## Commit & push

**Nothing is pushed until the feature is built, verified READY, and you've signed off.** State
lives in the ledger and the suite, not git, so there's never a reason to push early. Local commits
are *offered* at phase and step completions and are always declinable; iPhone commits need your
explicit approval. The push is one deliberate act at the end, and `/deploy` is separate again.

## Where things live

- **Feature suite**: `docs/features/<feature>/` — `README.md`, `01-architecture`,
  `02-app-impact`, `03-data-and-api` (the contract), `04-server`, `05-client`, `06-iphone`,
  `07-capture`, `08-testing`, `09-gaps-and-decisions` (the G/D/O/C/X ledger), `10+-phase-N-*`
  (the build guides).
- **Templates, gates, house rules, environment landmines**:
  `.claude/skills/build-spec/REFERENCE.md`.
- **State ledger**: outside git, in the project state store (same directory family as auto-memory),
  `build-spec/<feature>.md`.

## FAQ

- **Do I need to remember where I left off?** No — run `/build-spec` with no argument; the picker
  shows every incomplete feature and its next step.
- **Do I need git for the pipeline?** No — docs commits are offered at milestones, never required.
  Build phases commit as part of their rhythm (that's delivery); iPhone commits and deploys are
  always your explicit call.
- **Can it just build the whole thing?** Deliberately no. Build works one phase doc at a time, one
  app at a time, and must sign each phase's VERIFIED block (gates run fresh + live walk) before the
  next opens.
- **My feature only touches the web.** Fine — `02-app-impact` marks the others out of scope with a
  reason, their docs are one line each, and the plan drops their phases. The reason is what the
  audit checks.
- **A decision row blocks me.** Only OPEN `D#`/`O#`/`C#`/`X#` rows in 09 block the plan step —
  `/build-spec <feature>` presents them as questions with recommendations.
- **The audit found problems in my spec.** Normal — that's its job. Findings become ledger rows +
  dated spec corrections; re-run until a pass reports no new findings.
- **I have older feature docs that aren't numbered** (`docs/features/analytics`,
  `docs/features/state-management`). Run `/build-spec <feature>` — Step 0 detects a legacy suite and
  offers adoption: numbered index docs pointing at the existing content, `STATUS.md` folded into the
  README snapshot. Content is never rewritten.
