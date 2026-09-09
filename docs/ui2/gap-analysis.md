# UI 2.0 Gap Analysis

**Purpose:** prove no current functionality is silently lost. Runs ONLY after every README
screen row is `specced` — until then this file is method + empty tables. The doc itself is
the cross-session state: work it area-by-area in fresh sessions, checking off sweep sections
as they complete. No skill drives this; a session picks up at the first unchecked section.

**Inputs:** each screen spec's §7 Legacy mapping (pre-fills most of sweeps 1–2 — this phase
is a *verification* pass, not a from-scratch audit), the current codebase, and the
`makeready-api` MCP for endpoint truth.

**Dispositions** (every row gets exactly one):

| Disposition | Meaning |
|---|---|
| `carried:<screen-id>` | functionality lives on that 2.0 screen (its spec §7 confirms) |
| `merged:<screen-id>` | absorbed into another surface (name where on the screen) |
| `dropped (D#)` | deliberately cut — requires a dated ruling in DECISIONS.md |
| `GAP-###` | unaccounted for — open finding |

Every `GAP-###` resolves to one of: a new screen row in the README (+ queue entry), an
amendment to an existing screen spec, or a `dropped (D#)` ruling. **The phase exits when
zero GAPs are open**; then every screen row flips `specced` → `gap-checked` and the Build
program table is filled (suite decomposition per README).

---

## Sweep 1 — Routes (~50 cases) `[ ] not started`

Enumerate every case of `iphone/MakeReady/Services/Route.swift` (menus, editors, pages,
group/org, member, confirmations — associated values included).

| Route case | Disposition | Notes |
|---|---|---|

## Sweep 2 — Pages (74 files) `[ ] not started`

Every file under `iphone/MakeReady/Pages/` (Manage/ 38 is the bulk risk — work it by
subdomain: Group, Member, Org, Program). Include the tab roots even though trivially carried.

| Page file | Disposition | Notes |
|---|---|---|

## Sweep 3 — Capabilities `[ ] not started`

Per area, every user-visible operation (create/edit/delete/reorder/publish/export/share/
invite/respond/notify/…), sourced from `State/Actions/` + the pages' affordances — because a
screen can be "carried" while an affordance on it is lost. One table per area: Home, Groups,
Library/Media, Calendar, Search, Programs/Lessons/Activities, Members, Org, Video, Bible,
Notifications, Profile.

| Area | Capability | Disposition | Notes |
|---|---|---|---|

## Sweep 4 — Endpoints `[ ] not started`

Every endpoint the iPhone app calls (grep the Actions/service layer; cross-check against the
`makeready-api` MCP). Each is either consumed by some 2.0 screen spec's §5 Data & API, or
dispositioned. Also list `API-GAP` markers accumulated in screen specs — each becomes a task
for the backend suite (`activities-model` or a successor).

| Endpoint | Called from | Disposition | Notes |
|---|---|---|---|

## Open GAP findings

| # | Found in sweep | Description | Resolution | Status |
|---|---|---|---|---|
