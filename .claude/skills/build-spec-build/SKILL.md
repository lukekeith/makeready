---
name: build-spec-build
description: Execute a MakeReady feature's phase docs one at a time — the single app-changing step of the /build-spec pipeline. Opens the lowest unverified phase doc, works its checkbox tasks in order (each with its tests, each routed through its companion skill), runs that app's gates, walks the verification checklist, signs the dated VERIFIED block, commits, and only then opens the next phase doc. Enforces one app per phase and the contract freeze at the server phase. Resumes at the exact next unchecked item after any context clear. Never silently diverges from the suite — reality conflicts become dated doc updates. Use when the user asks to build, implement, or continue building a specced feature.
disable-model-invocation: true
---

# /build-spec-build <feature> — one phase, one app, verified before the next

Preconditions (check, don't assume): phase docs (10+) exist and the build go-ahead is recorded in
the ledger (if not, present the phase table and get it now). Read the ledger FIRST — it names the
current phase, the in-flight task, and the contract-freeze state; the phase doc's checkboxes are
the ground truth for what's done. Resume there, never from git archaeology. Conventions in
[`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md).

**The prime rule: the ONLY open phase is the lowest-numbered doc whose VERIFIED block is
unsigned.** Its preconditions line requires the previous phase's signed VERIFIED block — check it,
don't assume it. Working ahead into a later phase doc, for any reason, is a pipeline violation: if
the current phase is blocked, the blocker gets a ledger row and the handoff — the next phase does
NOT start.

**The second rule: stay in the phase's app.** The phase doc names one app. Editing another app's
code because it was "quicker" is a violation — it becomes a task in that app's phase, or a `G#`
row if it wasn't planned.

## The task rhythm (bounded unit = one checkbox row)

1. Take the next unchecked task in the open phase doc (order matters unless marked ∥).
2. Re-read the suite section the task cites — the suite is the contract. **When implementation
   reality contradicts it, stop, update the doc (dated: what was wrong, what changed), then
   continue — never silently diverge.** If that update **adds material** rather than just correcting
   a detail — a different approach, a newly-touched app, a design the suite never described — it is
   unaudited spec content: run a delta audit over it before the task is ticked (REFERENCE.md §3b).
   A phase cannot sign VERIFIED with unaudited material inside it.
3. **Use the task's companion skill** (REFERENCE.md §11) rather than freelancing: `/present-overlay`
   for any iPhone modal/menu, `/push-page` for a sub-screen, `/nav-route` for a deep link,
   `/component` `/page` `/store` for the web, `/api` for an endpoint. These encode conventions this
   pipeline does not restate.
4. Implement per the house rules (REFERENCE.md §10). The task's tests ship in the same unit — a
   task without its tests is not done.
5. Run the checks the task names. Green → tick the checkbox (with date), checkpoint the ledger.
   Red → fix before moving on; a task is never ticked with failing checks.
6. Context running low? Land the current task (or write its exact partial state into the ledger's
   *In flight*), update the ledger, stop, point at `/build-spec <feature>`.

**Server tasks:** `docker restart makeready-server` after every `server/src` edit before testing —
the container does not pick up host edits. curl with a non-bot User-Agent. Schema changes go
through `server/schema/` YAML → `schema:generate` → `schema:diff` → `migrate:apply`, never a
hand-written migration.

**iPhone tasks:** `npm run ios:build-check` is the compile gate and is covered by the build
go-ahead. **Launching the simulator (`/rebuild-iphone`), archiving, and committing iPhone code are
explicit user calls** — ask, don't assume. Run `/transition-review` on any diff touching animation
or presentation before signing the phase.

**Capture tasks:** rebuild the client bundle before capturing; web captures go through the host
`:8002` with `CAPTURE_BASE_URL`; restart the capture server after editing adapters; twins change
additively only.

## The phase-close rhythm (the anti-one-shot gate)

All tasks ticked does NOT close a phase. In order:

1. **Phase gates** — run the doc's gate list fresh (REFERENCE.md §7, filtered to this app); record
   a one-line output summary per gate in the doc. No asserting from memory.
2. **Verification checklist** — walk every item live (endpoints return 03's exact shape, migrations
   re-apply as no-ops, stores load, modals present and dismiss, twins diff clean), tick with
   evidence. On consumer phases the **contract-parity check** is mandatory: the fields consumed
   here match 03 field-for-field, traced in code.
3. **Sign VERIFIED** — flip the doc's block to `✅ YYYY-MM-DD` with the gate summary + commit shas.
   Update the README Phase status row + the ledger phase table.
4. **Freeze the contract** — when the phase just signed is the server API phase, mark 03 frozen in
   the ledger's Contract state and note the date at the top of `03-data-and-api.md`. From here, any
   contract change is a dated `03` amendment + an `X#` row + a re-run of the server phase's gates.
5. **Commit conventionally** (`feat(<feature>): phase N <app> — <summary>` + the repo's
   Co-Authored-By convention). Web/server phases commit as part of the rhythm; **iPhone commits
   need explicit approval**. Push and deploy are never done here.
6. **Handoff, then the next phase** — present the phase summary and what the next phase doc will
   do; continue without re-asking (the go-ahead covered the plan) unless the plan itself changed.

## Standing constraints

- Never reset or seed the local database unprompted; never touch production. `/dev-start` brings
  the stack up.
- A blocked task (missing decision, broken assumption, wrong contract) becomes a `G#`/`D#`/`X#` row
  in 09 + an annotation on the unchecked task — skip to the next unblocked task IN THE SAME PHASE
  and surface the blocker in the handoff; a phase with a blocked task cannot sign VERIFIED.
- Verification before completion, always: "done/passing" claims require the command output in hand.
- Write anything non-obvious you learn about the environment into the ledger's env notes, and
  anything durable about the codebase into a memory file.

## Definition of done (for this skill)

Every phase doc's VERIFIED block signed; README Phase status all ✅. Then hand off to
`/build-spec-verify` — the gate does its own fresh sweep; build completion is not the verified
state, and neither is the verified state the same as the human having used it.

## Exit handoff (standalone runs too)

End every run — complete, paused, or errored — with the standard handoff (`build-spec` §Step-end
handoff): what landed (phase/app/tasks/commits), what's next as copy/paste commands, open blockers
with their exact rows, and ALWAYS the two-line status block as the last thing in the response
(REFERENCE.md §6):

```
📊 <feature> ~64% ▓▓▓▓▓▓░░░░ — build 3/5: server ✅ client ✅, iphone open (4/9 tasks)
📍 Run `/build-spec <feature>` → resumes the iphone phase at its next unchecked task
```
