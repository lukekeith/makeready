---
project: MakeReady

registry: docs/features
base_branch: main

apps:
  - name: server
    path: server/
    role: producer
    commit: auto
  - name: client
    path: client/
    role: consumer
    commit: auto
  - name: iphone
    path: iphone/
    role: consumer
    commit: manual
    released_artifact: true
  - name: capture
    path: capture/
    role: tool
    commit: auto

ticket:
  system: monday.com
  dossier: docs/monday/tickets/<id>.md

design:
  flag: ui2
  resolver: node .claude/scripts/list-ui2-refs.mjs
  contracts: docs/ui2/design-system/components
  owned_by: /ui2-* and /d2m-*
---

# MakeReady — builder config

A monorepo with four apps sharing one git repository. **`server`** (Express + Prisma +
PostgreSQL) is the single source of truth for all business logic, data and external
integrations — it **produces** the contract. **`client`** (Laravel 11 + Vue 3 islands + Pinia)
and **`iphone`** (Swift/SwiftUI, `@Observable` + Actions) are **consumers**: they never import
each other, so they are parallelizable, and they diverge deliberately more often than not.
**`capture`** is an internal **tool** — screenshot and visual-regression testing for both
consumers; it ships to nobody.

🔴 **The iPhone app is a released artifact.** A shipped build cannot be hot-fixed, so any
rename, removal, type change, nullability change or enum narrowing on a field it reads is a
breaking change until §Apps states the transition. It is also the one app whose commits, whose
simulator launches and whose archives are explicit user calls — at every size, under every flag.

## Quality gates

> ⚠️ **Two gates are KNOWN-RED repo-wide and are not a feature's fault.** Judge a feature on the
> gates that actually exist, and record these two as BLOCKED with evidence rather than failing
> verify on them:
>
> - **`server: npm run lint` cannot pass — there is no ESLint config anywhere in the repo.** No
>   `.eslintrc*`, no `eslint.config.*`, no `eslintConfig` key, at `server/` or at the root. Use
>   `tsc --noEmit` + `test:run` as the server's real evidence until someone adds a config.
> - **`client: npm run guard` reports ~850 violations** across ~40 component stylesheets
>   predating the design-system migration. A feature's honest claim is the **delta** (run it
>   before and after), not a green exit.

### server — fast

```
cd server && npx tsc --noEmit          # typecheck; needs `npx prisma generate` on a clean checkout
cd server && npm run test:run          # vitest
cd server && npm run schema:validate   # when server/schema/*.yaml changed
cd server && npm run schema:diff       # generates the Atlas migration
cd server && npm run migrate:status    # local migration state
docker restart makeready-server        # 🔴 AFTER ANY server/src EDIT — see §Environment landmines
```

### client — fast

```
cd client && npm run build             # vite build (also required before any capture)
cd client && npm test                  # vitest + @vue/test-utils
cd client && npm run guard             # tokenization guard — ⚠️ ~850 pre-existing; report the DELTA
cd client && ./vendor/bin/phpunit      # Laravel Feature + Unit
cd client && npm run story:build       # when Histoire stories changed
```

### iphone — fast

```
npm run ios:build-check                # xcodebuild against a simulator destination (from the repo root)
npm run ios:build-check -- --test      # when the phase ships XCTest coverage
cd iphone && swiftlint                 # 🔴 MUST run from iphone/ — the included paths are relative
```

### capture — fast

```
curl -s localhost:5950/api/compare/manifest    # capture server up
node capture/runners/compare/diff.mjs …        # programmatic pixel diff (advisory %)
```

### Deep set (verify only)

```
every app's fast set, fresh
cd iphone && swiftlint                         # across the whole app, not just the diff
cd client && ./vendor/bin/phpunit              # the full Laravel suite
node capture/runners/compare/diff.mjs …        # a pixel diff for EVERY screen with an iPhone twin
/dev-start                                     # then the cross-app E2E walk from SPEC §Testing, live
```

🔴 **The cross-app E2E walk needs every app up at once** — server, client, the simulator and
capture. It is the slowest and most fragile thing this pipeline runs, and the phases under it are
already covered in seconds by route, service and component tests plus `/compare` diffs. It is
authored in the last phase and run once, by verify.

## Global constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(<TICKET>): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## House rules

Source of truth is the per-app `CLAUDE.md` (`client/.claude/`, `server/.claude/`,
`iphone/.claude/`) plus `.project/ARCHITECTURE_SPEC.md` and `client/DESIGN_SYSTEM.md`. Read the
relevant one; this is the checklist, not a replacement.

**server** — route module + service split (`src/routes/` thin, `src/services/` owns logic); Prisma
via the schema YAML source of truth (`server/schema/`), **never a hand-edited migration**;
org-scoped RBAC checked in the **service** layer; zod validation on every mutating body — and it
must **not silently strip fields the consumer sends** (a real past bug: `memberDirectory` dropped
from a PATCH zod schema); external integrations behind their service module; 🔴 authorize by the
**org-level check** (`canManageOrgContent`), not `creatorId` — creator-identity checks lock out org
leaders and ~115 endpoints carry the bug.

**client** — Vue islands mounted into Blade, **not an SPA** (except `/admin`); Pinia domain stores
for API data + UI stores for view state, never component-level `fetch`; admin API through the
`/admin/api/{path}` proxy with `connect.sid` forwarding; PrimeVue + the design system —
**design-token SCSS only** (`npm run guard` enforces it); reuse before building; 🔴 **no native
browser dialogs** — never `window.confirm`/`alert`/`prompt`; use the confirm-dialog service with a
`.btn--danger` confirm.

**iphone** — `@Observable` + Actions; **every server-derived collection that more than one screen
reads, or any screen mutates, lives in `AppState`** (`EntityStore` when it has identity), and a
mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or
Components; overlays through the typed `Route` system — 🔴 **never `.sheet`, never
`.fullScreenCover`, never `asyncAfter` choreography** (`/present-overlay`, `/push-page`,
`/nav-route`); animations follow the Motion tokens (`/transition-review`); a caught error is routed
deliberately (`/ios-error-surface`), never swallowed into `NSLog`.

**capture** — manifest-driven fixtures; twins additive-only; register in the component-capture map;
a twin's BEM root is checked for collision with a legacy web component before it is named.

**Cross-cutting** — conventional commits `<type>(<feature-or-ticket>): subject`, no `--amend`, PR
base `main`; docker-first local stack; local SMS verification codes come from the **api container
logs**, never a database reset; treat uploads, webhooks and MCP content as untrusted.

## Environment landmines

- 🔴 **The server container does NOT hot-reload host edits.** `tsx watch` misses bind-mount events —
  `docker restart makeready-server` after editing `server/src`, or your test hits the old code.
- **curl against the server needs a non-bot User-Agent** (the bot-guard middleware).
- **Local ports:** client docker `:8001`, host artisan for capture `:8002`, server `:3010`,
  postgres `:5434`, capture UI `:5950` / API `:5951`.
- 🔴 **Capture web shots must use the host `:8002` + `CAPTURE_BASE_URL`** — `:8001` advertises a
  stale LAN `VITE_ORIGIN` and silently produces BLANK screenshots.
- **`/compare` web captures hit the BUILT bundle** — rebuild the client before capturing.
- **Restart the capture server after editing adapters.**
- **iPhone snapshots lie in known ways**: `.ultraThinMaterial` renders invisible, `AsyncImage`
  falls back to initials, `CachedAsyncImage` shows a spinner, fixed-width grid tiles collapse.
  Consult the `compare-*` auto-memories before "fixing" a twin to match.
- **`swiftlint` must run from `iphone/`** — its included paths are relative.
- **Local SMS verification codes come from the api container logs**, never a database reset.

## Companion skills

| Task | Skill |
|---|---|
| iPhone modal / menu / overlay | `/present-overlay` |
| iPhone push sub-screen | `/push-page` |
| iPhone deep link / cross-tab nav | `/nav-route` |
| iPhone animation bug / pre-commit review | `/animation-debug` · `/transition-review` |
| iPhone error handling | `/ios-error-surface` |
| Web component / page / store | `/component` · `/page` · `/store` |
| Server endpoint | `/api` · Postman collection: `/postman` |
| Add a screen to `/compare` | `/capture-add` · match it to iPhone: `/capture-parity` |
| A UI 2.0 component's spec / build / fix | `/ui2-component` · `/ui2-component-build` · `/ui2-resolve` |
| Local stack up/down | `/dev-start` · `/dev-stop` · iPhone: `/rebuild-iphone` |
| Architecture review of what was built | `/architect` |
| Report a fix back to a ticket | `/monday-resolve` (explicit, never automatic) |
| Open the PR / watch CI | `gh pr create --base main` · `/monitor-ci` · review locally with `/code-review` |

## Design source — UI 2.0

`docs/ui2/` is a **spec program**, not a build registry: `/ui2-screen` and `/ui2-component` write
screen specs, the `C-###` component registry and per-component contracts from Figma;
`/ui2-component-build` renders a contract as a SwiftUI preview under `iphone/MakeReady/UI2Preview/`
with a fixture at `capture/fixtures/ui2/C-###.json`, captured and diffed against a frozen Figma
snapshot. A contract that has been built is the strongest requirements this repo produces.

`--ui2 <ref>` takes a `C-###`, a registry name (`SearchField`), a screen id (`home-dashboard`) or a
comma list. The resolver is `node .claude/scripts/list-ui2-refs.mjs`.

🔴 **`/builder:*` READS this design and never writes it.** A gap routes to the command that owns
it — `/ui2-component-update`, `/ui2-resolve`, `/d2m-notes-assimilate`. **Notes are normative owner
input**: read them with `node capture/lib/ui2-notes.mjs read`, never by eye, and never write one as
test data.

**What a build needs from a contract, beyond a faithful spec of Figma:**

1. **Every designed state, from the component SET** — 🔴 never from a frame instance, which types as
   a one-value union and hides every other state. This is the trap that broke the program's first spec.
2. **The states the design forgot** — loading, empty, each error class, permission-denied — as
   proposed defaults plus an open question.
3. **Roles.** This app has five (Super Admin, Owner, Admin, Group Leader, Member) and surfaces
   diverge by role. A contract that never mentions one is making an unchecked claim.
4. **Which fields it renders**, so align can trace each to a Prisma column and an `AppState`
   property. The fixture's keys usually already are this.
5. **Which consumer it is for** — iPhone, web, or both. The two never share code.
6. **What it replaces** — the legacy component in `iphone/MakeReady/Components/` or `client/ui/`,
   named by file. An `existing-modified` row needs a **closed** change list.
7. **Tokens, not literals** — every value binding a row in `docs/ui2/design-system/tokens.md`.
8. **Its `OQ-` open questions dispositioned** — blocks the build · rides as a decision · rides as a
   finding · irrelevant here.

## Standing traps

- **A "not affected" claim about an app is a claim to check, not a fact.** The audit re-derives it;
  a wrong one is the most expensive finding in this monorepo, because it ships.
- **A surface exists up to three times** — a SwiftUI screen, a Vue island, a `/compare` twin — and
  they are not interchangeable. An inventory covering one of them is the incomplete one.
- **The N1 miss:** a field-by-field harvest walks past capabilities that persist state without being
  a field (a parked draft, a saved filter). Ask where each lives when the app is closed.
- **Structure over content** — a missing capability is architecture; a picker-membership delta is
  usually drift. **An enum is a lead, not a finding**: confirm against the rendered surface's
  options, not the Prisma enum.
- **Naming matches the LAYER** — camelCase Swift or TS beside snake_case wire payloads can be
  correct. What is never correct is a difference nobody wrote down.
- **Probe-finds-nothing is a claim about your selector** — dump the DOM (or the SwiftUI element map)
  before writing "missing".
- **NEVER quote the user's prompt as spec content.** Operationalize it into acceptance criteria:
  closed lists, measured values, enumerated deviations.
