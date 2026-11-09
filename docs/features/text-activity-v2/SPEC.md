# text-activity-v2 — spec
> lg · ticket none

## Idea

**Why.** The owner walked the text-activity editor on a device on 2026-11-08, and it fought them in
four ways:
- A new activity opened on flat white.
- The Background and Actions tools opened sheets that covered the tool row.
- The tools only existed while editing text.
- Text edits needed Done to stick.

Leaders compose every lesson page in this editor, so it has to feel like a story editor: colourful
from the first moment, every control one tap away, and nothing covering the tools.

**What success looks like.**
- A leader taps **Add → Text** and lands on a colourful, organic blob gradient.
- They type, then tap off the text, and the edit is kept and saved.
- They open Background and pick Gradient, Colour or Image. They open Actions and add a "Next
  lesson" button. All of this happens in rails above a tool row that never moves or gets covered.
- The chips rail at the very bottom clears the phone's curved corners.

**In your words.**
- "every new activity should use a generated background gradient, but not perfectly linear, a full
  color background that looks like gradient blobbing" → D1, D2, D3, D5
- "do not use any action button modals or any modals for any of the controls, it's always going to
  be a two stack system, sometimes three if needed" → D6, D7, D8
- "These three things should all have the same background color." → D6
- "The bottom controls with the five icons for editing the activity should always be visible." →
  D6, D9
- "If I click 'Cancel', that's the only way the changes I've made won't be saved." → D10
- "adding 16px padding to the bottom activity chips and plus button rail" → D11

**The concept.** The editor's bottom area becomes one stack on one surface colour:

```
┌──────────────────────────────┐  top rail     — details of the middle rail's pick (only when needed)
├──────────────────────────────┤  middle rail  — the open tool's choices
├──────────────────────────────┤  tool row     — 🎨 🖼 ≡ Aa ⚡, always on screen
├──────────────────────────────┤  chips rail   — Idle only: activity chips + ＋, 16pt bottom pad
└──────────────────────────────┘
```

A new activity's background is generated once, at creation: a base colour plus 3–5 soft blobs drawn
from a curated palette, stored in the document so every renderer draws the same picture.

**How it fits today.**
- Colour and Font already open panels above the tool row.[^1]
- Background and Actions present sheets.[^2]
- In Idle the chips rail (C-081) replaces the tool row.[^3]
- The background holds `color`, `image`, `wash` and `motion`.[^4] The server keeps unknown
  background fields.[^5]
- A new Text activity starts on `#FFFFFF`.[^6]
- A canvas tap while editing is ignored.[^7]

Text-activity's model, endpoints and viewer are unchanged. This is a revision of its editor and of
one document field.

**Approaches considered.**
- **Chosen:** blobs stored outright in the document, from ~12 curated palettes, with the Background
  and Actions sheets folded into rails.
- **Rejected:**
  - a stored seed (every platform would have to share one random generator forever)
  - a rendered background image (an upload and a library image per activity, and it can't be
    reshuffled)
  - one middle rail that pages through settings (more taps, and Actions is cramped)
  - two specs, rails then gradients (the Gradient option lives in the rails, and both rebuild the
    same d2m screen)

[^1]: `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift:709-759`
[^2]: same file `:293`, `:646`, `:755`; the sheet itself is `sheetOverlay` `:848-897`
[^3]: same file `:684-705`
[^4]: `docs/features/activity-viewer/02-content-schema.md` §5
[^5]: `server/src/services/activity-document.ts:153-166` (`.passthrough()`)
[^6]: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:71`, and the untouched check's
    `starterBackground` at `ActivitiesEditorMapper.swift:11`
[^7]: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:238`; the gate is C-091's
    `ActivityCanvas.swift:385` (`isEnabled: mode == .idle`)

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Validates the new optional `background.gradient` in the activity document zod schema; `02-content-schema.md` §5 documents it | §server |
| client | ⬜ | No client code reads activity documents. The member rebuild is out of scope (text-activity D6), and it reads the documented field when it comes | — |
| iphone | ✅ | Gradient generator + palettes, new-activity starter, untouched rule, gradient in the decoder, editor mapper, viewer mapper and rail thumbnails; the editor's rails, Idle tools, tap-off commit and chips padding (d2m: editor screen, player screen, C-091, C-102, C-081; then container wiring) | §iphone |

**Sequencing:** contract settled (the document field, §Contract) → server validates it and verifies
(contract FREEZES) → iphone's first task files the d2m requests (D12) → iphone wires the generator,
mapper and container against what d2m returns → the walk.

**Backward compatibility:** the field is additive and optional. An installed TestFlight build decodes
the envelope leniently and keeps unknown fields at every level, `background` included (edits patch
the raw JSON by path, `ActivityDocument.swift:211-221`), so it shows `background.color`, the
gradient's base colour, and re-saves the gradient untouched. One visible quirk: a colour picked on an
old build changes `background.color` without setting `hidden`, so a new build then shows the gradient
again (over that colour, D17). No transition is needed.

**Blast radius:**
- every reader of an activity document's background: the iPhone editor (C-091), the viewer
  (`ActivityViewerMapper` → `ActivitiesPlayerScreen` → C-091), the rail's slide thumbnails
  (`ActivityThumbnail.Page`, hand-drawn in the app, not C-091) and the server's validator
- server search and summaries read only text, so they're unaffected

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Gradient storage | `background.gradient` = `{ style: "blobs", blobs: [{ x, y, r, color }] }` with 1–8 blobs (the generator writes 4, D3; readers draw any count the server accepts); `background.color` stays required and is every renderer's fallback (superseded in part 2026-11-08 by D17: the gradient's base lives in `gradient.base`, and `color` equals it while the gradient shows). Draw order: `color`, `gradient`, `image`, `wash`, content. Rejected: a seed (every platform must share one generator forever); a rendered image (an upload and a library row per activity, not reshufflable) | owner 2026-11-08 |
| D2 | Blob geometry | `x`, `y` are the blob centre and `r` its radius, each a fraction of the background box's **width** (the box is C-091's page: `pageHeight` from `placement()`, `ActivityCanvas.swift:311-333`, viewport-tall when the content fits; `motion` is not drawn by any renderer today, so every mode uses that box; the thumbnails use their fixed 440×956 reference page), so `y` may exceed 1 on a tall page and the picture is identical at any width. Each blob is a radial gradient from `color` at the centre to fully transparent at `r`, composited with normal blending over `color`. Rejected: wu (the same picture, but a fraction survives a future reference-width change) | (assumed at spec) 2026-11-08 |
| D3 | Generator | ~~A new activity picks one of the curated palettes at random. The palette's darkest colour becomes `color`, and 4 blobs are drawn from its other colours: `x` uniform 0–1, `y` uniform 0–1.6, `r` uniform 0.45–0.8. A pure Swift function `ActivityBackgroundGenerator.make(palette:rng:)` with an injectable RNG so tests are deterministic. Rejected: a random hue with a harmony rule (unpredictable, some dull)~~ **Superseded 2026-11-08 (owner walk, round 2):** A new activity picks one of the curated palettes at random. Its darkest colour becomes `color` (= `gradient.base`), and 4 blobs are drawn from its vivid colours (the others), cycling: `x` uniform 0–1, `y` uniform 0–1.6, `r` uniform 0.6–1.0, so neighbouring blobs overlap and the page reads as a colourful gradient. Pure `ActivityBackgroundGenerator.make(palette:rng:)`, injectable RNG. Rejected: the 0.45–0.8 radii (blobs too small and separate to read as a gradient) | owner 2026-11-08 (palettes); (assumed at spec) the numbers; owner 2026-11-08 (round 2) |
| D4 | Palettes | ~~12 palettes of 4–5 hex colours, in one Swift data file. Every colour meets 4.5:1 contrast against white text (`#FFFFFF`), enforced by a unit test over every palette colour. The owner tunes them after the walk. Rejected: the organization's brand colour (orgs store none; a separate decision)~~ **Superseded 2026-11-08 (owner walk, round 2):** 12 palettes, each 1 dark base + 3–4 vivid colours, in one Swift data file. The base (darkest) meets ≥ 4.5:1 against white (`#FFFFFF`); every other colour is a bright, saturated hue (HSB saturation ≥ 0.55) meeting ≥ 3:1 against white — WCAG AA for large text, which canvas text is. Both enforced by a unit test over every palette. Rejected: 4.5:1 on every colour (forces deep tones; the owner saw the result as a solid colour) | owner 2026-11-08; owner 2026-11-08 (round 2) |
| D5 | Which activities | Only activities created from now on get a generated gradient: the Text tile's starter document (`ActivityNewContainer.textDocument`) and every future kind's starter. Existing, imported and fixture activities keep their backgrounds. Rejected: also fixtures (decide after seeing the result); converting white 1.0 content (changes authors' content unasked) | owner 2026-11-08 |
| D6 | The rail stack | ~~The editor's bottom area is one stack on `Token.layoutBackground` with no hairlines between rails, bottom to top: chips rail (Idle only), tool row, middle rail, top rail. The tool row is on screen in every mode except Load-failed. No tool presents a sheet, modal, menu or alert: the Background sheet, the Actions sheet and the editor's pushed media-pick page (subject to D22) are removed. The save-failure alert ("Couldn't save activity", text-activity D46) is not a tool and stays. Rejected: tools only while editing (Background is page-level and was unreachable without a text edit)~~ **Superseded 2026-11-08 (owner walk, round 2):** The editor's bottom area is one stack on `Token.layoutBackground` with no hairlines between rails. **Idle:** the chips rail only — no tool row. **Editing** (a text object being edited, new or existing): the stack takes the chips rail's place at the bottom of the screen, covering it — that swap is how the leader sees they are in edit mode. Bottom to top: tool row, middle rail, top rail; the tool row is on screen for the whole edit and never covered. Ending the edit (Done, tap-off, Cancel) brings the chips rail back. Load-failed: no stack. No tool presents a sheet, modal, menu or alert: the Background sheet, the Actions sheet and the pushed media-pick page (subject to D22) are removed; the save-failure alert stays. Rejected: tools in Idle (owner, round 2: the controls belong to edit mode, entered by tapping something on the activity); an Idle "Page" button for Background/Actions (owner chose edit-mode only) | owner 2026-11-08; owner 2026-11-08 (round 2) |
| D7 | What each tool opens | The full map is in §iphone · Rails. Middle rail = the tool's choices; top rail = the picked choice's details, shown only when it has some. Tapping the open tool again closes its rails. Rejected: one rail paging through settings with a back arrow (more taps, Actions cramped) | owner 2026-11-08 |
| D8 | Typing in a rail | A field typed in a rail (an action's label, URL, prayer title and body, write prompt) is a C-045 TextInput in the top rail. The keyboard lifts the whole stack, and the tool row stays visible above the keyboard. A single-line field ends on Return; every field (multiline included — the prayer body and the write prompt, where Return types a newline) ends on a canvas tap or a tool tap, and keeps its value. A canvas tap that ends a field does nothing else (D21). Rejected: a sheet for fields (the rule is no modals) | (assumed at spec) 2026-11-08 |
| D9 | Tools in Idle | ~~In Idle the tool row sits above the chips rail. Background (🖼) and Actions (⚡) act on the page and are enabled; colour (🎨), alignment (≡) and font (Aa) act on a selected text object, so they're drawn at the disabled tone and take no tap until one is being edited. While editing text the chips rail hides and all five tools are enabled. Rejected: page tools only in Idle (the row would change shape between modes)~~ **Superseded 2026-11-08 (owner walk, round 2):** Tools appear only in Editing, all five enabled: colour (🎨), background (🖼), alignment (≡), font (Aa), actions (⚡). Background and Actions act on the page but are reached from edit mode: tap any text, or tap the canvas to add text. Idle shows no tool row, so C-102's disabled state is unused by the editor. Rejected: the Idle row with dimmed text tools (round 1) | owner 2026-11-08; owner 2026-11-08 (round 2) |
| D10 | Tap off the text | While a text object is being edited, a tap on the canvas outside it ends the edit the same way Done does: an added object left empty is dropped, otherwise the edit is kept and the document saves (one PUT). The editor stays open in Idle. Cancel is the only action that restores the document from before the edit. Rejected: tap-off doing nothing (today; edits needed Done) | owner 2026-11-08; staying in the editor (assumed at brainstorm) |
| D11 | Chips rail padding | C-081 ActivityNavBar gains a bottom-inset prop (it has none; fixed height, `ActivityNavBar.swift:56`), and the editor passes 16pt, so its chips and ＋ sit 16pt higher than today. The editor chrome ignores the bottom safe area (`ActivitiesEditorScreen.swift:388-389`), so the 16pt is measured from today's position, not added to a safe-area inset. ActivityNewScreen's C-081 per D23. Rejected: relying on the safe area alone (today; the curved corners still clip the end chips and ＋) | owner 2026-11-08 |
| D12 | Who builds the screen | The rails, the Idle tools, tap-off on the canvas, the padding and the gradient drawing are d2m's, handover lane, in five subjects: the `activities-editor` screen, the `activities-player` screen (gradient fields in its per-page background `State`), C-091 (draws `gradient`), C-102 IconButton (a new disabled state — it has none, OQ-C-102-5) and C-081 (the bottom-inset prop). The rail thumbnails (`ActivityThumbnail.Page`) are app code, not d2m. iPhone's first task files one `request_project_change` per subject with this spec as the reference; the container and mapper code against what d2m returns. Rejected: editing the d2m views in place (handover rule) | (assumed at spec) 2026-11-08 |
| D13 | The Gradient option's controls | Top rail: a ↻ Shuffle button (a new `blobs` layout from the current palette) followed by the 12 palettes as swatch chips (a palette tap regenerates with that palette). The document remembers the palette by its colours, not an id, so palettes can be retuned without breaking documents. Rejected: shuffle only (no colour choice); dragging individual blobs (a new canvas mode) | owner 2026-11-08 |
| D14 | Switching background kinds | Picking **Colour** keeps `gradient` stored but sets `background.gradient.hidden = true`, so the solid colour shows and Gradient brings the blobs back unchanged. Picking a colour sets `background.color` (what Gradient restores the base to: D17). Picking **Image** keeps the gradient as the layer under the image (visible while it loads and around a transparent image), obeying `hidden`. Picking **Gradient** clears `hidden`; on a document with no `gradient` (every activity made before this) it generates one from a random palette (D3). The rail's selected option is derived: `image` set → Image; else no `gradient` or `hidden` → Colour; else Gradient. Removing an image: D18. Rejected: deleting the gradient on Colour (one tap loses the generated look for good) | (assumed at spec) 2026-11-08 |
| D15 | "The animation icon" | The owner's "animation icon" is tool 7, Actions (glyph `zap`). The real animation tool (6) stays hidden, as do highlight (5) and the eyedropper (text-activity D17) | (assumed at brainstorm) 2026-11-08 |
| D16 | Which new activities count as untouched (backing out deletes them) | untouched = no text objects, no actions, no `background.image`, no `background.wash`, whatever `color` and `gradient` hold. `isUntouched` (`ActivitiesEditorMapper.swift:112-118`) drops its `#FFFFFF` check and `starterBackground`. Rejected: comparing against the generated starter (the container would have to keep the starter document; Shuffle in an otherwise empty activity would then keep it). | owner 2026-11-08 (audit recommendation) |
| D17 | The gradient's base colour vs the Colour pick | `gradient.base` (`#RRGGBB`, required inside `gradient`) holds the palette's darkest colour. While the gradient shows, `background.color` = `gradient.base`. Colour sets `color` to the swatch and `hidden = true`. Gradient sets `color = gradient.base` and clears `hidden`. Shuffle and a palette chip rewrite `base` and `blobs` together. Rejected: one `color` for both (D1 as written; a Colour pick overwrites the base, so Gradient can't bring it back unchanged — D14's promise breaks) | owner 2026-11-08 (audit recommendation) |
| D18 | Removing a background image | picking **Gradient** or **Colour** in the Background rail removes `background.image` and `background.wash` (one tap, no confirm). Rejected: a separate Remove chip under Image (one more control; nothing removes an image today, so without either the image covers every Gradient or Colour pick for good) | owner 2026-11-08 (audit recommendation) |
| D19 | When Background and Actions edits save, and what Cancel covers | Background and Actions edits patch the document live. In Idle they save with one PUT when their rail closes or the editor is left. During a text edit they save with that edit's commit (Done or tap-off). Cancel restores only the edited text object, keeps the page edits, and saves them if any were made. An action added and still empty (no label) when its rail closes is dropped. Rejected: a PUT per change (today `changeActions` PUTs mid-edit, carrying the half-typed text, so a later Cancel leaves the server holding text the leader cancelled); Cancel reverting the whole page (one Cancel loses unrelated background work) | owner 2026-11-08 (audit recommendation) |
| D20 | Tapping another text object while editing one | it commits the current edit exactly as tap-off does (D10), then starts editing the tapped object. Rejected: ignore the tap (today, `ActivitiesEditorContainer.swift:249`; feels broken now that tap-off commits) | owner 2026-11-08 (audit recommendation) |
| D21 | A canvas tap while a rail is open in Idle | while any rail is open or a rail field is focused, a canvas tap only closes the field or rails — it never adds a text object. With nothing open, a tap on the empty canvas adds a text object as today. Rejected: always add an object (today's `tapEmpty`, `:238-245`; with page tools usable in Idle, ending a field would drop a stray object) | owner 2026-11-08 (audit recommendation) |
| D22 | Browsing the library for a background image | the Image top rail shows the library's images as thumbnails, newest first, loading more as it scrolls, with a last "More…" chip that pushes the existing media pick page (search and Source/Tags/Leaders/Time filters, `MediaHomeContainer.swift:83, :149`) — a pushed page, not a sheet. Rejected: thumbnails only (drops search and filters from a library that grows org-wide); the pushed page only (today; the owner asked for rails) | owner 2026-11-08 (audit recommendation) |
| D23 | The 16pt chips padding on the New Activity screen | ActivityNewScreen's C-081 (`ActivityNewScreen.swift:101`) passes the same 16pt, so the bar sits in the same place on both screens. Rejected: editor only (the bar jumps 16pt between New Activity and the editor) | owner 2026-11-08 (audit recommendation) |

## Contract

The activity document is the interface: the server validates and stores it, and the iPhone editor,
the viewer and the future member web viewer read it.

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `background.gradient` in the activity document (`02-content-schema.md` §5), carried by `POST /api/lesson-versions/:id/activities`, `PUT /api/content-activities/:id` and every read returning `ContentActivity` | server | iphone (editor, viewer, rail thumbnails) | as text-activity D35 | `gradient?: { style: "blobs", base: "#RRGGBB", hidden?: boolean, blobs: Blob[] }` (`base` per D17), `Blob = { x, y, r: number, color: "#RRGGBB" }` | stored and returned unchanged; unknown keys inside `gradient` preserved | 400 `VALIDATION` when `style` isn't `"blobs"`, `blobs` has fewer than 1 or more than 8 entries, `x`/`r` fall outside 0–1, `y` outside 0–4, or `base` or a blob `color` isn't `#RRGGBB` |

No endpoint, route or response shape changes. The server accepts only `style: "blobs"`; the iPhone decoder still tolerates an unknown style (forward compatibility for a later style the server learns first).

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `ContentActivity.document` → `background.gradient` (inside the JSON document; no column) | §Contract | D1 | |

**Data plan:** none. The field lives inside the existing `document` JSON column, so no migration
runs, and existing documents have no `gradient` and render as before (D5).

## server

- `services/activity-document.ts`: add `gradient` to the `background` zod object (`:153-166`), optional,
  `.passthrough()` like its siblings, with the bounds and error of §Contract, reusing the `hex` and
  `unit` helpers (`:23-24`). The publish content hash (`:248-256`) sees the gradient like any other
  field, so a Shuffle marks a published lesson changed — intended. The 256 KB limit is
  unchanged; 8 blobs is under 1 KB.
- `docs/features/activity-viewer/02-content-schema.md` §5: document `gradient`, its draw order (D1),
  geometry (D2) and `hidden` (D14), and add one blob example to §11.
- No route, service or search change: search and summaries read only text.

## iphone

**State and models.**
- `ActivityDocument` decodes `background.gradient` leniently (an unknown `style` → ignored and
  preserved), so a malformed gradient never fails the decode (text-activity D11). `ActivityBackground`
  is synthesized Codable decoded with `?? .default` (`ActivityDocument.swift:198`): it needs a custom
  `init(from:)` with `try?` per field, or a bad `gradient` drops the whole background to the default.
- `ActivitiesEditorMapper.isUntouched` per D16.
- `ActivitiesEditorMapper` maps `gradient` into C-091's background, and the Background rail's edits
  back into the document.
- `ActivitiesEditorMapper.applyBackground` (`:184-198`) today writes `color`, and `focal` and `wash`
  only when an image exists. It gains `gradient`, `base`, `hidden` and the image removal of D18,
  keeping every other field. `motion` has no UI anywhere and stays as stored (patched by path).
- `ActivityViewerMapper.appendPage(background:)` (`:277-293`, `:360-367`) passes the gradient to the
  player screen's per-page background fields.
- `ActivityThumbnail.Page` (`:77-110`, app code) draws the gradient between colour and image, sharing
  one pure blob-drawing view with C-091 where d2m's build allows.

**Generator.**
- `MakeReady/UI2/Activities/ActivityBackgroundGenerator.swift` (D3).
- `ActivityBackgroundPalettes.swift` (D4).
- `ActivityNewContainer.textDocument` calls the generator instead of writing `#FFFFFF` (D5), taking
  `palette:` and `rng:` parameters (defaulted) so its tests stay deterministic.

**Rails** (d2m, D12). The bottom stack per D6, on `Token.layoutBackground`:

| Tool | Middle rail (C-106 of C-035 chips unless noted) | Top rail |
|---|---|---|
| 🎨 Colour | C-094 TextColorPalette (as built) | — |
| 🖼 Background | Gradient · Colour · Image | Gradient: ↻ Shuffle + 12 palette chips (D13). Colour: C-094. Image: library thumbnails per D22, then the wash colour (C-094) and opacity (system Slider), the wash shown only with an image (as today) |
| ≡ Alignment | Left · Centre · Right | — |
| Aa Font | font strip (as built) | weight row (as built) |
| ⚡ Actions | the page's actions as chips, then ＋ Add | the selected action: Kind chips (Add to Prayer List · Write · Open link · Next lesson) · Placement chips (Inline · Pinned; picking Pinned demotes the page's other pinned action to Inline — at most one, as the server enforces) · Remove (C-105, hidden on a just-added action, as today) · its fields per D8 (prayer title + multiline body, write prompt multiline, URL single-line) |

- **Actions, carried over from the sheet:** a new action is Add to Prayer List, Inline, empty label; a
  chip with an empty label reads "Action"; a tap on an inline action preview on the canvas opens the
  Actions rail with that action selected while editing; in Idle it does nothing (D6/D9 round 2, OQ-activities-editor-44). Saving and empty actions per D19.
- **Which rails survive a mode change:** starting a text edit closes the Background and Actions rails;
  ending it closes Colour, Alignment and Font. Background and Actions opened during an edit stay open
  until the edit ends.

- **The Image option's focal point:** while Image is open, a drag on the canvas moves the focal
  point and the canvas does not scroll; a tap still closes the rails (D21). (assumed at spec)
- **Tap-off (D10):** C-091's empty-canvas tap is reported while editing too. The screen reports it
  as `onTapOff`, and the container commits the edit through `model.commitEdit()` — a new method
  extracted from `done()`'s edit branch (`ActivitiesEditorContainer.swift:275-280`), which Done then
  calls too. Tapping another object while editing per D20.
- **Load-failed** keeps back only, with no stack.

**Container.**
- `ActivitiesEditorContainer`: `tapOff()` → commit the edit and save. `cancel()` and the save moments
  per D19 (`changeActions` stops PUTting on every change).
- Tool enablement per D9 is the screen's (it already derives the mode from `editingIndex`, Screen
  `:612`), drawn with C-102's new disabled state.
- `changeBackground` handles gradient, shuffle, palette and the `hidden` toggle.
- The Image option loads library images inline, copying `MediaHomeContainer.pickBackground`
  (`:506-513`: merge `mediaMap`, write the image). `MediaHomeContainer`'s pick mode stays for D22's
  "More…".

**C-091** (d2m): draws `gradient` between `color` and `image` per D1/D2 in every mode. The viewer
gets it through the `activities-player` screen (D12); the rail thumbnails are `ActivityThumbnail.Page`
(above), not C-091.

## Testing

**server.**
- `activity-document` tests: a document with a valid gradient saves and round-trips unchanged.
- Unknown keys inside `gradient` survive.
- Each bound in §Contract is rejected with 400 `VALIDATION`: `style`, the blob count of 0 and 9,
  `x` −0.1 and 1.1, `y` 4.1, `r` 1.1, a non-hex blob `color`, a missing or non-hex `base`.
- A document without `gradient` is unaffected.

**iphone.**
- `ActivityBackgroundGeneratorTests`:
  - a seeded RNG gives a fixed document
  - every blob is inside D3's ranges
  - 4 blobs per document
  - `color` is the palette's darkest colour
- `ActivityBackgroundPalettesTests`: every palette has 4–5 colours, and every colour is ≥ 4.5:1
  against white (D4).
- Decoder tests: a document with a gradient decodes; an unknown `style` decodes and re-encodes
  unchanged; a malformed `gradient` leaves `color`, `image` and `wash` decoded.
- Mapper tests:
  - Shuffle keeps the palette's colours
  - a palette chip swaps them
  - Colour sets `hidden`, and Gradient clears it
  - Image keeps the gradient
  - Colour then Gradient restores `color` to `gradient.base` (D17)
  - Gradient or Colour removes `image` and `wash` (D18)
  - Gradient on a document with no gradient generates one
  - `isUntouched` is true for a generated starter and false once an object, action or image exists (D16)
- Viewer mapper and `ActivityThumbnail` tests: a gradient reaches the page's background fields.
- Container tests:
  - `tapOff` while editing commits and saves once
  - `tapOff` on an added empty object drops it
  - Cancel restores the edited object and keeps (and saves) page edits (D19)
  - tapping another object commits, then edits it (D20)
  - a canvas tap with a rail open adds no object (D21)
  - backing out of an untouched generated activity deletes it (D16)
- `ActivityNewContainer` test: the starter document carries a `blobs` gradient.
- Screen contract tests: Idle tool enablement per D9; the rail stack replaces `sheetLayout`.
- **Tests this rewrites** (they assert today's behaviour): ActivityNewContainerTests `:38` (two
  starters equal) and `:112` (`#FFFFFF`); ActivitiesEditorMapperTests `:44-45` and
  ActivitiesEditorContainerTests `:48` (untouched = `#FFFFFF`); ActivitiesEditorScreenContractTests
  `:49-60` (`sheetLayout`); the `openTool` sheet values in ViewRegistry `:3918` and CaptureFixture
  `:1087`.

**E2E walk (one).**
1. A leader adds Text and the page opens on a blob gradient.
2. They type, then tap the canvas off the text: the text stays.
3. Relaunch and reopen: it's unchanged.
4. Background → Gradient → Shuffle twice, then a palette chip. Background → Colour → a swatch.
   Background → Gradient again: the gradient is back.
5. Background → Image → a library thumbnail.
6. Actions → ＋ Add → Kind "Next lesson" → label typed in the top rail, with the keyboard up and the
   tool row visible.
7. Throughout, no sheet ever appears and the tool row never moves off screen.
8. The chips rail clears the corners.
9. The viewer shows the same gradient.
10. Add Text again and back out without touching it: the new activity is gone (D16).

**Human-verification script** (only a person can judge these):
1. Gradients look organic and good. Add ten activities and note any palette you'd change.
2. White text reads on every one.
3. On the smallest phone (375pt), typing an action's URL keeps the field and the tool row both
   visible.
4. The chips and ＋ sit clear of the curved corners on an iPhone 17 Pro Max.

## Out of scope

- dragging or recolouring individual blobs, and animated gradients
- organization brand colours
- gradients for existing, imported or fixture activities (D5)
- the hidden animation, highlight and eyedropper tools (D15)
- any client or member-facing change
- a lesson-level shared background (`02` §5, still "later")

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | The editor screen and C-091 are d2m-built; this spec's iPhone UI is a handover change d2m makes | build-time risk: iPhone's first task files the requests (D12) and waits for d2m before the container tasks |
| F2 | Typing in a top rail above the keyboard is tight on 375pt phones | build-time risk: the d2m request pins rail heights for 375pt; human script item 3 checks it |
| F3 | The working tree on `feature/text-activity` holds uncommitted editor fixes from the 2026-11-08 walk (full-screen editor, muted Done, drag fixes, local image store) that this spec builds on — still uncommitted at the audit (10 files incl. `docker-compose.yml`'s `dev-images` service) | resolve before the build starts: commit them on `feature/text-activity` |
| F4 | stale-spec (audit): `model.commitEdit()` didn't exist; the thumbnails are app code, not C-092/C-091; the viewer needs the player screen; C-102 has no disabled state; C-081 has no inset prop and the editor ignores the bottom safe area | fixed in place: §iphone, D11, D12 |
| F5 | design (audit): six behaviours the spec left open — untouched rule, base vs Colour, image removal, save moments + Cancel scope, tap on another object, canvas tap with a rail open, library browsing, New Activity padding | ruled D16–D23, owner 2026-11-08 |
| F6 | contract (audit): D17's recommendation adds `gradient.base` — an additive required-inside-optional hex field, checked against the server's `hex` helper; no consumer exists yet beyond iphone | D17 ruled 2026-11-08: §Contract carries `base`; the server task validates it |
| F7 | A failed save bumps `screenGeneration` and re-seeds the screen (`ActivitiesEditorScreen.swift:368`, Container `:58`), resetting open rails and the selected palette | build-time risk: the editor-wiring task checks that a failed tap-off save keeps the rails, or accepts the reset and says so |
| F8 | The Image focal drag competes with C-091's vertical ScrollView (`ActivityCanvas.swift:262`) on a tall page | build-time risk: the d2m editor-screen request pins "no scroll while Image is open"; walk step 5 checks it |
| F9 | D4's 4.5:1 rule means every palette colour has relative luminance ≤ 0.183 — deep tones only, no bright yellows or pastels. Blends of compliant colours stay compliant, so testing each palette colour suffices | build-time risk: the palettes task shows the owner the 12 palettes before committing; human script item 1 |

## Plan

The plan, task by task: `docs/features/text-activity-v2/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · Validate `background.gradient` on the server
- Phase 2 · Task 2 · Decode `background.gradient` without losing the background
- Phase 2 · Task 3 · Palettes and the blob generator
- Phase 2 · Task 4 · New activities start on a gradient and still auto-delete when untouched
- Phase 2 · Task 5 · Background document operations
- Phase 3 · Task 6 · File the d2m handover requests and wait for the builds
- Phase 4 · Task 7 · Tap-off, tap-another and the save moments
- Phase 4 · Task 8 · Wire the Background rail, the inline image picker and the tool states
- Phase 4 · Task 9 · The viewer and the rail thumbnails draw the gradient

## Fixes

- [x] iphone — the study-program-home rail slide (C-079 ActivityScreenshot, 112pt at 440:956) showed a cropped page: `ActivityThumbnail` still rendered at C-061's 33×44 and cropped the page's middle, then C-079 aspect-filled that 3:4 image and cropped its sides. Now it renders the whole page at 112 × 243.3pt (render version 2 in the cache key, so old crops redraw). Owner report 2026-11-08, "Nathan's Private Study" (local)
- [ ] iphone (d2m: activities-editor) — D6/D9 superseded: Idle shows the chips rail only; while editing, the tool row and rails take the chips rail's place at the bottom of the screen (covering it — the edit-mode signal), all five tools enabled. Owner walk round 2, 2026-11-08
- [x] iphone — D3/D4 superseded: palettes retuned to a dark base (≥ 4.5:1) + vivid blobs (≥ 3:1, saturation ≥ 0.55), blob radius 0.6–1.0; palette and generator tests updated. Owner walk round 2
- [ ] iphone (d2m: C-092 + activities-editor) — pinch and rotate need both fingers on the text and the move follows only the first finger, so a rotate drags the text around. Pinch/rotate must work anywhere on the canvas for the object being manipulated (the one under the first touch), and the move must follow the touch centroid. Owner walk round 2
- [ ] iphone (d2m: C-092) — a rotated or scaled object's tap area is its unrotated, unscaled layout rectangle (`contentShape` applied outside `rotationEffect`/`scaleEffect`, `CanvasTextObject.swift:254-286`), so taps on rotated or enlarged text miss. The tap area must follow the rendered, transformed shape. Owner walk round 2
