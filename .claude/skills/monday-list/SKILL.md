---
name: monday-list
description: List all open monday.com tickets merged with their local dossier state (docs/monday/tickets/). Deep-dived tickets (screenshots + comments fully evaluated via /monday-ticket) show rich context — verdict, affected areas, root cause, readiness for /monday-resolve; the rest show the deep-dive queue in order, marking which ticket /monday-ticket will pick next. Flags dossiers gone stale (new monday comments since the last evaluation). Read-only. Use when asked to list/show open tickets, see ticket status, or check what's next in the pipeline.
---

# Monday.com Ticket List

A read-only status board merging live monday state with the local dossier store. The pipeline contract is `docs/monday/PIPELINE.md` — this skill implements its "deep-dive queue" ordering. No mutations to monday, no codebase investigation, no dossier writes: this is a fast lookup, not an analysis.

## 1 — Fetch live board state

Auth (never print the token):
```bash
TOKEN=$(jq -r '.. | objects | select(has("MONDAY_TOKEN")) | .MONDAY_TOKEN' ~/.claude.json | head -1)
```

Default board `18413909869` (status column `color_mm3gbyzr`). Fetch all items with status, priority, and update timestamps:

```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"{ boards(ids: [18413909869]) { items_page(limit: 100) { items { id name created_at group { title } column_values { id text } updates { created_at creator { name } } } } } }"}'
```

Open = status ≠ "Done". Note each item's most-recent update timestamp — it drives staleness detection.

## 2 — Load dossier state

Read frontmatter from every `docs/monday/tickets/<id>.md` (skip TEMPLATE.md): `status`, `verdict`, `last_review`, `deep_dive`, `affected_areas`, `type`, `app`, `nature`. For tickets with `deep_dive` set, also pull from the body: the Problem statement, the In scope lines of Affected areas, the Root cause line, and the latest Resolution log entry if any.

Cross-check for drift both ways:
- **Stale dossier**: monday has updates newer than `deep_dive` (or newer than `last_review` for non-dived tickets) → the evaluation predates new information.
- **State mismatch**: dossier says `closed` but monday isn't Done (or vice versa) → flag for reconciliation.

## 3 — Output

Lead with counts: total open · deep-dived (ready) · awaiting deep dive · stale · unreviewed.

### Section A — Deep-dived (evaluated via /monday-ticket)

These have had screenshots + comments fully evaluated, so show the rich context. One block per ticket:

```
**<title>** (<id>) — <verdict> · dossier status: <status> · dived <deep_dive>
  Type/App/Nature: <type> · <app> · <nature>
  Problem: <one-line problem statement>
  Areas: <platform> — <in-scope screens/files, compressed to one line>
  Root cause: <one-liner, or "n/a">
  Ready: /monday-resolve <id> "<...>"        ← only when affected_areas: confirmed and status is open/in-progress
  ⚠ STALE: <n> monday update(s) since the dive — re-run /monday-ticket <id>   ← when applicable
```

### Section B — Awaiting deep dive (queue order)

Ordered by the PIPELINE.md queue rule: never-dived before stale-dived; within a bucket, board Priority (High → Medium → Low → unset), then oldest `created_at` first. Mark the first entry `→ next up` — this is what `/monday-ticket` with no argument will pick. Table:

| # | Ticket | Created | Priority | Review verdict | affected_areas | Gist |
|---|---|---|---|---|---|---|

Gist = one short line from the dossier Problem (or the ticket name if no dossier). Tickets with no dossier at all get verdict UNREVIEWED and a note to run `/monday-review`.

### Section C — Anomalies (only if any)

State mismatches, Done-status items sitting outside the Completed group, dossiers whose ticket no longer exists on the board.

Close with the single most useful next command (usually `/monday-ticket` for the next-up item, or `/monday-resolve` for a confirmed-and-ready ticket).
