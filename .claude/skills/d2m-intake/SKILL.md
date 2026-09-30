---
name: d2m-intake
description: Capture and classify the Figma URL(s) behind ONE intake — screenshot each node through the Figma MCP, attach the pictures to the intake, propose a state label per node and (for a new subject) a category, name and platform — then report and STOP. Writes no spec, mints nothing, touches no registry row; the user commits in the d2m wizard. Started by the d2m app, not by hand. Designed to run in a FRESH session. The hand-typed `--frames <collection-slug>` form records an existing collection's Figma frame bounds and nothing else.
argument-hint: <intake-id> [--project <slug>] [--era <key>] · or: --frames <collection-slug> [--project <slug>] [--era <key>]
---

# Figma intake — $ARGUMENTS

Capture and classify intake **$ARGUMENTS**. This is the INTAKE phase: the output is pictures and
a recommendation on the intake record in **d2m** — never a spec, never a registry row, never a
file. One intake per run; the run ends when `put_intake_result` has been called.

`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. The d2m
app appends them to the prompt it submits. **Pass them through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Only two writes exist for an intake run:** `attach_asset` with an `intake:<id>#<ordinal>` target,
  and `put_intake_result`. A third, `put_sheet_frames`, exists only in the `--frames` form below and
  is its only write. Never `upsert_component`, `upsert_screen`, `mint_component_id`, `upsert_tokens`,
  `add_decision` or `append_note`. The commit is the USER's click.
- **The ref keeps the node the user pasted.** If a URL points at an INSTANCE, resolve upward to
  its main component for the recommendation and say so in `notes` — but the ref's node id is not
  yours to change.
- **A node you cannot capture is reported, not skipped.** Set that ref's `error` (private file,
  deleted node, no permission) and carry on with the rest; the wizard shows it in red.
- **No spec content.** No deviations, no props, no tokens. Those are `/d2m-component` and
  `/d2m-screen`, which run later from the refs this intake attaches.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()` — **state the project slug and era key in your first report line.**
2. `get_intake(intake: "<intake-id>")` → `kind` (component | screen | collection), `target` (null
   for a new subject; otherwise the existing `C-###`, screen id or collection id), and `refs[]`.
   The refs whose `snapshotUrl` is null are the ones this run captures. A ref with a
   `sourceRefId` is a RE-CAPTURE of an existing reference whose URL changed — treat it like any
   other pending ref.
3. Only when `target` is null: `list_components()` (its sections are the component categories) or
   `list_screens()` (its named sections are the screen categories — never **Ungrouped**, the
   no-namespace section whose `id` is null: `ungrouped` is a reserved name the server refuses), for the kind the intake declares, and
   `get_registry_rules()` for the naming rules a proposed component name must follow. A collection
   has no categories — load neither list for one; `get_registry_rules()` is still not needed (a
   collection's name is prose).

**Exit checklist 0:** project + era stated ✓ · intake read, pending refs listed ✓ · categories
loaded when untargeted ✓

## 1. Capture every pending ref

For each pending ref, in ordinal order:

1. Capture the node — **the sharpest picture any route will give, and every route before
   giving up.** Read the node's own width × height from `get_metadata` first; that is what
   each rung is measured against. Try the rungs IN ORDER and stop at the first that lands a
   PNG at **2× or better** (`file /tmp/<intake-id>-<ordinal>.png` prints the pixel size — compare
   it to the node). A rung that errors, answers a non-PNG, or comes back under 2× is noted in
   one line (which rung, why) and you go straight to the next — never ask, never stop early.
   - **Rung 1 — REST at 4×, when `$FIGMA_TOKEN` is set in this terminal's environment:**
     `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/images/<fileKey>?ids=<nodeId>&format=png&scale=4"`
     answers `{"images":{"<nodeId>":"<url>"}}` (node id with its colon; a non-null `err` means
     it did not render). Then `curl -sL -o /tmp/<intake-id>-<ordinal>.png "<url>"`. Never
     write the token itself into a note or the report. Unset token → skip, without comment.
   - **Rung 2 — the claude.ai Figma connector's `download_assets` at 4×:**
     `mcp__claude_ai_Figma__download_assets` with `fileKey`, `nodeId`, `defaultFormat: "png"`,
     `defaultScale: 4`. It answers `{"export":{"url":…}, "rawImages":[…], "svgAssets":[…]}` — curl
     `export.url` (the render; the rest are the node's source images) the same way. It honours an
     export preset set on the node in Figma, so a node with a 1× preset comes back at 1× here: that
     is what the size check is for.
   - **Rung 3 — the connector's `use_figma`, exporting through the Plugin API at 4×:**
     ```js
     const n = await figma.getNodeByIdAsync('<nodeId>');
     const bytes = await n.exportAsync({ format: 'PNG', constraint: { type: 'SCALE', value: 4 } });
     return figma.base64Encode(bytes);
     ```
     Write the returned string to `/tmp/<intake-id>-<ordinal>.b64` and `base64 -d` it into the
     PNG. A return too large for the tool (a whole screen at 4×) errors — that is a fall-through,
     not a stop.
   - **Rung 4 — the connector's `get_screenshot` at 1×:** `fileKey`, `nodeId`,
     `maxDimension: 4096` answers a URL; curl it. This renders at 1× and `maxDimension` never
     upscales, so a 32×40 symbol comes back 32×40 — it will not pass the 2× check, and that is
     expected: it is the floor, not a candidate.
   - **No rung passed?** Attach the LARGEST PNG any rung produced (better than none) and put a
     `notes` line on the ref saying which rungs ran and why each fell through — the wizard shows
     notes. Nothing at all → note the failure (step 4) and continue.
   The Dev Mode server's `get_screenshot` is for LOOKING at the node: it answers an inline
   image you cannot save, so it is never a rung. For a component SET, capture the whole set —
   every variant in one image; for a frame, the frame. Never search the filesystem or read
   d2m's source for a screenshot file: the ladder above is the whole recipe.
2. `attach_asset(kind: "<figma_snapshot for a component intake | screen_frame for a screen or
   collection intake>", target: "intake:<intake-id>#<ordinal>", sourcePath: "/tmp/<intake-id>-<ordinal>.png",
   scale: <measured>, note: "node <id>, captured <date> at <N>× via <rung>")`. `scale` is the
   MEASURED ratio — the PNG's width over the node's width from `get_metadata`, rounded, clamped
   to 1–4 — not the scale you asked for. Always pass it: the snapshot chain keeps a softer
   capture behind a row's current sharper one rather than letting it take over, and can only
   do that when told.
3. `get_design_context` on the node → its **name** and **type** (component set / component /
   instance / frame / section). Keep both for the report.
4. **1b. Sheet frames (collection intakes only).** A collection sheet holds several screens, and the
   app cuts a minted screen at the Figma frame's exact bounds when it knows them. From the
   `get_metadata` answer for the ref's node, take its **direct children of type FRAME** (not nested
   frames, not sections, not instances) and, for each, its `x`, `y`, `width`, `height`. Convert to
   **fractions of the exported image**: `get_metadata` reports a node's direct children already in
   coordinates relative to that node's own top-left, whether the node is a SECTION or a FRAME — its
   own `x`/`y` are the page's absolute coordinates, but a child's `x`/`y` fall inside its own
   `width`/`height` unchanged (checked live against one of each on a real Figma file). So no
   subtraction of the node's own `x`/`y` is ever needed: divide `x` and `w` by the node's own `width`,
   `y` and `h` by its `height`. Then clamp `x`/`y` to 0–1 and clip `w` to `1 − x` and `h` to `1 − y`: a
   rect that runs past the image is refused by `put_intake_result` as a whole, every ref with it.
   Keep `{ figmaNodeId, name, rect: { x, y, w, h } }` per child for phase 3. Nothing here is ever a
   device size — never a device size is assumed, looked up or rounded to; the frame's own bounds are
   the answer. A section with no FRAME children returns `[]` and a one-line note.
5. Capture failed? Note the ref's ordinal and the reason; continue.

**Exit checklist 1:** every pending ref attached or its failure noted ✓ · name + type recorded per
ref ✓ · sheet frames listed per collection ref ✓

## 2. Classify (untargeted intakes only)

Skip this phase entirely when the intake has a target — the row already knows what it is.

From the node types and one look at the pictures:

- `kindLooksLike`: a component set, a component, or an instance whose main component is one →
  **component**; a single frame showing one screen → **screen**; a section, a page, or a frame
  holding **several** screens side by side or stacked → **collection**. When this disagrees with
  the intake's `kind`, say so in `notes` — the wizard offers the user a switch.
- `category`: an EXISTING section/group name from phase 0 when one fits; otherwise a new one, with
  `categoryIsNew: true`. Never a category from the other kind's list, and never **Ungrouped**
  (reserved — a screen with no category stays unassigned; propose a real domain instead). For a collection,
  `category: ""` and `categoryIsNew: false` — it has none.
- `name`: for a component, a ROLE-based name that passes `get_registry_rules()` (family suffix,
  no Figma layer names); for a screen, `<area>-<name>` in kebab case; for a collection, a short
  prose name for what the sheet holds (`Single-field edit screens`) — never a layer name.
- `platform`: `ios` / `web` / `both` when the design or the project makes it clear; else
  `unspecified`.
- Per ref, a short state `label`: the variant property's value when there is one (`state=Active` →
  "Active", `Property 1=Empty` → "Empty"); else two or three words for what the picture shows
  ("Owner view", "Loading"). The first ref is the default state unless a name says otherwise. For
  a collection, the frame's own name in two or three words.

**Exit checklist 2:** kind judged ✓ · category from the right list or marked new ✓ · name obeys the
rules ✓ · one label per ref ✓

## 3. Report

`put_intake_result(intake: "<intake-id>", refs: [{ ordinal, label, figmaName, nodeKind, error?, sheetFrames? }],
recommendation?: { … })` — `sheetFrames` is the phase-1b list, on collection refs only;
`nodeKind` is `set` for a component set, `symbol` for a lone component, `frame` for a frame,
`section` for a section, else `unknown`. `recommendation` is `{ kindLooksLike, category,
categoryIsNew, name, platform, notes }`, only for an untargeted intake.

Then print a two-line summary — how many refs captured, how many failed, and (untargeted) the
recommended kind / category / name — and **stop**. Do not offer to spec it; the wizard does.

**Exit checklist 3:** put_intake_result called once ✓ · summary printed ✓ · sheetFrames on every
collection ref ✓ · nothing else written ✓

## --frames <collection-slug> — record an existing collection's Figma frames

A separate form, typed by a human in a Claude session; the d2m app never starts it. It runs phase
1b alone for a collection that already exists (one captured before frames were recorded), and
its only write is `put_sheet_frames`. No intake is read or written.

1. `project_info()` — **state the project slug and era key in your first report line**, before any
   write; then `get_drawings(subject: "<collection-slug>")` → `frames[]`, each with its
   `frame` slug and `figmaNodeId`. A collection with no frames, or a frame with no node id, is
   reported and skipped.
2. Per frame: `get_metadata` on its `figmaNodeId` → the direct FRAME children → fractions, exactly
   as phase 1b.
3. `put_sheet_frames(collection: "<collection-slug>", frame: "<frame-slug>", frames: [{ figmaNodeId,
   name, rect }])` per frame — the call replaces that sheet's set, so pass every child every time.
4. Print one line per frame — `<frame-slug>: N frames recorded` — and stop. A refusal is printed
   verbatim; it names what to call instead.

**Exit checklist --frames:** project + era stated ✓ · frames listed from get_drawings ✓ · one
put_sheet_frames per frame ✓ · nothing else written ✓
