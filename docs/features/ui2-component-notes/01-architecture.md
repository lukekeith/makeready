# 01 — Architecture

## Overview

Three things that only make sense together:

1. **Screen element targeting.** A screen in the 2.0 browser is a flat Figma PNG. This feature
   gives it an **element map** — one rect per component *instance* on the frame, each carrying
   the `C-###` it resolved to — so the browser can hit-test the render. Hovering draws a
   labelled bounding box; clicking selects that component.
2. **The Component tab.** A fourth right-panel tab (Screen · Component · Comments) that shows
   the selected component *without leaving the screen*: identity, artwork, designed states, an
   Open button, and its notes.
3. **Notes.** Durable, timestamped, append-only statements of intent, stored as git-tracked
   markdown beside the specs, cross-referencing other components and screens with `@` tags.
   They are **normative build input**: `/ui2-component-build` reads them, and a new
   `/ui2-component-update` verifies a built preview against spec + notes and fixes the gaps.

The through-line is that the 2.0 program can already say what a component *looks like* (Figma)
and what it *is* (the contract), but has nowhere to say what it is *for* and how it should
*behave in a particular place* — and no way to point at a thing on a screen and talk about it.

## Decisions

| # | Decision | Ruling | Who |
|---|---|---|---|
| D1 | Note storage | **Git-tracked markdown**, one append-only file per target: `docs/ui2/design-system/components/notes/C-###.md` and `docs/ui2/screens/notes/<screen-id>.md`. Written by the capture server, read directly by the skills. Notes are normative spec content, so they live where every other normative artifact lives — reviewable in a PR, diffable, and surviving a capture-DB reset. | owner 2026-09-11 |
| D2 | Notes vs comments | **Two channels, both stay.** A *comment* is pinned to a point on a version, says "this render is wrong versus Figma", and is resolved and closed by `/ui2-resolve`. A *note* is unpinned, never resolved, outlives every render, and states intent. No migration; the Comments tab is untouched. | owner 2026-09-11 |
| D3 | Note precedence | **Newer notes supersede older ones**, and **a note supersedes the spec**. `/ui2-component-update` applies the note and **reports every override** in a drift list so the owner can decide whether Figma or the spec doc should be updated. The skill never silently edits `docs/ui2` normative docs. | owner 2026-09-11 |
| D4 | Component tab depth | Title block (id + name + status), the component's frozen artwork, its designed-state list, an **Open component** button, then the notes list. Not a mirror of the component page. | owner 2026-09-11 |
| D5 | Element-map provenance | `/ui2-screen` phase 2 **authors** the map going forward (it already resolves every instance to a row — that resolution *is* the map). The 10 already-specced screens are **backfilled now** by a generator that matches Figma instance names against the registry's Figma-ref column, **hand-checked against each spec's §4 closed list**. An instance that does not match is left **unmapped**, never guessed. | owner 2026-09-11 |
| D6 | Screen notes | Screens carry notes too, same format, same UI, in the Screen tab. | owner 2026-09-11 |
| D7 | Note immutability | Notes are **append-only**: no edit, no delete in the UI. Correcting a note means writing a newer one, which D3 makes authoritative. Hand-editing the file is permitted for typos and is not a supported workflow. | *(default)* |
| D8 | Hit priority | The **smallest** rect containing the point wins, so a `C-043` chip inside a `C-037` row selects the chip. Identical-area ties resolve to the entry that appears **later** in the map, which the authoring order makes the innermost. Same rule as the existing built-render hit test (`Ui2Layout.jsx` `hitTest`). | *(default)* |
| D9 | Selection is addressable | The selected component lives in the URL as a query param (`?c=C-037`), so a selection is linkable, survives reload, and gives the chip-click a target that is not a navigation. | *(default)* |
| D10 | `@` tag storage | The typeahead inserts a **canonical token** — `@C-###` or `@<screen-id>` — and the renderer resolves it to the current display name at read time. A rename therefore never rots a note. | *(default)* |

## Requirement provenance

Owner's words (2026-09-11) → operationalized criteria. This table is the **only** place the
request appears verbatim; every other doc speaks in testable terms (REFERENCE.md §3c).

| R# | Their words | Operationalized criteria |
|---|---|---|
| R1 | "hovering over any component on the page and get a bounding box that highlights only when hovering, the bounding box is not visible otherwise" | While the pointer is over the screen render and comment mode is OFF, exactly one box is drawn: the smallest mapped instance rect containing the pointer (D8). Pointer leaving the render, or entering comment mode, removes it. Zero boxes are painted at rest. |
| R2 | "The bounding box also has a label with the component's name" | The box carries a label reading `C-### Name`, resolved from the registry at render time (not from the map's stored name). It is placed above the box's top edge, and below it when the box's top is within the label's height of the render's top edge. |
| R3 | "clicking the component in the screen will open details about that component in the Component tab" | A click on the render inside a mapped rect (comment mode OFF) sets `?c=<C-###>` and makes Component the active right-panel tab. It does **not** navigate away from the screen. |
| R4 | "add a 'Component' tab to the right panel to the right of the Screen tab" | The 2.0 right-panel tab order for a screen is exactly: Screen · Component · Comments. |
| R5 | "The component tab will have a title block at the top stating the name of the selected component" | The tab's first block shows the `C-###` id and the registry name, plus status chips for specced / built / has-artwork. With no selection it shows an empty state naming how to select (hover-and-click, or a §4 chip). |
| R6 | "a button to open that component… make the component tags like `cmp-ui2s__chip` open the clicked component in the Component tab instead of navigating" | The Component tab carries an **Open component** control that navigates to `/components/2.0/<C-###>`. A `.cmp-ui2s__chip` click in the Screen tab **selects** (R3) instead of navigating. Navigation away from the screen happens only via the Open control. |
| R7 | "a list of notes that are date and time stamped, max of two lines visible when the note is in a card form" | Each note renders as a card: a timestamp line (local time, from the note's stored UTC instant) and the body clamped to **2 lines**. A clamped card is expandable in place; expanding never navigates and never opens an editor. |
| R8 | "add a new note, which converts the entire right side below the tabs to a notepad, with 'cancel' and 'save' buttons in a button bar at the bottom" | Add-note replaces the whole right-panel area below the tab strip with a full-height composer. A button bar pinned to its bottom holds exactly **Cancel** and **Save**. Cancel discards and restores the list; Save appends and restores the list with the new note first. |
| R9 | "tag another component or screen by using the @ symbol which will open up a typeahead of all available components and screens, just like a code editor's code help" | Typing `@` in the composer opens a filtered list over the union of all registry components and all README screens, filtered as more characters are typed, dismissed on Escape, committed on Enter/Tab/click. A commit inserts the canonical token (D10). |
| R10 | "This way I can specify intended use-cases and functionality with much more precision" | Notes are normative: R11 and R12 make them binding inputs to build and verification. |
| R11 | "notes need to be taken into account when running /ui2-component-build" | The skill loads the target's notes **and each dependency's notes** in phase 0; they bind phases 3–4; and phase 6 classifies a Figma-vs-render difference that a note *caused* as expected rather than as a diff failure. |
| R12 | "a new skill called /ui2-component-update that reads the spec, all the notes, and verifies the built component (if built) meets the requirements. If it doesn't, then it will attempt to fix it." | A new `/ui2-component-update <C-###>` derives an effective requirement set from contract + notes, verifies the built preview against it, fixes what fails, recaptures, and reports. An unbuilt component yields the requirement set and a pointer to `/ui2-component-build`, not a failure. |
| R13 | "Newer notes always supersede older notes, so if I change the way something works in a newer note and forget to update the older notes, it will always defer to the newer note" | Where two notes make incompatible claims about the same property, the one with the later timestamp is applied and the older one is reported as superseded. Supersession is **per-property**, not per-note: an older note's non-conflicting statements stay in force. |

## Baseline patterns this builds on

| Pattern | Where | How it is reused |
|---|---|---|
| Element map sidecar, rects as 0–1 fractions of the render | `capture/server.mjs` `ui2ElementMap()`; files like `capture/fixtures/compare/_shots/ui2-c-030/design/iphone/*.elements.json` | Screens get the same file shape beside their snapshot, plus a `ref` field the iOS harness has no need for. |
| Hit test: smallest containing rect, deepest-first tie-break | `capture/src/pages/components/Ui2Layout.jsx:200-208` (`hitTest`) | The RULE is reused; the code is not reusable where it sits. **Corrected 2026-09-10 (audit pass 1):** `hitTest` is an inline `useCallback` that keys its label and path off `e.name` and returns no `ref`, so the screen path needs it extracted to `capture/src/lib/` (precedent: `src/lib/ui2-layout.js` + `test/ui2-layout.test.mjs`) and returning the element's `ref`. See 09 §C-6. |
| Box overlay positioned in percentages | `capture/src/components/viewer/CommentLayer.jsx` (`cmp-target-box`) | A third box variant is added (`--component`) with a label; the existing `--inspect` and `--hover` variants are untouched. |
| Hover plumbing already threaded through the render pane | `RenderPane.jsx:20,119-139,280` props `onHoverInspect` / `onClearInspect` / `hoverBox` / `inspectBox` | The props exist, but they do **not** carry this feature as-is. **Corrected 2026-09-10 (audit pass 1):** `ZoomPane.jsx:104` reports hover ONLY while comment mode is on (`:141` clears the same way) — the exact inverse of R1 — and `RenderPane` builds `commentProps` explicitly (`:119-139`), so a `componentBox` prop needs a key there. Both files are shared with the 1.0 era (`CompareDetail.jsx:523,536`, `ComponentsLayout.jsx:351`), so the change is additive and regression-checked against them. See 09 §C-3. |
| Server writes into `docs/ui2` | `capture/lib/ui2-fixture.mjs` `writeUi2Fixture()`, `capture/server.mjs` fixture PUT route | Note appends use the same "capture server owns a repo file" pattern. |
| Screen index + spec parsing | `capture/lib/ui2-index.mjs` `buildUi2Screens()` / `parseScreenSpec()` | Extended with note reading and the mention index. |
| Skill phase structure with exit checklists | `.claude/commands/ui2-component-build.md` | `/ui2-component-update` follows the same shape. |

## Out of scope (deliberate)

- **Editing or deleting a note** (D7). Correction is a newer note.
- **Notes on a component *in the context of one screen*.** A note belongs to the component
  globally; `@<screen-id>` inside the body is how a note scopes itself to a place.
- **Threaded replies on notes.** That is what comments are for (D2).
- **Rich text.** The composer is plain text with `@` tokens; rendering is plain text plus
  resolved mention chips.
- **Hover boxes on the 1.0 era**, on built `iphone` renders (they already have the Layout tab's
  own box), and on component renders. Screens only.
- **Auto-mapping instances the generator cannot resolve** (D5). Unmapped areas simply have no
  box.
- **`/ui2-screen` re-running the backfill generator.** Going forward the spec run authors the
  map as part of decomposition; the generator is a one-time migration tool.
- **Any production app change.** See `02-app-impact.md`.
