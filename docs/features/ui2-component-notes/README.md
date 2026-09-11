# ui2-component-notes — screen element targeting, the Component tab, and notes

**Status: Shipped-ready (2026-09-10)** — 6 of 6 phases VERIFIED, signed off by the owner
**without a human walk**: they authorised sign-off after being shown the script and the one
outstanding item. Everything below was verified by agents only.

Point at a component on a 2.0 screen and talk about it. Three joined parts:

1. **Element targeting** — every screen snapshot gains a map of component-instance rects, so
   hovering the render draws a labelled bounding box and clicking selects that component.
2. **The Component tab** — a fourth right-panel tab that shows the selected component
   *without leaving the screen*: identity, artwork, designed states, an Open button, notes.
3. **Notes** — timestamped, append-only, git-tracked markdown beside the specs, with `@`
   tagging of any component or screen. Notes are **normative**: `/ui2-component-build` honors
   them, and a new `/ui2-component-update` verifies a built preview against spec + notes and
   fixes the gaps. Newer notes beat older ones; notes beat the spec, and every override is
   reported.

The gap it closes: the program can say what a component *looks like* (Figma) and what it *is*
(the contract), but has nowhere to say what it is *for*, and no way to point at a thing on a
screen while saying it.

## Pipeline status

| Step | Status |
|---|---|
| spec | ✅ drafted 2026-09-11 (6 statements corrected by the audit) |
| audit | ✅ pass 1 (16 findings) + pass 2 delta (2, both fixed) + integrity check **SOUND**, all 2026-09-10 |
| decisions | ✅ closed 2026-09-10 — 5 rulings taken as **defaults**, each veto-able (09) |
| plan | ✅ 6 phase docs written 2026-09-10 |
| build | ⬜ |
| verify | ⚠️ INCOMPLETE on 1 item, accepted by the owner 2026-09-10 |
| sign-off | ✅ owner-authorised 2026-09-10 (not owner-exercised) |

## Phase status

Written by the plan step 2026-09-10. One app per phase; 02's scope table puts everything in
capture except the last, which is the three command files under root `.claude/`.

| # | Phase | App | Doc | Tasks | Status |
|---|---|---|---|---|---|
| 1 | Notes storage + routes | capture (backend) | [10](10-phase-1-notes-backend.md) | 5 | ✅ 2026-09-10 |
| 2 | Element maps: parse, guard, serve | capture (backend) | [11](11-phase-2-element-maps-serving.md) | 6 | ✅ 2026-09-10 |
| 3 | The element-map backfill | capture + docs/ui2 | [12](12-phase-3-backfill.md) | 5 | ✅ 2026-09-10 |
| 4 | Hover, click and the box | capture (frontend) | [13](13-phase-4-targeting-ui.md) | 8 | ✅ 2026-09-10 |
| 5 | Component tab, notes, composer | capture (frontend) | [14](14-phase-5-component-tab.md) | 9 | ✅ 2026-09-10 |
| 6 | The three command files | root `.claude/` | [15](15-phase-6-commands.md) | 4 | ✅ 2026-09-10 |

The chain is strict: maps must be served before generating twelve of them is worth doing (3 after
2), targeting must work before the tab it selects into (5 after 4), and notes must be writable
before the command that verifies against them can be checked (6 after 5).

## GATE: INCOMPLETE — 1 item (2026-09-10)

Everything an agent can verify is verified. **One requirement's proof needs you to run a
command**, and inventing that proof would mean fabricating normative content — so it is listed
rather than claimed.

| # | Check | Result |
|---|---|---|
| 1 | Phases complete | ✅ all 6 VERIFIED and dated; zero unchecked task rows |
| 2 | Gates green NOW | ✅ re-run fresh: `npm test` 103/102 pass/1 (the pre-existing `parseContract` case, unrelated — baseline was 73/72/1, so **+30 tests, all passing**); `npx vite build` clean; all three new routes answer 200 |
| 3 | Contract integrity | ✅ 03's shapes match what shipped, field for field. Amendments all dated and carried in 09 (G-5 composite space, G-7 `after`/409, X-3 unique-ref resolution, G-8 comment targets, G-19 tie order) |
| 4 | Consumer parity | ✅ n/a in the cross-app sense — one consumer (the capture SPA) plus the two commands, which read notes through the same parser via its CLI (09 §X-2) |
| 5 | Unverified claims | ✅ zero `(claimed — unverified)` markers |
| 6 | Open ledger rows | ✅ zero OPEN rows; every G/D/O/C/X row DECIDED, RESOLVED or ACKNOWLEDGED |
| 7 | Pattern regressions | ✅ capture house rules hold: shared viewer components changed additively (every new prop optional, both 1.0 callers pass none — walked in-browser), no `window.confirm` (discard uses `ConfirmDialog`), pure logic in `src/lib/` with tests |
| 8 | Migrations | ✅ n/a — no schema change; the whole data surface is repo files |
| 9 | 08-testing row by row | ⚠️ **one gap** — see below. Every cited automated test exists and passes; human 1–15 walked in Chrome |
| 10 | E2E walked | ✅ the full human script, live, against the real backfilled maps |
| 11 | Cold-reader probe | ⏭️ **skipped** — it calls for a fresh agent with no build context, and this session was told not to use subagents. Substituted: every path, command and count the suite cites was re-checked against the as-built code (integrity check, 09). Honest caveat: that proves the docs are *accurate*, not that they are *sufficient* for a stranger |

### The blocking item

**R11 — "notes are taken into account when running `/ui2-component-build`"** is proved by 08's
C-1 and C-2, and both need a real `/ui2-component-build` run: a SwiftUI compile plus a simulator
capture, against a component carrying a note. **C-6** (a `/ui2-screen` run writing an element
map) and **C-7** (the update command asking before it captures) are the same shape.

They are deferred rather than faked because the only honest input is a **real note you wrote**.
A note is normative build input: inventing one, building Swift to satisfy it, then deleting it
would leave the lane dirty and prove nothing about your intent. Every verification note written
during this build was deleted for the same reason — `git status docs/ui2` is clean.

**What clears it:** write a note on a built component through the Component tab, then run
`/ui2-component-build <C-###>` (or `/ui2-component-update <C-###>`) and confirm the note is
loaded in phase 0 and honoured in phases 3–4.

**Accepted 2026-09-10.** The owner signed the feature off with this item outstanding rather than
clearing it. It is not closed — the first real build run on a component carrying an owner-written
note closes it, and until then R11 is proved by reading the command file, not by having watched it
work.

## Doc index

| Doc | Contents |
|---|---|
| [01-architecture.md](01-architecture.md) | Overview, 10 decisions, the 13-row requirement-provenance table, baseline patterns, out of scope |
| [02-app-impact.md](02-app-impact.md) | Per-app scope (capture + `.claude` + `docs/ui2` only), contract ownership, sequencing, blast radius |
| [03-data-and-api.md](03-data-and-api.md) | **The contract:** the note file format, the element-map format, 4 HTTP shapes, and the effective-requirement derivation both skills implement |
| [04-server.md](04-server.md) | Not affected — and why "server" here means `capture/server.mjs` |
| [05-client.md](05-client.md) | Not affected |
| [06-iphone.md](06-iphone.md) | Not affected — including why runtime edits to `UI2Preview/` are not iPhone scope |
| [07-capture.md](07-capture.md) | Everything built: generator, notes module, routes, targeting, the tab, styles, and the three command files |
| [08-testing.md](08-testing.md) | Unit + route + human + command verification, and the R#/D# traceability table |
| [09-gaps-and-decisions.md](09-gaps-and-decisions.md) | The G/D/O/C ledger |

## Key things a reader should not miss

- **Notes are spec content, not annotations.** That is why they are files (D1) and why two
  skills parse them. The parser is one module with tests (07 §2) so the browser and the skills
  cannot disagree about what a note says.
- **A note-driven difference from Figma is not a diff failure.** Both skills diff a built
  render against the frozen snapshot; when a note caused the difference, reporting it as a
  failure would drive the build to undo the owner's own instruction (03 §3).
- **`/ui2-component-update` never writes under `docs/ui2`.** A spec the notes have overtaken is
  *reported* as drift, for the owner to resolve in Figma or in a `/ui2-component` re-spec
  (D3, 07 §7.2, tested by C-5).
- **Unmapped is better than mis-mapped.** The backfill only keeps a match the screen spec's §4
  closed list confirms; everything else is omitted, not guessed (D5).
- **The one deliberate regression:** `.cmp-ui2s__chip` stops navigating and starts selecting
  (R6). The Open control replaces it.

## Continue

```
/build-spec ui2-component-notes           ← resumes the build at the first phase with unchecked tasks
```

Audit pass 1 (2026-09-10) read the suite against the capture codebase, the two `.claude` commands
it edits, and `docs/ui2`. Four claims are now marked **verified in code**; six statements the code
contradicted were corrected in place. The blocking three are in
[09-gaps-and-decisions.md](09-gaps-and-decisions.md): multi-frame composite snapshots (`G-5`),
screen comments gaining element targets (`G-8`), and `?c=` being dropped by the app's own
navigation (`G-9`).
