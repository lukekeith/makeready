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

[^1]: `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift:711-755`
[^2]: same file `:293`, `:646`, `:755`
[^3]: same file `:684-700`
[^4]: `docs/features/activity-viewer/02-content-schema.md` §5
[^5]: `server/src/services/activity-document.ts:153-165` (`.passthrough()`)
[^6]: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:71`
[^7]: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:238`

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Validates the new optional `background.gradient` in the activity document zod schema; `02-content-schema.md` §5 documents it | §server |
| client | ⬜ | No client code reads activity documents. The member rebuild is out of scope (text-activity D6), and it reads the documented field when it comes | — |
| iphone | ✅ | Gradient generator + palettes, new-activity starter, gradient in the mapper and decoder; the editor's rails, Idle tools, tap-off commit and chips padding (d2m screen + C-091 render, then container wiring) | §iphone |

**Sequencing:** contract settled (the document field, §Contract) → server validates it and verifies
(contract FREEZES) → iphone's first task files the d2m requests (D12) → iphone wires the generator,
mapper and container against what d2m returns → the walk.

**Backward compatibility:** the field is additive and optional. An installed TestFlight build decodes
the envelope leniently and keeps unknown fields (text-activity D11), so it shows `background.color`,
the gradient's base colour, and re-saves the gradient untouched. No transition is needed.

**Blast radius:**
- every reader of an activity document's background: the iPhone editor and viewer (C-091), the
  rail's slide thumbnails (C-092 viewer mode, text-activity D26) and the server's validator
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
| D1 | Gradient storage | `background.gradient` = `{ style: "blobs", blobs: [{ x, y, r, color }] }` with 3–5 blobs; `background.color` stays required and is the gradient's base and every renderer's fallback. Draw order: `color`, `gradient`, `image`, `wash`, content. Rejected: a seed (every platform must share one generator forever); a rendered image (an upload and a library row per activity, not reshufflable) | owner 2026-11-08 |
| D2 | Blob geometry | `x`, `y` are the blob centre and `r` its radius, each a fraction 0–1 of the background box's **width** (the box is the page: `pageHeight` under `scroll`, the viewport under `fixed`), so `y` may exceed 1 on a tall page and the picture is identical at any width. Each blob is a radial gradient from `color` at the centre to fully transparent at `r`, composited with normal blending over `color`. Rejected: wu (the same picture, but a fraction survives a future reference-width change) | (assumed at spec) 2026-11-08 |
| D3 | Generator | A new activity picks one of the curated palettes at random. The palette's darkest colour becomes `color`, and 4 blobs are drawn from its other colours: `x` uniform 0–1, `y` uniform 0–1.6, `r` uniform 0.45–0.8. A pure Swift function `ActivityBackgroundGenerator.make(palette:rng:)` with an injectable RNG so tests are deterministic. Rejected: a random hue with a harmony rule (unpredictable, some dull) | owner 2026-11-08 (palettes); (assumed at spec) the numbers |
| D4 | Palettes | 12 palettes of 4–5 hex colours, in one Swift data file. Every colour meets 4.5:1 contrast against white text (`#FFFFFF`), enforced by a unit test over every palette colour. The owner tunes them after the walk. Rejected: the organization's brand colour (orgs store none; a separate decision) | owner 2026-11-08 |
| D5 | Which activities | Only activities created from now on get a generated gradient: the Text tile's starter document (`ActivityNewContainer.textDocument`) and every future kind's starter. Existing, imported and fixture activities keep their backgrounds. Rejected: also fixtures (decide after seeing the result); converting white 1.0 content (changes authors' content unasked) | owner 2026-11-08 |
| D6 | The rail stack | The editor's bottom area is one stack on `Token.layoutBackground` with no hairlines between rails, bottom to top: chips rail (Idle only), tool row, middle rail, top rail. The tool row is on screen in every mode except Load-failed. No tool presents a sheet, modal, menu or alert: the Background sheet and the Actions sheet are removed. The save-failure alert ("Couldn't save activity", text-activity D46) is not a tool and stays. Rejected: tools only while editing (Background is page-level and was unreachable without a text edit) | owner 2026-11-08 |
| D7 | What each tool opens | The full map is in §iphone · Rails. Middle rail = the tool's choices; top rail = the picked choice's details, shown only when it has some. Tapping the open tool again closes its rails. Rejected: one rail paging through settings with a back arrow (more taps, Actions cramped) | owner 2026-11-08 |
| D8 | Typing in a rail | A field typed in a rail (an action's label, URL, prayer title and body, write prompt) is a C-045 TextInput in the top rail. The keyboard lifts the whole stack, and the tool row stays visible above the keyboard. Return or a tap on the canvas ends the field and keeps its value. Rejected: a sheet for fields (the rule is no modals) | (assumed at spec) 2026-11-08 |
| D9 | Tools in Idle | In Idle the tool row sits above the chips rail. Background (🖼) and Actions (⚡) act on the page and are enabled; colour (🎨), alignment (≡) and font (Aa) act on a selected text object, so they're drawn at the disabled tone and take no tap until one is being edited. While editing text the chips rail hides and all five tools are enabled. Rejected: page tools only in Idle (the row would change shape between modes) | owner 2026-11-08 |
| D10 | Tap off the text | While a text object is being edited, a tap on the canvas outside it ends the edit the same way Done does: an added object left empty is dropped, otherwise the edit is kept and the document saves (one PUT). The editor stays open in Idle. Cancel is the only action that restores the document from before the edit. Rejected: tap-off doing nothing (today; edits needed Done) | owner 2026-11-08; staying in the editor (assumed at brainstorm) |
| D11 | Chips rail padding | C-081 ActivityNavBar gets 16pt of extra bottom inset inside the editor, below its chips and ＋, on top of the safe area. Rejected: relying on the safe area alone (today; the curved corners still clip the end chips and ＋) | owner 2026-11-08 |
| D12 | Who builds the screen | The rails, the Idle tools, tap-off on the canvas, the padding and C-091's gradient drawing are d2m's (`activities-editor` screen and C-091, handover lane). iPhone's first task files one `request_project_change` per subject with this spec as the reference; the container and mapper code against what d2m returns. Rejected: editing the d2m views in place (handover rule) | (assumed at spec) 2026-11-08 |
| D13 | The Gradient option's controls | Top rail: a ↻ Shuffle button (a new `blobs` layout from the current palette) followed by the 12 palettes as swatch chips (a palette tap regenerates with that palette). The document remembers the palette by its colours, not an id, so palettes can be retuned without breaking documents. Rejected: shuffle only (no colour choice); dragging individual blobs (a new canvas mode) | owner 2026-11-08 |
| D14 | Switching background kinds | Picking **Colour** keeps `gradient` stored but sets `background.gradient.hidden = true`, so the solid colour shows and Gradient brings it back unchanged. Picking a colour sets `background.color`. Picking **Image** keeps the gradient as the layer under the image (visible while it loads and around a transparent image). Picking **Gradient** clears `hidden`. Rejected: deleting the gradient on Colour (one tap loses the generated look for good) | (assumed at spec) 2026-11-08 |
| D15 | "The animation icon" | The owner's "animation icon" is tool 7, Actions (glyph `zap`). The real animation tool (6) stays hidden, as do highlight (5) and the eyedropper (text-activity D17) | (assumed at brainstorm) 2026-11-08 |

## Contract

The activity document is the interface: the server validates and stores it, and the iPhone editor,
the viewer and the future member web viewer read it.

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `background.gradient` in the activity document (`02-content-schema.md` §5), carried by `POST /api/lesson-versions/:id/activities`, `PUT /api/content-activities/:id` and every read returning `ContentActivity` | server | iphone (editor, viewer, rail thumbnails) | as text-activity D35 | `gradient?: { style: "blobs", hidden?: boolean, blobs: Blob[] }`, `Blob = { x, y, r: number, color: "#RRGGBB" }` | stored and returned unchanged; unknown keys inside `gradient` preserved | 400 `VALIDATION` when `style` isn't `"blobs"`, `blobs` has fewer than 1 or more than 8 entries, `x`/`r` fall outside 0–1, `y` outside 0–4, or a `color` isn't `#RRGGBB` |

No endpoint, route or response shape changes.

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `ContentActivity.document` → `background.gradient` (inside the JSON document; no column) | §Contract | D1 | |

**Data plan:** none. The field lives inside the existing `document` JSON column, so no migration
runs, and existing documents have no `gradient` and render as before (D5).

## server

- `services/activity-document.ts`: add `gradient` to the `background` zod object, optional,
  `.passthrough()` like its siblings, with the bounds and error of §Contract. The 256 KB limit is
  unchanged; 8 blobs is under 1 KB.
- `docs/features/activity-viewer/02-content-schema.md` §5: document `gradient`, its draw order (D1),
  geometry (D2) and `hidden` (D14), and add one blob example to §11.
- No route, service or search change: search and summaries read only text.

## iphone

**State and models.**
- `ActivityDocument` decodes `background.gradient` leniently (an unknown `style` → ignored and
  preserved), so a malformed gradient never fails the decode (text-activity D11).
- `ActivitiesEditorMapper` maps `gradient` into C-091's background, and the Background rail's edits
  back into the document.
- `ActivitiesEditorMapper.applyBackground` today only writes `color`, `focal` and `wash`. It gains
  `gradient` and `hidden`, keeping every other field.

**Generator.**
- `MakeReady/UI2/Activities/ActivityBackgroundGenerator.swift` (D3).
- `ActivityBackgroundPalettes.swift` (D4).
- `ActivityNewContainer.textDocument` calls the generator instead of writing `#FFFFFF` (D5).

**Rails** (d2m, D12). The bottom stack per D6, on `Token.layoutBackground`:

| Tool | Middle rail (C-106 of C-035 chips unless noted) | Top rail |
|---|---|---|
| 🎨 Colour | C-094 TextColorPalette (as built) | — |
| 🖼 Background | Gradient · Colour · Image | Gradient: ↻ Shuffle + 12 palette chips (D13). Colour: C-094. Image: library thumbnails (D40's pick mode, inline instead of a pushed page), then the wash colour (C-094) and opacity (system Slider) |
| ≡ Alignment | Left · Centre · Right | — |
| Aa Font | font strip (as built) | weight row (as built) |
| ⚡ Actions | the page's actions as chips, then ＋ Add | the selected action: Kind chips · Placement chips (Inline · Pinned) · Remove (C-105) · its fields per D8 |

- **The Image option's focal point:** while Image is open, a drag on the canvas moves the focal
  point. No other gesture runs on the canvas while Image is open. (assumed at spec)
- **Tap-off (D10):** C-091's empty-canvas tap is reported while editing too. The screen reports it
  as `onTapOff`, and the container commits the edit (`model.commitEdit()`, which Done also calls).
- **Load-failed** keeps back only, with no stack.

**Container.**
- `ActivitiesEditorContainer`: `tapOff()` → commit the edit and save.
- Tool enablement per D9 (from `editingIndex`).
- `changeBackground` handles gradient, shuffle, palette and the `hidden` toggle.
- The Image option calls the media pick inline. `MediaHomeContainer`'s pick mode stays for any other
  caller.

**C-091** (d2m): draws `gradient` between `color` and `image` per D1/D2 in every mode, the viewer
included. The rail thumbnails (C-092 viewer mode) inherit it.

## Testing

**server.**
- `activity-document` tests: a document with a valid gradient saves and round-trips unchanged.
- Unknown keys inside `gradient` survive.
- Each bound in §Contract is rejected with 400 `VALIDATION`: `style`, the blob count of 0 and 9,
  `x` −0.1 and 1.1, `y` 4.1, `r` 1.1, a non-hex `color`.
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
  unchanged.
- Mapper tests:
  - Shuffle keeps the palette's colours
  - a palette chip swaps them
  - Colour sets `hidden`, and Gradient clears it
  - Image keeps the gradient
- Container tests:
  - `tapOff` while editing commits and saves once
  - `tapOff` on an added empty object drops it
  - Cancel restores
  - Idle tool enablement per D9
- `ActivityNewContainer` test: the starter document carries a `blobs` gradient.

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
| F3 | The working tree on `feature/text-activity` holds uncommitted editor fixes from the 2026-11-08 walk (full-screen editor, muted Done, drag fixes, local image store) that this spec builds on | resolve before the build starts: commit them on `feature/text-activity` |
