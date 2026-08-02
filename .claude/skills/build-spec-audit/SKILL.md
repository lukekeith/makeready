---
name: build-spec-audit
description: Verify a MakeReady feature suite (docs/features/<feature>/, docs 01–08) against all four codebases before any code is written — per-app pattern compliance (server routes/services/RBAC, client islands/stores/proxy, iPhone AppState/Actions/Routes), schema & lifecycle check, the CROSS-APP CONTRACT audit (producer/consumer parity, breaking changes for shipped iPhone builds, wrong "not affected" claims), component coverage per consumer, and an adversarial gap hunt — recording findings in 09-gaps-and-decisions.md's G/D/O/C/X ledger. First code-facing step of /build-spec; re-run until a pass reports no new findings. Use when the user asks to audit, verify, or gap-check a feature spec.
---

# /build-spec-audit <feature> — the spec suite meets four codebases

Input: `docs/features/<feature>/` docs 01–08. Output: a dated audit pass in
`09-gaps-and-decisions.md` (+ dated corrections applied to 01–08). **Read-only against code** —
this step edits docs only. Templates + conventions in
[`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md) — load it before writing anything. Read
the ledger on entry; create it (and 09 from the template, if the draft step didn't seed it) if
this is the first pipeline step to run.

Each phase below is a bounded unit: fold its findings into 09 and checkpoint the ledger before
starting the next. Findings are rows, not prose: `G#` (spec gap), `D#` (open decision), `O#`
(non-technical blocker), `C#` (component-coverage hole), `X#` (cross-app contract risk) — never
renumber, only append. Suite statements the code contradicts are corrected in place immediately
(dated), with the audit row recording what changed. A pass with zero NEW findings = audit clean;
record the dated verdict at the top of 09 and in the README snapshot.

## Phase A — Cross-app contract (02, 03) — run this FIRST

The most expensive findings live here, so they come first.

- **Scope truth**: check every ⬜ row in 02's scope table against the root CLAUDE.md §Cross-App
  Impact Guide and against the actual code. An app marked "not affected" that reads the changed
  table, endpoint, or `AppState` entity = **`X#` row**. Grep both consumers for the endpoints and
  models 03 touches.
- **Producer/consumer parity**: every field 05 (client) and 06 (iPhone) claim to consume exists in
  03's response table, with the same name and type. Every endpoint 03 defines has at least one
  named consumer. Mismatch = `X#`.
- **Divergence check**: where the two consumers use *different* endpoints or shapes for the same
  capability, confirm 02 records it as a deliberate decision. Undocumented divergence = `X#`.
- **Backward compatibility**: for each change, would an iPhone build already in the field break?
  (Removed/renamed response fields, newly-required request fields, changed status codes, stricter
  zod validation.) Each risk = `X#` with the mitigation (additive-only, versioned, flag-gated).
- **Auth reachability**: the client reaches admin endpoints through `/admin/api/{path}` with
  `connect.sid` forwarding; iPhone hits the server directly with its own session. Confirm the
  planned endpoints are reachable from BOTH paths and that the proxy entry is specced. Also
  confirm authorization is org-level (`canManageOrgContent` style) rather than `creatorId` —
  creator-only checks lock out org leaders (a known repeat bug).

## Phase B — Schema & lifecycle (03)

For every model/table in 03: naming and type conventions, org scoping + indexes, the
`server/schema/` YAML source of truth (never hand-edited Prisma or migrations), FK/cascade
behavior, enum values vs existing ones, and the lifecycle hunt — what happens to dependent rows on
delete/restore of each parent? What happens to *enrolled members* or *scheduled lessons* mid-
change? Race conditions on unique constraints? Migration ordering and reversibility? Does the
iPhone's disk cache hold a now-stale shape (offline support means old JSON survives an upgrade)?
Every hole = `G#`.

## Phase C — Per-app pattern compliance (04, 05, 06, 07)

Spawn parallel Explore agents — mechanical sweeps `sonnet`, judgment reads `opus` — one per
in-scope app, each checking its doc against its own `CLAUDE.md` and REFERENCE.md §10:

- **server (04)** — route module thin / service owns logic; zod on every mutating body **and it
  doesn't strip fields the consumers send**; RBAC checked in the service layer; literal routes
  before `:id`; external integrations behind their service; audit/logging conventions.
- **client (05)** — Vue islands mounted into Blade (not ad-hoc SPA); Pinia domain store + UI store,
  never component-level fetching; the `/admin/api` proxy entry specced; design-token SCSS only
  (`npm run guard` will enforce it); PrimeVue/design-system reuse over bespoke markup.
- **iphone (06)** — the state-management rule: any server-derived collection more than one screen
  reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity), and the
  mutating Action refreshes derived state in the same call; no `APIClient` in Pages/Components;
  overlays through the typed `Route` system with the right chrome (**never `.sheet` /
  `.fullScreenCover` / `asyncAfter` choreography**); Motion tokens for transitions; error handling
  routed per `/ios-error-surface`.
- **capture (07)** — twins additive-only; the fixture/adapter/ViewRegistry work named; whether an
  existing twin is being reused or a new one is needed (check the `compare-twins-index` memory for
  its traps and BEM collisions).

Cross-cutting claims get spot-verified with `file:line`: named baseline components exist with the
claimed props, named patterns still look like the suite assumes. Mark each `**verified in code
(date)**` or correct it.

## Phase D — Component coverage (05, 06 — the no-bespoke-UI gate)

1. **Inventory sweep** (Explore, `sonnet`), per consumer: what exists TODAY in
   `client/resources/js/components/` + `client/ui/` and in `iphone/MakeReady/Components/`.
   Components move; never trust a stale inventory.
2. **Matrix check**: every element of every view maps to a named existing component (verify the
   export/props actually fit) or a **(new)** row. Neither = `C#`. Bespoke markup where a component
   exists = `C#`.
3. **Missing components**: for each **(new)**, name the in-repo reference pattern it copies, and —
   when a twin exists on the other platform — whether it should be built as a `/compare` twin so
   both platforms share one source of truth.
4. **UX-pattern check**: loading, empty, and error states specified per view, per app; navigation
   placement; permission-gated rendering; modal vs page vs inline matched to the nearest existing
   surface. A view state the suite doesn't cover = `G#`. A genuinely NEW UX pattern = `D#` — new
   patterns are a human decision, not an audit default.

## Phase E — Gap hunt (adversarial pass, `opus`)

Walk each user flow end-to-end hunting for unspecified behavior: auth boundaries (member vs group
leader vs admin vs super admin), org isolation, empty/missing-data edges, double-submit and
idempotence, concurrent mutation from two devices, push-notification payload + deep-link
correctness, media/video upload failure paths, timezone traps, offline-then-reconnect on iPhone,
seed/test-data needs, and migration ordering against a running production server. Each = `G#` with
a proposed resolution (Recommended), or `D#` if genuinely contested. Also grade 08: does the test
plan cover the risks this pass surfaced, in the right app? Missing coverage = `G#` against 08.

## Delta pass (`/build-spec-audit <feature> --delta`) — the mandatory follow-up to new material

Triggered whenever material is **added** to an already-audited suite (REFERENCE.md §3b): a decision
applied at the gate, a mid-build reality conflict written back into a doc, a spec revision. **Runs
in the same session that created the material** — a deferred delta audit is a skipped one.

Scope it to the delta, not the whole suite. Read the ledger's checkpoint log and the dated edits to
find exactly what changed, then run **only the phases the change touches**:

| What was added | Phases to run |
|---|---|
| A newly in-scope app | A (its "not affected" claim is now void — re-check the whole scope table), C for that app, D if it renders UI |
| A new design (a pattern, a store change, an algorithm) | C against that app's house rules, E adversarially — **a design that has never been attacked is the highest-risk thing in a suite** |
| A changed contract or response shape | A in full, plus B if the shape has lifecycle implications |
| A new consumer of existing data | A (parity), D (component coverage) |
| A behavior change the user asked for | E, plus whichever doc-specific phase owns it |

Two things a delta pass must do that a first pass doesn't:

1. **Re-examine what the change invalidated**, not just what it added. A decision that pulls an app
   into scope voids every "not affected" claim that leaned on it; a design that changes how data is
   read voids verification steps written for the old read path.
2. **Attack the new design specifically.** New material arrives with the confidence of a decision
   just made and no adversarial reading behind it. Ask: what does this design assume about ordering,
   about concurrency, about the empty case, about the second call? What existing code path does it
   silently change? Which in-repo exemplar does it claim to follow, and does that exemplar actually
   do what the doc says?

Record it as its own dated pass in 09's log, naming **what triggered it** ("delta — D3 pagination
design + X1 capture scope"). Findings go through the decisions gate exactly like a first pass, and
their consequences are themselves delta-audited — each round is strictly smaller, so this terminates,
but it is not cut short to reach the plan step.

## 09's shape

Header (status + dated pass log) → the G/D/O/C/X ledger tables → per-pass findings notes → the
verified-claims delta (what got marked verified / corrected each pass). Re-runs report only NEW
findings + newly-resolved rows.

## Exit handoff (standalone runs too)

End every run — complete, paused, or errored — with the standard handoff (`build-spec` §Step-end
handoff): what happened in plain language, next actions as copy/paste commands (clean audit → the
decisions gate or `/build-spec-plan <feature>`; findings → the specific suite edits owed), and
ALWAYS the two-line status block as the last thing in the response (REFERENCE.md §6):

```
📊 <feature> ~NN% ▓▓▓░░░░░░░ — audit: pass 2 clean, 3 decisions open
📍 Answer the decisions above → then run `/build-spec <feature>` and it applies them + re-audits
```
