# ui2-component-notes — screen element targeting, the Component tab, and notes

**Status: planned — building** (audit clean, decisions closed, 6 phase docs, 2026-09-10)

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
| verify | ⬜ |
| sign-off | ⬜ |

## Phase status

Written by the plan step 2026-09-10. One app per phase; 02's scope table puts everything in
capture except the last, which is the three command files under root `.claude/`.

| # | Phase | App | Doc | Tasks | Status |
|---|---|---|---|---|---|
| 1 | Notes storage + routes | capture (backend) | [10](10-phase-1-notes-backend.md) | 5 | ✅ 2026-09-10 |
| 2 | Element maps: parse, guard, serve | capture (backend) | [11](11-phase-2-element-maps-serving.md) | 6 | ⬜ |
| 3 | The element-map backfill | capture + docs/ui2 | [12](12-phase-3-backfill.md) | 5 | ⬜ |
| 4 | Hover, click and the box | capture (frontend) | [13](13-phase-4-targeting-ui.md) | 8 | ⬜ |
| 5 | Component tab, notes, composer | capture (frontend) | [14](14-phase-5-component-tab.md) | 9 | ⬜ |
| 6 | The three command files | root `.claude/` | [15](15-phase-6-commands.md) | 4 | ⬜ |

The chain is strict: maps must be served before generating twelve of them is worth doing (3 after
2), targeting must work before the tab it selects into (5 after 4), and notes must be writable
before the command that verifies against them can be checked (6 after 5).

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
