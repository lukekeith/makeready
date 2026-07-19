---
name: monday-review
description: Review open monday.com tickets against the MakeReady codebase to determine which are already fixed and which are outstanding. Produces an evidence-backed verdict table; verifiably-fixed tickets can then be moved to Done (with an evidence comment) after user confirmation. Use when asked to review/triage monday tickets, check which reported bugs are fixed, or close out completed tickets.
---

# Monday.com Ticket Review

You are reviewing open monday.com tickets for the MakeReady project (web client + iPhone app) and determining, with evidence, which are already fixed in the codebase. The bar for "fixed" is high: a verdict of VERIFIED FIXED requires identifying the concrete commit(s) that address the ticket AND confirming the change is present on current `main`. Never close a ticket on vibes.

This is stage 1 of the pipeline in `docs/monday/PIPELINE.md` (review → `/monday-ticket` deep dive → `/monday-resolve`). Read that contract, and read the per-ticket dossiers in `docs/monday/tickets/` before investigating — prior verdicts, root causes, and affected-area mappings are already recorded there; refresh them rather than rediscovering from scratch.

## 1 — Authentication

Prefer monday MCP tools if they're available in the session. Otherwise use the GraphQL API directly. The token lives in the monday MCP server config:

```bash
TOKEN=$(jq -r '.. | objects | select(has("MONDAY_TOKEN")) | .MONDAY_TOKEN' ~/.claude.json | head -1)
```

NEVER print or log the token. Verify auth with a `{ me { name } }` query before proceeding. If no token is found, ask the user for one (env var `MONDAY_TOKEN` also acceptable).

## 2 — Fetch open tickets

Default board: **Ongoing Tasks Tracking** (`18413909869`), status column `color_mm3gbyzr` (labels: Not Started / In Progress / Blocked / Done). If the user names a different board, discover it via `{ boards(limit: 50) { id name items_count } }` and find its status column via `columns { id title type settings_str }`.

"Open" = any item whose status is NOT "Done" (including empty/unset status).

```bash
curl -s -X POST https://api.monday.com/v2 \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"{ boards(ids: [18413909869]) { items_page(limit: 100) { items { id name created_at column_values { id text } updates { body created_at creator { name } } } } } }"}'
```

Collect for each ticket: id, name, created_at, current status, priority, and all updates/comments (they often contain reproduction details or screenshots context that sharpen the search).

## 3 — Investigate each ticket against the codebase

For each open ticket, gather evidence from BOTH apps (tickets rarely say which platform — check `client/` (Laravel+Vue web) and `iphone/` (SwiftUI) unless the ticket clearly indicates one):

1. **Git history**: `git log --oneline --since=<ticket created_at minus 30 days>` plus keyword searches (`git log --all -i --grep="<keywords>"`, `git log -S"<symbol>"`). A fix commit may predate the ticket slightly (user reported a stale build) — use dates as signal, not proof.
2. **Release notes**: check `docs/progress/` (the progress-archive skill writes per-archive release notes there) for mentions of the reported issue.
3. **Code inspection**: read the current code path the ticket describes and judge whether the reported behavior can still occur. The fix must be observable in the code as it exists NOW on main (not reverted, not behind a dead flag).
4. Spawn parallel Explore/general-purpose agents when there are many tickets — group them by theme (e.g., lesson-player UI, navigation, auth) and give each agent the ticket text + updates verbatim.

## 4 — Classification rubric

| Verdict | Bar | Action eligible |
|---|---|---|
| **VERIFIED FIXED** | Concrete commit(s) identified + change confirmed present on main + change directly addresses the reported behavior | ✅ May move to Done after user confirmation |
| **LIKELY FIXED** | Strong evidence (related commit/code) but can't confirm the exact reported behavior is resolved without running the app | ❌ Report only; suggest a manual check |
| **OUTSTANDING** | No fix found; reported behavior still possible in current code | ❌ Report; optionally note where the fix would go |
| **NEEDS CLARIFICATION** | Ticket too vague to map to code (UX opinions, "I don't know what to do next"-type feedback) | ❌ Report; suggest a clarifying question to post on the ticket |

## 5 — Report and persist to the local store

Output a table: Ticket | Platform | Verdict | Evidence (commit hash + file:line or doc ref) | Recommended action. Lead with counts (X verified fixed, Y outstanding, ...). Be honest about uncertainty — a wrong "Done" erodes trust in the whole board.

Then persist (per `docs/monday/PIPELINE.md`):

1. **Dated triage file** — write the full per-ticket verdict report to `docs/monday/triage-<today>.md` and add/refresh its line in `docs/monday/README.md`'s doc table.
2. **Dossier sync** — for every reviewed ticket with a dossier in `docs/monday/tickets/`, update frontmatter `verdict` + `last_review` and append a Triage history line (`<date> /monday-review: <verdict> — <one-line evidence>`). Do NOT touch `affected_areas` on existing dossiers (only `/monday-ticket` may set `confirmed`; downgrading is a deep-dive decision).
3. **New-ticket stubs** — for open tickets with no dossier, create one from `docs/monday/tickets/TEMPLATE.md`: frontmatter + verbatim reports + your verdict; `affected_areas: none` (or `provisional` if your investigation credibly pinned files — cite them in Affected areas with the provisional banner), `deep_dive: none`. The stub must be honest about what review did NOT do: screenshots not viewed.

## 6 — Move verified tickets to Done (confirmation-gated)

This is an outward-facing mutation: **list the VERIFIED FIXED tickets and get explicit user confirmation before mutating** (the user may also pre-authorize with `--apply`). Then, for each confirmed ticket:

1. Set status to Done:
```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation { change_simple_column_value(board_id: 18413909869, item_id: ITEM_ID, column_id: \"color_mm3gbyzr\", value: \"Done\") { id } }"}'
```
2. Post an evidence comment so the closure is auditable:
```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation { create_update(item_id: ITEM_ID, body: \"Verified fixed in <short-hash> — <one-line summary of the fix>. Closed by automated review.\") { id } }"}'
```
3. Move the item to the board's completed group — setting the Status column does NOT move items between groups, so Done items otherwise linger under "In Progress"/"Backlog". On the default board the group is `group_mm3g94qf` ("Completed"); on other boards discover it via `{ boards(ids: [ID]) { groups { id title } } }` and match a title like Completed/Done:
```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation { move_item_to_group(item_id: ITEM_ID, group_id: \"group_mm3g94qf\") { id } }"}'
```
4. Sweep for strays: query all items' status + group, and move ANY item with status Done into the completed group (the user may have marked items Done manually).
5. Confirm each mutation succeeded (response contains the id) and report the final tally.
6. For each closed ticket, update its dossier in `docs/monday/tickets/`: frontmatter `status: closed` and a Triage history line recording the closure + evidence commit.

Never mutate tickets classified below VERIFIED FIXED (group moves of already-Done items are exempt — they're housekeeping, not closures), and never delete or archive anything.
