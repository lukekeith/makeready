---
name: d2m-detect
description: Propose the components and containers on ONE design screenshot as drawings — read what is already drawn, walk the picture (or just one selected drawing's rect, --within), propose rects with names (or a link to an existing row) through put_drawings, print the count, and STOP. Mints nothing, writes no spec, no artwork, no element map; the user confirms the proposals in the d2m app and mints them (Create N components on a screen or component, Mint on a collection). Started by the app's Analyze button, re-runnable at any time. Designed to run in a FRESH session.
argument-hint: <subject-id> [--frame <slug>] [--within <drawing-id>[,<drawing-id>…]] [--project <slug>] [--era <key>]
---

# Detect — $ARGUMENTS

Propose drawings on **$ARGUMENTS**. This is the DETECT phase: the output is `proposed` drawings on
one image in **d2m** — never a registry row, never a spec, never a file. One image per run; the
run ends when `put_drawings` has been called once — once per box when `--within` is a list.

**Arguments:** `<subject-id>` is a collection id (`shared-edit-field`), a screen id, or a
component code (`C-051`). `--frame <slug>` picks the image: a collection's or a screen's frame,
or a component's PREVIEW (the app sends the one the user is looking at — a component's previews
are its frames, and two previews may show the same picture); a subject with one image needs no
flag. `--within <drawing-id>` is the drawing the user had selected when they clicked
**Analyze {name}**: the run looks ONLY inside that drawing's rect and proposes what it holds —
the id, rect and name come from `get_drawings`. A **comma-separated** list of ids is every box
of one new component's name group (the pane's "all N boxes" — Luke, 2026-09-28): the same
component drawn N times. Walk each box as its own scoped run, carrying what the first taught you
to the rest (they share a design, so a part found in one is looked for in each), and write each
box separately. Without it the
button read **Analyze this screenshot** and the whole image is the scope. `--project <slug>` and
`--era <key>` override the scope this repo's `.mcp.json` pins — the d2m app appends them. **Pass
all of them through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Only one write exists for this run:** `put_drawings`. Never `mint_component_id`,
  `commit_drawings`, `upsert_component`, `upsert_screen`, `put_element_map`, `attach_asset`,
  `add_decision`, `append_note`. Confirming is the USER's click; minting is theirs too (or
  `/d2m-component`'s, which mints only what they confirmed).
- **Add around confirmed work; never re-propose it.** Everything `get_drawings` returns with
  `status: confirmed` — and every drawing with `source: user` — is settled. Do not propose a rect
  that duplicates one, do not propose a different name for one. `put_drawings` cannot touch them
  even if you try, but a duplicate proposal is noise the user has to delete.
- **An instance of a known row is linked, not named.** When the picture shows a component the
  registry already has (`list_components`), the proposal carries `rowCode` and no `name`.
  `put_drawings` rejects a `name` that matches a live row for this reason.
- **A `screen` drawing is the user's and only the user's.** `get_drawings` may return
  `kind: "screen"` boxes — the user drew each around one screen of a multi-screen export and
  named it as a reusable pattern (only a collection holds them). Never propose one, never rename
  one, never propose a box that duplicates one: `put_drawings` rejects `kind: "screen"` by key.
  A screen box IS a scope: with `--within` it, propose inside it exactly as inside a container;
  unscoped, a proposal that lands inside a screen box nests under it (or under the deepest
  container inside it).
- **Names obey `get_registry_rules`:** role-based, PascalCase, the family suffix the rules ask for,
  never a Figma layer name (`Frame 12`, `Group 3`) and never the first consumer's name.
- **No spec content.** No props, no states, no deviations, no tokens. A `note` is one sentence on
  what the thing is FOR in this picture, and only when the picture makes it plain.
- **Tools describe themselves; d2m's code does not.** Never read d2m's source or another
  skill's SKILL.md to work out a tool; if a tool cannot do what this skill says, say so and
  continue.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()` — **state the project slug and era key in your first report line.**
2. `get_drawings(subject: "<subject-id>", frame: "<slug>")` (omit `frame` when none was given)
   → the image's `assetId`, its `scale`, its `width`/`height`, its `crop` (propose nothing outside
   it), and every drawing already there, as a tree with rects in fractions AND design points.
   Note which are `confirmed` or `source: user` — those are the fixed points this run adds
   around — and which are earlier `proposed` ones (yours to replace, phase 2). With `--within`,
   find that id in the tree: its rect (in points) is the region you walk, its children are what
   is already drawn there. Not in the tree → stop: print one line `no drawing <id> on this
   image` and call nothing. A list: find every id the same way; any one missing stops the run
   the same way, before anything is written.
3. `list_components()` — every live row with its code and name, so an instance of a known
   component is linked by `rowCode`. `get_registry_rules()` — the naming rules a new name must
   pass. **On a `C-###` subject, also `get_component(id)`:** its §5 (`consumes`) is the list of
   parts the contract already asserts — placed first, by measurement, in phase 1. A screen
   subject has no §5; its parts are what you see.
4. **The eye is the Figma Dev Mode server's `get_screenshot` on the subject's node** — a
   collection's or screen's frame `figmaNodeId` (`get_drawings` reports it per frame) or, on a
   component, the frame's `figmaNodeId` from `get_drawings` (the preview's own ref when it has
   one, else the primary ref — `get_component`'s `figmaRefs[]`, `isPrimary`). When that primary
   ref has `kind: "derived"`, screenshot its `nodeId` (the PARENT) and use the ref's `rect` to
   locate the subject's snapshot inside it — everything you propose is measured against the
   snapshot, not the parent. A SCREEN minted from a screen drawing has the same shape: its
   frame's `figmaNodeId` is the parent section and the frame's `derived` ref in `get_screen`
   carries the `rect` — screenshot the parent, locate the frame by the rect, measure against
   the frame. `get_metadata` on the same node is the structure: repeated children with the same
   name are a list, an auto-layout frame holding a title and a button is a title block.
   **No node, or no Figma MCP in this session → stop:** print one line
   `no picture to analyze — <no Figma node | Figma MCP not available>` and call nothing; never
   propose from the layer tree alone.

**Exit checklist 0:** project + era stated ✓ · existing drawings read, confirmed/user ones
listed ✓ · `--within` drawing found, its rect and children noted (or no flag) ✓ · registry +
naming rules loaded ✓ · layer tree + picture read, or stopped with the one-line report ✓

## 1. Propose

**Known parts first, by measurement.** On a `C-###` subject whose §5 names parts (phase 0.3),
do not find them by eye: the node tree has their exact bounds. For each row in `consumes` and
each instance of it under the subject's node (`get_metadata` — an INSTANCE child whose main
component is that row's node, or whose name is the row's Figma name), its rect in design points
= the child's bounds − the snapshot node's origin (for a `derived` primary ref, − the ref's
`rect` origin within the parent), ÷ the file's scale. Skip an instance the tree already shows
linked to that row (`rowCode`, rects overlapping by more than half) — confirmed or proposed.
These go into the phase-2 call as `{ kind, rowCode, points }`, no `name`. A §5 part the tree
cannot locate (flattened layers, a hidden instance, a subject with no node) is `not placed:
<C-### Name> — <reason>` in the report; do not fall back to guessing its rect — propose by eye
below only what §5 does NOT already name. `--within` narrows this too: only parts inside the
selected drawing's rect.

Then walk the image top-to-bottom — or, with `--within`, walk ONLY the selected drawing's rect
top-to-bottom, as if it were the image. For every region that is visibly a thing:

- **A component subject is the outermost container.** On a `C-###` the image IS that
  component: never propose a rect spanning the image, and never a proposal named as the
  subject; propose what it holds (its list container, its rows, its known parts).
- **The `--within` drawing is the outermost container of a scoped run.** Never re-propose it,
  never rename it, never propose outside its rect — `put_drawings` rejects those as
  `outside <name>`. Everything you propose lands as its child (or a descendant); do not give
  those proposals a `parentKey` unless the parent is another container IN THIS CALL. If the
  selected drawing is a `component`, every proposal will be rejected with the fix (the user sets
  its Kind to container) — report that line and stop; it is theirs to change.
- **A container** — a repeated group (a list of near-identical rows, a grid of cards), a title
  block (title left, action right), a card, a section with its own background, **or any
  row/cell that visibly holds a component the registry already has.** A suggestion row holding
  a `+` that is `C-021 GlyphButton` is a container named `AISuggestion`, with the `+` as its
  `rowCode: "C-021"` child in the SAME call, `parentKey` set to the row's `key`. Containers
  nest; a container's rect must hold all of its children. Repeated containers share one name
  exactly as repeated components do.
- **A component** — a leaf with nothing inside it: a button, a field, a chip, an avatar, a
  plain text row.
- **A known row** — `rowCode: "C-###"`, no `name`. A known instance nested inside another row
  is the container case above, never a child of a component — `put_drawings` rejects a child
  whose parent is not a container.
- **A new thing** — a `name` that passes the naming rules. The same name on every instance:
  three suggestion rows are three proposals named `AISuggestion`, not `AISuggestion1/2/3`.
- **A note** — one sentence, only when the purpose is plain ("the list of AI-proposed field
  values; `+` adds one").

Rects are in **design points** (`points: { x, y, w, h }`, measured against `width ÷ scale` ×
`height ÷ scale`) or **fractions** (`rect`, 0–1 of the full image) — one or the other per
proposal; `put_drawings` converts. Keep every proposal inside the `crop` when there is one, and
inside its container. Skip what is already drawn and confirmed; skip decoration (dividers,
backgrounds with nothing in them); skip text that is not a component (a paragraph is a
component's content, not a component).

**Exit checklist 1:** §5 parts placed by measurement (N placed / M already drawn / K not
placed, reasons noted; or no §5) ✓ · containers found for every repeat/title block/card ✓ ·
every known instance carries `rowCode` ✓ · every new name passes the rules ✓ · nothing
proposed over a confirmed or user drawing ✓

## 2. Write once, report, stop

```
put_drawings(subject: "<subject-id>", frame: "<slug>", within: "<drawing-id>", replaceProposed: true,
             drawings: [{ key, kind, points | rect, name | rowCode, note?, parentKey? }, …])
```

`within` is the `--within` id, omitted when there was no flag. With a list, make
**one `put_drawings` call per box**, each with that box's id as `within` and only the proposals
inside it — `within` scopes one drawing, so a single call cannot cover two boxes. `replaceProposed: true` clears
the image's earlier `proposed` skill proposals first (never confirmed or user-drawn ones) — with
`within`, only those UNDER the selected drawing, never the drawing itself and nothing outside
it — so a re-run replaces its own previous guess instead of piling on.
The reply lists what was `accepted` (with ids) and what was `rejected` with the rule it broke —
crossed its container, outside the crop, not PascalCase, names an existing row. **Do not retry
a rejected proposal in a second call**: report it.

Print one line — `N proposed (K linked to existing rows), M rejected` — then the rejects, one per
line with the reason, then on a `C-###` subject a `Placed:` line — `P §5 parts by measurement
(C-### ×k, …), M already drawn, K not placed (<part> — <reason>)` — then **stop**. Do not confirm, do not mint, do not offer to spec: the user
confirms in the app's Drawings tab and mints them (**Create N components** on a screen or
component, **Mint** on a collection).

**Exit checklist 2:** put_drawings called once ✓ · count line printed ✓ · rejects listed ✓ ·
nothing else written ✓
