# 08 — Testing

## 1. Gates

Single-app feature; the gate list is capture's.

| Gate | Command | Applies to |
|---|---|---|
| Unit tests | `cd capture && npm test` | every phase |
| Build | `cd capture && npx vite build` | every phase touching `src/` |
| Server boots + routes answer | `curl -s localhost:5951/api/ui2/mentions -o /dev/null -w '%{http_code}'` | phases 1, 3 |
| No console errors in the browser | `read_console_messages` on `/components/2.0/<screen>` | phases 2, 3 |

The suite currently stands at **72 pass / 1 fail** (73 tests) — `parseContract handles the
axis-shaped matrix` is a **pre-existing** failure unrelated to this feature. **Verified in code
(2026-09-10)** by running `cd capture && npm test` on the working tree: `# pass 72 # fail 1`. That is the baseline; a phase is green when it adds
no new failure. Fixing it is not this feature's job and must not be bundled in.

## 2. Unit tests

`capture/test/ui2-notes.test.mjs` (new):

| # | Test |
|---|---|
| N-1 | `parseNotes` returns notes oldest-first with exact bodies, blank lines preserved |
| N-2 | A `##` heading that is not an ISO instant is body text, not a boundary |
| N-3 | `formatNote` output round-trips through `parseNotes` unchanged |
| N-4 | `appendNote` on a missing file creates title + preamble + one note |
| N-5 | `appendNote` twice in the same millisecond produces two distinct ids 1ms apart |
| N-6 | `notesPath` maps `C-052` and `home-dashboard` to the two directories, throws on `nonsense/../etc` |
| N-7 | `extractMentions` finds `@C-052` and `@home-dashboard`, ignores an email-like `a@b`, ignores `@` at end of input |
| N-8 | A corrupt file yields `{ notes: [], parseError }` rather than throwing |

`capture/test/ui2-elements.test.mjs` (new):

| # | Test |
|---|---|
| E-1 | A well-formed map parses and attaches to the right variant by snapshot stem |
| E-2 | A map whose `size` aspect ratio diverges from the PNG by >1% is discarded (null) |
| E-3 | A map with an element missing `ref` is rejected as malformed (03 §1.2 makes `ref` required) |
| E-4 | An element whose `ref` is not in the registry attaches with `resolved: null`, not dropped |
| E-5 | Editing a map file changes the index cache stamp (a stale index would serve old boxes) |

`capture/test/ui2-index.test.mjs` (extend):

| # | Test |
|---|---|
| X-1 | `buildUi2Screens` attaches `elements` to variants that have a map and `null` to those that don't |

`capture/src/lib/hit-test.js` + `capture/src/lib/mentions.js` (new pure helpers) tested from
`capture/test/ui2-target.test.mjs` — `package.json`'s `"test": "node --test test/*.test.mjs"`
only collects `capture/test/*.test.mjs`, so a test file anywhere else never runs
(**verified in code, 2026-09-10**; precedent: `src/lib/ui2-layout.js` tested from
`test/ui2-layout.test.mjs`):

| # | Test |
|---|---|
| H-1 | Hit test returns the smallest containing rect; a chip inside a row wins (D8) |
| H-2 | Equal-area tie resolves to the later entry (D8) |
| H-3 | Hit test with an empty or null map returns null, never throws |
| H-4 | Typeahead filter matches on id and on name, case-insensitively; ranks exact-id-prefix first |
| H-5 | Token commit replaces only the active `@query` and leaves surrounding text intact |

## 3. Route tests

Exercised with `curl` against a running capture server, asserted by status + shape:

| # | Check |
|---|---|
| R-1 | `GET /api/ui2/notes?target=C-052` on a component with no file → 200, `exists:false`, `notes:[]` |
| R-2 | `POST` then `GET` returns the note newest-first with resolved `refs` |
| R-3 | `POST` with an empty body → 400; with an unknown target → 404 |
| R-4 | `GET /api/ui2/mentions` returns every registry row and every README screen row |
| R-5 | `GET /api/ui2/screen-detail?id=home-dashboard` carries `variants[].elements` with resolved refs |
| R-6 | A screen with no map returns `elements: null` and still returns every other key |

## 4. Human verification script

Run at `http://localhost:5950/components/2.0/home-dashboard/default`.

1. **R1** — Move the pointer across the render. A box appears under the pointer and follows it; exactly one box at a time. Move off the render: no box. Nothing is drawn at rest.
2. **R2** — The box carries a label reading `C-### Name`. Hover a component near the very top of the frame: the label flips inside the box rather than clipping.
3. **R8 (nesting)** — Hover the avatar inside an enrollment row: the avatar's box wins, not the row's.
4. **R3** — Click a component. The Component tab activates, the URL gains `?c=C-###`, and the screen render and selected state are unchanged.
5. **R5** — The tab's first block names the component and shows its status chips. Reload the page: the same component is still selected.
6. **R6** — Click a chip in the Screen tab's component list: it selects into the Component tab, no navigation. Then press **Open component**: now it navigates to that component's page.
7. **R7** — A component with several notes lists them newest first, each clamped to two lines with its timestamp. Expand one: it grows in place.
8. **R8** — Press Add note. Everything below the tab strip becomes the notepad; Cancel and Save sit in a bar at the bottom. Press Cancel with text typed: a confirm dialog appears (not a browser dialog). Confirm: the list returns unchanged.
9. **R9** — In the notepad type `@day`: a typeahead lists `C-052 DayChip`. Arrow down, press Enter: the canonical token is inserted. Type `@home`: screens appear. Press Escape: the popup closes without inserting.
10. **R7/R9** — Save. The note appears at the top of the list with its mention rendered as a chip carrying the component's current name. Check the file on disk: it matches 03 §1.1.
11. **Comment mode isolation** — Press `c`. Hover the render: the component box is gone and comment placement behaves as before. Press Escape: component hover returns.
12. **Degradation** — Open a screen with no element map. It renders normally with no boxes and no errors in the console.

## 5. Command verification

| # | Check |
|---|---|
| C-1 | `/ui2-component-build` on a component with a note that contradicts the contract: the build follows the note, and phase 6 lists the resulting Figma difference under note-driven divergence, not as a diff failure |
| C-2 | `/ui2-component-build` on a component whose **dependency** has a note: the dependency's note is loaded and honored |
| C-3 | `/ui2-component-update` on an unbuilt component: prints the effective requirement set and stops, pointing at `/ui2-component-build`; makes no edit |
| C-4 | `/ui2-component-update` with two notes contradicting each other on one property and agreeing on another: the newer wins on the contested property, the older's other statement survives (R13) |
| C-5 | `/ui2-component-update` never writes under `docs/ui2` — verified with `git status --porcelain docs/ui2 \| grep -v '/notes/'` before and after a run that produced a drift list, comparing the two. **Corrected 2026-09-10 (audit pass 1):** the original check was unscoped, and notes live under `docs/ui2/**/notes/` and are routinely dirty from the browser's own appends, so it would have failed on a correct run (09 §G-11) |
| C-6 | `/ui2-screen` on any screen writes an element map whose refs are a subset of that spec's §4 closed list |

## 6. Requirement traceability

| R# | Covered by |
|---|---|
| R1 | H-1, H-3, human 1, human 12 |
| R2 | human 2 |
| R3 | human 4 |
| R4 | human 4 |
| R5 | human 5 |
| R6 | human 6 |
| R7 | human 7, human 10 |
| R8 | human 8 |
| R9 | H-4, H-5, N-7, human 9 |
| R10 | *(satisfied through R11 + R12 — carries no test of its own; it is the rationale, not a behavior)* |
| R11 | C-1, C-2 |
| R12 | C-3, C-5 |
| R13 | C-4 |
| D1 | N-4, N-5, human 10 |
| D5 | C-6, E-3 |
| D8 | H-1, H-2, human 3 |
| D9 | human 5 |
