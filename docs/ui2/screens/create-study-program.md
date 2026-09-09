# create-study-program — Create Study Program (creation flow, step 1)

Platform: iphone · Status: specced · Specced: 2026-09-03

A **shared-edit-field pattern instantiation acting as step 1 of the program-creation
flow** — the pattern's `text-single` arrangement with a Create action instead of Save.
The frame is named "Create program step 1"; later steps are undesigned (OQ-2).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3833-33374
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3833:33374` ("Create program step 1", 440×956)
- Frozen snapshot: `assets/create-study-program.png` — captured 2026-09-03
- Pattern source: `screens/shared-edit-field.md` — chrome, input, and state contracts
  apply as written there; this spec defines only the deltas.

**Deviations (closed list):**
1. The sample title "Daily Inspiration" is content; the page description's final copy is
   TBD (the frame's copy ends in a placeholder joke — "…baking cookies and breakfast
   tacos" — owner supplies real copy).
2. The status bar is the iOS system status bar.
3. The Create button renders affirmative in the frame despite being a sample state — the
   §3 empty/dirty rule governs.

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page, exactly the shared-edit-field pattern layout: system status bar → **C-040
PageHeader** (`Two icons` + `showIcons=false`, back + centered title "Create study
program") → content (p16, gap `space-section-gap` 32):

1. **Page description** — Regular 14/20 `color-text-secondary` (copy per deviation 1).
2. **C-046 FieldGroup** — `Text`/`Default`: label "Give your program a title" + 44pt
   C-045 TextInput.
3. **C-048 PageActionButton** — "Create", 408×38.

No AI-suggestions block is designed on this frame (the pattern renders C-051 only where
the design gives it — it doesn't here).

## 3. Behavior contract

**States (closed list)** — the pattern's clean/dirty machine mapped to creation:
- `empty` — title blank; Create renders `disabled`.
- `ready` — title non-blank; Create renders `affirmative`.
- `creating` — proposed default per pattern OQ-shared-edit-field-3 (button disabled +
  activity indicator).
- `create-failed` — proposed default per the same OQ (inline error above the button,
  value preserved).

**Interactions (closed list):**
- Back → discard and pop (nothing persisted before Create).
- Create → §5 create call → **proposed default: push `study-program-home` for the new
  program** (legacy slid to Program Home; OQ-1 ratifies), unless undesigned later steps
  intervene (OQ-2).
- Text input focus/value states per C-045's contract.

**Motion:** standard push/pop; nothing bespoke designed.

## 4. Components

Closed list rendered: **C-040 PageHeader** (Two icons, showIcons=false) · **C-045
TextInput** (single, within C-046) · **C-046 FieldGroup** (Text/Default) · **C-048
PageActionButton** (disabled/affirmative, label "Create").

No rows introduced or modified — this screen is the first consumer of C-045/C-046
outside the pattern spec itself; all contracts bind as defined in
`screens/shared-edit-field.md` §4.

## 5. Data & API

| Need | Endpoint | Status |
|---|---|---|
| Create the program from a title | `POST /api/programs` (verified — `server/src/routes/programs.ts:215`) | **API-GAP/contract clash:** the route requires `templateId` (uuid) and accepts `days` (default 30), but this design collects ONLY a title. Either undesigned later steps supply template/days (OQ-2), or the suite makes `templateId` optional — note the activities model (`docs/features/activities/`) is expected to retire the template concept, which the backend suite must reconcile here |
| Post-create data for the destination screen | `GET /api/programs/{id}` (verified) | ✅ exists |

Writes: one `POST /api/programs` on Create; nothing before it.

## 6. Connections

- **Entry:** a program-creation affordance — undesigned; anticipated from `library-home`
  (its add/create menu, pending Figma) and possibly home surfaces (OQ-3).
- **Exits:** back → caller (discard) · Create → `study-program-home` (proposed, OQ-1) or
  a later creation step (undesigned, OQ-2).
- **Overlays:** none.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

| Legacy element | Disposition |
|---|---|
| `Pages/Manage/Program/CreateProgramPage.swift` — `Route.swift` case `.createProgram` (`Services/Route.swift:46`) | **replaced** — legacy collects name/template/days/cover in one modal form and slides in-place to Program Home; 2.0 splits creation into pattern steps starting with title-only |
| Legacy post-create behaviors (auto-create lessons from template; cover/tags synced after create — `parity-create-program` dossier) | **carried at the API layer**, pending the template-model reconciliation in §5 |
| Program import flow (`POST /api/programs/import`, legacy import button) | **not this screen** — unplaced in 2.0; gap-analysis candidate |

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-create-study-program-1 | Post-create destination: push the new program's `study-program-home` (proposed, matches legacy) — ratify | No — default proposed | owner |
| OQ-create-study-program-2 | "Step 1" implies more steps: what do they collect (template/days/cover/description?), and does Create fire at step 1 or at the end? Ties directly to the §5 `templateId` clash | No for this spec; **gates the build suite's creation contract** | owner (frames) + backend suite |
| OQ-create-study-program-3 | Entry affordance: no designed control opens this flow yet (library-home add menu pending Figma) | No — entry deferred | owner (frames) |
