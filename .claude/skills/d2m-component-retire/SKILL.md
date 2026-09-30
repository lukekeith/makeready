---
name: d2m-component-retire
description: Retire an icon-only registry row into the glyph library — `/d2m-component-retire C-### --into glyphs`. Reads the row's artwork per state, asks the owner once for any glyph name that is a judgement, mints one glyph per distinct artwork with put_glyph, syncs the catalog and Glyph.swift as a child of this run with sync_glyphs, rewrites the repo's call sites to Glyph(…) under the preview directory only and deletes the absorbed c<code>-* imagesets, then — last — strikes the row with retire_into_glyphs and recaptures each consumer it edited. Refuses a row whose content is not only glyph artwork, having written nothing. (Started by the workbench's Prompt ▸ Retire… dialog.)
argument-hint: <C-###> --into glyphs [--project <slug>] [--era <key>]
---

# Component retire — $ARGUMENTS

Retire the registry row in **$ARGUMENTS** into the project's glyph library. The row draws nothing
but a single-colour icon in each of its states, so it is not a component: an icon that is only an
icon is a glyph. When this run ends, the icon exists as one glyph per distinct artwork, the repo
draws it through the generated `Glyph` view, every consumer records the glyph it draws, and the
row is struck — its code kept and never reused.

`--into glyphs` is the only destination this skill knows. Any other value ends the run failed
before any write: "only `--into glyphs` is supported — use Merge or Remove from the Retire…
dialog". `--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins,
and the command the workbench copies always carries them. **Pass `--project` and `--era` through
to every tool call.**

`<code>` below is the row's number as written in its id (`C-<code>`). The repo's own artwork for
the row lives in imagesets named `c<code>-*` — the id lower-cased without its dash (C-072 →
`c072-*`).

## Hard rules (re-read before EVERY phase)

- **Strike last.** `retire_into_glyphs` is the LAST write of the run, called once, after every
  glyph is minted, the sync has ended `done` and every call site is rewritten. A run that stops
  earlier leaves the row live — that is the safe failure. Never strike the row any other way:
  never `delete_component`, never `merge_components`, never a struck status through
  `upsert_component`.
- **One write path per thing.** Glyphs go in through `put_glyph` with `source: "absorbed"`. The
  consumers' glyph usages, the struck edges and screen uses, and the strike itself go in through
  `retire_into_glyphs` — never `use_glyph`, and never a re-put of a consumer's closed list through
  `upsert_component` or `upsert_screen` (that read-modify-write drops whatever changed since you
  read it).
- **Icon-only or nothing.** A row whose content is anything but glyph artwork — text, a child
  component, a hit target, its own layout — is not retired. The run ends failed in phase 1 with
  the reason, having written nothing.
- **Ask once.** Every name that is a judgement goes to the owner in ONE `await_answers` call, and
  then you END YOUR TURN. Never ask in prose: a prose question ends the run with nothing filed.
- **Code only under `project.previewDir` and `project.registryCasePath`**, plus deleting the
  absorbed `c<code>-*` imagesets in the glyph catalog directory and running
  `project.targetSyncCmd`. Never another part of the project repo, never a hand edit to
  `project.pbxproj` — `targetSyncCmd` is the only thing allowed to touch it — never Figma, and
  never d2m itself: a tool that fails is REPORTED — the error verbatim, and where the run
  stopped — not patched.
- **The normaliser's refusal is final.** When `put_glyph` refuses the art (a mask, a filter, an
  image, text), end failed with the refusal verbatim. Never edit the SVG to get past it.
- **Ending failed** means: write nothing more, print the phase's exit checklist, then print
  `✗ <reason>` as the very last line of the final message, and stop. Say what was already
  written (glyphs minted, files edited) so the owner knows what a re-run will find: a re-run
  finds its own minted glyphs again by hash and mints nothing twice.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 1. READ — the row, its consumers, its artwork and its call sites

1. `project_info()`. **State the project slug and era key in your first report line.** From its
   settings note `project.repoPath`, `project.previewDir`, `project.registryCasePath`,
   `project.targetSyncCmd`, `project.lintCmd` and `project.figmaFileKey`, and the two glyph
   paths: the catalog directory is `project.glyphCatalogPath`, or
   `<project.previewDir>/Resources/Glyphs.xcassets` when that is null; the generated Swift file is
   `project.glyphSwiftPath`, or `<project.previewDir>/Glyph.swift` when that is null. Every path is
   relative to `project.repoPath`.
2. `get_component(component: "C-<code>")` and `build_status(component: "C-<code>")`. End failed,
   having written nothing, when:
   - the row does not exist, or is already struck: "C-<code> is already struck";
   - the row is **not icon-only**. It is icon-only when every state draws one single-colour
     vector artwork in a fixed box, the states differ only in that artwork, its tint or its size,
     it consumes no other component, and nothing in it is text or a hit target. Otherwise: "C-<code>
     is not icon-only — <what else it draws>; use Merge or Remove from the Retire… dialog".
3. **Consumers.** From `get_component`, list the rows that consume C-<code> and the screens that
   use it. For each consuming row, `get_component(component: "C-<consumer>")` and
   `build_status(component: "C-<consumer>")`. A §4 prop anywhere whose options are delegated to
   C-<code> (its type cell names `C-<code>`) blocks the retire: end failed, having written nothing,
   with "C-<consumer>.<prop> takes its options from C-<code> — re-point that prop first".
   `retire_into_glyphs` refuses the same at the end; finding it now keeps the run from rewriting
   code it cannot finish.
4. **Artwork, per state, from the first of these sources that has it:**
   1. **The row's own assets** — a state's artwork, or an option's asset, on `get_component`.
   2. **The repo's `c<code>-*` imagesets** in the catalog directory. Read each imageset's
      `Contents.json` and take the file its `images[].filename` names — never a file name you
      guess — then read that SVG's text. Match an imageset to its state by the state's slug in
      the imageset's name, and by the view source under `project.previewDir` that names the
      imageset for that state.
   3. **The row's Figma node**, through the export ladder below: the file key and node id of the
      row's primary Figma reference on `get_component`, else `project.figmaFileKey`. Export per
      state — when the node is a component set, export each state's own variant child, never the
      set.

   A state no source has art for ends the run failed: "no artwork for C-<code> state `<state>` —
   <each source and why>".
5. **Distinct artworks.** Two states whose SVG text is identical share one glyph: they differ only
   by tint or size, which the call site carries.
6. **Call sites.** Under `project.previewDir`, find the view type that draws the row (its name on
   `get_component`, or a `C-<code>` comment beside it) and every place that constructs it. For each
   call site record: the file and line, the state it renders (a literal, or a runtime value), the
   tint the view applies for that state (a `Token` colour by name), the box it draws in, in points
   (its `.frame` size), and any modifier the view applies to its own root beyond the artwork (an
   element marker, an accessibility label). A call site outside `project.previewDir` ends the run
   failed, having written nothing: this run edits nothing there.

### The export ladder (artwork source 3)

Try the rungs in order for each state's node. **The first rung that answers SVG text wins.** If a
rung errors or answers anything other than `<svg …>` text, note it in one line (which rung, and
why) and go straight to the next.

- **Rung 1: the Figma connector's `use_figma`, through the Plugin API.** Load the `figma-use`
  skill first if this session has it.
  ```js
  const n = await figma.getNodeByIdAsync('<nodeId>');
  if (!n) return { missing: true };
  const nodes = n.type === 'COMPONENT_SET' ? n.children.filter((c) => c.visible) : [n];
  const out = [];
  for (const k of nodes) out.push({ id: k.id, name: k.name, svg: await k.exportAsync({ format: 'SVG_STRING' }) });
  return out;
  ```
  In short, rung 1 is `exportAsync({ format: 'SVG_STRING' })` on each state's own node. Match each
  child to its state by its variant name. `missing: true` means the node is gone: go to rung 2,
  and if every rung fails, end failed as above.
- **Rung 2: the connector's `download_assets`.** Call `mcp__claude_ai_Figma__download_assets` with
  `fileKey`, the state's `nodeId` and `defaultFormat: "svg"`. It answers `{"export":{"url":…}, …}`.
  Download `export.url` with `curl -sL -o /tmp/retire-<state>.svg "<url>"` and read the file's text.
- **Rung 3: REST, only when `$FIGMA_TOKEN` is set in this terminal's environment.**
  `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/images/<fileKey>?ids=<nodeId>&format=svg"`
  answers `{"images":{"<nodeId>":"<url>"}}`; a non-null `err` means it did not render. Then
  `curl -sL -o /tmp/retire-<state>.svg "<url>"`. Never write the token into the report. When the
  token is unset, skip this rung without comment.

**Exit checklist 1:** project + era stated ✓ · row live and icon-only ✓ · no prop delegates its
options to it ✓ · artwork in hand for every state, source named per state ✓ · distinct artworks
counted ✓ · every call site found inside `project.previewDir`, with its state, tint and size ✓

## 2. ASK — the glyph names

Read `list_glyphs(includeStruck: true)`. Propose one kebab-case name per distinct artwork: what
the icon means, not what the row is called, and never with a component prefix — `link`, never
`c072-link`, and never the row's name.

A name is a **judgement** — ask it — when any of these holds:

- the state's label is not an icon name (`true` / `false`, `on` / `off`, `default`, `selected`);
- two readings disagree: the state's label, the contract's artwork cell, the Figma layer name;
- the name is already in the library, minted or struck — it may be this very art, or another
  icon that needs a different name;
- its lowerCamel form is a Swift keyword or a member the generated enum declares itself
  (`default`, `return`, `self`, `init`, `label`, `raw-value`, `all-cases`, …): `put_glyph`
  refuses those, so propose another.

Ask with `await_answers(subject: "C-<code>", questions: [{ question, options, recommended }])` —
every judgement in ONE call, one question per name, your proposal first among its `options` with
`recommended: 0` and each real alternative after it — then END YOUR TURN with one line naming
what you filed. The owner answers from the Contract tab or the terminal, and this session is
resumed with the answers by code: read them as rulings and continue at phase 3.

When no name is a judgement, say so in one line and go straight on.

**Exit checklist 2:** one name per distinct artwork ✓ · every judgement asked in one call, or none
needed ✓ · answers read as rulings ✓

## 3. MINT — the glyphs, then the sync

For each distinct artwork, `put_glyph(name: "<name>", svg: "<the SVG text>", source: "absorbed")`,
adding `figmaNodeId: "<nodeId>"` and `figmaFileKey: "<fileKey>"` when the art came from Figma
(source 3). Pass the SVG text exactly as read: `put_glyph` normalises it. Read each answer:

- **The glyph `<name>`:** minted. Keep its `warnings` for the report.
- **A `note` saying `already in the library as <x>`:** that art already IS `<x>`. Nothing was
  minted; use `<x>` for those states from here on.
- **A refusal naming a reserved name:** file ONE more `await_answers` for that name alone and END
  YOUR TURN; resume here with the answer.
- **Any other refusal:** end failed with it verbatim.

Then `sync_glyphs(wait: true)` — the catalog and `Glyph.swift` are written as a child of this run,
in this run's own slot. Read the answer:

- **Any `warning:` line in `report` about the Xcode project — even when `status` is `"done"`:**
  the sync emits one of three: `warning: <project> does not build <file> yet — …`, `warning:
  <project> has no readable project.pbxproj — …`, or `warning: no .xcodeproj above <swift path> —
  …`. End failed with "Glyph.swift is not in the app target yet — add it to the Xcode project once
  by hand (the sync never edits the project file), then run Retire… again". Rewrite nothing: phase
  4's call sites would not compile. The minted glyphs stay; the re-run finds them.
- **`status: "done"` and no such warning in `report`:** Continue.
- **Any other `status`, or `timedOut: true`:** end failed with the report's last lines. Rewrite
  nothing: without `Glyph.swift` the new call sites cannot compile.

**Exit checklist 3:** every distinct artwork minted or matched, names recorded ✓ · the sync ended
`done` ✓ · `Glyph.swift` written and in the app target ✓

## 4. REWRITE — the call sites, under `project.previewDir` only

1. Read the generated Swift file (phase 1's path). Use its `GlyphName` cases and its `Glyph`
   initialiser exactly as declared: the case is the glyph name in lowerCamel (`link-off` →
   `.linkOff`), and the `size: GlyphSize` and `tint` parameters are whatever it declares. Never
   guess the signature.
2. Rewrite each call site to `Glyph(.<case>, size: <the GlyphSize case>, tint: <the state's
   tint>)`, mapping phase 1's box (recorded in points) to the `GlyphSize` case of equal points:
   `16` → `.sm`, `24` → `.md`, `32` → `.lg`. When the box matches none of those exactly, use the
   NEAREST case and add `.frame(width: <box>, height: <box>)` right after the `Glyph(…)` call to
   keep the original layout box — list that call site in the report. A call site whose state is a
   runtime value chooses the case and tint from it (`flag ? .link : .linkOff`, and the matching
   tints). Keep every modifier the call site itself carries, and move onto it each modifier the
   old view applied to its own root beyond the artwork (phase 1, step 6).
3. When no call site under `project.previewDir` constructs the old view any more, delete its type
   — and its file, when the file held nothing else. When `build_status` said the row is **built**,
   also remove its case in `project.registryCasePath`. Decoding fields are additive optionals and
   stay, re-commented to say the row was retired into the glyph library.
4. Delete the absorbed `c<code>-*` imagesets from the catalog directory — only those whose art was
   minted or matched in phase 3, and only once nothing under `project.previewDir` names them. List
   each in the report; git keeps them.
5. Run `project.targetSyncCmd` when you deleted a file and the project has one, then
   `project.lintCmd`. Fix a lint failure in a file you edited here; report any other.

**Exit checklist 4:** every call site rewritten to `Glyph`, tint and size carried ✓ · the old view
type removed, or kept with the reason ✓ · absorbed imagesets deleted and listed ✓ · target synced
where a file went, lint clean ✓ · nothing edited outside `project.previewDir`,
`project.registryCasePath` and the catalog, plus `project.targetSyncCmd`'s own changes — no hand
edit to `project.pbxproj` ✓

## 5. STRIKE — the registry, last; then recapture and report

Strike the row: `retire_into_glyphs(component: "C-<code>", usages: [{ glyph: "<name>", target: "C-<consumer>" }], reason: "<one line>")`.

- `usages` has one entry per consumer per glyph it now draws. That means each consuming row whose
  call site you rewrote (`target: "C-<consumer>"`) and each screen that used the row
  (`target: "<screen slug>"`, with the glyph its frames show). A state no consumer renders keeps
  its glyph in the library and gets no usage.
- `reason` is one line on why the row is retired; the strike note adds the glyph names.

Read the answer: `struck: true` with `usagesAdded`, `edgesStruck` and `screenUsesStruck`. A refusal
— a prop delegating its options to the row, or the row already struck — is reported verbatim; the
row is still live and the code is already rewritten, so say exactly that and end failed.

Then recapture: for each consumer whose file you edited and which `build_status` reported built,
`capture(component: "C-<consumer>", wait: true)`, and read its state and log tail. When
`project_info` says the project has no render lane (`captureAdapter` `noop`), say so and skip —
never report a render that did not happen.

**Report:**

- **project + era** — the scope line, first;
- **glyphs** — each name, the state(s) it draws, its artwork source (row asset / `c<code>-*`
  imageset / Figma node and rung), minted or matched as `<x>`, and the normaliser's warnings;
- **the sync** — its runId and status, and its adopted and "not in the library" lines;
- **call sites** — each file:line, before → after, noting any that needed a `.frame` fallback
  because its box matched no `GlyphSize` case exactly;
- **removed** — the old view type or file, the registry case, and each deleted imageset;
- **the strike** — the counts `retire_into_glyphs` answered, and the row as it now reads;
- **recaptures** — each consumer and its capture's final state;
- **anything not done**, and why.

**Exit checklist 5:** `retire_into_glyphs` called once, after everything else ✓ · the row struck
with the glyph names ✓ · each edited, built consumer recaptured, or the missing render lane said ✓
· report covers all eight points ✓
