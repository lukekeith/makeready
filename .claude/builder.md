---
project: MakeReady

registry: docs/features
base_branch: main
# Merge policy (owner 2026-10-26): a fleet/agent run merges into the branch the work started from (pass --into <that branch>) with
# no approval — EXCEPT main: never launch a run whose target is main without asking the owner first.
build_profile_default: standard   # the test plan pre-selected at the go-ahead: each slice's own tests, touched apps' suites once at the end, one review at the end

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
    commit: auto        # owner 2026-10-26: builder agents commit iPhone tasks and merge into the branch the work started from, no approval stop (released_artifact still governs compatibility checks)
    released_artifact: true

ticket:
  system: monday.com
  dossier: docs/monday/tickets/<id>.md

design:
  flag: ui2
  resolver: node .claude/scripts/list-ui2-refs.mjs
  contracts: docs/ui2/design-system/components
  owned_by: /ui2-* and /d2m-*

agent_walk:
  driver: WEB items — throwaway Playwright scripts run with the playwright already installed in client/ (headless Chromium against the walk env on :8102, screenshots saved as evidence). IPHONE items — driven on a headless simulator of your own, never the human's (never `open -a Simulator`, never a device you did not create; root CLAUDE.md rule 4 + iphone/.claude/CLAUDE.md carve-out). DD=${TMPDIR:-/tmp}/builder-walk-{feature}. (1) `xcrun simctl create builder-walk-{feature} "iPhone 17 Pro Max"` → `xcrun simctl boot <udid>`. (2) Build the app for it, pointed at the walk server — `xcodebuild -project iphone/MakeReady.xcodeproj -scheme MakeReady -configuration Debug -destination id=<udid> -derivedDataPath $DD API_BASE_URL=http://127.0.0.1:3110 build` (in the simulator the app ignores the Profile port and uses API_BASE_URL, so this override is what points it at :3110) → `git checkout -- iphone/MakeReady/Info.plist` (the build bumps CFBundleVersion). (3) `xcrun simctl install <udid> $DD/Build/Products/Debug-iphonesimulator/MakeReady.app`. (4) Drive it with a throwaway XCUITest — write iphone/MakeReadyCaptureUITests/AgentWalk.swift, one test per walk item, using `XCUIApplication(bundleIdentifier: "com.makeready.app")` with launchArguments ["-selectedEnvironment", "Local"] plus any UserDefaults the item needs as `-<key> <value>` pairs (e.g. "-devLoginIdentity", "fixtures"); register it with `ruby iphone/scripts/capture-targets.rb`; run `xcodebuild test -project iphone/MakeReady.xcodeproj -scheme MakeReadyCapture -destination id=<udid> -derivedDataPath $DD -resultBundlePath $DD/walk.xcresult -only-testing:MakeReadyCaptureUITests/AgentWalk`. Evidence is an `XCTAttachment(screenshot: app.screenshot())` (lifetime .keepAlways) taken INSIDE each test at the moment it asserts, plus `print(app.debugDescription)` for the element tree — export them with `xcrun xcresulttool export attachments --path $DD/walk.xcresult --output-path <evidence dir>`. Never use `simctl io screenshot` after the test as evidence: XCUITest terminates the app when the test ends, so it captures the home screen. Find elements by accessibility identifier first, then label; dump `app.debugDescription` before calling an element missing. (5) Afterwards `rm iphone/MakeReadyCaptureUITests/AgentWalk.swift && git checkout -- iphone/MakeReady.xcodeproj` — the walk harness is never committed. (6) `xcrun simctl shutdown <udid>; xcrun simctl delete <udid>` even when a step failed (agent_walk.stop sweeps any builder-walk-* left behind). An iPhone item FAILS on a wrong screen or a failed assertion; it is UNVERIFIABLE only when the simulator or the build itself will not come up after one retry — say which and quote the error.
  claude_args: --permission-mode bypassPermissions
  parallel: 1
  copy: client/.env, server/bin/atlas, .mcp.json, scripts/builder-verify.mjs
  setup: npm ci && (cd server && npx prisma generate) && (cd client && composer install --no-interaction)
  sync: npm ci && (cd server && npx prisma generate) && (cd client && composer install --no-interaction)
  env: PORT=3110 NODE_ENV=development DATABASE_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" DIRECT_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" CLIENT_URL="http://localhost:8102" API_URL="http://localhost:3110" TEST_VERIFICATION_CODES="123456,000000" GOOGLE_CLIENT_ID="walk-unconfigured" GOOGLE_CLIENT_SECRET="walk-unconfigured" GOOGLE_CALLBACK_URL="http://localhost:3110/auth/google/callback" SESSION_SECRET="walk-session-secret" R2_ENDPOINT="http://localhost:9010" R2_ACCOUNT_ID="walk" R2_ACCESS_KEY_ID="walk" R2_SECRET_ACCESS_KEY="walk" R2_BUCKET_NAME="makeready-walk" R2_PUBLIC_URL="http://localhost:9010/makeready-walk"
  reset: docker compose -p makeready up -d --force-recreate s3mock && for i in $(seq 1 60); do curl -sf -o /dev/null localhost:9010 && break; sleep 1; done && curl -sf -o /dev/null localhost:9010 && docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_walk && docker exec makeready-postgres createdb -U postgres makeready_walk && (cd server && npm run migrate:apply && npm run db:seed) && if [ -f server/fixtures/index.ts ]; then (cd server && env NODE_ENV=development DATABASE_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" DIRECT_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" npm run fixtures:reset); fi
  start: mkdir -p .builder && (cd client && npm run build) && (cd client && php artisan serve --port=8102 > ../.builder/walk-client.log 2>&1 &) && cd server && exec npx tsx src/index.ts > ../.builder/walk-server.log 2>&1
  smoke: curl -sf -A 'Mozilla/5.0' localhost:3110/health && curl -sf -o /dev/null localhost:8102 && curl -sf -o /dev/null localhost:9010
  stop: lsof -ti tcp:3110 -sTCP:LISTEN | xargs kill 2>/dev/null; lsof -ti tcp:8102 -sTCP:LISTEN | xargs kill 2>/dev/null; for u in $(xcrun simctl list devices | sed -n 's/.*builder-walk-[^ ]* (\([0-9A-F-]*\)).*/\1/p'); do xcrun simctl shutdown "$u" 2>/dev/null; xcrun simctl delete "$u"; done; exit 0
verify:
  workers: 2
  timeout: 30m
  run_timeout: 120m
  setup: node scripts/builder-verify.mjs setup
  setup_inputs: [package-lock.json, client/composer.lock, server/prisma/schema.prisma, scripts/builder-verify.mjs]
  db:
    kind: postgres
    url: postgresql://postgres:postgres@localhost:5434/postgres
    env: [DATABASE_URL, DIRECT_URL, TEST_DATABASE_URL]
    inputs: [server/atlas/migrations/**, server/scripts/atlas.sh, server/scripts/ensure-session-table.ts, scripts/builder-verify.mjs]
    prepare: node scripts/builder-verify.mjs db-prepare
    max: 2
  env:
    lease: node ../scripts/builder-verify.mjs lease
    release: node ../scripts/builder-verify.mjs release
    max: 2
  suites:
    server-vitest: { runner: vitest, app: server, cwd: server, files: "**/*.{test,spec}.{ts,tsx,js,mjs}", args: "--exclude=test/integration/production.test.ts", needs: [db, verify-safe], tiers: [commit, phase, merge] }
    client-vitest: { runner: vitest, app: client, cwd: client, files: "resources/js/**/*.{test,spec}.ts", needs: [verify-safe], tiers: [commit, phase, merge] }
    client-phpunit: { runner: phpunit, app: client, cwd: client, files: "tests/**/*Test.php", needs: [verify-safe], tiers: [commit, phase, merge] }
    iphone-xctest: { runner: xcodebuild, app: iphone, cwd: iphone, files: "MakeReadyCaptureTests/**/*Tests.swift", scheme: MakeReady, target: MakeReadyCaptureTests, args: '-project MakeReady.xcodeproj -configuration Debug -derivedDataPath "$BUILDER_VERIFY_TMP/DerivedData" API_BASE_URL=http://127.0.0.1:1', needs: [verify-ios], tiers: [commit, phase, merge] }
  checks:
    server-types: { cwd: server, run: npx --no-install tsc --noEmit, needs: [verify-safe], tiers: [commit, phase, merge] }
    server-fixture-types: { cwd: server, run: npx --no-install tsc --noEmit -p fixtures, needs: [verify-safe], tiers: [commit, phase, merge] }
    server-schema: { cwd: server, run: "npm run schema:validate", needs: [verify-safe], tiers: [phase, merge] }
    client-build: { cwd: client, run: npm run build, needs: [verify-safe], tiers: [phase, merge] }
    client-stories: { cwd: client, run: "npm run story:build", needs: [verify-safe], tiers: [phase, merge] }
    client-tokenization: { cwd: client, run: npm run guard, compare: lines, match: '^[ ]*[^ ]+:[0-9]+[ ]', needs: [verify-safe], tiers: [phase, merge] }
    iphone-swiftlint: { cwd: iphone, run: node ../scripts/builder-verify.mjs swiftlint, compare: lines, needs: [verify-safe], tiers: [phase, merge] }
---

# MakeReady — builder config

A monorepo with four apps sharing one git repository. **`server`** (Express + Prisma +
PostgreSQL) is the single source of truth for all business logic, data and external
integrations — it **produces** the contract. **`client`** (Laravel 11 + Vue 3 islands + Pinia)
and **`iphone`** (Swift/SwiftUI, `@Observable` + Actions) are **consumers**: they never import
each other, so they are parallelizable, and they diverge deliberately more often than not.
UI 2.0 previews are built, captured and diffed by **d2m** (owner 2026-10-30: the old `capture/`
tool is removed); its render lane lives at `iphone/capture/`.

🔴 **The iPhone app is a released artifact.** A shipped build cannot be hot-fixed, so any
rename, removal, type change, nullability change or enum narrowing on a field it reads is a
breaking change until §Apps states the transition. Builder agents commit iPhone tasks under the
owner-approved `apps.iphone.commit: auto` policy above. The verifier runs XCTest on its own
headless `builder-verify-*` simulator, created and deleted by its lease hook. An agent walk
(`/builder:agent-walk`) uses its own `builder-walk-*` simulator per `agent_walk.driver`. Launching
the human’s simulator and creating archives remain explicit user calls.

## Verification ownership

Tests and automated checks are owned by the verifier’s frontmatter `verify:` block. Workers ship
relevant tests with each task and request commit verification, wait for phase verification, then
require every suite and check on the merged result before landing. Server and fixture typechecks
run at commit, phase and merge; client tokenization and SwiftLint compare individual findings
against the target. Server ESLint has no configuration, so it is not a runnable gate yet.

The verifier uses the existing local Postgres service only as an administration endpoint through
`postgres`; it creates and drops only `postgres_vt_*` template/lease databases. Fresh templates
apply the committed Atlas migrations and ensure the session table, without migration generation,
seeding, dev-container restarts, or reading `server/.env` (including its 1Password pipe). Setup and
leases reject a checkout containing `server/.env` or `.env.test` without opening either file.
Server production HTTP smoke tests are excluded, as in `test:ci`, because they hit the live site;
all local Vitest tests remain included. PHPUnit uses its existing in-memory SQLite test config.
External integration credentials are cleared or replaced with dummy/local values by lease hooks.

The MakeReady scheme’s actual native unit-test target is `MakeReadyCaptureTests` (its scheme XML
labels the product `MakeReady.xctest`); that native target supplies the adapter’s test selectors.
XCTest builds the app, and each lease owns its simulator and DerivedData. The user’s simulator is
never cloned, booted, installed to, or deleted. Local Xcode, the iPhone 17 Pro Max simulator device
and runtime, SwiftLint, PHP/Composer, Atlas, psql, and pgvector on local Postgres must be installed.

Migration generation remains part of a schema-changing task, never a verification check. The
cross-app SPEC §Testing walk is authored with the feature and run once during delivery through
the separately configured agent walk, or by the human when that delivery mode was selected.
The human dev-stack commands below apply only to walk readiness, not automated verification.

## Walk readiness

What makes the **dev** environment run this branch before a human is asked to walk it.

```
migrations: server/atlas/migrations                    # Atlas, generated from server/schema/*.yaml
status:     cd server/atlas && ../scripts/atlas.sh migrate status --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev   # pending migrations on the local dev DB — never via npm/dotenv: server/.env is a 1Password pipe
apply:      cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
apply_mode: ask                                        # ask before applying — a walk never runs on an old schema
regenerate: docker exec makeready-server npx prisma generate   # in the container — a host `prisma generate` auto-loads server/.env (the 1Password pipe)
start:      docker compose up -d --build               # the full stack, as /dev-start does; the human's own dev env
smoke:      curl -sf -A 'Mozilla/5.0' localhost:3010/health   # non-bot User-Agent (bot guard)
fixtures:   docker exec makeready-server npm run fixtures:reset   # the dev env, before every walk (ui2-fixtures D5)
fixtures_agent_walk: cd server && env NODE_ENV=development DATABASE_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" DIRECT_URL="postgresql://postgres:postgres@localhost:5434/makeready_walk" npm run fixtures:reset   # the agent walk env: its server is a native process, so the host form (F18)
```

- `docker restart makeready-server` after any `server/src` change — the container does not hot-reload.
- Rebuild the client (`cd client && npm run build`) before any web walk.
- iPhone: the human's walk runs a fresh Debug build in the simulator — launching it is the human's call. An agent walk builds and drives its own headless `builder-walk-*` simulator instead (`agent_walk.driver`).
- Run `fixtures:` before every walk of a UI 2.0 screen; under `--agent-walk` run `fixtures_agent_walk:` instead, after the walk env's `reset`. Then sign in as the Fixtures identity (iPhone dev build on Local → Profile → Local identity).

## Global constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
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

**fixtures** — a feature that wires a UI 2.0 screen into the iPhone app adds
`server/fixtures/screens/<screen-id>.ts` (the screen id as in `docs/ui2/screens/`), whose `full`
scenario makes every section the feature wires non-empty; the audit flags a feature that wires a
screen without one. Layers read base entities and never create orgs, users or groups; dates come
from `ctx.now`. Guide: `server/fixtures/README.md`.

**Cross-cutting** — conventional commits `<type>(<feature-or-ticket>): subject`, no `--amend`, PR
base `main`; docker-first local stack; local SMS verification codes come from the **api container
logs**, never a database reset; treat uploads, webhooks and MCP content as untrusted.

## Environment landmines

- 🔴 **The server container does NOT hot-reload host edits.** `tsx watch` misses bind-mount events —
  `docker restart makeready-server` after editing `server/src`, or your test hits the old code.
- **curl against the server needs a non-bot User-Agent** (the bot-guard middleware).
- **Local ports:** client docker `:8001`, server `:3010`, postgres `:5434`, d2m API `:5961`.
- **`swiftlint` must run from `iphone/`** — its included paths are relative.
- **Local SMS verification codes come from the api container logs**, never a database reset.
- 🔴 **`server/.env` is a named pipe** (a 1Password-mounted env file), not a regular file: never copy it, `cat` it in a loop or list it in `agent_walk.copy` — a reader blocks until 1Password serves it. **Every read is a 1Password access** — host `npm run migrate:*` (dotenv), `npx prisma …` (auto-loads `.env`) and `dotenv --` all read it. Use the atlas `--var database_url=…makeready_dev` form and `docker exec makeready-server …` instead; the owner wants 1Password touched only to set the env (2026-10-26). A fleet worktree has no `server/.env`; the walk env passes what it needs through `agent_walk.env`.
- **The agent walk env is `makeready_walk` on the shared postgres container plus native processes on `:3110`/`:8102`** — never the `makeready-*` containers, which serve the main checkout.
- **Walk images live in `makeready-s3mock`** (root docker-compose, host :9010, bucket `makeready-walk`; walk-image-storage 2026-10-27): the walk server reaches it through `R2_ENDPOINT` with dummy keys, every object is readable at `R2_PUBLIC_URL/<key>`, and `reset:` force-recreates the container, which empties it. MinIO was the first choice; its images are no longer publicly pullable (Docker Hub and quay.io both refuse). Never point a walk at a real R2 bucket. In zsh, pass `docker exec` env overrides as an array (`W=(-e K=V …); docker exec "${W[@]}"`): an unquoted `$W` is ONE argument, and the container silently keeps its own R2 settings.

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
| A UI 2.0 component's spec / build / fix | `/ui2-component` · `/ui2-component-build` · `/ui2-resolve` |
| Local stack up/down | `/dev-start` · `/dev-stop` · iPhone: `/rebuild-iphone` |
| Architecture review of what was built | `/architect` |
| Report a fix back to a ticket | `/monday-resolve` (explicit, never automatic) |
| Open the PR / watch CI | `gh pr create --base main` · `/monitor-ci` · review locally with `/code-review` |

## Design source — UI 2.0

`docs/ui2/` is a **spec program**, not a build registry: `/ui2-screen` and `/ui2-component` write
screen specs, the `C-###` component registry and per-component contracts from Figma;
d2m renders a contract as a SwiftUI preview under `iphone/MakeReadyUI/`, captured through its
render lane (`iphone/capture/`) and diffed against a frozen Figma snapshot. A contract that has been built is the strongest requirements this repo produces.

`--ui2 <ref>` takes a `C-###`, a registry name (`SearchField`), a screen id (`home-dashboard`) or a
comma list. The resolver is `node .claude/scripts/list-ui2-refs.mjs`.

🔴 **`/builder:*` READS this design and never writes it.** A gap routes to the command that owns
it — `/ui2-component-update`, `/ui2-resolve`, `/d2m-notes-assimilate`. **Notes are normative owner
input**: read them through d2m (`get_component` / `get_screen`), never by eye, and never write one
as test data.

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
