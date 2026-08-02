# Feature-spec pipeline — templates, conventions & house rules (MakeReady monorepo)

Load this before writing anything in the `/build-spec` family. It is the single source of truth
for the suite shape, the ledger, the progress formula, the per-app gates, and the cross-app
rules that make a four-app monorepo safe to change from one spec.

The reference suites in-repo today are `docs/features/state-management/` and
`docs/features/analytics/`. They predate this pipeline (unnumbered docs + `STATUS.md`) — treat
them as *content* examples, not *shape* examples. Shape is defined below.

---

## 1. The feature suite (`docs/features/<feature>/`)

A feature is a SUITE of **numbered** docs, never one file. The number IS the dependency order:
you cannot write `04-server.md` honestly without `03-data-and-api.md` settled, and you cannot
build the iPhone phase before the server phase is verified.

| Doc | Written by | Contents |
|---|---|---|
| `README.md` | `/build-spec-draft`, updated by EVERY step | Status line, **Pipeline status (snapshot)** + **Phase status** tables (committed twins of the ledger), doc index, governing rules, the "resume with `/build-spec <feature>`" line |
| `01-architecture.md` | draft | Overview, the **Decisions table** (every settled design question + who decided), baseline patterns cited by `file:line`, permissions/RBAC summary, **Out of scope (deliberate)** |
| `02-app-impact.md` | draft | **The monorepo doc.** Per-app scope (server / client / iphone / capture), the cross-app sequencing plan, contract ownership, and blast radius. Template in §2 |
| `03-data-and-api.md` | draft | **The shared contract.** Prisma/YAML schema changes + migration list, and the endpoint table every consumer codes against (method, path, auth, request, response, error codes). Frozen after the server phase verifies (§3) |
| `04-server.md` | draft | Route modules, services, middleware, permission checks per endpoint, external integrations (Twilio / R2 / Stream / APNs / Claude / API.Bible), push payloads |
| `05-client.md` | draft | Laravel routes (`web.php`), Blade pages, Vue islands/components, Pinia stores, `/admin/api/{path}` proxy entries, SCSS/design-system usage, per-view component coverage matrix |
| `06-iphone.md` | draft | `AppState` entities/properties, Actions, `Route` cases + chrome, Pages, Components, offline/disk-cache impact, push deep links, per-view component coverage matrix |
| `07-capture.md` | draft | `/compare` fixtures, adapters, twins, ViewRegistry cases, screenshot fixtures to re-capture — or an explicit **"Not affected — <reason>"** |
| `08-testing.md` | draft | Per-app test plan, the gate list this feature's phases draw from (§7), the cross-app E2E walk script, the human-verification script (§6) |
| `09-gaps-and-decisions.md` | seeded by draft, **owned by** `/build-spec-audit` | The G/D/O/C/X ledger + dated audit pass log. OPEN rows block the plan step |
| `10+-phase-<N>-<name>.md` | `/build-spec-plan` | One doc PER PHASE — the build guide `/build-spec-build` follows step-by-step. Template in §5 |
| *(state ledger)* | every step | **Outside git** — §4 |

**Every app gets a doc, including the ones it doesn't touch.** `05`, `06`, `07` always exist; an
untouched app's doc contains one line: `**Not affected** — <why>`. An omission you can read is a
decision; a missing file is an oversight. The audit checks those "not affected" claims and turns
wrong ones into `X#` rows.

**Adopting a legacy suite** (unnumbered docs, `STATUS.md`): don't rewrite the content. Add the
numbered docs as thin index/pointer files where content already exists elsewhere in the folder,
fold `STATUS.md` into the README snapshot tables (leave `STATUS.md` in place with a pointer), and
record the adoption in the ledger.

---

## 2. `02-app-impact.md` — the monorepo doc

The one artifact this pipeline has that a single-app pipeline doesn't. It is what stops a spec
from shipping a server change that silently breaks the iPhone app in production.

```markdown
# App impact

## Scope per app

| App | In scope | What changes | Owner doc |
|---|---|---|---|
| server  | ✅/⬜ | <schema, N endpoints, service, push> | 04-server.md |
| client  | ✅/⬜ | <routes, islands, stores, proxy> | 05-client.md |
| iphone  | ✅/⬜ | <AppState, Actions, pages, routes> | 06-iphone.md |
| capture | ✅/⬜ | <fixtures, adapters, twins> | 07-capture.md |

⬜ rows state **why not** in one line. Cross-check against the root `.claude/CLAUDE.md`
§Cross-App Impact Guide — a change type listed there as touching an app that this table
marks ⬜ needs an explicit justification, not silence.

## The contract (who produces, who consumes)

| Contract | Producer | Consumers | Defined in |
|---|---|---|---|
| `GET /api/...` | server | client (via `/admin/api` proxy), iphone | 03 §<n> |

## Cross-app sequencing

Contract → server → consumers, in this order, with the reason each dependency is real:

1. `03` contract settled + migrations planned
2. server implements + verifies (contract now FROZEN — §3)
3. client and iphone build against the frozen contract (parallelizable — they never import
   each other)
4. capture fixtures/compare (only after both consumers render)
5. cross-app E2E + human walk

## Backward compatibility

- Existing iPhone builds in the field / TestFlight hit the same server. Which of these
  changes are breaking for an older client? <list, or "none — additive only">
- Migration is <additive | destructive>; rollout order is <server-first | flag-gated>.

## Blast radius (what else reads this data)

<Endpoints/tables/AppState entities other features depend on, with file:line. A shared
EntityStore or a shared Blade partial makes this bigger than it looks.>
```

---

## 3. Cross-app rules (binding on every step)

1. **Contract-first.** No consumer code is written against an endpoint whose shape isn't in
   `03-data-and-api.md`. If a consumer phase discovers the contract is wrong, that is a
   **`03` amendment + a server-phase reopen**, dated — never a consumer-side workaround and
   never a second shape for the second consumer.
2. **Server is the single source of truth.** Business logic never gets reimplemented in client
   or iPhone to route around a server gap. A gap becomes a `G#` row and a server task.
3. **Contract freeze.** When the server phase signs VERIFIED, `03`'s endpoint table is frozen
   for the rest of the build. Amendments require: the dated edit in `03`, an `X#` row saying
   what broke, and a re-run of the server phase's gates. Consumers must not be mid-flight
   against an unfrozen contract.
4. **Consumer parity.** When both client and iPhone are in scope for the same user-facing
   capability, they consume the **same endpoint with the same fields**. Divergence is a `D#`
   decision, never an accident. `/build-spec-verify` diffs the two consumer docs for it.
5. **Never edit iPhone code from a web task** (and vice versa) because it was "quicker". The
   phase doc names the app; work outside it is a pipeline violation and gets a ledger row.
6. **Additive-only for shared twins.** `/compare` twins are rendered by BOTH the capture
   harness and production — new props default to the captured rendering; existing
   markup/classes are never altered. (See the `compare-twins-index` memory before touching
   any twin.)

---

## 3b. The no-unaudited-material invariant

**No spec material reaches the plan or the build without having been audited — including material
the pipeline itself just added.**

The audit is not a phase you pass once. It is a property the suite either has or doesn't, and it is
*lost* the moment new material lands. New material arrives from three places, and all three are easy
to miss because they feel like progress rather than like new risk:

| Source | Example |
|---|---|
| **A decision at the gate** | "design store-backed pagination now" adds a store-architecture design that has never been examined. "Pull capture into scope" adds a whole app |
| **A mid-build reality conflict** | `/build-spec-build` hits something the suite got wrong, updates the doc (dated) — that updated doc content is unaudited |
| **A spec revision** | the user changes their mind about a behavior and 01–08 are edited |

**The rule: audit the delta immediately, in the same session it is created — never "next time".**
A deferred audit is a skipped audit; the session that created the material is the one that still
has the context to examine it.

Concretely:

1. Applying a decision's consequences is **not finished** until the delta audit has run over what
   changed. The decisions gate does not hand off to `/build-spec-plan` — it hands off to
   `/build-spec-audit --delta`.
2. The delta pass is **scoped to the new material**, not a full re-sweep (`build-spec-audit`
   §Delta pass). It is usually small; that is the point — small enough that there is no excuse.
3. **Audit credit holds at half** while unaudited material exists (§6). A suite whose audit was
   clean and then gained a new design is *not* a clean-audit suite, and the progress number must
   say so rather than ratcheting.
4. `/build-spec-check` re-runs too — new material means new citations, new commands, new counts.
5. The ledger records the delta pass as its own row, naming what triggered it, so a cold session
   can tell an audited suite from a suite that merely *was* audited once.

**If the delta audit finds something, that finding goes back through the decisions gate**, and its
consequences are themselves delta-audited. The loop terminates because each round is strictly
smaller — but it must be allowed to run more than once rather than being cut short to reach the
plan step.

## 4. The state ledger (the pipeline's memory, outside git)

Location: the project state store — the same per-project directory that holds this project's
auto-memory (`memory/MEMORY.md`); ledgers go in a sibling folder:
`<project-state-dir>/build-spec/<feature>.md`. For this repo that resolves to
`~/.claude-home/projects/-Users-lukekeith-www-makeready/build-spec/<feature>.md`. **Derive it
from where auto-memory lives for the active profile; never hardcode it blind.**

Created by the first pipeline step to run, updated by EVERY step at EVERY checkpoint — a plain
file write, **no commit involved**. A cold session reads it FIRST and trusts it over conversation
memory, then spot-verifies its top rows against the artifacts it cites. The README's snapshot
tables are the committed, low-churn twins so a developer without the ledger can continue from the
suite alone.

```markdown
# <feature> — build-spec pipeline state

> Resume with `/build-spec <feature>`. This ledger is the authoritative pipeline state,
> stored OUTSIDE git (survives branch switches, resets, and context clears).
> Feature suite: <absolute path to docs/features/<feature>/>
> Apps in scope: server ✅ · client ✅ · iphone ✅ · capture ⬜

**Progress:** ▓▓▓▓▓▓░░░░ ~NN% (<one clause: where it stands / what remains>) — formula in
REFERENCE.md §6; recompute at every checkpoint, never eyeball.

## Step status

| Step | Status | Last pass | Result / evidence |
|---|---|---|---|
| spec | ✅/🔄/⬜ | YYYY-MM-DD | suite 01–08 + README written |
| audit | ✅/🔄/⬜ | YYYY-MM-DD | pass N: X findings (0 = clean) — 09 has the rows |
| decisions | ✅/🔄/⬜ | — | open: D#, O#, C#, X# (list) |
| plan | ✅/🔄/⬜ | YYYY-MM-DD | phase docs 10–NN written; N phases, M tasks |
| build | ✅/🔄/⬜ | — | phase table below |
| verify | ✅/🔄/⬜ | YYYY-MM-DD | READY / INCOMPLETE: <list> |
| sign-off | ✅/🔄/⬜ | YYYY-MM-DD | human tested: <what they exercised, in their words> |

## Contract state

- `03` frozen: ⬜ / ✅ (date, at server phase N VERIFIED)
- Amendments since freeze: <X# rows, or none>

## Build phases (mirror the README's Phase status; ledger is finer-grained)

| Phase | App | Doc | Status | Verified | Commits | Notes |
|---|---|---|---|---|---|---|

## In flight (the ONLY scratch state — everything else lives in the suite)

- <step>: <bounded unit in progress, exactly enough for a cold session to continue>

## Environment notes (what this session had to do to make things run)

- <e.g. "docker restart makeready-server needed after every server/src edit">

## Checkpoint log (append-only; one line per checkpoint)

- YYYY-MM-DD <step>: <what completed>
```

---

## 5. Phase-doc template (`10+-phase-<N>-<name>.md`)

Each phase doc is a self-contained build guide for **exactly one app** (the cross-app E2E phase
is the sole exception). A cold session opens it and knows what to build, what to test, and what
proves the phase done.

```markdown
# Phase <N> — <name>  ·  app: <server | client | iphone | capture | cross-app>

> Part of docs/features/<feature>/. Preconditions: Phase <N-1>'s **VERIFIED** block is signed
> (or "none — first phase"). <For consumer phases:> the contract in 03 is FROZEN.
> Do not start tasks here until both hold.

## Goal
<2-3 sentences: what exists at the end of this phase that didn't before, and how we know.>

## Companion skills (use these, don't freelance)
<e.g. iPhone overlay → /present-overlay · sub-screen → /push-page · deep link → /nav-route ·
web component → /component · web page → /page · Pinia store → /store · endpoint → /api>

## Tasks (execute in order unless marked ∥ parallelizable)

- [ ] <N>.1 <task> — files: <paths> · spec: <doc §> · tests: <the tests THIS task ships>
- [ ] <N>.2 …

Every task row names its files, its spec section, and the tests that ship WITH it. Tests are
never a later phase. A task that adds a shared `/compare` twin ships its fixture + adapter +
capture in the same row.

## Phase gates (run fresh, record output — no asserting from memory)

- [ ] <the app's gate commands from 08-testing.md — REFERENCE.md §7>

## Verification checklist (beyond gates — the "did it actually work" walk)

- [ ] <observable behaviors: a route responds with the contract's exact shape, a migration
      re-applies as a no-op, an island mounts, a modal presents with the right chrome,
      AppState refreshes after the mutation…>
- [ ] Contract parity: <for consumer phases — the response fields consumed here match 03 §n
      field-for-field, traced in code>
- [ ] Spec parity spot-check: <the 1-3 load-bearing spec claims this phase implements,
      re-read and traced in the shipped code>

## VERIFIED

⬜ Not yet — do not open the next phase doc.
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
```

---

## 6. Pipeline progress (%)

Every handoff shows how far the WHOLE pipeline is, computed with this fixed formula so the number
is deterministic across sessions. **100% = built, verified, and the human has tested it and said
it works.** Weights (sum 100):

| Step | Weight | Earned when |
|---|---:|---|
| spec | 10 | suite 01–08 + README exist |
| audit | 10 | latest pass CLEAN (zero new findings); **half credit** while passes still find things, **and half credit whenever unaudited material exists** (§3b) — a suite that was clean and then gained a new design is not a clean-audit suite |
| decisions | 5 | no OPEN D#/O#/C#/X# rows in 09 |
| plan | 8 | phase docs 10+ written + build go-ahead recorded |
| build | 60 | split EVENLY across the phase docs; see below |
| verify | 5 | verdict READY |
| sign-off | 2 | human exercised the feature and confirmed it works (§8) |

**Build credit per phase:** a phase with a signed VERIFIED block earns its full share. The one
currently-open phase earns a partial share = checked boxes ÷ all checkable boxes in its doc
(count `- [x]` vs `- [ ]`/`- [~]` with grep, not by eye). Unopened phases earn 0.

**Spec credit while drafting** (so the number moves during a long spec conversation, instead of
sitting at 0 until the last file lands) — the spec step's 10 points split:

| Sub-unit | Points | Earned when |
|---|---:|---|
| recon | 1 | the per-app recon is folded into working notes |
| design settled | 3 | the user approved the presented design (Phase 3) |
| suite written | 6 | pro-rata over the 10 suite files (README + 01–09), 0.6 each as each is written |

### The status block — ends EVERY response during any `/build-spec*` work

Two lines, always, no exceptions — including mid-conversation turns, errors, and low-context stops.
Brief by design; the detail belongs above it.

```
📊 <feature> ~NN% ▓▓▓▓▓▓░░░░ — <where it stands right now>
📍 Run `/build-spec <feature>` → <what that command will DO next, in plain words>
```

**Line 2 must always say what the command does next, not just name it.** `/build-spec <feature>` is
the only command the user ever needs to type — the orchestrator detects the state and dispatches to
the step skill itself. Printing a bare command next to a sentence like "next step is
`/build-spec-plan`" reads as a contradiction: it looks like two different commands, or like the
footer is stale. Never make the reader infer that one runs the other.

Real examples — note that line 2 names the *step* in words, and never asks the user to type a
`/build-spec-<step>` command:

```
📊 group-goals ~4% ░░░░░░░░░░ — spec: design approved, 3 of 10 docs written
📍 Run `/build-spec group-goals` → continues writing the suite (04-server next)

📊 state-management ~25% ▓▓▓░░░░░░░ — audit ✅ clean · decisions ✅ · nothing built
📍 Run `/build-spec state-management` → runs the PLAN step: writes the per-phase build guides

📊 group-goals ~33% ▓▓▓░░░░░░░ — plan: 5 phase docs written
📍 Run `/build-spec group-goals` → asks you to approve the phase plan, then starts building

📊 group-goals ~64% ▓▓▓▓▓▓░░░░ — build 3/5: server ✅ client ✅, iphone open (4/9 tasks)
📍 Run `/build-spec group-goals` → resumes the iphone phase at task 4.5

📊 group-goals ~98% ▓▓▓▓▓▓▓▓▓▓ — verify: READY, all gates green
📍 Nothing to run — test it yourself (script above), then tell me and I'll commit + push
```

When the pipeline is **waiting on the user** (a decision, a gate, a sign-off), line 2 says so
instead of naming a command:

```
📍 Answer the decisions above → then run `/build-spec <feature>` and it applies them + re-audits
```

Recompute from the ledger every time (never carry the previous number forward, never eyeball).
Re-running an earlier step doesn't subtract — but if a step's output is **invalidated** (the
contract changed after the audit; a consumer doc changed after verify), drop back to that step's
figure and say why. An honest reversal beats a ratchet.

---

## 7. Quality gates (per app — phase gate lists draw from here; verify runs them all)

**Server** (`/server`)
```
cd server && npx tsc --noEmit                 # typecheck (needs `npx prisma generate` on a
                                              # clean checkout — src/generated/prisma must exist)
cd server && npm run lint                     # eslint, --max-warnings 0
cd server && npm run test:run                 # vitest
cd server && npm run schema:validate          # when schema/*.yaml changed
cd server && npm run schema:diff              # generates the Atlas migration
cd server && npm run migrate:status           # local migration state
docker restart makeready-server               # AFTER ANY server/src EDIT — see §9
```

**Client** (`/client`)
```
cd client && npm run build                    # vite build (also required before any capture)
cd client && npm run guard                    # tokenization guard (design-token compliance)
cd client && ./vendor/bin/phpunit             # Laravel Feature + Unit tests
cd client && npm run story:build              # when Histoire stories changed
```

**iPhone** (`/iphone`)
```
npm run ios:build-check                       # xcodebuild against a simulator destination (repo root)
npm run ios:build-check -- --test             # when the phase ships XCTest coverage
cd iphone && swiftlint                        # MUST run from iphone/ — included: paths are relative
cd iphone && swiftlint lint --write-baseline .swiftlint-baseline.json   # ONLY when consciously
                                              # accepting a violation (1,118 entries today)
```
The build go-ahead (`/build-spec` Step 4) covers running `ios:build-check` as a phase gate.
**Launching the app (`/rebuild-iphone`), archiving, and committing iPhone code remain explicit
user calls.**

**Capture** (`/capture`)
```
curl -s localhost:5950/api/compare/manifest   # capture server up
node capture/runners/compare/diff.mjs …       # programmatic pixel diff (advisory)
```
Web captures go through the **host** artisan on `:8002` with `CAPTURE_BASE_URL` set — not the
docker `:8001` (§9). Rebuild the client bundle first.

**Cross-app**: the E2E walk in `08-testing.md`, executed live against the local stack
(`/dev-start`), plus a `/compare` diff for any screen with an iPhone twin.

---

## 8. Human sign-off (the last 2%)

Agent evidence is **evidence**, not sign-off. A green `ios:build-check`, a clean pixel diff, and a
passing test suite can all be true while the person who owns the feature has seen nothing.

Before the README status line flips to `Shipped`:

1. Land everything and get the verify verdict to READY.
2. **Hand them the app** — the exact URL / simulator screen, what to tap, what to look for,
   newest and least-exercised surfaces first, plus the local facts they'd otherwise rediscover
   (which port, which seeded org, where SMS codes come from, which surfaces can't work locally).
3. **Stop.** Don't call it "verified" or "done" while only agents have exercised it. Say plainly
   what is and isn't human-tested.
4. Proceed only on an explicit affirmative about the *feature working*. A go-ahead to run the
   pipeline, or approval of a plan, is not this.

## 8b. Commit & push policy

**Nothing is pushed until the feature is built, verified READY, and signed off.** The pipeline's
persistence is the ledger + the suite, not git — so there is never a reason to push early "so the
work isn't lost."

| Moment | What happens |
|---|---|
| Any checkpoint mid-phase | Ledger + doc writes only. No git. |
| Phase close (server / client / capture) | **Offer** a local conventional commit (`feat(<feature>): phase N <app> — <summary>`). The user may decline and keep going — declining is not a problem, the docs carry the state. Never push. |
| Phase close (iPhone) | Commit requires **explicit approval**, same as launching or archiving the app. |
| Docs-only steps (draft / audit / plan) | Offer a `docs(<feature>): …` commit at step completion. Never force. |
| Verify = READY | Still no push. Hand the app to the human (§8). |
| **After sign-off** | This is the commit-and-push moment: squash-or-tidy as the user prefers, push once. |
| Deploy | `/deploy` — the user's explicit command, always, and never part of the pipeline. |

**Deploys are never part of the pipeline.** `/deploy` is the user's explicit command, always.

---

## 9. Environment landmines (cost hours when rediscovered — check the ledger's env notes too)

- **The server container does NOT hot-reload host edits.** `tsx watch` misses bind-mount events —
  `docker restart makeready-server` after editing `server/src`, or your test hits the old code.
- **curl against the server needs a non-bot User-Agent** (the bot guard middleware).
- **Local ports:** client docker `:8001`, host artisan for capture `:8002`, server `:3010`,
  postgres `:5434`, capture UI `:5950` / API `:5951`.
- **Capture web shots must use the host `:8002` + `CAPTURE_BASE_URL`** — `:8001` advertises a
  stale LAN `VITE_ORIGIN` and silently produces BLANK screenshots.
- **`/compare` web captures hit the BUILT bundle** — rebuild the client before capturing.
- **Restart the capture server after editing adapters.**
- **iPhone snapshots lie in known ways**: `.ultraThinMaterial` renders invisible, `AsyncImage`
  falls back to initials, `CachedAsyncImage` shows a spinner. Consult the `compare-*` memories
  before "fixing" a twin to match.
- **Org authorization**: many endpoints authorize by `creatorId` and lock out org leaders — new
  endpoints use the org-level check (`canManageOrgContent`), not creator identity.

---

## 10. House rules the audit enforces

Source of truth is the per-app `CLAUDE.md` (`client/.claude/`, `server/.claude/`,
`iphone/.claude/`) plus `.project/ARCHITECTURE_SPEC.md` and `client/DESIGN_SYSTEM.md`. Read the
relevant one; this is the checklist, not a replacement.

**Server** — route module + service split (`src/routes/` thin, `src/services/` owns logic);
Prisma via the schema YAML source of truth (`server/schema/`), never hand-edited migrations;
org-scoped RBAC checked in the service layer; zod validation on every mutating body (and it must
not silently strip fields the consumer sends — a real past bug); external integrations behind
their service module.

**Client** — Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for
API data + UI stores for view state, never component-level `fetch`; admin API through the
`/admin/api/{path}` proxy with `connect.sid` forwarding; PrimeVue + the design system —
design-token SCSS only (`npm run guard` enforces it); reuse before building.

**iPhone** — `@Observable` + Actions; **every server-derived collection that more than one screen
reads, or any screen mutates, lives in `AppState`** (`EntityStore` when it has identity), and a
mutating Action refreshes the derived state in the same call (`docs/features/state-management/`);
no `APIClient` calls from Pages/Components; overlays via the typed `Route` system —
**never `.sheet`/`.fullScreenCover`, never `asyncAfter` choreography** (`/present-overlay`,
`/push-page`, `/nav-route`); animations follow the Motion tokens (`/transition-review`).

**Capture** — manifest-driven fixtures; twins additive-only; register in the component-capture map.

---

## 11. Companion skills (the build step routes to these instead of freelancing)

| Task | Skill |
|---|---|
| iPhone modal / menu / overlay | `/present-overlay` |
| iPhone push sub-screen | `/push-page` |
| iPhone deep link / cross-tab nav | `/nav-route` |
| iPhone animation bug / review | `/animation-debug`, `/transition-review` |
| iPhone error handling | `/ios-error-surface` |
| Web component / page / store | `/component`, `/page`, `/store` |
| Server endpoint | `/api` · Postman collection: `/postman` |
| Add a screen to `/compare` | `/capture-add` · match it to iPhone: `/capture-parity` |
| Local stack up/down | `/dev-start`, `/dev-stop` · iPhone: `/rebuild-iphone` |
| Architecture review of what was built | `/architect` |

---

## 12. Ledger conventions (uniform across features — the pipeline greps these)

- **G# gaps** — things the spec doesn't cover that the built feature must. Never renumber;
  append. States: open (proposed resolution) → `**RESOLVED (date, evidence)**` /
  `**Fixed in the spec (date)**`.
- **D# decisions** — choices with >1 defensible answer; options listed, **Recommended** or
  `**DECIDED (name, date)**`. OPEN decisions block `/build-spec-plan`.
- **O# open items** — non-technical blockers (copy, legal, a Monday ticket, an App Store
  constraint). Own table.
- **C# component-coverage holes** — a view element with no existing component, per app. Resolves
  to an existing component, a **(new)** row in `05`/`06`, or a `D#`.
- **X# cross-app contract risks** — producer/consumer mismatches, breaking changes for shipped
  iPhone builds, an app marked "not affected" that actually is, a consumer divergence. Own table.
  OPEN `X#` rows block the plan step **and** the verify verdict.

**These letters are internal.** They exist so the pipeline can grep and so rows never collide. When
an open row is put to the user at the decisions gate, it is renumbered D1, D2, D3… in display order
and its ledger id becomes a trailing note (`build-spec` §Step 2). A reader should never have to
learn what `X` means to answer a question.

## 13. The verification convention (every factual claim in the suite)

- Verified claims carry `file:line` evidence and a dated marker: `**verified in code
  (YYYY-MM-DD)**`, or inline (`server/src/routes/programs.ts:214`).
- Unverified claims are explicitly `(claimed — unverified)`. `/build-spec-audit` removes the
  marker or corrects the claim; `/build-spec-verify` fails on any remaining marker.
- Cite `path:line` at write time but anchor prose to stable names (function / route / model /
  Swift symbol) so later passes can re-find them when lines drift.
