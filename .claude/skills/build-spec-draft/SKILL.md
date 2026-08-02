---
name: build-spec-draft
description: Write a buildable feature spec suite for the MakeReady monorepo through conversation — recon the existing patterns across server/client/iphone, settle which apps are affected and what the shared API contract is, ask clarifying questions one at a time until the design is settled, present it for approval, then write the numbered suite docs/features/<feature>/ (README + 01-architecture through 08-testing + seeded 09 ledger) per the pipeline's templates. The entry point of the /build-spec pipeline; the conversation ends when the suite is ready to audit. Use when the user wants to spec, design, or plan a new feature.
---

# /build-spec-draft <feature> — conversation → buildable spec suite

Output: the `docs/features/<feature>/` suite — `README.md` + `01-architecture.md` …
`08-testing.md` + a seeded `09-gaps-and-decisions.md` — per
[`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md) §1. Feature name is kebab-case; derive
one from the idea and confirm if the user didn't give one. If a suite already exists, this is a
revision conversation — read it first and say what exists.

This is a DIALOGUE, not a form. The spec is done when the user says it is — not when every section
has words in it. **The one thing you may not leave vague is the app-impact table and the API
contract** — every later step depends on them.

## Phase 1 — Recon (before any questions)

Read the root `.claude/CLAUDE.md` §Cross-App Impact Guide, then the per-app `CLAUDE.md` for each
app the idea plausibly touches. Identify which existing feature is the closest structural baseline
in each app and spawn parallel Explore agents (`sonnet` for enumeration, `opus` where judgment is
needed) to map:

- **server** — the closest route module + service pair, its RBAC checks, the Prisma models and the
  `server/schema/` YAML that generates them, existing endpoints that already return part of what
  this feature needs;
- **client** — the closest page/island/store trio, the `/admin/api` proxy entries, which design-
  system components exist for the views this feature needs;
- **iphone** — the closest Page + Actions + AppState entities, the `Route` cases and chrome used
  by comparable surfaces, whether the data belongs in an `EntityStore`;
- **capture** — whether a comparable screen already has a `/compare` twin + fixture.

Also check the memory index for a relevant memory (parity specs, twin traps, known server bugs)
and read the ones that match. Fold everything into working notes — the spec cites these by
`file:line`.

## Phase 2 — Clarify (one question at a time)

Ask via **AskUserQuestion** — ONE question per message, multiple-choice preferred, your
recommendation first and marked (Recommended). Work the fundamentals before the surface:

1. **Which apps.** Web only? iPhone only? Both consumers? This single answer reshapes everything
   downstream — ask it early, and sanity-check the answer against the Cross-App Impact Guide (a
   schema change almost never touches only one consumer).
2. **Data model shape** — new Prisma model vs extension; relationships; org scoping; what's
   sensitive.
3. **The contested architecture** — every feature has one or two genuinely contested choices
   (where the state lives, whether it's push-driven, sync vs poll, one endpoint vs several).
   Present 2–3 approaches WITH schema/contract previews and trade-offs.
4. **The contract** — one endpoint serving both consumers, or different shapes? (Same shape is the
   default; divergence must be argued.) Pagination, filtering, and the offline/disk-cache
   implications for iPhone.
5. **Lifecycle & policy edges** — the questions the gap audit would otherwise catch: deletes and
   cascades, idempotence/double-submit, permission tiers (Owner / Admin / Group Leader / Member),
   what happens to enrolled members mid-change, timezone traps on dates.
6. **UX placement per consumer** — navigation home, modal vs page vs inline, and how each state
   (loading/empty/error) is shown, per app. Where the two consumers legitimately differ, say so
   explicitly.
7. **Backward compatibility** — will iPhone builds already in the field keep working?

Don't ask what recon already answered or what has one defensible answer — decide those and record
them in the Decisions table. Stop asking when new answers stop changing the design.

## Phase 3 — Present the design (sections, then approval)

Present the full design in spec-section order (apps affected → data model → contract → server →
client → iPhone → capture → testing → out-of-scope), each section scaled to its complexity, and
ask for approval, inviting per-section pushback. Revise until approved. YAGNI ruthlessly:
everything cut goes in **Out of scope (deliberate)** so the cut is visible and intentional.

## Phase 4 — Write the suite

Write the numbered docs per the REFERENCE templates, one doc at a time (each write is a
checkpoint — create the ledger FIRST, then update its *In flight* row between docs):

- **README.md** — status line (`drafting` → `spec complete`), Pipeline status snapshot (spec 🔄,
  everything else ⬜), doc index, governing rules, the resume instruction.
- **01-architecture** — overview, the **Decisions table** (every Phase-2/3 answer, including the
  ones you decided silently), baseline patterns by `file:line`, RBAC summary, out-of-scope.
- **02-app-impact** — REFERENCE.md §2's template, filled: the scope table (with a stated reason
  for every ⬜), the contract producer/consumer table, the sequencing plan, backward compatibility,
  blast radius.
- **03-data-and-api** — the schema changes (YAML → Prisma → Atlas migration list) and the endpoint
  table every consumer codes against: method, path, auth/role, request body, response fields,
  error codes. **This is the contract** — write it as if a second team were implementing the
  consumer from it alone.
- **04-server / 05-client / 06-iphone / 07-capture** — per their REFERENCE rows. An app that isn't
  affected still gets its file with `**Not affected** — <why>`.
- **05/06 component coverage**: every element of every view maps to a named existing component
  (verify it exists NOW — a quick inventory pass) or a **(new)** row with a proposed contract.
  Spec approval = approval to build those new components — say so explicitly to the user.
- **08-testing** — per-app test lists, the gate list the phase docs draw from (REFERENCE.md §7),
  the cross-app E2E walk, and the **human-verification script** (what the user will be asked to
  tap at sign-off).
- **09-gaps-and-decisions** — seeded: empty G/D/O/C/X tables + any decision the conversation left
  genuinely open (as `D#` rows) and any cross-app risk you already smell (as `X#` rows).

Then self-review with fresh eyes — placeholder scan, internal consistency (does 06 consume fields
03 actually returns?), scope check (decompose into multiple feature suites if it's really several
features), ambiguity check — fix inline. Offer a commit (`docs(<feature>): add feature spec
suite`); don't force it.

## Phase 5 — Hand off

Ask the user to review the written spec. When they're satisfied, the conversation is over:

```
/build-spec <feature>          ← audit the spec against all four codebases (next step)
```

Note that the audit re-verifies every claim — the suite doesn't need to be perfect, it needs to be
complete enough to audit.

## The status block — every turn of this conversation, not just the end

A spec conversation is long and it is easy to lose the sense of how far along it is. **End every
response — every clarifying question, every design section, every doc written — with the two-line
status block** (REFERENCE.md §6):

```
📊 <feature> ~4% ░░░░░░░░░░ — spec: design approved, 3 of 10 docs written
📍 Run `/build-spec-draft <feature>` → keeps writing the suite (04-server next)
```

Once the suite is complete, line 2 switches to the orchestrator, which takes it from there:

```
📍 Run `/build-spec <feature>` → runs the INTEGRITY CHECK, then the audit
```

The spec step is worth 10 points of the whole pipeline, sub-divided so the number moves as the
conversation progresses (REFERENCE.md §6 §Spec credit while drafting): recon 1 · design approved 3
· each suite file written 0.6. During Phase 2 the honest reading is low single digits — say what
the remainder is ("the build is most of the work") so a small number doesn't read as no progress.
Update the ledger as each doc lands so a cold session recomputes the same figure.

## Exit handoff (every pause too)

Same shape as the pipeline's (`build-spec` §Step-end handoff). An in-progress spec conversation is
resumable: the suite drafts ARE the working notes — a README with `Status: drafting` + partial
01–08 beats a lost conversation. Create the ledger before the first doc, keep its *In flight* row
current, and always close with the status block. Re-entry is `/build-spec-draft <feature>` while
the spec is still being written; `/build-spec <feature>` once the suite exists.
