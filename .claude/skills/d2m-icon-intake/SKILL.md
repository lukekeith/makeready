---
name: d2m-icon-intake
description: Import ONE glyph from a Figma node — export the node's SVG through the Figma MCP and fill the glyph the d2m Icons page created for it, under exactly the name the user gave, with put_glyph. Mints no component, renames nothing, writes nothing else; a node holding several icons fails the run. Started by the d2m app, not by hand. Designed to run in a FRESH session.
argument-hint: <figma-url> --name <name> [--project <slug>] [--era <key>]
---

# Glyph intake — $ARGUMENTS

Import the glyph at **$ARGUMENTS** into this project's glyph library. The d2m app created the
glyph `--name` when the user pressed **Import** on the Icons page. That glyph is PENDING, with
no artwork, and this run was queued to fill it. The output is one normalised SVG on that glyph
in **d2m**. It is never a component, a file or a second glyph. One glyph per run; the run ends
when `put_glyph` has answered.

`--name <name>` is the glyph's name, chosen by the user. `--project <slug>` and `--era <key>`
override the scope this repo's `.mcp.json` pins. The d2m app appends all three to the prompt it
submits. **Pass `--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Exactly ONE write exists for this run: `put_glyph`**, called once. Never `use_glyph`,
  `attach_asset`, `upsert_component`, `mint_component_id`, `add_decision` or `append_note`.
  What draws the glyph is recorded later, by the skills that use it.
- **The name is the user's.** `put_glyph` gets `--name` exactly as given. The Figma layer name
  goes in the report as a suggested rename and is never applied: the user renames on the
  Icons page.
- **One node, one glyph.** A node that holds more than one icon mints nothing: the run ends
  failed with "<N> vectors found in <layer> — import one node URL per glyph". Never pick one of
  the icons, and never mint several. Rung 1 answers `icons > 1` for the same reason: that IS the
  failure — do not try rung 2 or rung 3 for a node that already answered more than one icon.
- **The normaliser's refusal is final.** When `put_glyph` refuses the art (a mask, a filter, an
  image, text), end the run failed with the refusal reported VERBATIM on the `✗` line — never
  summarised, never paraphrased. Never edit the SVG to get past it: the fix is in Figma.
- **Ending failed** means: write nothing more, then stop. On failure, print the phase's exit
  checklist FIRST; the `✗ <reason>` line — carrying the verbatim refusal where there is one — is
  always the very last line of the final message. The server reads only that last line for the
  glyph's tile (a checklist printed after it would bury the reason). The glyph stays pending,
  and the Icons page offers Retry and Remove on its tile.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.**
2. Parse the Figma URL from `$ARGUMENTS`. The file key is the path segment after `/design/`
   or `/file/`. The node id is the `node-id` query value with its `-` turned into `:`
   (`node-id=3622-5999` → `3622:5999`). If the URL has no `node-id`, end failed: "the URL names
   no node — import a node URL".
3. `get_glyph(name: "<name>")` reads the glyph this run fills:
   - `pending: true` is the usual case: the Figma import is waiting for its art. Fill it.
   - `pending: false` means the user chose **Replace artwork** on a minted glyph. Its usages
     stay, and phase 2 passes `replace: true`.
   - An error, or an answer whose `name` is not `<name>` (a merged name answers with its
     keeper): end failed with "no glyph `<name>` to fill in this era — import it again from the
     Icons page".

**Exit checklist 0:** project + era stated ✓ · file key + node id parsed ✓ · glyph read,
fill or replace recorded ✓

## 1. Export the SVG

Try the rungs in order. **The first rung that answers SVG text wins.** If a rung errors or
answers anything other than `<svg …>` text, note it in one line (which rung, and why) and go
straight to the next. Never ask, and never stop early. **Exception: rung 1 answers `icons > 1`
for a node that holds more than one icon — that is not a rung failure, it is the D6 multi-icon
failure below. Do not try rung 2 or rung 3 in that case; a second or third export would only
re-render the same multi-icon node.**

- **Rung 1: the Figma connector's `use_figma`, through the Plugin API.** Load the `figma-use`
  skill first if this session has it.
  ```js
  const n = await figma.getNodeByIdAsync('<nodeId>');
  if (!n) return { missing: true };
  const HOLDERS = ['COMPONENT_SET', 'SECTION', 'FRAME', 'GROUP'];
  const ICONS = ['COMPONENT', 'INSTANCE', 'FRAME', 'GROUP'];
  const icons = HOLDERS.includes(n.type) && 'children' in n
    ? n.children.filter((c) => c.visible && ICONS.includes(c.type) && 'children' in c).length
    : 0;
  const svg = icons > 1 ? null : await n.exportAsync({ format: 'SVG_STRING' });
  return { name: n.name, type: n.type, icons, svg };
  ```
  In short, rung 1 is `exportAsync({ format: 'SVG_STRING' })`. If it answers `missing: true`,
  the node is gone: end failed with "node <nodeId> not found in <fileKey>".
- **Rung 2: the connector's `download_assets`.** Call `mcp__claude_ai_Figma__download_assets`
  with `fileKey`, `nodeId` and `defaultFormat: "svg"`. It answers `{"export":{"url":…}, …}`.
  Download `export.url` with `curl -sL -o /tmp/glyph-<name>.svg "<url>"` and read the file's
  text.
- **Rung 3: REST, only when `$FIGMA_TOKEN` is set in this terminal's environment.**
  `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/images/<fileKey>?ids=<nodeId>&format=svg"`
  answers `{"images":{"<nodeId>":"<url>"}}`. A non-null `err` means it did not render. Then run
  `curl -sL -o /tmp/glyph-<name>.svg "<url>"`. Never write the token into the report. If the
  token is unset, skip this rung without comment.
- **No rung answered?** End failed with "no SVG export for node <nodeId> — <each rung and why>".

**How many icons the node holds.** Rung 1 counts them (`icons`). If rung 1 did not run, read the
node with the connector's `get_metadata` and apply the same rule to its direct children:
- The node is ONE glyph when it is a vector, a boolean, a component or an instance, or a frame
  or group whose children are only vector shapes. That holds however many paths the icon is
  drawn with.
- It holds SEVERAL when it is a component set, a section, a frame or a group with two or more
  visible children that are each a component, an instance, a frame or a group.

If it holds several, mint nothing and end failed with "<N> vectors found in <layer> — import
one node URL per glyph", where `<N>` is the count and `<layer>` is the node's name.

Keep the node's **layer name** for the report.

**Exit checklist 1:** node holds one icon ✓ · SVG text in hand, rung named ✓ · layer name
recorded ✓

## 2. Fill the glyph

`put_glyph(name: "<name>", svg: "<the exported SVG text>", source: "figma", figmaNodeId: "<nodeId>", figmaFileKey: "<fileKey>")`

Add `replace: true` only when phase 0 found the glyph minted (Replace artwork). Pass the SVG
text inline, exactly as exported: `put_glyph` normalises it. Then read the answer:

- **The glyph `<name>` with `pending: false`:** it is filled. Keep its `warnings` for the
  report.
- **A `note` that says `already in the library as <x>`:** the library already has this art.
  Nothing was filled and `<name>` stays pending. End failed with "already in the library as
  `<x>`".
- **A refusal (`put_glyph failed: …`):** the normaliser could not draw the art, or the glyph
  changed under you. End failed with that refusal reported verbatim on the `✗` line.

**Exit checklist 2:** put_glyph called once ✓ · answer read: filled, duplicate or refused ✓

## 3. Report

Print these lines, then **stop**:

- **Glyph:** `<name>` filled from node `<nodeId>` via <rung>, or its artwork replaced for
  Replace artwork
- **Warnings:** the normaliser's `warnings`, one per line, or "none"
- **Suggested rename:** the Figma layer name, kebab-cased, when it differs from `<name>`. Add
  "rename it on the Icons page if you prefer it". This run never renames.

**Exit checklist 3:** summary printed ✓ · layer name offered as a suggestion, not applied ✓ ·
nothing written but the one `put_glyph` ✓
