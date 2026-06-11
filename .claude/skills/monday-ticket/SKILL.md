---
name: monday-ticket
description: Deep-dive a single monday.com ticket — accepts a URL, item ID, or (fuzzy) ticket title. Reads the full ticket including screenshot attachments and all comments, builds a complete understanding of the reported issue, then investigates the MakeReady codebase to determine whether it's still relevant, how to verify it, and (if it exists) produces a root-cause summary ready for fix planning. Use when asked to evaluate, investigate, understand, or scope a specific monday ticket.
---

# Monday.com Ticket Deep-Dive

You are evaluating ONE monday.com ticket end-to-end for the MakeReady project (monorepo: `client/` Laravel+Vue web app with the member-facing lesson player, `iphone/` SwiftUI app, `server/` Express API). The deliverable is a verdict — still relevant or not — plus, if the issue exists, a summary sharp enough to plan a fix from.

## 1 — Resolve the ticket from the argument

Auth (never print the token):
```bash
TOKEN=$(jq -r '.. | objects | select(has("MONDAY_TOKEN")) | .MONDAY_TOKEN' ~/.claude.json | head -1)
```

The argument may be:
- **URL** — `https://<account>.monday.com/boards/<board_id>/pulses/<item_id>` → take `<item_id>`.
- **Numeric ID** — use directly.
- **Title text** — fuzzy-match: fetch item names from the active boards (default ticket board: `18413909869` "Ongoing Tasks Tracking"; fall back to `{ boards(limit: 50) { id name items_page(limit: 100) { items { id name } } } }`), case-insensitive substring/closest match. If multiple plausible matches, list them and ask the user which one.

## 2 — Fetch the complete ticket

```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"{ items(ids: [ITEM_ID]) { id name created_at creator { name } board { id name } group { title } column_values { id text type } assets { id name public_url file_extension file_size } updates { body created_at creator { name } assets { name public_url file_extension } } } }"}'
```

Collect: title, board/group, status & priority, created date + reporter, every comment (strip HTML from `body`), and every asset on the item AND on its updates.

## 3 — Read the attachments (do not skip this)

Screenshots are usually the highest-signal part of a bug ticket. `public_url` is pre-signed — download without auth headers:

```bash
mkdir -p /tmp/monday-assets/ITEM_ID
curl -s -o "/tmp/monday-assets/ITEM_ID/<name>" "<public_url>"
```

Then **view every image with the Read tool** and describe what each shows (which screen of which app, what's visibly wrong, any UI elements that identify the exact page/component). PDFs can also be Read. Skip videos/unreadable formats but note their presence. Asset timestamps in filenames (e.g., `media_2026-05-21_...`) date the observation — useful for matching against fix commits.

## 4 — Build full understanding

Synthesize title + comments + screenshots into a precise problem statement:
- What behavior was reported, on which platform (web member experience / web admin / iPhone app — identify from the screenshots' chrome and UI), on which screen/component?
- What did team comments add (workarounds, "by design" notes, promised fixes)?
- What would "fixed" observably look like?

State this understanding explicitly before investigating — if the ticket is too vague even with attachments, stop and say what question to post on the ticket.

## 5 — Investigate the codebase

1. **Locate the code**: find the exact page/component from the screenshots (match visible text, labels, and layout to Blade views / Vue islands in `client/` or SwiftUI pages in `iphone/`).
2. **Check for fixes**: `git log --oneline --since=<ticket date minus 14 days>` over the relevant paths, keyword greps (`git log -i --all --grep=...`, `git log -S"<symbol>"`), and `docs/progress/` release notes. The screenshot date bounds when the bug demonstrably existed.
3. **Read the current code path** and reason about whether the reported behavior can still occur — confirm any candidate fix is on `main` and not reverted. Beware: the screenshotted UI may have been redesigned or removed entirely since (that's a valid resolution: OBSOLETE).
4. Spawn an Explore agent for broad searches if the surface area is unclear.

## 6 — Determine verifiability

How could the issue's existence be confirmed today? In order of preference:
- **Code-level proof**: the defect is visible in the code itself (e.g., a `pushState` with no `popstate` listener proves browser-back is broken). Strongest — cite file:line.
- **Capture tool**: a screenshot fixture in `capture/fixtures/` could reproduce the state (note which view/fixture would need to exist).
- **Manual repro steps**: precise steps on local dev (which URL/page, what to tap, what to observe). The local stack: web client + Express server on :3010 (Docker).
- **Not verifiable as stated**: say so and what's missing.

## 7 — Report

```
## Ticket: <title> (<id>, <board>/<group>, status, priority)
**Reported**: <date> by <name> · **Attachments**: <n> screenshots (described above)

### Understanding
<precise problem statement, platform, screen, what fixed-looks-like>

### Verdict: STILL RELEVANT | ALREADY FIXED | OBSOLETE | CANNOT MAP
<evidence: commit hashes, file:line, screenshot↔code matches>

### Verification
<how to prove it exists/doesn't, per section 6>

### Fix summary (only if STILL RELEVANT)
- Root cause: <file:line + mechanism>
- Affected surface: <pages/components>
- Proposed approach: <2-5 bullet sketch>
- Risk/effort: <S/M/L + anything the fix could break>
- Related tickets: <other board items touching the same surface, if noticed>
```

This skill is read-only on monday — it never changes status, group, or posts comments. If the verdict is ALREADY FIXED, suggest running `/monday-review` (or offer to close it with evidence via that skill's mutation flow). If the user asks to proceed with the fix, the Fix summary seeds the plan.
