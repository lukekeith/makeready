# 02 — App impact

## Scope per app

| App | In scope | What changes | Owner doc |
|---|---|---|---|
| server | ⬜ | Production Express server untouched. This feature lives entirely in the capture dev tool, which runs its own Express (`capture/server.mjs`) against its own Postgres. No production endpoint, model, or migration is involved. | 04-server.md |
| client | ⬜ | No web-app change. Nothing in `client/` reads `docs/ui2`, and the 2.0 browser renders Figma PNGs, not web twins — the `/compare` web-twin iframe path is not on this feature's route. | 05-client.md |
| iphone | ⬜ | No app or harness change. `iphone/MakeReady/UI2Preview/` is **read and edited at command runtime** by `/ui2-component-build` and the new `/ui2-component-update` — but that is those commands doing their job on the owner's notes, not part of building this feature. The XCTest element-map harness is untouched: screens get their map from Figma, not from the simulator. | 06-iphone.md |
| capture | ✅ | Backend: note read/append routes, a mention index route, element-map serving for screens, `buildUi2Screens`/index extensions, one migration script. Frontend: the Component tab, the hover/click targeting layer on screen renders, the note card list, the notepad composer with `@` typeahead, and the chip-click behavior change. No Prisma schema change — notes are files (D1). | 07-capture.md |
| root `.claude` | ✅ | One new command (`.claude/commands/ui2-component-update.md`) and edits to two existing ones (`ui2-component-build.md`, `ui2-screen.md`). | 07-capture.md §7 |
| `docs/ui2` | ✅ | Two new content directories (`design-system/components/notes/`, `screens/notes/`) and one new artifact class (`screens/assets/<stem>.elements.json`). No existing normative doc is rewritten by this feature. | 03-data-and-api.md §1 |

Cross-check against `.claude/CLAUDE.md` §Cross-App Impact Guide: the nearest listed row is
**"Screenshot fixtures → capture only"**. No database-schema, API, auth, media, or
content-model row applies. The only datastore this touches is the repo filesystem.

## The contract (who produces, who consumes)

| Contract | Producer | Consumers | Defined in |
|---|---|---|---|
| Note file format (`notes/<target>.md`) | capture backend (append), `/ui2-screen` + `/ui2-component` (read) | `/ui2-component-build`, `/ui2-component-update`, capture SPA | 03 §1.1 |
| Screen element map (`<snapshot-stem>.elements.json`) | `/ui2-screen` phase 2; the backfill generator once | capture backend → capture SPA | 03 §1.2 |
| `GET /api/ui2/notes` | capture backend | capture SPA | 03 §2.1 |
| `POST /api/ui2/notes` | capture backend | capture SPA | 03 §2.2 |
| `GET /api/ui2/mentions` | capture backend | capture SPA (the `@` typeahead) | 03 §2.3 |
| `elements` on `GET /api/ui2/screen-detail` | capture backend | capture SPA | 03 §2.4 |
| Effective-requirement derivation (spec + notes, newest wins) | `/ui2-component-update` | the owner's drift report | 03 §3 |
| Existing, unchanged: `/api/ui2/screens`, `/api/ui2/detail`, `/api/ui2/version/:vid`, comment CRUD + comment MCP tools | capture backend | capture SPA, `/ui2-resolve` | 03 §4 |

## Cross-app sequencing

Single-app feature; sequencing is within the capture phase plan, not across apps.

1. `03` contract settled (this suite) — the two **file formats** are the real contract here,
   because two skills and one SPA all parse them independently.
2. **Phase 1 (data + backend)** must land before any UI: the element-map format, the generator
   that backfills 10 screens, the note files, and the routes that read/append them.
3. **Phase 2 (targeting)** and **Phase 3 (Component tab + notes UI)** both consume phase 1.
   Targeting is independent of notes and can verify on its own.
4. **Phase 4 (skills)** last — `/ui2-component-update` cannot be verified until notes exist to
   verify against, and `/ui2-component-build`'s note-awareness needs the same.
5. The contract freezes when phase 1 verifies.

## Backward compatibility

- **Nothing deploys as part of this feature.** **Corrected 2026-09-10 (audit pass 1):** capture is
  not purely workspace-only — `capture/server.mjs:79` treats `NODE_ENV=production` or `RAILWAY=true`
  as production mode and `:1883-1890` serves the committed `capture/dist/` bundle with an SPA
  fallback. The GET routes this feature adds run in that mode; the POST is gated by the same
  `!isProduction` block as the fixture write (03 §2.2). The consequence the suite must carry is in
  09 §X-1: the Add-note control is hidden when `detail.canCapture === false`, and a missing
  `docs/ui2` tree degrades to `exists:false` / `elements:null` rather than erroring.
- **Additive files only.** A screen without an element map renders exactly as it does today
  (no boxes, no targeting) — the feature degrades to the current behavior rather than erroring.
  A component without notes shows an empty notes list.
- **No existing route changes shape.** `screen-detail` gains an `elements` key; every current
  key keeps its meaning.
- **`.cmp-ui2s__chip` changes behavior** (R6): it selects instead of navigating. This is the one
  deliberate regression to existing behavior, and the Open control replaces the lost affordance.
- **The comment channel is untouched** (D2) — no route, no table, no resolution flow changes, so
  `/ui2-resolve` and every stored comment keep working. **Amended 2026-09-10 (09 §G-8):** one
  behavior does change — a comment placed on a **screen** now records which component it landed
  on, because the screen's new element map feeds the hit test the comment composer already runs.
  Comments stored before this ships have no target and render exactly as they do today.
- **Notes are additive to the skills.** A component with no notes makes
  `/ui2-component-build` behave exactly as it does today.

## Blast radius

| If this breaks | What is lost | What still works |
|---|---|---|
| Element map missing or malformed | Hover boxes and click-to-select on screens, and screen comments fall back to untargeted pins | The whole screen view: render, states, versions, comments, Screen tab |
| Note routes fail | Reading and adding notes in the browser | Every other tab; notes on disk are still readable by the skills and by the owner |
| Note file hand-corrupted | That one target's notes list, and `/ui2-component-update`'s input for it | Every other target — files are per-target, so a parse failure is isolated |
| Mention index fails | The `@` typeahead | Typing a token by hand still produces a valid note |
