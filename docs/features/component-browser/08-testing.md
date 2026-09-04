# 08 — Testing

Capture has no test runner today; this feature introduces a minimal `node --test` suite for
the pure backend logic (no framework additions beyond `npm test` wiring in `capture/package.json`).

## 1. Automated tests (capture)

| Test file | Covers |
|---|---|
| `capture/test/fs-index.test.mjs` **(new)** | Index build against a temp fixture tree: folders/leaves; wiring joins (fixture/adapter/registry each toggled) **including the kebab-case join (a `CardStudy.swift` ↔ `card-study.json` pair — CR1) and a comparison with no Swift file (excluded from the tree)**; basename collision flagging (D17); helper files appear not-capturable (D18). |
| `capture/test/scope.test.mjs` **(new)** | D6 grammar: `A/B/Name` exact · `A/**` recursive · bare `A` ≡ `A/**` · `**` all · unknown path → error; bare unique component name resolves, ambiguous name → error listing paths (G3); unwired components included with null comparisonId. |
| `capture/test/fixture-write.test.mjs` **(new)** | 03 §2.4: variant-targeted `shared` replacement, implicit-`default` fixture, formatting round-trip, 404/409/400 error paths (unit-level against the write helper). |
| `capture/test/versions.test.mjs` **(new)** | DB-1/DB-1b/DB-3 against the dev DB using synthetic rows under comparison id `__test-component-browser`, created directly via `db/index.mjs` and deleted in teardown — NO capture runs (D19): finalize keeps both Version rows; non-captured platform's shot is COPY-forwarded (old version keeps its row); `versionShots` fallback respects the capturedAt bound; `listVersions` optional filter leaves the single-arg shape unchanged; `addComment` with an old version's screenshotId anchors versionId to that version (DB-2). |

Run: `cd capture && npm test`.

## 2. Gate list (the build phase runs these fresh)

```
cd capture && npm test                                  # the suite above
curl -s localhost:5951/api/components/tree | jq '.tree | length'      # index serves
curl -s "localhost:5951/api/components/scope?scope=Card/**" | jq .totals
curl -s localhost:5950/api/compare/manifest >/dev/null  # /compare regression: manifest still serves
node capture/runners/compare/capture.mjs CardEvent pro-max iphone     # one real capture still lands
```
Plus, because the command edits Swift at runtime, the command file itself must instruct
`npm run ios:build-check` before recapture (07 §6) — verified by reading the shipped command.

## 3. E2E walk (live, against the running stack)

1. `/capture-start` (UI :5950, API :5951). Open `http://localhost:5950/components`.
2. Tree shows the 15 folders; filter `cardev` → `Card/CardEvent` remains; an unwired
   component (e.g. one of the 26) shows the gray badge; selecting it shows the wiring
   checklist with a copyable `/capture-add` command.
3. Select `Card/CardEvent` → variants listed; select one → render appears in ZoomPane;
   wheel-zoom + drag-pan + `0`-fit work.
4. Recapture → docked log streams; on done a NEW timeline entry appears and the old one
   remains (D4). Select the old version → its render + a "current version" chip elsewhere.
5. Comment on the old version and another on the current one; both appear grouped in the
   Comments tab (old one labeled with capture date).
6. Data tab: change a visible string (e.g. `title`) → Save & Recapture → new version renders
   the edited value; `git diff capture/fixtures/compare/cards/CardEvent.json` shows the edit.
7. Copy the command from the tree row (`/component-resolve Card/CardEvent`) and from the
   folder row (`/component-resolve Card/**`); run the single-component one in Claude Code:
   both comments are addressed (Swift edit or reply), replies + resolutions appear in the UI,
   and a fresh version lands after the batch recapture.
8. `/compare` regression: open an existing comparison, recapture a variant — history retained,
   both-platform shots still pair on the newest version, comments still pin.

## 4. Human-verification script (sign-off)

You (Luke) on `http://localhost:5950/components`, newest surfaces first:
- Drill Card → CardEvent → each variant; zoom/pan; flip between two versions.
- Leave one comment on an old render and one on the current; edit fixture data and
  Save & Recapture; confirm the render changed.
- Copy `/component-resolve Card/CardEvent`, run it in Claude, watch it resolve your comments
  and produce a new render; then try a folder scope `Card/**`.
- Spot-check `/compare` still behaves (pick any comparison you know).
Local facts: capture stack via `/capture-start`; iPhone captures take minutes (xcodebuild);
fixture edits are visible in git.

## 5. Requirement traceability

| R# | Proven by |
|---|---|
| R1 | E2E 2–3 (drill-down + deep link); human script bullet 1 |
| R2 | fs-index tests; E2E 2 (tree + filter) |
| R3 | scope/variant fallback in `lib.mjs` (existing) + E2E 3; VariantList default state (07 §3.2) |
| R4 | E2E 3 (zoom/pan/fit) |
| R5 | fixture-write tests; E2E 6 (edit → recapture → changed render, git-visible) |
| R6 | E2E 5 + 7 (same comment models/routes/MCP; reply/resolve round-trip) |
| R7 | E2E 7 (copy → run → resolved + new render); command gate note (§2) |
| R8 | versions tests (DB-1/DB-3); E2E 4–5 (history retained, old-version comments included in command run) |
| R9 | scope tests (grammar); E2E 7 (folder scope) |
| R10 | Reading the shipped command file: invocation = scope only (checked in build phase verification) |
