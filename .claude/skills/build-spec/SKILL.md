---
name: build-spec
description: One-command orchestrator for the MakeReady feature-spec build pipeline. Takes a buildable spec in docs/features/<feature>/ all the way to implemented-verified-and-signed-off across the monorepo's four apps (server, client, iphone, capture) — by detecting where the feature currently stands and driving the family skills (build-spec-audit, build-spec-plan, build-spec-build, build-spec-verify) in sequence, pausing only at real human decisions. Enforces contract-first, server-then-consumers ordering so one spec can safely change multiple apps. Invoked WITHOUT an argument, it lists every known feature with where each stands and lets the user pick one to continue. The individual steps still run standalone. Use only when explicitly invoked via /build-spec.
disable-model-invocation: true
---

# Feature spec → implementation pipeline (one command, end-to-end, four apps)

Invocation: **`/build-spec <feature>`** — `<feature>` is the kebab-case folder name under
`docs/features/` (e.g. `state-management`).

**`/build-spec` with NO argument = the pipeline picker.** Enumerate every feature the two
sources know about, merge, present one table:

1. **State ledgers** — `ls <project-state-dir>/build-spec/*.md` (location convention in
   [REFERENCE.md](REFERENCE.md) §4); read each ledger's step-status table (fast, authoritative).
2. **Feature folders without a ledger** — `ls docs/features/*/` not covered by (1); infer status
   from artifacts (Step 0's table) and note "ledger missing — will rebuild". A folder with
   unnumbered docs is a **legacy suite** — status "needs adoption" (REFERENCE.md §1).

Present via **AskUserQuestion** — one option per INCOMPLETE feature, description = one-line status
prefixed with its pipeline % (REFERENCE.md §6): "~35% — audit clean; 2 decisions open — next:
decisions gate". Recommend the feature closest to done. Signed-off features are mentioned in the
summary but omitted from the options unless nothing else exists. On selection, continue exactly as
if invoked with that feature.

The premise: **every feature starts as a buildable spec SUITE in `docs/features/<feature>/`** —
numbered docs + a README tracker (written with `/build-spec-draft`), audited against the codebase
before any code is written, planned as per-phase build-guide docs, and built ONE PHASE AT A TIME —
**one app per phase, server before its consumers** — each phase verified and signed off in its doc
before the next opens. Resumable after any context clear. One-shotting a feature is forbidden by
construction.

```
  /build-spec-draft <feature> ─▶ the suite: README + 01-architecture … 08-testing (+ 09 seeded)
          │                       incl. 02-app-impact (which apps) + 03-data-and-api (the contract)
          │
  0 /build-spec-check ──▶ integrity: every file:line citation opened, every count re-grepped,
          │               every gate command proven to exist AND to be invoked from the right
          │               directory, every link resolved, ledger ↔ artifacts ↔ code agree.
          │               Minutes. Re-run after ANY suite change — a spec that is wrong about
          │               itself makes every later step reason off bad evidence
          │
  1 /build-spec-audit ──▶ 09-gaps-and-decisions.md: suite verified against FOUR codebases —
          │               per-app pattern compliance, schema/lifecycle, CROSS-APP CONTRACT
          │               (producer/consumer parity, breaking changes for shipped iPhone
          │               builds, "not affected" claims), component coverage per consumer,
          │               gap hunt (G/D/O/C/X ledger). Re-run until a pass reports nothing new
          │
  2 [decisions gate] ──▶ open D#/O#/C#/X# rows resolved by the human
          │
  3 /build-spec-plan ──▶ phase docs 10+ — ONE APP PER PHASE, dependency-ordered:
          │               contract/migrations → server → client ∥ iphone → capture → E2E
          │
  4 /build-spec-build ─▶ ONE phase doc at a time: tasks → gates → verification checklist →
          │               dated VERIFIED sign-off → commit → next phase. The server phase's
          │               sign-off FREEZES the contract in 03 (re-enter any number of times)
          │
  5 /build-spec-verify ─▶ READY / INCOMPLETE verdict (all phases VERIFIED, all per-app gates
          │               green fresh, no unverified claims, consumer parity holds, E2E walked)
          │
  6 [human sign-off] ──▶ the user personally exercises the feature and says it works (§below)
```

**How it runs the steps:** read and follow each family skill's `SKILL.md` in turn — they are the
single source of truth; do not re-implement their logic here.

## The loop: keep going until you hit a real gate

One invocation should make as much progress as it can. **Do not stop to ask "continue to the next
step?"** — that question has one useful answer and turns a pipeline into a wizard. Detect the
state, run the step, and roll straight into the next one.

Stop only for:

1. **A real gate** — the decisions gate (Step 2), the build go-ahead (Step 4), human sign-off
   (Step 6). These have answers only the user has.
2. **A real question raised by the work** — a `D#` the audit surfaced, a contract choice, a
   blocked task. Ask it, in a batch with any siblings, then continue on the answer.
3. **Context genuinely running low** — checkpoint the ledger and say so.

**A finished bounded unit is NOT a reason to stop** (Luke, 2026-08-04). Land the task, checkpoint
the ledger, and take the next one in the same run — through phase closes, through `VERIFIED`
sign-offs, into the next phase doc, and on to `/build-spec-verify` if you get that far. Keep going
until one of the three reasons above actually bites. Re-typing the command is not a checkpoint
mechanism; the ledger is. Narrate progress compactly between units rather than presenting a full
step-end handoff at each one — the full handoff belongs at the actual stop.

Everything else is the pipeline's own business. So the intended rhythm is exactly:
`/build-spec <feature>` → it works → it asks what it genuinely needs → you answer →
`/build-spec <feature>` again, until verify is READY and you've tested it.

## Step-end handoff (after EVERY step, and on every pause/stop)

The pipeline is built for a developer with no prior context. When a step completes and you are
about to continue, a one-paragraph note is enough. When you STOP — for a gate, a question, or a
context edge — present:

1. **What just happened** — 2–4 sentences, plain language, no session shorthand. Name the apps
   involved.
2. **What is being asked / what's next** — if it's a question, ask it (AskUserQuestion,
   recommendation first, related decisions batched). If it's a change the user must make, give the
   file, the exact edit, and the command to re-run afterward.
   **Never present `/build-spec-<step>` as the thing to run next.** `/build-spec <feature>` runs
   that step itself; offering both invites the reader to think they are different paths. Name the
   next step in **words** ("next it writes the phase docs"), and mention the standalone commands
   only if the user asks how to run one step in isolation.
3. **The status block** — the last two lines of the response, ALWAYS, no exceptions: every turn of
   a spec conversation, every step end, every error, every low-context stop. Exact format and the
   recompute rules are in REFERENCE.md §6:
   ```
   📊 <feature> ~64% ▓▓▓▓▓▓░░░░ — build 3/5: server ✅ client ✅, iphone open (4/9 tasks)
   📍 Run `/build-spec <feature>` → resumes the iphone phase at task 4.5
   ```
   Line 2 **always states what the command will do**, never just names it — a bare command beside
   prose that says "next step is X" reads as a contradiction. Compute the % from the ledger with the
   fixed formula — never carry forward, never eyeball.

Step skills running standalone follow the same handoff shape.

## Context survival (binding on every step — the pipeline outlives any one session)

1. **The state ledger is the pipeline's memory, and it lives OUTSIDE git** (template + location in
   [REFERENCE.md](REFERENCE.md) §4). Every step reads it on entry and updates it at every
   checkpoint — a plain file write; git is never a dependency for continuation. On a cold start,
   TRUST THE LEDGER over anything remembered from conversation — then spot-verify its top rows
   against the artifacts it cites.
2. **All findings live in files, never in conversation.** A discovery that exists only in a chat
   message or an agent report does not exist — write it into the suite (09 for findings, the phase
   doc for build state, 01–08 for corrections) the moment it arrives.
3. **Work in bounded units** sized to finish well within one context window: one audit phase, one
   phase doc, one task row — never "the whole step" as one unpersisted arc.
4. **At every STEP completion, update the README's snapshot tables** (Pipeline status + Phase
   status) — the committed, shareable twins of the ledger.
5. **Checkpoint = ledger update (+ the file writes it describes).** When context runs low mid-step:
   finish the current bounded unit (or write its partial state into the ledger's *In flight*),
   update the ledger, and tell the user to re-invoke `/build-spec <feature>` fresh. Never start a
   unit you can't land.
6. **Parallel agents are fire-and-fold:** brief them from the docs, fold their results into the
   docs immediately — an unfolded agent report dies with the session. Right-size the model:
   `sonnet` for mechanical sweeps (route/endpoint enumeration, file-existence checks, component
   inventories), `opus` for real reasoning (contract seams, RBAC analysis, schema lifecycle,
   anything whose wrong answer would mislead the plan). Unsure → `opus`.
7. **Record environment friction in the ledger's env notes** — the landmines in REFERENCE.md §9
   plus anything new this feature hit.

## Step 0 — Detect pipeline state

Read the state ledger first; it names the current step and any in-flight unit. If missing or
stale, infer from artifacts, then (re)create the ledger (report the detection either way):

| Observation | State → next step |
|---|---|
| No `docs/features/<feature>/` (or a README with no numbered docs) | run `/build-spec-draft <feature>` (conversational — needs the user) |
| Folder exists with UNNUMBERED docs (legacy suite) | offer adoption (REFERENCE.md §1), then continue |
| Suite exists but 09 has no dated **Integrity check** (or the suite changed since the last one) | run `/build-spec-check` — minutes, mechanical, and it stops the audit from reasoning off wrong citations |
| Suite 01–08 exists; 09 has no dated audit pass (or 01–08 changed since the last one) | run `/build-spec-audit` |
| 09's latest pass reported findings | re-run `/build-spec-audit` |
| Audit clean, but OPEN `D#`/`O#`/`C#`/`X#` rows in 09 | pause — the decisions gate (Step 2) |
| Decisions resolved, no phase docs (10+) | run `/build-spec-plan` |
| A phase doc has unchecked tasks or an unsigned VERIFIED block | run `/build-spec-build` (resumes at that phase's next unchecked item) |
| A consumer phase is open but `03` is not frozen | stop — the server phase must verify first (REFERENCE.md §3) |
| All phase docs VERIFIED, no verify verdict (or code changed since) | run `/build-spec-verify` |
| Verify = INCOMPLETE | present the blocking list; loop to the step that clears it |
| Verify = READY, no human sign-off recorded | Step 6 — hand them the app (below) |
| Signed off | done — offer `/deploy` (the user's call, never automatic) |

## Step 2 — The decisions gate (human)

The first unconditional pause. Present every OPEN `D#`/`O#`/`C#`/`X#` row from 09 **as a stacked
block in the chat**, in this exact shape — one block per decision, all of them in one message:

```
**D1 — <the question in plain language, as a question>**
<1–3 sentences of context: what this is about, why it came up, and what it changes. No ledger
jargon, no bare symbol names — say "the tag list the Library filter uses", not "allProgramTags".>

- **A) <option>** *(Recommended)* — <consequence: cost, risk, what it buys>
- **B) <option>** — <consequence>
```

Rules that make this readable rather than a wall:

- **Plain language wins over precision.** The evidence is already in 09; this block exists to be
  understood, not to be complete. Name screens and behaviors the way a user would.
- **Number them D1, D2, D3… in the display even when their ledger ids differ** (`X1`, `O2`, `C4`).
  The ledger id is a grep key, not a user-facing label — show it in a trailing note
  (`↳ recorded as X1`) so the doc and the chat stay traceable without leaking taxonomy into the
  question. **Never make the reader learn what the letters mean.**
- **Order by blast radius, not by id.** A cross-app scope question answered late is the most
  expensive kind of rework, so it goes first even if it's numbered last.
- **Say what happens if they pick nothing yet** — which phases stay blocked.
- Recommend one option per decision, and give the one-line reason for the recommendation.
- **Then, and only then**, optionally mirror the block into AskUserQuestion for click-through. The
  chat block is the source of truth; the picker is a convenience. If a decision doesn't fit
  multiple-choice, just ask it in prose.

Record each answer in the ledger row (`**DECIDED (name, date)**`) and apply the consequences to the
affected suite docs (dated). **If the user says a decision is unclear, that is a finding about the
presentation, not about them** — rewrite the block with more context and less vocabulary, don't
re-send the same text.

**Then, before anything else: audit the delta (REFERENCE.md §3b).** A decision that adds material —
a new design, a newly in-scope app, a changed approach — has created spec content that has never
been examined. Run `/build-spec-audit` in **delta mode** over exactly what changed, **in this same
session**, and only then consider the gate closed. The decisions gate hands off to the delta audit,
never straight to `/build-spec-plan`.

Also sweep for **stale `OPEN` markers** before moving on: a row the decision just resolved must stop
saying OPEN, because that string is what blocks the plan step. And a row that can never be resolved
(a standing constraint like "simulator builds need approval") is marked ACKNOWLEDGED, not left OPEN
to stall the gate forever.

## Step 4 — Build go-ahead (human)

`/build-spec-build` changes the app(s). Before the first build phase, present the phase table
(phase, app, task count) and take one explicit go-ahead. That go-ahead also covers running
`npm run ios:build-check` as a phase gate. Later phases within the same approved plan proceed
without re-asking; re-ask only if the plan itself changes. **Launching the iPhone app, archiving,
and deploying stay separate explicit calls.**

## Step 6 — Human sign-off (human)

The last unconditional pause, and the last 2% (REFERENCE.md §8). READY means the agents verified
it; it does not mean anyone has used it. Hand the user the app: the exact URL / simulator screen,
what to tap, what to look for — newest and least-exercised surfaces first — plus the local facts
they'd otherwise rediscover. Then stop. Do not describe the feature as done, shipped, or verified
while only agents have exercised it. Record their words in the ledger and flip the README status
line only on an explicit affirmative that the feature works.

## Ground rules

- **One feature per run.** Steps 0–3 are read-only against app code (check and audit may not change
  code; corrections are doc edits) and safe to re-run; steps 4–5 change code.
- **Re-run `/build-spec-check` after any suite change**, and always before `/build-spec-plan` and
  before `/build-spec-verify`. It is cheap, and every later step reasons off the suite's claims.
- **One app per build phase**, and the server phase precedes its consumers (REFERENCE.md §3).
- Every factual claim written into the docs follows the **verification convention**
  (REFERENCE.md §13): `file:line` evidence + dated marker, or `(claimed — unverified)`.
- **Nothing is pushed until built + verified READY + signed off** (REFERENCE.md §8b). Local
  commits are offered at phase and step completions, never forced, never blocking; iPhone commits
  need explicit approval. The push is a single deliberate act at the end.
- **Deploys are never part of the pipeline.** `/deploy` is the user's explicit command.
