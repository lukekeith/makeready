---
name: d2m-component
description: Spec ONE component — from its row's saved Figma references, or a component/set link passed as an override — ingest every designed variant and state, resolve it against the project's component registry (mint a new C-### row or enrich an existing one), write the component's normative contract into d2m, and update the registry + tokens. The component-level sibling of d2m-screen for a component instead of a whole screen. Spec-writing only, no app code. Designed to run in a FRESH session.
argument-hint: [C-### id or component name] [Figma component/set URL — optional; the row's saved refs are used without it] [--project <slug>] [--era <key>]
---

# Component spec — $ARGUMENTS

Spec the component **$ARGUMENTS** for this project's era. This is the SPEC phase: output is
content in **d2m**, never app code and never a file in the project repo. Work ONE component
(one Figma component or variant set) per run; each phase ends with something verifiable.

**Arguments:** `<C-### | name>` alone → spec that registry row from its own saved Figma refs
(phase 0 reads them, primary first); a row with none cannot be specced this way. `<figma-url>`
alone → spec the component at that node (mint or enrich — phase 0 decides which). `<C-### |
name> <figma-url>` → target that registry row explicitly and attach the URL as a new ref,
overriding the saved ones for this run. A URL pointing at a whole frame/screen → stop and tell
the user to run `/d2m-screen` instead; a URL pointing at ONE instance inside a frame → resolve
to its main component/set and spec that (say you did).

`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. They are
appended by every command the d2m workbench copies, so they will usually be present. **Pass
them through to every tool call** — a run that reads one scope and writes another is the
failure this flag exists to make visible.

## How this differs from /d2m-screen

A screen run documents one *instantiation* and consumes components; this run documents the
*whole component*: every designed variant and state, the full prop contract, and its place in
the registry. It writes no screen spec, adds no screen-map node, and touches the spec queue
only if a registry-level fact recorded there goes stale. An owner-pasted component link is an
explicit designation that the component is real — this refines the project's decision register
on how far the Figma component sheet is normative (the sheet is not wholly normative, but an
owner-designated set is) — record the designation in the contract.

## Hard rules (re-read before EVERY phase)

- **Spec content only.** Writes go through `upsert_component`, `upsert_tokens`, `upsert_screen`,
  `attach_asset`, `add_decision`, `append_note`, `put_glyph`, `use_glyph` — and `commit_drawings`,
  the one write that mints registry rows
  (phase 0.4b): it turns the drawings the user has CONFIRMED on this row's images into registry
  rows, exactly as the app's **Create N components** button does. It never mints a proposed
  (dashed) or unnamed drawing; those are the user's to confirm or name. And `put_drawings`, for
  ONE purpose (phase 2.2b): placing the parts §5 resolves on this row's own picture as linked
  proposals (`rowCode`, never a name) — confirming them is the user's click. This run writes
  **no file** into the project repo — not a contract, not a token file, not a view.
- **Glyphs.** Single-colour icons are glyphs from the library: reach for `list_glyphs` and
  reference the glyph; if it is missing, mint it with `put_glyph`; a component whose content is
  only a glyph is not a component.
- **Figma is normative**: cite node URL + frozen snapshot(s) + capture date; deviations are a
  CLOSED enumerated list ending "anything else that differs from the source is a defect".
  Never "match as closely as possible", "similar to", "like the design".
- **Registry discipline**: exactly one row per component — allocate a new id with
  `mint_component_id()` only after proving no existing row covers it (check names AND anatomy —
  a geometry variant of an existing row is an amendment or a consolidation OQ, never a
  duplicate). Check the project's legacy candidate pool (its own component directory, any
  inventory doc it keeps — `project_info()` gives you `repoPath`) before minting `new`.
- **A row is retired ONLY by `/d2m-component-merge`.** When this run finds that the row it is
  speccing and another row describe one component — the owner designated the other row's Figma
  set as this one's source, the anatomies match, "consolidate" was ruled — you do NOT strike the
  other row here. Not by writing `removed` into its status, not by writing `~~name~~` into its
  cells (`upsert_component` refuses both), not by editing its "Defined in" to point at this one.
  A strike done any of those ways leaves a row that every view still lists as live, crossed out
  and unspecced. Spec THIS row, absorb the other's designed states into §3 with a
  dated change-list line saying where they came from, and finish the report with the exact
  command the owner runs next: `/d2m-component-merge <this> <other>`. If the consolidation is
  not yet ruled, it is an OQ on this contract, not a strike.
- **Naming & scoping rules** (`get_registry_rules()`) apply in full — role-based name, family
  suffix, no collisions; renames propagate the same run, and d2m keeps the old name resolvable
  rather than breaking a link.
- **Tokens by name**: new Figma variables become token rows via `upsert_tokens`; raw values
  become tokens or flagged literals — never silent.
- **One component per run.** A session may loop to another only if the user says so.
- **Tools describe themselves; d2m's code does not.** Never read d2m's own source (`~/www/d2m`,
  `packages/`, `apps/server`), your own session's transcript files under `~/.claude*/projects`,
  or another skill's SKILL.md to work out how a tool behaves — and never `find /` or sweep the
  filesystem for a file a tool should have given you. If a tool cannot do what this skill says,
  say so in the report and continue with what you have. Every one of those detours has cost a
  run minutes and answered nothing the tool's own description did not.
- **§4 takes the rulebook's shape.** The design decides which props exist; `get_rules()` (phase
  0.7) decides how the table expresses them — a state-owning row's companion callback or
  binding, one closure row per action or one enum-typed action row, a variant row's enum type,
  which rows are required, and how every callback, boolean and acronym is spelled. A contract
  that spells a callback one way while the rulebook rules another is a spec defect the build
  will not repair.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why.

## 0. Load context

1. `project_info()` — **and state the project slug and era key in your first report line.**
   A mis-pinned repo must be visible now, not after this run has written to the wrong
   registry. Keep `figmaFileKey`, `componentSheetNode` and `repoPath` from it; those are the
   only "constants" this run has, and they are per-project values.
2. `get_registry_rules()` — the full rules header, including the naming & scoping rules you are
   about to be judged against.
3. `list_components()` — you are about to search it for an existing row. `get_tokens()` for the
   populated families, `get_decisions()` in full.
4. **Where the Figma node comes from.** A URL on the command line is an override and is attached
   as a ref. With NO URL — the normal case from the d2m app — the node(s) are the row's
   `figmaRefs` in `get_component(id)`: primary first, and EVERY ref is a designed state to
   ingest (each has its own frozen picture). A row with no refs at all cannot be specced: stop
   and tell the user to add a Figma reference in the app (the row's page offers it).
   **A row minted from a drawing** has a primary ref with `kind: "derived"`: its `nodeId` is the
   PARENT frame's node (the screen frame or component the user drew on) and its `rect` is the
   fraction of that node's export the row was cut from — it is not the component's own node.
   Then also `get_drawings(row: "C-###")` → every instance of this row as drawn: its subject,
   frame, `parentNodeId`, rect in points, the user's `note` (what this is FOR, in that
   screenshot's context), the container holding it (`parent`) and the children it holds. The
   note is the contract's opening sentence (phase 3). **Also `get_drawings(subject: "C-###")`**
   → what is drawn ON this row's own images (one entry per preview that shows a distinct
   picture): its top-level drawings are its parts, each with its own children. Read both —
   `row:` is where this row is used, `subject:` is what it holds — and both feed §5's
   composition.
   **4b. Mint what the user confirmed.** When `get_drawings(subject:)` shows any drawing that is
   `confirmed`, named and not linked to a row, call `commit_drawings(subject: "C-###")` ONCE —
   the app's **Create N components** as a tool (Luke, 2026-09-20: a spec run on a drawn-over
   component creates the parts the user confirmed, so they can be linked and specced). Each
   `created` entry is now a real row with its artwork attached and the drawing linked; carry
   its code into §5 as `holds N × C-### Name`, never `(unminted)`. Everything in `skipped` stays
   as it is — a `proposed (dashed)` drawing is a guess awaiting the user's confirm, an unnamed
   one awaits a name — and is listed in the report's **Next** block, not minted. No confirmed
   unlinked drawing → skip this step, say so in the checklist. Do NOT spec the minted rows in
   this run: each is its own `/d2m-component C-###`.
5. Resolve the target: does a registry row already cover this node/set (match by Figma ref, by
   name, or by anatomy)? → this run **enriches** that row: `get_component(id)` first and carry
   its contract forward, never restart. No row → this run **mints**: either allocate the id now
   with `mint_component_id()`, or omit `code` on the phase-3 write and let `upsert_component`
   take one from the same counter. Both draw on an atomic, append-only counter and a removed
   row's id is never reissued — what is never acceptable is picking the next id by eye off the
   list.
5b. **An open build stop is part of the brief.** On an enrich, read `get_component(id).buildRun.stop`.
   When it is not null, a build of this row stopped and is waiting on this contract: its
   `reason`, `evidence` and `ownerNote` are part of this run's brief — the owner's note says how
   they want it fixed. Name, in the report, what the contract changes for it; a
   `part-not-minted` stop's part goes into §5 by its minted code (`mintedCode`) once it has one.
   The stop ticks itself off when the contract meets it — never try to close it.
6. If the row's contract is anchored in a screen spec's §4, this run MAY relocate it: the new
   component contract becomes the anchor, the screen spec's §4 subsection is replaced by a
   pointer (`upsert_screen`), and the registry "Defined in" is repointed. Relocate only when the
   component contract adds material the screen section lacks; otherwise the contract supplements
   and cross-links.
7. **Read the rulebook.** `get_rules()` — every code-pattern decision of this era answered
   once. `ruled` entries are the owner's word: §4's prop table takes the SHAPE they rule (step
   3 of phase 3). `defaulted` entries are the catalog's ★ for what is not yet ruled: use them,
   and list them in the report as "defaulted, unruled". **Never stop on an unruled decision.**
   Print `rulebook: N ruled, M defaulted`.

**Exit checklist 0:** project + era stated ✓ · registry rules + component list + tokens +
decisions loaded ✓ · drawings read (`row:` and `subject:`) ✓ · confirmed drawings minted through
`commit_drawings` (N created / none to mint), skipped ones noted for **Next** ✓ · target
resolved to mint-or-enrich with the existing contract read ✓ · id minted through
`mint_component_id()` if minting ✓ · not actually a screen URL ✓ · `buildRun.stop` read (its
reason, evidence and owner note in the brief, or none open) ✓ · rulebook read: N ruled, M
defaulted ✓

**Read the component's NOTES before writing anything in a re-spec:**

```
read_notes("C-###")
```

Notes are the owner's intent recorded since the last run — normative, and newer beats older,
per property. Always through `read_notes`; never by eye. A note that contradicts what this run
is about to write is a thing to raise, not to quietly overwrite.

## 1. INGEST — capture the whole set

0. **Derived ref → find the child node.** `get_metadata` on the ref's `nodeId` (the parent) and
   walk its children accumulating offsets; the node whose bounds match the ref's `rect` × the
   parent's width/height **within ±2 pt** on every side is the component's real node. Found →
   record the node id and proceed through steps 1–5 with THAT node as the subject, and cite it
   in §1 as `node <id>, located from the derived ref on <parent>`; the row's derived ref stays
   as provenance. Not found (the drawing spans several layers, or the design was flattened) →
   the row's snapshot — the crop the commit cut at the parent's scale — **is the normative
   snapshot**, §1 says so in one sentence (`Normative source: the crop at rect … of <parent
   node>; no single Figma node bounds it`), and steps 1 and 3 run against the parent node (its
   `get_metadata` and `get_variable_defs`), and step 4's `get_design_context` on the parent is
   read for that region only. Never invent a node id.
1. `get_metadata` on the node → if it's a variant set, enumerate every symbol (name = the
   variant-prop assignment). If it's a lone component, note that.
2. **The frozen snapshot.** First look at what you already have: `get_component(code)` →
   `figmaRefs[]` → the primary ref's `snapshotUrl` and `snapshotStale`, and the row's `snapshot`
   (`sha`, `capturedAt`). **A ref with a `snapshotUrl` and `snapshotStale: false` IS the frozen
   snapshot** — the intake or a previous run attached it. Cite its sha and date and move on;
   do not capture it again. Capture only when the primary ref has no snapshot or is stale:
   - **To LOOK at the node**, use the Dev Mode server's `get_screenshot`
     (`mcp__figma-dev-mode-mcp-server__get_screenshot`, 4×). It answers an inline image you can
     read; it does not give you a file, so it cannot be attached.
   - **To ATTACH one — the sharpest picture any route will give, and every route before
     giving up.** Read the
     node's own width × height from `get_metadata` first; that is what each rung is measured
     against. Try the rungs IN ORDER and stop at the first that lands a PNG at **2× or better**
     (`file /tmp/<code>.png` prints the pixel size — compare it to the node). A rung that
     errors, answers a non-PNG, or comes back under 2× is noted in one line (which rung, why) and
     you go straight to the next — never ask, never stop early.
     - **Rung 1 — REST at 4×, when `$FIGMA_TOKEN` is set in this terminal's environment:**
       `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/images/<fileKey>?ids=<nodeId>&format=png&scale=4"`
       answers `{"images":{"<nodeId>":"<url>"}}` (node id with its colon; a non-null `err` means it
       did not render). Then `curl -sL -o /tmp/<code>.png "<url>"`. Never write the token
       itself into a note, a report or a contract. Unset token → skip, without comment.
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
       Write the returned string to `/tmp/<code>.b64` and `base64 -d` it into the PNG. A
       return too large for the tool (a whole screen at 4×) errors — that is a fall-through, not a
       stop.
     - **Rung 4 — the connector's `get_screenshot` at 1×:** `fileKey`, `nodeId`, `maxDimension:
       4096` answers a URL; curl it. This renders at 1× and `maxDimension` never upscales, so a
       32×40 symbol comes back 32×40 — it will not pass the 2× check, and that is expected: it is
       the floor, not a candidate.
     - **No rung passed?** Attach the LARGEST PNG any rung produced (better than none) and say in
       the report which rungs ran and why each fell through. Nothing at all → note the failure and
       continue.
     Never search the filesystem or read d2m's source for a screenshot file: the ladder above
     is the whole recipe. Then `attach_asset(kind: "figma_snapshot", target: "C-###", sourcePath: "/tmp/<code>.png",
     scale: <measured>, note: "node <id>, captured <date> at <N>× via <rung>")`. `scale` is the
     MEASURED ratio — the PNG's width over the node's width from `get_metadata`, rounded, clamped
     to 1–4 — not the scale you asked for. Always pass it: the snapshot chain keeps a softer
     capture BEHIND a row's current sharper one rather than letting it take over, and it can only
     do that when told the scale.
   d2m copies the bytes into its own storage and records the sha, so a later Figma edit is a
   visible re-spec event and not silent drift. One image of the whole set where possible;
   per-variant images otherwise. The snapshot chain is **append-only and sha-keyed**:
   re-attaching identical bytes changes nothing, and only genuinely different bytes supersede —
   which is what makes "the published symbol has not drifted" a checkable claim rather than an
   assertion. Then `refresh_snapshot(target: <code>)` registers the snapshot as a design version
   per designed state, which is what gives the workbench a design side to show beside the
   render. It is idempotent on the sha, so `created: 0` is the normal answer on a re-run, and
   an `undesigned` state is skipped rather than claiming artwork it has none of.
3. `get_variable_defs` → diff against `get_tokens()`; `upsert_tokens(rows)` for the new ones
   (project naming conventions, cite the Figma variable). Raw values → token row or flagged
   literal. A color token with `scale` or `aliasOf` set is managed on the Colors page. Write it
   only to record `usedBy`; if the Figma value differs, report it rather than retrying.
4. `get_design_context` on the set (or per-variant for large sets) → geometry, spacing,
   typography, and the variant-prop type (`state?: ...` unions are the axis evidence).
5. Also probe `project.componentSheetNode` — the sheet copy of this component — if the given
   node lives elsewhere: the sheet may hold MORE variants than the pasted node. (A project with
   no `componentSheetNode` configured simply has no sheet; say so rather than guessing a node.)

**Exit checklist 1:** node + snapshot(s) + date pinned ✓ · snapshot present (already attached,
or attached this run through `attach_asset`) and its sha reported ✓ · every variant symbol enumerated ✓ · token diff written
through `upsert_tokens` ✓ · no unexplained raw values ✓ · for a derived ref: the child node
located (±2 pt) or "the crop is the normative snapshot" said ✓

## 2. RESOLVE — variants, sub-components, naming

1. **Full state/variant matrix.** List every axis × value the source designs. For each:
   consumed already (by which screen), designed-unconsumed, or newly designed. States the
   contract needs but the source doesn't design (pressed/disabled/empty/error…) become
   **proposed defaults + an OQ** — never stated as fact.
   **Drawn instances are designed evidence.** Every instance `get_drawings(row:)` returned in
   phase 0 is this component as designed somewhere else — a box the user drew on another
   subject's picture and linked to this row, often with a `note` saying why (Luke,
   2026-09-20: "this demonstrates a title on the left with a link button on the right … this
   must become a variant of SectionHeader"). For each instance: look at it — screenshot its
   `parentNodeId` and cut its `rect` (points) — and compare it with the states the matrix
   already has. Matches one → it is a consumer of that state: record it (§5, Consumed-by).
   Matches none → a **new designed variant**: propose the axis and value under the naming
   rules, enter it in the matrix as designed-unconsumed with its source cited as
   `<subject> · <frame> · node <parentNodeId> · rect`, and carry the user's `note` into §3
   as the rationale, quoted verbatim — the note is the owner's word and outranks your reading
   of the pixels. Raise an OQ only when the axis is genuinely ambiguous (a `layout` value, or
   a `trailing` slot?); never drop an instance, never re-derive the note. Its children
   (`children`, linked or proposed) are that variant's parts for step 2.
2. **Sub-components:** every nested element resolves to an existing registry row (this
   component joins its Consumed-by) or is named as a **part** that is not a row yet. For a row
   read from drawings, the parts are the container's children from BOTH `get_drawings(row:)`
   (where this row is drawn on other subjects) AND the top-level drawings of
   `get_drawings(subject:)` on this row's own images — a linked child is its `C-###` (phase
   0.4b minted every confirmed one), a proposed unconfirmed child is `<name> (proposed,
   unconfirmed)`; minting beyond what the user confirmed is never this run's call. For a set
   ingested from Figma with no drawings, a nested element the registry lacks becomes an OQ
   naming it, not a mint.
   **2b. Place the parts on the picture.** A part named in §5 and not drawn is invisible in the
   app (Luke, 2026-09-20: a specced KpiCard showed no drawing for the chart §5 named). You have
   better information than /d2m-detect's eye: the primary ref's `get_metadata` gives every child
   node's exact bounds. Walk **every instance in the node tree**, not just the parts step 2
   resolved, and draw each one **whatever step 2 ruled about its fit** (Luke, 2026-09-28: a
   re-spec of C-036 judged its option rows a poor fit for C-067 ActionMenuRow, drew nothing,
   and the owner — who built the frame from C-067 — saw no parts at all). The drawing records
   what the design is made of; whether §5 consumes it, extends it or replaces it is the OQ's
   call, and the owner can only weigh that with the instances on the picture. Per instance:
   its rect in design points = the child's bounds minus the snapshot node's origin (for a
   `derived` primary ref, minus the ref's `rect` origin within the parent), ÷ the file's scale;
   skip one `get_drawings(subject:)` already shows on this image (same row or name, rects
   overlapping by more than half). Then map it:
   - its `mainComponent` (or the set that owns it) is a registry row's Figma ref → `rowCode`
     of that row. A fit step 2 contested still links to the row it IS an instance of, with a
     `note` naming the question: `"instance of C-067 with overrides — fit is OQ-C-036-1"`.
   - a nested instance or a distinct repeated element the registry lacks → `name: "<the
     Figma component's name>"` and a `note` saying it has no row yet (and the OQ, if one
     names it). Never mint here: a named, unlinked proposal is the user's to confirm and
     `commit_drawings` mints it on a later run (phase 0.4b).
   - a distinct part that is **not an instance** — a named frame or group the user would
     point at: a button, a control, a badge (Luke, 2026-09-28: C-036's "close button" is a
     plain frame around a `Close` icon, and the run drew the fifteen rows but not it) →
     `name:` the layer's name in PascalCase (`CloseButton`) and a `note` giving its node.
     Draw it even when a ruling keeps it **inline anatomy** — part of this component, not a
     row: the note says so ("inline part of C-### per OQ-C-###-#"), and the drawing still
     shows the owner where it is. Skip only a **layout wrapper** — a frame whose children
     are all drawn themselves (the list around the rows, an auto-layout stack) — a bare
     shape or background (an overlay fill, a divider), and a glyph (it lives in the glyph
     library, not the registry).
   Then ONE call per image:
   ```
   put_drawings(subject: "C-###", frame: "<preview slug, when the row has more than one image>",
                replaceProposed: false,
                drawings: [{ key, kind: "component" | "container", rowCode: "C-###", points, note? },
                           { key, kind: "component", name: "<Figma name>", note, points }, …])
   ```
   `replaceProposed: false` — never wipe /d2m-detect's or a previous run's proposals. The app
   shows them dashed — with the row's chip, or the name — until the user confirms. A part the
   node tree cannot locate (flattened layers, an instance the file hides, an image with no
   node) is listed as `not placed: <part> — <reason>` in the report; never guess a rect from
   the pixels here — that is /d2m-detect's job, and the report names
   `/d2m-detect C-### --project <slug> --era <key>` for it. Read the reply: an `accepted` entry
   is placed, a `rejected` one is reported with its reason, not retried.
   **2c. Measure each state's place in the set picture.** Several previews share one whole-set
   snapshot, so without this every preview shows the same picture with nothing to say which
   variant is which (Luke, 2026-09-20). You already have the answer from step 1: for each §3
   state whose symbol is a child of the set node, its rect in design points = the symbol's
   bounds minus the set node's origin (for a `derived` primary ref, minus the ref's `rect`
   origin within the parent), ÷ the file's scale — the same arithmetic as 2b. Carry it into the
   phase-3 write as that state's `figmaNodeId` (the symbol) and `artwork: { points }`. An
   `undesigned` state has no symbol and sends neither; a lone component (no set) sends neither.
   The app outlines the selected variant with it on the design view; the server pins it to the
   picture it was measured on, so a re-captured snapshot simply drops the outline until the
   next run measures again — never guess a rect from the pixels to fill the gap.
3. **Naming & scoping check** on the row being minted/enriched AND its sub-components; renames
   propagate now. **This covers every axis, variant value and prop, not just the component
   name:** Figma's `Property 1` / `Variant2` / `Variant3` are placeholders it auto-assigns, and
   carrying one into the matrix, the prop table or a fixture is a spec defect — it reaches the
   generated code signature and the Data tab, and `Property 1` is not a legal identifier in any
   code flavour. Record the Figma string once in §1 as evidence, then name the axis for what it
   **selects**. If every variant differs only in one value a consumer should supply, that value
   is the prop and the variants are its designed values — drop the axis rather than renaming it.
   If the right name is genuinely unclear, **ask the owner in this run**; parking it as an
   ordinary OQ ships the placeholder into code while the OQ waits.
4. Ambiguities → ask the owner, all of a decision's questions at once; what the owner leaves
   unanswered stays an open `OQ-C-###-#` row on the contract.

   **How to ask the owner, always:** `await_answers(subject, questions: [{ question, options, recommended }])`
   — every question this decision needs in ONE call, each with the answers it offers (your proposal
   first) — then END YOUR TURN with one line naming what you filed. The questions land on the
   document as real `OQ-…` rows; the owner answers them from the Contract tab or the terminal,
   and this session is resumed with the answers by code — read them as rulings and continue from
   where you paused. Never ask in prose: a prose question ends the run with nothing filed and
   nothing to resume.

**Exit checklist 2:** matrix complete with per-variant consumption status ✓ · sub-components
resolved ✓ · parts placed on the picture through `put_drawings` (N placed / M already drawn / K
not placed, reasons noted) ✓ · every designed state's place in the set picture measured for the
phase-3 write (N of M; the rest named with why) ✓ · naming check passed ✓ · ambiguities asked
or parked ✓

## 3. WRITE — the component contract

`upsert_component(...)` with all six sections — omit `code` to mint, supply it to enrich (if
you allocated an id in phase 0.5, supply that one). An empty section means "verified none",
never "didn't look".

**Stamp the spec date.** A first spec passes `speccedAt`; a re-spec of an existing contract
passes `respeccedAt` — each as the current full ISO datetime (`2026-09-29T13:02:25.000Z`), never
a bare date. The build compares these to tell a part re-specced after its consumers, and two
specs on the same day are only told apart by the time.

**Every field is partial**: what you do not mention is left untouched, so a run that restates
§1 and §3 does not blank §5. The exception is a list you *do* supply — `deviations`, `props`,
`consumes`, a state's `propValues` — which REPLACES that list, because a closed list with one
stale member is not closed. The sections are addressed by anchor, so a re-run replaces the ones
it rewrites and leaves the rest — but every one of these must exist:

```markdown
# C-### <Name> — <one-line role>

<For a row minted from a drawing: the drawing's `note`, verbatim, as the first sentence — the
owner's own statement of what this is for.>

Status: <new | existing | existing-modified> · Specced: <date> · Owner-designated: <how this
run was invoked>

## 1. Normative source
Figma set/node URL + id + the attached snapshot(s) + capture date; sheet copy if distinct.
**Deviations (closed list):** …then "Anything else that differs from the source is a defect."

## 2. Anatomy & geometry
Structure, dimensions, spacing, typography — token names only; literals flagged.

## 3. Variant & state matrix
The CLOSED table: every axis × value, its geometry delta, and its consumption status
(consumed-by screen / designed-unconsumed / proposed-default+OQ). End with the sentence
"Variants not in this table may not be built without a ruling."

## 4. Props contract
Name, type, purpose per prop; how variants map to props — **in the rulebook's shape** (phase
0.7). Concretely: the props are flat parameters, one Model struct, or a view-model, as the
prop-shape rule says; a prop the component displays and the caller owns is a value row plus its
change-callback (or binding) row as the state-ownership rule says; each user action is a closure
row, or all of them one enum-typed row, as the action rule says; a designed variant's type cell
is the enum (or the alternative) the variant rule says, named where the enum-placement rule
puts it; a prop is required or defaulted as the optionality rule says; and every callback,
boolean and acronym in the Name column is spelled by the naming rules. A `ruled` entry's
`samples` show the shape — copy it. Where a `defaulted` entry decided a row's shape, say so in
the report.

**Never restate another row's value set.** A prop that takes a set owned by another component
cites the row — `C-021 glyph`, or `[C-021 glyph]` for a list — and d2m resolves the options
through that contract (the delegation is a real reference, resolved once at write time).
Copying the values in is a spec defect: the copy drifts the moment the owner adds one.

## 5. Composition
Sub-component registry rows consumed (IDs), and which rows/screens consume THIS component
(known + anticipated).

For a row drawn as a CONTAINER: its **parts** — each child from `get_drawings(row:)` (where it
is drawn elsewhere) AND from the top-level drawings of `get_drawings(subject:)` on its own
snapshot, each as `holds N × C-### Name` (a linked child — after phase 0.4b every confirmed
child is one) or `holds N × <name> (proposed, unconfirmed)` for a dashed guess the user has not
confirmed (it is not a row yet, and this run did not make it one). For a row drawn INSIDE a container:
the container under Consumed-by, as `C-### Name` when the container is a row, else `<name>
(unminted container on <subject>)`.

## 6. Open questions
OQ-C-###-# rows: question, blocks?, who decides.
```

**Every open question gates the build.** The owner answers them in the workbench — a click on
one of the question's `options`, or a typed answer — and `/d2m-component-build` refuses while
any is still `open`, blocking or not. So write every question **with its answers attached**:
`upsert_component`'s `openQuestions[].options` is the list of complete sentences the owner can
adopt by clicking, and `recommended` is the index of the one this run proposes.

**Every question carries a recommendation unless it genuinely cannot.** You have just read
the Figma, the tokens, the sibling contracts and the notes — for most questions (the pressed
look, the disabled look, a height to unify at, which of two tokens to cite, whether a hit
target follows C-021's 44pt) that is enough to say what the program *should* do, and the owner
would rather ratify a good default than compose one. So, per question:

- **2–4 options**, each a complete sentence the owner can adopt verbatim as the ruling
  ("Unify at 38pt everywhere — the 1px stroke sits outside a 36pt content box, as the bordered
  symbols already do"). Concrete: name the value, the token, the state. Never "option A".
- **`recommended`** = the one you would take, with the reason folded into its sentence
  (the platform convention, the sibling contract that already does it, the token that exists).
- A "proposed default" in the question text is ALWAYS one of the options, worded as the ruling
  it would become ("Ratify the proposed default — …").
- **Omit `recommended` only when the answer strongly requires the owner** — a product or scope
  call (what a feature is *for*, whether a surface exists), a design the program has no
  precedent for, a question whose answer changes other components' contracts. Then still
  offer the options you can see, and say in the question why you are not choosing.

The owner can always type their own. A question with no options is a question that waits for
prose, and a build that waits on it. On a re-spec, read the contract's questions first: one the
owner has **answered** (`status: closed`, `answer`) is a ruling — honour it in the sections and
do not re-open it; write a new question only for something genuinely new. And a question whose
own text records a resolution (an imported `~~struck~~ RESOLVED …` row) is closed, not
re-asked: send it back with `status: "closed"` and the resolution as `closedNote`.

**The state matrix is the identity boundary.** d2m keys versions, comments and fixtures on a
state's **id**, with the slug assigned once and the display label free to change — so a label
edit no longer silently re-keys a variant. Nor can a rewritten `states` array quietly drop one:
a state present in the contract and absent from what you send is **left in place** and reported
back as a warning. **Read those warnings**, and decide each one deliberately — a state that
should genuinely go is struck with `removeStates`: its preview — and the versions and threads on
it — stays in the workbench, reading as removed, and is never simply omitted and forgotten.

**Exit checklist 3:** all 6 sections written through `upsert_component` ✓ · deviation list +
matrix closed with their defect/ruling sentences ✓ · every referenced ID exists in the registry
✓ · every warning the write returned read and answered (an `artwork for <state> not stored`
warning names why) ✓ · no pre-existing state dropped by omission ✓ · §4 rows follow the
rulebook: N ruled obeyed, M defaulted (named) ✓ · each designed state sent with its
`figmaNodeId` + `artwork` from 2c ✓

## 4. UPDATE — the shared artifacts

1. Tokens — re-verify the phase-1 additions with `get_tokens()`.
2. Screens — if the contract relocated (phase 0.6), land the pointer edit with `upsert_screen`;
   if this run changed a consumed variant's status, annotate the consuming spec's
   state-coverage line the same way.
3. The **registry row is part of the same `upsert_component` call** — row minted or amended
   (dated closed change list), "Defined in" → this contract, Figma ref updated, Consumed-by
   honest (may be empty — that's fine for an owner-designated pre-spec; screens append later).
   The old "registry last" ordering existed so a crash could not leave a registry row pointing
   at a contract that was never written; d2m gives that for free, because one logical edit is
   one revision set and either all of it lands or none of it does. What still holds: **do not
   announce a row you have not written.**
4. Tell the user: project + era, the row (ID + name + mint/enrich), the variant matrix headline
   (N variants, which are unconsumed), new tokens, open OQs, any consolidation flags raised, and
   **the rulebook**: every `ruled` entry §4 obeyed (`R-## label`) and every entry it used
   defaulted, unruled (`R-## label — defaulted, unruled`), so the owner can see which
   conventions this contract assumed.
5. Before **Next**, a `Drawn variants:` line — `N new (from <subject> <frame>: <axis>=<value>
   — "<note, shortened>")`, or `none — every drawn instance matches a designed state`, or
   `none drawn` — and a `Placed:` line — `N parts on <frame> (C-### ×k, …), M already drawn, K not
   placed (<part> — <reason>)`, or `none — §5 names no parts`. Placed parts are dashed until the
   user confirms them in the Drawings tab; say so. Then a `Measured:` line — `N of M designed
   states placed in the set picture (<state> — <reason> for any not)`, or `none — lone
   component`.
6. End with a **Next** block — the UI's job is to walk the user through every component, so
   the report hands them the next step per part:
   - `Minted: C-0xx Name (artwork attached, linked from <subject>) → /d2m-component C-0xx`, one
     line per `created` entry of phase 0.4b;
   - `Pending your confirm: <name> (proposed by /d2m-detect on <frame>)` and `Pending a name: N
     drawings on <frame>`, from `skipped`;
   - nothing minted and nothing pending → `Next: none — every drawn part is a specced row or
     linked to one`.

**Exit checklist 4:** tokens ✓ · consuming screens consistent ✓ · registry row written in the
same edit as the contract, with honest Defined-in/Consumed-by ✓ · user told, with the scope
line and the rulebook list ✓
