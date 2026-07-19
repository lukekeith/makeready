---
name: monday-ticket
description: Deep-dive a single monday.com ticket — accepts a URL, item ID, or (fuzzy) ticket title; with NO argument it takes the next open ticket from the deep-dive queue automatically. Reads the full ticket including screenshot attachments and all comments, builds a complete understanding of the reported issue, investigates the MakeReady codebase, and writes/updates the ticket's dossier in docs/monday/tickets/<id>.md — including the CONFIRMED affected-areas contract (exact screens/components/files in scope, sibling surfaces out of scope) that /monday-resolve requires before it will implement a fix. Use when asked to evaluate, investigate, understand, or scope a specific monday ticket, to prepare a ticket for resolution, or to "do the next deep dive".
---

# Monday.com Ticket Deep-Dive

You are evaluating ONE monday.com ticket end-to-end for the MakeReady project (monorepo: `client/` Laravel+Vue web app with the member-facing lesson player and the `/admin` LeaderApp, `iphone/` SwiftUI app, `server/` Express API). This is stage 2 of the pipeline in `docs/monday/PIPELINE.md` — read that contract first. The deliverable is twofold: a verdict (still relevant or not) AND the ticket's **dossier** at `docs/monday/tickets/<id>.md` with `affected_areas: confirmed` — the scope contract that gates `/monday-resolve`.

## 1 — Resolve the ticket from the argument

Auth (never print the token):
```bash
TOKEN=$(jq -r '.. | objects | select(has("MONDAY_TOKEN")) | .MONDAY_TOKEN' ~/.claude.json | head -1)
```

**No argument → take the next ticket from the deep-dive queue** (rule defined in `docs/monday/PIPELINE.md`):
1. Fetch open items (status ≠ Done) from board `18413909869` with priority, `created_at`, and update timestamps.
2. Read frontmatter from every `docs/monday/tickets/<id>.md`.
3. Queue = open tickets not `in-progress`/`resolved-pending-verify`/`closed`, ordered: never-dived (`deep_dive: none` or no dossier) before stale-dived (monday updates newer than `deep_dive`); within a bucket, Priority High → Medium → Low → unset, then oldest `created_at`.
4. Announce the pick ("Next in queue: <title> (<id>) — <why it's next>") and proceed with the full deep dive below. If the queue is empty, say so and point at `/monday-list` for the board state.

Otherwise, the argument may be:
- **URL** — `https://<account>.monday.com/boards/<board_id>/pulses/<item_id>` → take `<item_id>`.
- **Numeric ID** — use directly.
- **Title text** — fuzzy-match against `docs/monday/tickets/*.md` frontmatter first, then item names from the active boards (default ticket board: `18413909869` "Ongoing Tasks Tracking"; fall back to `{ boards(limit: 50) { id name items_page(limit: 100) { items { id name } } } }`), case-insensitive substring/closest match. If multiple plausible matches, list them and ask the user which one.

If a dossier already exists at `docs/monday/tickets/<id>.md`, read it — you are refreshing/confirming it, not starting blind. Preserve its Triage history and Resolution log.

## 2 — Fetch the complete ticket

```bash
curl -s -X POST https://api.monday.com/v2 -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"{ items(ids: [ITEM_ID]) { id name created_at creator { name } board { id name } group { title } column_values { id text type } assets { id name public_url file_extension file_size } updates { body created_at creator { name } assets { name public_url file_extension } } } }"}'
```

Collect: title, board/group, status & priority, created date + reporter, every comment (strip HTML from `body`), and every asset on the item AND on its updates.

## 3 — Read the attachments (do not skip this)

Screenshots are usually the highest-signal part of a bug ticket — and they are what disambiguates *which* screen the reporter meant. `public_url` is pre-signed — download without auth headers:

```bash
mkdir -p /tmp/monday-assets/ITEM_ID
curl -s -o "/tmp/monday-assets/ITEM_ID/<name>" "<public_url>"
```

Then **view every image with the Read tool** and describe what each shows (which screen of which app, what's visibly wrong, any UI elements that identify the exact page/component). PDFs can also be Read. Skip videos/unreadable formats but note their presence. Asset timestamps in filenames (e.g., `media_2026-05-21_...`) date the observation — useful for matching against fix commits.

## 4 — Build full understanding

Synthesize title + comments + screenshots into a precise problem statement:
- What behavior was reported, on which platform (web member experience / web LeaderApp / iPhone app — identify from the screenshots' chrome and UI), on which screen/component?
- Multi-report tickets: enumerate the distinct sub-issues; each gets its own scope mapping.
- What did team comments add (workarounds, "by design" notes, promised fixes)?
- What would "fixed" observably look like?

State this understanding explicitly before investigating — if the ticket is too vague even with attachments, stop, update the dossier with `affected_areas: none` and the open question, and say what to post on the ticket.

## 5 — Investigate the codebase and pin the affected areas

1. **Locate the exact code**: match visible text, labels, and layout from the screenshots to Blade views / Vue islands in `client/` or SwiftUI pages in `iphone/`. Verify every path exists on `main` (glob it) — no paths from memory.
2. **Disambiguate siblings — the core discipline.** MakeReady is full of near-identical surface families; the dossier must say which member of the family is in scope AND name the confusable ones as out of scope:
   - the four iPhone activity editors (Read / Exegesis / Write / Video) under `iphone/MakeReady/Pages/Manage/Program/`,
   - web LeaderApp twin panes of iPhone screens (`client/resources/js/islands/leader-app/components/`),
   - the member lesson player's per-step files (`client/resources/js/components/domain/lesson-island/steps/{video,youtube,read,exegesis,input,complete}-step.vue`),
   - member vs. leader variants of a screen; LeaderApp `/admin` vs. parked `/admin-legacy`,
   - shared components (`MarkdownEditor.swift`, shared SCSS, common Vue components) — flag that touching them affects screens beyond this ticket.
3. **Assess cross-app impact** using the table in the root `.claude/CLAUDE.md` (schema change → both consumers; auth → all three apps; etc.). State it even when it's "none".
4. **Check for fixes**: `git log --oneline --since=<ticket date minus 14 days>` over the relevant paths, keyword greps (`git log -i --all --grep=...`, `git log -S"<symbol>"`), and `docs/progress/` release notes. The screenshot date bounds when the bug demonstrably existed. History before the 2026-05-20 squash (`fc69ddb`) is collapsed — current-code inspection is the fallback evidence there.
5. **Read the current code path** and reason about whether the reported behavior can still occur — confirm any candidate fix is on `main` and not reverted. Beware: the screenshotted UI may have been redesigned or removed entirely since (that's a valid resolution: OBSOLETE).
6. Spawn an Explore agent for broad searches if the surface area is unclear.

## 6 — Determine verifiability

How could the issue's existence be confirmed today? In order of preference:
- **Code-level proof**: the defect is visible in the code itself. Strongest — cite file:line.
- **Capture tool**: a screenshot fixture in `capture/fixtures/` could reproduce the state (note which view/fixture would need to exist).
- **Manual repro steps**: precise steps on local dev (which URL/page, what to tap, what to observe). The local stack: web client + Express server on :3010 (Docker).
- **Not verifiable as stated**: say so and what's missing.

## 7 — Write the dossier (the primary artifact)

Create or update `docs/monday/tickets/<id>.md` per `docs/monday/tickets/TEMPLATE.md`:

- Fill Problem, Reports (verbatim, complete), Screenshots (your descriptions from step 3), Affected areas (In scope with verified paths / Explicitly out of scope siblings / Cross-app impact), Root cause, Verification.
- Frontmatter: `deep_dive: <today>`; `affected_areas: confirmed` **only if** you viewed the attachments (or the ticket verifiably has none and the text alone pins the screen) AND every in-scope path was verified to exist. Otherwise leave `provisional`/`none` and say why.
- Append a Triage history line: `<date> /monday-ticket: <verdict> — <one-liner>`.
- Preserve existing Triage history and Resolution log entries.

This skill is the ONLY stage allowed to set `affected_areas: confirmed` (see PIPELINE.md).

## 8 — Report to the user

```
## Ticket: <title> (<id>, <board>/<group>, status, priority)
**Reported**: <date> by <name> · **Attachments**: <n> screenshots (described above)

### Understanding
<precise problem statement, platform, screen, what fixed-looks-like; sub-issues enumerated>

### Verdict: STILL RELEVANT | ALREADY FIXED | OBSOLETE | CANNOT MAP
<evidence: commit hashes, file:line, screenshot↔code matches>

### Affected areas: confirmed | provisional | none
<the In scope / Out of scope summary — what /monday-resolve may and may not touch>

### Verification
<how to prove it exists/doesn't, per section 6>

### Fix summary (only if STILL RELEVANT)
- Root cause: <file:line + mechanism>
- Proposed approach: <2-5 bullet sketch>
- Risk/effort: <S/M/L + anything the fix could break>
- Related tickets: <other board items touching the same surface, if noticed>

Dossier: docs/monday/tickets/<id>.md (affected_areas: <value>)
Next: /monday-resolve <id> "<your solution>"   — or /monday-review to close if ALREADY FIXED
```

This skill is read-only on monday — it never changes status, group, or posts comments. If the verdict is ALREADY FIXED, suggest running `/monday-review` (or offer to close it with evidence via that skill's mutation flow). If the user asks to proceed with the fix, `/monday-resolve` picks up from the dossier.
