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
| D16 | Which new activities count as untouched (backing out deletes them) | ~~untouched = no text objects, no actions, no `background.image`, no `background.wash`, whatever `color` and `gradient` hold. `isUntouched` (`ActivitiesEditorMapper.swift:112-118`) drops its `#FFFFFF` check and `starterBackground`. Rejected: comparing against the generated starter (the container would have to keep the starter document; Shuffle in an otherwise empty activity would then keep it).~~ **Superseded 2026-11-09 (owner walk, round 5):** No activity is ever deleted automatically. Picking a type creates the activity for good; leaving it empty — switching chips or backing out of the editor — keeps it. `isUntouched` and the delete-on-back path in `leave()` are removed. Removing an activity is a deliberate delete only. Rejected: deleting an untouched activity on back (the owner wants a picked activity to be permanently part of the lesson) | owner 2026-11-08 (audit recommendation); owner 2026-11-09 (round 5) |
| D17 | The gradient's base colour vs the Colour pick | `gradient.base` (`#RRGGBB`, required inside `gradient`) holds the palette's darkest colour. While the gradient shows, `background.color` = `gradient.base`. Colour sets `color` to the swatch and `hidden = true`. Gradient sets `color = gradient.base` and clears `hidden`. Shuffle and a palette chip rewrite `base` and `blobs` together. Rejected: one `color` for both (D1 as written; a Colour pick overwrites the base, so Gradient can't bring it back unchanged — D14's promise breaks) | owner 2026-11-08 (audit recommendation) |
| D18 | Removing a background image | picking **Gradient** or **Colour** in the Background rail removes `background.image` and `background.wash` (one tap, no confirm). Rejected: a separate Remove chip under Image (one more control; nothing removes an image today, so without either the image covers every Gradient or Colour pick for good) | owner 2026-11-08 (audit recommendation) |
| D19 | When Background and Actions edits save, and what Cancel covers | Background and Actions edits patch the document live. In Idle they save with one PUT when their rail closes or the editor is left. During a text edit they save with that edit's commit (Done or tap-off). Cancel restores only the edited text object, keeps the page edits, and saves them if any were made. An action added and still empty (no label) when its rail closes is dropped. Rejected: a PUT per change (today `changeActions` PUTs mid-edit, carrying the half-typed text, so a later Cancel leaves the server holding text the leader cancelled); Cancel reverting the whole page (one Cancel loses unrelated background work) | owner 2026-11-08 (audit recommendation) |
| D20 | Tapping another text object while editing one | it commits the current edit exactly as tap-off does (D10), then starts editing the tapped object. Rejected: ignore the tap (today, `ActivitiesEditorContainer.swift:249`; feels broken now that tap-off commits) | owner 2026-11-08 (audit recommendation) |
| D21 | A canvas tap while a rail is open in Idle | while any rail is open or a rail field is focused, a canvas tap only closes the field or rails — it never adds a text object. With nothing open, a tap on the empty canvas adds a text object as today. Rejected: always add an object (today's `tapEmpty`, `:238-245`; with page tools usable in Idle, ending a field would drop a stray object) | owner 2026-11-08 (audit recommendation) |
| D22 | Browsing the library for a background image | the Image top rail shows the library's images as thumbnails, newest first, loading more as it scrolls, with a last "More…" chip that pushes the existing media pick page (search and Source/Tags/Leaders/Time filters, `MediaHomeContainer.swift:83, :149`) — a pushed page, not a sheet. Rejected: thumbnails only (drops search and filters from a library that grows org-wide); the pushed page only (today; the owner asked for rails) | owner 2026-11-08 (audit recommendation) |
| D23 | The 16pt chips padding on the New Activity screen | ActivityNewScreen's C-081 (`ActivityNewScreen.swift:101`) passes the same 16pt, so the bar sits in the same place on both screens. Rejected: editor only (the bar jumps 16pt between New Activity and the editor) | owner 2026-11-08 (audit recommendation) |
| D24 | The editor canvas never scrolls | In the activity editor the canvas is fixed to the screen in every mode: no vertical scroll, no scroll insets for the header or bottom bars, no autoscroll while dragging. Only the objects on it move (drag, pinch, rotate). Content placed past the screen's edge is reached by dragging objects, never by scrolling the page. The viewer (activities-player) is unchanged. Rejected: the scrolling page with bar-height insets (two-finger gestures moved the canvas and the text together — owner walk round 3) | owner 2026-11-09 |
| D25 | Grabbing a text layer | The canvas picks the object a touch acts on itself, by geometry, at the first finger-down: each object's grab area is its rendered box (centre, layout width × measured height, scale and rotation applied) padded by 24 pt on every side and at least 88 × 88 pt, tested in the object's rotated frame. The edited object wins while editing; otherwise the topmost object (last drawn) whose grab area holds the touch. A second finger anywhere on the canvas then pinches and rotates that object. A tap inside a grab area opens that object for editing (D20). Rejected: picking by a touch-down reported from the text view (it races the canvas recognizers and loses most of the time — owner walk round 3) and the tight layout box as the hit area | owner 2026-11-09 |
| D26 | One editor view: switching activities | The activity editor is one view and never navigates while the leader works in it. Tapping a chip in C-081 ActivityNavBar swaps the canvas area to that activity in place and selects that chip: no page push, replace or pop. Before switching, the current activity's unsaved changes save (one PUT, D19), an open text edit commits first (D10). The new activity opens in Idle; the leader enters edit mode by interacting with it, as with text. Back still leaves the editor. Chips are on screen in every state except a text edit, where the tool stack covers them (D6 round 2). Rejected: replacing the page per chip (text-activity D39 — each tap was a new view) | owner 2026-11-09 |
| D27 | Adding an activity in place | Tapping ＋ replaces the canvas area with the activity-type grid (C-086 ActivityTypeGrid, the same tiles and availability as the New Activity page) — no page change. While the grid shows, ＋ is disabled (C-081 gains an add-enabled flag). Picking a type creates the activity at once on the lesson's draft (as the New Activity page does today), appends its chip, selects it and swaps the canvas to it in Idle. Tapping an existing chip while the grid shows closes the grid without adding anything and swaps to that activity; ＋ re-enables. Rejected: the separate New Activity page (a new view) | owner 2026-11-09 |
| D28 | Kinds the editor can't edit yet | A chip for a kind the editor can't edit (video, youtube, write, poll) swaps the canvas area to that activity read-only, drawn as a member sees it, with the note "This activity can't be edited yet." The chip is selected; no page change, no banner; no edit mode and no tools for it. Rejected: the banner with no swap (today) and a note-only canvas | owner 2026-11-09 |
| D29 | The edit rails have no background | Following Instagram's story editor (owner's reference screenshot, 2026-11-09): no rail draws a solid background, so the canvas stays visible behind the controls. **Tool row:** the five tools sit in one container centred horizontally, 4 pt padding on every side, 8 pt corner radius, 16 pt gap between controls, filled with a dark blur material (the system's dark ultra-thin material) that blurs the canvas behind it; the selected tool keeps its selected look inside it. **Middle and top rails:** no rail background; each individual control (chip, swatch, button) carries the same dark blur material. Supersedes D6's "one stack on `Token.layoutBackground`". Rejected: the opaque rail stack (round 1 — it hides the page being edited) | owner 2026-11-09 |
| D30 | The size slider docks | While editing, when the size slider (C-093) has not been touched for 2 s, it animates left until only its right half is visible at the screen's left edge (its centre line on the edge); touching its visible half brings it fully back, and it docks again after the next 2 s untouched. It starts docked-in only after first appearing in full when an edit begins. Motion: one ease-out animation, ≈ 250 ms. Rejected: always fully shown (it covers the canvas's left edge) | owner 2026-11-09 |
| D31 | The editor's activity chips are the page's shape | ~~Every chip in the editor's C-081 rail — the screenshot chip and the empty C-061 ActivitySlide alike — has the page's 440:956 aspect, the same as C-079 ActivityScreenshot: 44 pt tall, 44 × 440 / 956 ≈ 20.25 pt wide. A screenshot fits the chip exactly (scaled to fit, never cropped), so it reads as a miniature of the phone. Supersedes OQ-C-081-6's 33 × 44 aspect-fill, top-aligned chip. Rejected: 33 pt wide (the rail grows ~28 pt taller); the program rail's 112 × 243 (too large for the bottom rail)~~ **Superseded 2026-11-09 (owner):** Every chip in the editor's C-081 rail — the screenshot chip and the empty C-061 ActivitySlide — has the page's 440:956 aspect at **72 pt tall, 72 × 440 / 956 ≈ 33.1 pt wide**; the strip is 72 pt tall. The screenshot fits exactly (scaled to fit, never cropped). Rejected: 44 pt tall / ≈ 20 pt wide (too narrow to read — owner) | owner 2026-11-09; owner 2026-11-09 (72 pt) |
| D32 | Snapping while dragging a text layer | While a text layer is moved (the centroid move), its position snaps on each axis independently to the nearest target within 8 pt on screen, and lets go only after the finger carries it 12 pt past (hysteresis). Targets: the page's vertical centre (x 220 wu); the standard padding lines — x 24 and 416 wu, y T 107 wu and the viewport less B 85 wu (110 with a pinned action); every other layer's left, right, top and bottom edges and both centre lines (a rotated layer by its rotated bounding box); and the standard gap — the dragged layer 24 wu above or below another layer. A light selection haptic plays each time a snap engages. Pinch never snaps; rotation snaps to every multiple of 45° (0°, 45°, 90°, 135°, 180° and the negatives) within 4°, so a layer is easy to level or set at a clean angle (owner 2026-11-09), with the same selection haptic on engage. The values live as named constants in one place: padding 24 wu, gap 24 wu, engage 8 pt, release 12 pt, rotation 4°. Rejected: the vertical centre only (07 §5 — too little for a consistent look) and snapping during pinch (fights the finger) | owner 2026-11-09 |
| D33 | Snap guides show only when active | A guide is drawn only while the layer is snapped to it: a 1 pt line, white at 80% opacity. Page guides (centre, padding) span the canvas; a layer-to-layer guide runs between the two layers; a gap guide is a short segment across the 24 wu gap. The reserved-zone guides (activities-editor D3: top chrome, rail, end space, pinned band) draw only while the dragged layer enters that zone, not for the whole drag. The documented vertical-centre guide (07 §5) is one of these guides. Rejected: always-visible guides while dragging (clutter; the owner wants to see only what is aligning) | owner 2026-11-09 |
| D34 | The editing controls hug their content | While editing, the tool row's band is its own 40 pt (4 + 32 + 4), not C-081's bar height (104 since D31), and its bottom edge sits 16 pt above the keyboard's top edge (or above the bottom safe area with no keyboard). Rails stack with only their own 8 pt insets between each other and the tool row — nothing added. Every editor strip (C-106 ChipStrip: Gradient · Colour · Image, font, weight, animation, actions; and the gradient rail) is centred horizontally when its content fits the width, and leading-aligned and scrollable when it overflows. C-094's dot row (C-097 and the 8 pt gap above it) is omitted entirely with one page and shown only with two or more. The gradient rail's ↻ Shuffle is a 33 × 44 `radius-card` tile with the same blur as the palette tiles, its glyph centred. Rejected: keeping the band at the bar height (32 pt slack above and below — owner: the controls take too much space, ≤ 16 pt to the keyboard) | owner 2026-11-10 (walk round 11) |
| D35 | Colour swatch pages | Text colour, background colour and the image wash share six pages of nine swatches, swiped with C-097 dots: 1 General (today's nine: White, Black, Blue, Green, Yellow, Orange, Red, Pink, Purple) · 2 Blues & teals · 3 Greens · 4 Yellows, oranges & reds · 5 Purples & pinks · 6 Neutrals (white → black, warm and cool greys). Each family page runs light → dark. A swatch is outlined when its hex equals the current colour (§9.2). Rejected: 5 pages (two families share a page) and 4 pages (fewer shades per hue) | owner 2026-11-10 (walk round 11) |
| D36 | Alignment opens a rail | While editing, tool 3 (alignment) is a category tool like colour or font: a tap opens its rail in the middle-rail slot — three C-102 icon buttons, left · centre · right (lines left-aligned, centred, right-aligned), centred per D34, each with the rail controls' blur — and closes whatever rail was open (colour, font, …); tapping it again closes it. The button matching the edited object's alignment is `selected`; a tap sets that alignment at once (one ObjectEdit) and keeps the rail open. The tool shows `selected` while its rail is open. Supersedes §3 tool 3's tap-to-cycle (center → left → right). Rejected: the cycle (the leader can't see which alignment comes next, and it leaves the previous tool's rail on screen) | owner 2026-11-10 (walk round 12) |

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
- [x] iphone (d2m: activities-editor) — D6/D9 superseded: Idle shows the chips rail only; while editing, the tool row and rails take the chips rail's place at the bottom of the screen (covering it — the edit-mode signal), all five tools enabled. Owner walk round 2, 2026-11-08
- [x] iphone — D3/D4 superseded: palettes retuned to a dark base (≥ 4.5:1) + vivid blobs (≥ 3:1, saturation ≥ 0.55), blob radius 0.6–1.0; palette and generator tests updated. Owner walk round 2
- [x] iphone (d2m: C-092 + activities-editor) — pinch and rotate need both fingers on the text and the move follows only the first finger, so a rotate drags the text around. Pinch/rotate must work anywhere on the canvas for the object being manipulated (the one under the first touch), and the move must follow the touch centroid. Owner walk round 2
- [x] iphone (d2m: C-092) — a rotated or scaled object's tap area is its unrotated, unscaled layout rectangle (`contentShape` applied outside `rotationEffect`/`scaleEffect`, `CanvasTextObject.swift:254-286`), so taps on rotated or enlarged text miss. The tap area must follow the rendered, transformed shape. Owner walk round 2
- [x] iphone (d2m: C-091 + activities-editor) — D24: the editor canvas never scrolls (no scroll, no bar-height scroll insets, no autoscroll); only its objects move. Owner walk round 3, 2026-11-09
- [x] iphone (d2m: C-091) — tap-off never fires: C-091 reports an empty-canvas tap only in Idle (`ActivityCanvas.swift:393`, `isEnabled: mode == .idle`), so the screen's editing tap-off (D10) and rail-close tap (D21) never receive it. Report the tap in every editor mode. Owner walk round 3 ("tap off the text … same as Done")
- [x] iphone (d2m: activities-editor, C-092 if needed) — D25: object picking moves into the canvas bridge, by geometry, at finger-down (padded, rotated grab rects; topmost wins; edited object first); C-092's SwiftUI touch-down probe no longer decides it. Owner walk round 3 ("I'm only able to grab it a small percentage of the time")
- [x] iphone (d2m: activities-editor, C-092) — a short drag opens edit mode: SwiftUI's tap gestures (C-092 `onTapGesture`, C-091 `SpatialTapGesture`) still fire on lift-off after the canvas bridge moved the object (`cancelsTouchesInView = false`), and the tap tolerates the small movement. A touch is a tap only when no move, pinch or rotate began during it and the finger travelled < 10 pt from finger-down. Owner walk round 4, 2026-11-09
- [x] iphone (d2m: activities-editor) — entering and leaving edit mode jumps instead of animating; the screen contract's §3 Transitions table already specifies it (Idle → Editing ≈ 170–200 ms, the object animating from its transform to the edit slot; Editing → Idle 150 ms ease-out, position + scale + rotation together). Owner walk round 4
- [x] iphone (d2m: activities-editor, C-081) — D26/D27/D28: the canvas area shows the selected activity, the type grid (C-086) or a read-only page for a non-editable kind; C-081 gains an add-enabled flag (＋ disabled while the grid shows); chip and ＋ taps never navigate. Owner walk round 5, 2026-11-09
- [x] iphone (app: ActivitiesEditorContainer) — D26/D27/D16: the model switches activities in place (save, then load the tapped activity into the same model), creates a picked type on the draft and switches to it, and never deletes an untouched activity; `selectSlide`/`addActivity` stop navigating. Owner walk round 5
- [x] iphone (d2m: C-081 filled chip + activities-editor; app: container) — the editor's activity chips show each activity's screenshot when one exists (canvas kinds: the rendered thumbnail; video: its poster; YouTube: its still), per OQ-C-081-6 (33×44, aspect-fill, top-aligned, clipped, active outline); today the chip is a stub and the editor passes no image. Owner walk round 6, 2026-11-09
- [x] iphone (d2m: activities-editor) — D29: tool row in a centred dark-blur container (4 pt padding, 8 pt radius, 16 pt gaps); middle/top rails lose their background, each control carries the dark blur material. Owner walk round 7, 2026-11-09
- [x] iphone (d2m: activities-editor, C-093 if needed) — D30: the size slider docks to the left edge (right half visible) after 2 s untouched and undocks on touch. Owner walk round 7
- [x] iphone (d2m: activities-editor, C-093 if needed) — the size slider is choppy and laggy when dragged from docked with the keyboard up: (1) every slider frame reports an ObjectEdit (`apply` with `report: true`, `ActivitiesEditorScreen.swift:731`), so the container rebuilds the screen state per frame and the focused text field re-lays text under the keyboard each frame — slider frames must be display-only with one ObjectEdit on release (§9.1a parity); (2) docked, a separate overlay takes the touch, undocks, then disappears mid-drag (`:744-756`), so the slider's own drag never receives the touch — one touch on the docked half must undock and keep tracking the same drag, relative from where it started (no thumb jump). Owner walk round 8, 2026-11-09
- [x] iphone (d2m: activities-editor, C-094) — the colour rail pages into blank space: the editor passes C-094 three pages of which two are empty (`ActivitiesEditorScreen.swift:2031`, pages 2–3 undesigned per OQ-04-1), so C-097 shows three dots and a swipe lands on a blank page; the drag is also unbounded at the ends. Only pages that hold colours exist; dots show only when there is more than one page (one dot per page); a drag past the first or last page rubber-bands back. Applies to every C-094 in the editor (text colour, page colour, wash colour). Owner walk round 9, 2026-11-09
- [ ] iphone (d2m: C-094) — when a palette gains a second page (OQ-04-1), a drag past its first or last page must rubber-band back; today only a single page springs back. Carried from round 9; not needed until a second page exists
- [x] iphone (d2m: C-081, C-061) — D31: the editor's chips (filled and empty) are 440:956 at 44 pt tall (≈ 20.25 pt wide) and the screenshot fits exactly. Owner walk round 10, 2026-11-09
- [x] iphone (d2m: activities-editor, C-091) — D32/D33: snapping on the move (targets, 8 pt engage / 12 pt release, haptic), rotation snap to every 45° within 4°, guides drawn only while active, reserved-zone guides only while entering a zone. The snap math as a pure, unit-tested function. Owner 2026-11-09 (snapping brainstorm)
- [x] iphone (d2m: C-081, C-061, ActivityNewScreen rail) — D31 superseded: chips 72 pt tall × ≈ 33.1 pt wide (440:956), strip 72 pt; screenshot fits exactly. Owner 2026-11-09
- [x] iphone (d2m: activities-editor, C-106, C-094, C-097) — D34: tool row band 40 pt at 16 pt above the keyboard; rails 8 pt apart; strips centred when they fit; no dot row with one page; Shuffle a 33 × 44 tile. Owner walk round 11, 2026-11-10
- [x] iphone (d2m: activities-editor, C-094) — D35: six swatch pages (General · Blues & teals · Greens · Yellows, oranges & reds · Purples & pinks · Neutrals); with pages now real, the carried round-9 rubber-band at the first/last page is due. Owner walk round 11
- [ ] iphone (d2m: activities-editor, glyphs) — D36: alignment opens a middle rail of three icon buttons (align left · centre · right) replacing the tap-to-cycle; opening it closes the other rails. Owner walk round 12, 2026-11-10
