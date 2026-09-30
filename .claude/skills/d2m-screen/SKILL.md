---
name: d2m-screen
description: Spec ONE screen — ingest its Figma design (or doc source), decompose it against the project's component registry, write the normative screen spec into d2m, and update the shared artifacts (registry, tokens, screen map, spec queue). Spec-writing only, no app code. With no argument, takes the next item from the project's dependency-ordered spec queue. Designed to run in a FRESH session.
argument-hint: [screen-id — omit to take the next queued item] [Figma URL — optional; the row's saved refs are used without it] [--project <slug>] [--era <key>]
---

# Screen spec — $ARGUMENTS

Spec the screen **$ARGUMENTS** for this project's era. This is the SPEC phase: the output is
content in **d2m**, never app code and never a file in the project repo. Work ONE screen per
run; each phase ends with something verifiable.

**Arguments:** none → take the next queued screen. `<screen-id>` → target that screen using its
own saved Figma refs (phase 0 reads them, primary first); a screen with none is `pending-figma`
and cannot be specced this way. `<screen-id> <figma-url>` → attach the URL as a new ref for that
screen, overriding the saved ones for this run, then spec (or re-spec) it. A bare Figma URL with
no id → ask the user which screen it is (or propose a new `<area>-<name>` id from what the design
shows) before proceeding.

`--project <slug>` / `--era <key>` override the scope this repo's `.mcp.json` pins, and every
command the workbench copies carries them. **Pass them through to every tool call.**

**No screen id given?** `get_spec_queue()` → take the FIRST unchecked item whose prerequisites
are `specced`, tell the user which one you picked and why it's next, and proceed. If a
prerequisite isn't `specced`, stop and surface that instead of speccing out of order. If the
queue is drained, say so and name what the project's phase gates put next (gap analysis, or
`/d2m-screen-build <screen-id>` for a specced screen whose §4 components are all built or deferred, usually).

## Hard rules (re-read before EVERY phase)

- **Spec content only.** Writes go through `upsert_screen`, `put_drawings`, `upsert_component`,
  `upsert_tokens`, `attach_asset`, `add_decision`, `put_glyph`, `use_glyph`. Never
  `put_element_map`: a frame's map is a
  projection of its confirmed, row-linked drawings, and a skill proposes drawings rather than
  writing boxes. This run writes **no file** into the project repo — the screen is built by
  `/d2m-screen-build <screen-id>`, from the spec and contracts this produces,
  once every §4 component is built or deferred.
- **Figma is normative** where attached: cite node URL + frozen snapshot + capture date;
  deviations are a CLOSED enumerated list ending "anything else that differs is a defect".
  Banned phrasings: "match as closely as possible", "similar to", "like the design".
- **Every visual element resolves to a registry row or a proposed drawing**
  (`list_components()`, `get_drawings`). This run mints no registry row: an element with no row is
  proposed through `put_drawings` for the user to confirm, and **Create N components** in the
  app mints it. Check the project's legacy candidate pool — its own component directory and any
  inventory doc it keeps, under the `repoPath` that `project_info()` reports — before proposing
  a new NAME; a legacy component that genuinely fits is named in the proposal's `note`. No row
  without a defining contract.
- **Glyphs.** Single-colour icons are glyphs from the library: reach for `list_glyphs` and
  reference the glyph; if it is missing, mint it with `put_glyph`; a component whose content is
  only a glyph is not a component.
- **A pattern screen's name and intent are the user's.** A screen whose refs are `kind: "derived"`
  and whose notes open with `Pattern intent (drawn on <subject>/<frame>):` was minted from a
  screen drawing: the user drew the box, chose the name and wrote the intent. This run does not
  rename the screen and neither widens nor narrows the pattern. The spec's first section states
  the intent verbatim. A concrete use the picture shows ("Group name") is an *instance* of the
  pattern, written under a **Uses** list, never as the pattern itself. Two frames are two
  instances; a difference between them is a variation point the intent must already name —
  else an open question, never a second pattern.
- **Tokens by name**: raw values only as flagged per-screen literals.
- **No legacy blending**: the spec describes the new UI on its own terms; legacy appears only
  in §7 Legacy mapping and in registry `existing` rows.
- **One screen per run.** Finish by updating the queue — that is how the next session
  continues. A session with leftover context may loop to another screen only if the user says
  so.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why to the user.

## 0. Load context (always, especially in a fresh session)

1. `project_info()` — **state the project slug and era key in your first report line**, so a
   mis-pinned repo is visible before anything is written. It also gives you `figmaFileKey`,
   `componentSheetNode` and `repoPath`; this run has no other constants.
2. If `get_screen(id)` answers that `<id>` **is a collection, not a screen — mint a screen out
   of it in the app**, stop: print that line and call nothing. A collection is never specced —
   its screens are minted from it (the Collection tab's Mint) and specced once minted.
   `list_screens()` — find the screen's row (platform, Figma status, current status, notes) and
   `get_spec_queue()` for its prerequisites. If the screen isn't listed, `upsert_screen` a row
   in the right section AND a queue entry first (position by dependencies), and tell the user
   you did.
3. **Where the Figma frame comes from.** A URL on the command line is an override and is attached
   as a ref. With NO URL, the frame(s) are the screen's `figmaRefs` in `get_screen(id)`: primary
   first, one frozen frame per ref. A screen with no refs is `pending-figma` and cannot be
   specced: stop and tell the user to add a Figma reference in the app. A screen whose refs are
   `derived` **is** referenced: its frozen frame is the crop the commit cut from the parent's
   export, and its drawings (`get_drawings`) came with it.
4. `get_decisions()` in full — it is short and binding — and the screen map neighbourhood of
   this screen (what links here, what it links to) from `get_screen(id)`.
5. `get_registry_rules()` plus `list_components()` — the rules header and every category
   plausibly relevant to this screen — and `get_tokens()`'s populated families.
6. If the screen's notes name a doc source, read it.
7. If the status says part of the work is done (a `draft` spec exists), `get_screen(id)` and
   continue it — don't restart.

**Exit checklist 0:** project + era stated ✓ · screen row found (or added) ✓ · prerequisites
specced ✓ · decisions + registry + tokens loaded ✓ · doc sources read ✓

**Read the screen's NOTES** before anything else in a re-spec:

```
read_notes("<screen-id>")
```

Notes are the owner's intent recorded since the last run — normative, and newer beats older.
Always through `read_notes`, never by eye. A note that contradicts what this run is about to
write is a thing to raise, not to quietly overwrite.

## 1. INGEST — capture the normative source

**Figma screen** (URL provided now or on the screen row):

   **Derived ref (a pattern screen)? Do NOT capture.** The frame's asset is the crop the commit
   cut, and the drawings copied onto it are measured against that image — a re-capture is a new
   asset and would orphan every one of them. Skip the ladder and `attach_asset` for such a
   frame. You may `get_metadata` the parent node (the ref's `nodeId`) and find the child frame
   whose bounds match the ref's `rect` (±2 pt) to cite as the Figma node in §1 — record it in
   the report; the asset stays.

1. Capture the frame — **the sharpest picture any route will give, and every route before
   giving up.** Read the
   node's own width × height from `get_metadata` first; that is what each rung is measured
   against. Try the rungs IN ORDER and stop at the first that lands a PNG at **2× or better**
   (`file /tmp/<screen-id>-<frame-slug>.png` prints the pixel size — compare it to the node). A rung that
   errors, answers a non-PNG, or comes back under 2× is noted in one line (which rung, why) and
   you go straight to the next — never ask, never stop early.
   - **Rung 1 — REST at 4×, when `$FIGMA_TOKEN` is set in this terminal's environment:**
     `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN" "https://api.figma.com/v1/images/<fileKey>?ids=<nodeId>&format=png&scale=4"`
     answers `{"images":{"<nodeId>":"<url>"}}` (node id with its colon; a non-null `err` means it
     did not render). Then `curl -sL -o /tmp/<screen-id>-<frame-slug>.png "<url>"`. Never write the token
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
     Write the returned string to `/tmp/<screen-id>-<frame-slug>.b64` and `base64 -d` it into the PNG. A
     return too large for the tool (a whole screen at 4×) errors — that is a fall-through, not a
     stop.
   - **Rung 4 — the connector's `get_screenshot` at 1×:** `fileKey`, `nodeId`, `maxDimension:
     4096` answers a URL; curl it. This renders at 1× and `maxDimension` never upscales, so a
     32×40 symbol comes back 32×40 — it will not pass the 2× check, and that is expected: it is
     the floor, not a candidate.
   - **No rung passed?** Attach the LARGEST PNG any rung produced (better than none) and say in
     the report which rungs ran and why each fell through. Nothing at all → note the failure and
     continue.
   The Dev Mode server's `get_screenshot` is for LOOKING at the node: it answers an inline image
   you cannot save, so it is never a rung. Never search the filesystem or read d2m's source for a
   screenshot file: the ladder above is the whole recipe.
   Then `attach_asset` the file (`kind: "screen_frame"`, target `<screen-id>#<frame-slug>`,
   `scale: <measured>` — the PNG's width over the frame's width from `get_metadata`, rounded,
   clamped to 1–4; always pass it) as this screen's frozen frame, one per frame. d2m copies the bytes
   into its own storage and records the sha — a frame whose image only exists at a path in
   someone's checkout is not a frame. This is the FROZEN snapshot the spec cites, and a later
   Figma edit is a visible re-spec event (re-run this skill with the URL and diff), never silent
   drift; re-attaching identical bytes is a no-op, so only genuinely new artwork supersedes.
   Then `refresh_snapshot(target: <screen-id>)` registers it as the design side the workbench shows —
   idempotent on the sha, so `created: 0` on a re-run is the normal answer, not a failure.
2. `get_metadata` → the layer/frame structure (feeds decomposition in phase 2).
3. `get_variable_defs` → diff against `get_tokens()`; `upsert_tokens(rows)` for the new ones,
   citing the Figma variable. Raw values with no variable: decide token vs flagged literal.
   A color token with `scale` or `aliasOf` set is managed on the Colors page. Write it only to
   record `usedBy`; if the Figma value differs, report it rather than retrying.
4. `get_design_context` → measurements, spacing, typography for the layout contract.
5. Record in the spec: full node URL, node id, snapshot asset(s), today's date.

Do NOT use the Figma design-to-code skills here — those are build-phase tools; this phase only
extracts facts into the spec.

**No-Figma screen:** the normative source is a named doc — an analysis section, a decision
register section, a legacy screen file (for a deliberately-similar carry-over), or the user's
description operationalized into closed acceptance criteria live in this session (closed lists,
measured values, enumerated deviations — never quoted prompts). Mark the screen row `no-figma`.
The spec itself becomes the normative source.

**Exit checklist 1:** normative source pinned (node+snapshot+date, or named doc §) ✓ ·
snapshot(s) attached through `attach_asset` with their shas reported ✓ · token diff written
through `upsert_tokens` ✓ · no unexplained raw values ✓

## 2. DECOMPOSE — resolve every element against the registry

**Start from what is already drawn.** `get_drawings(subject: "<screen-id>")` → per frozen
frame, the tree of drawings with their status and row. Sort them:

- **`confirmed` with a `row`** — an element already resolved. It is in §4's roll-call as that
  row, at that rect, under that name. **Do not mint, rename or re-rect it**, and do not propose
  another drawing over it. Its container (the drawing holding it) and its children are §2's
  structure for free.
- **`confirmed` without a `row`** — the user has named it and not yet pressed Create. Report it
  as `unminted — press Create N components in the app`; it is NOT in §4 until it is a row, and
  this run does not mint it.
- **`proposed`** — an earlier guess (yours, `/d2m-detect`'s, or the vision job's) the user has
  not confirmed. Not evidence. Leave it; phase 2's own proposals replace it.

Then walk the design for what has **no drawing at all**.

Walk the design top-to-bottom and enumerate EVERY visual element. Each resolves to exactly one
of:

- **Existing registry row** with a confirmed, linked drawing → this screen joins its Consumed-by;
  nothing to write for the element itself.
- **Existing registry row** with **no drawing** → propose one: `put_drawings` with `rowCode` and
  no name (phase 2's single call, below). It enters §4 only once the user confirms it.
- **Registry row needing modification** → status `existing-modified` with a CLOSED change list
  in the row (and the delta detailed in this spec) — the row's own drawing rules above still
  decide whether it is on this frame.
- **A thing with no row** → propose it: `put_drawings` with a `name` that passes the naming
  rules (a container for a repeated group or title block, a component for a leaf; children in
  the same call with `parentKey`). **This run does not mint it.** `mint_component_id` is not
  called from this phase: the user confirms the proposal and **Create N components** mints the
  row, with its artwork cropped from this frame and a derived Figma ref, and the next run of
  this skill finds it as a confirmed, linked drawing. Check the legacy candidate pool first all
  the same — a legacy component that genuinely fits is named in the proposal's `note` so the
  user can pick the `existing` row instead.
- **Two rows that turn out to be one component** → the element resolves to the row that will
  SURVIVE, and the report ends with `/d2m-component-merge <keep> <duplicate>` for the owner to
  run. This run does not strike the other row — not `status: removed`, not a `~~struck~~` name
  or status cell (`upsert_component` refuses both), not a "Defined in" repointed by hand. Only
  `merge_components` sets `removedAt`. Unruled, it is a consolidation OQ on the keeper.

**State/variant coverage — MANDATORY per component instance.** A frame shows ONE instantiation;
never document it as the whole component. For every instance that is, or updates, a registry
row:
1. Inspect its `get_design_context` output for **variant props with default values** (e.g.
   `state?: "Activity 1"`, `style?: "Default"`, `aligned?: "Right"`) — each is evidence of OTHER
   designed variants not on this frame; probe the main component (`get_metadata` /
   `get_design_context` on its node) where reachable.
2. The spec's §4 contract carries an explicit **state-coverage line**: which states/variants the
   Figma source DEFINES, and which the contract needs but the source doesn't design
   (focused/filled/empty/pressed/error…). Undesigned states become **proposed defaults + an OQ**
   for the owner to ratify or answer with state frames — NEVER stated as fact.
3. Variant axes observed but not enumerated → an OQ listing them ("used variants are contracted;
   unenumerated variants may not be built without a ruling").

**The component sheet is `project.componentSheetNode`** from `project_info()`: probe it for each
consumed component's set (`get_metadata` on the whole sheet is too large — drill into the
component's own set node). The sheet is NOT wholly normative — some entries are prototype-only;
a sheet component matters only when a screen consumes it, and its designed states then enter the
consuming spec's contracts. A project with no sheet node configured has no sheet: say so rather
than inventing one.

Ambiguities (is this one component or two? does this state exist? what does this button do?) →
ask the owner as they arise; anything the owner leaves unanswered stays an `OQ-<screen-id>-#`
row in §8 and pins the screen at `blocked`.

**How to ask the owner, always:** `await_answers(subject, questions: [{ question, options, recommended }])`
— every question this decision needs in ONE call, each with the answers it offers (your proposal
first) — then END YOUR TURN with one line naming what you filed. The questions land on the
document as real `OQ-…` rows; the owner answers them from the Contract tab or the terminal,
and this session is resumed with the answers by code — read them as rulings and continue from
where you paused. Never ask in prose: a prose question ends the run with nothing filed and
nothing to resume.

**Naming & scoping check (`get_registry_rules()`):** every new NAME (a proposal's, or a row
Create minted from one) follows the naming & scoping rules (role-based, no first-consumer or
Figma-layer names, family suffixes, no
collisions); every CONSUMED row is re-checked against its now-larger consumer set — if
consumption outgrew the name, rename in place (the `C-###` id is stable, and d2m keeps the old
name resolvable so no link or thread breaks) with a dated "renamed from" note, and repoint every
consumer the same run.

**Component artwork — MANDATORY for every row this run touches.** A registry row that nobody can
SEE is a name, not a component: a row minted by a screen run used to render blank in the
workbench, so the reader had no way to tell what the row referred to. Every row this phase
resolves therefore ends the run with a picture.

Per resolved component, in this order:

1. **Already got artwork? Leave it alone.** `get_component(id)` tells you whether the row has a
   snapshot. A row that has been BUILT, SPECCED (its contract cites a frozen snapshot), captured
   by an earlier screen run, or **minted from a drawing** (its primary `figmaRefs[]` entry has
   `kind: "derived"` — its artwork is the crop the commit cut) is done — never overwrite it, and
   never re-point a contract's snapshot at a frame-local instance.
2. **No artwork? Capture the COMPONENT, never the screen.** Same capture ladder as phase 1 —
   every rung, sharpest first, measured `scale` — on:
   - the row's **main component or set node** when the registry ref determines one — the
     isolated symbol, which is what a component browser should show; else
   - the **instance node inside this screen's frame** (`get_metadata` gives its id). That renders
     the component alone, trimmed to its own bounds, with the sample content the screen gave it —
     exactly the use-case view.
   Saving the whole screen frame as a component's artwork is a defect: at 440×2521 the component
   is invisible, and the asset then blocks a real capture by rule 1.
3. **Attach it with `attach_asset`,** keyed to the component row, with its `scale`. d2m owns the
   filename and the sha; there is no slug to get wrong and no second file to disambiguate — one
   artwork per row. A capture less dense than the row's current one is stored but not made current.
4. **A row whose Figma ref is `no-figma`** has no design to capture — skip it, and say so in the
   exit note rather than inventing artwork.

The screen's OWN frozen frame(s) are attached to the screen (phase 1); component artwork is
attached to the component. Two different targets, one tool.

**Propose what has no drawing — ONE `put_drawings` call per frozen frame.** The walk has just
paired every instance on the frame with a row or a name; the drawings are that pairing written
down where the user can correct it. The element map — what the workbench hit-tests, what
comments anchor to, what the Screen tab's roll-call counts — is a projection of the frame's
**confirmed, row-linked** drawings and is never written by hand: `put_element_map` refuses a
frame that has drawings (`409`), and every frame this skill has touched since 2026-09-19 has.

```
put_drawings(subject: "<screen-id>", frame: "<frame-slug>", replaceProposed: true,
             drawings: [{ key, kind, points | rect, rowCode | name, note?, parentKey? }, …])
```

- **Rects in design points** (`points`, measured against the exported node's width × height from
  `get_metadata`, offsets accumulated down the tree) or as fractions of the exported image
  (`rect`). `get_drawings` reports the frame's `scale`, `width`, `height` and `crop`; keep every
  proposal inside the crop. Measure `points` against `get_drawings`' `width ÷ scale` ×
  `height ÷ scale` for the frame, not the Figma node's own size — a SECTION export is padded (a
  1096×3206 section renders as a 1176×3286 file), so node-relative points drift on such frames.
- **`rowCode` for an instance of a known row; `name` for a new thing; never both.** Repeated
  instances share one name. A container's children go in the same call with `parentKey`.
- **`replaceProposed: true`** clears the frame's earlier *proposed* drawings (never confirmed or
  user-drawn ones) so a re-spec replaces its previous guess.
- **Read the reply.** `accepted` is what landed; `rejected` names each proposal that broke a rule
  (crossed its container, outside the crop, not PascalCase, names an existing row). A rejected
  proposal is reported, not retried in a second call.
- **An element the walk could not resolve is OMITTED.** Unmapped is better than mis-mapped.
- **§4's roll-call on a re-spec is the PRIOR roll-call (`get_screen`'s §4) ∪ the confirmed,
  linked drawings; this run's proposals only ADD once the user mints them (confirm, then
  Create N components).** A row in the prior roll-call with no drawing is NOT evidence it left
  the screen — it was specced before drawings existed. A use the owner has **deferred** on this
  screen (`get_screen` shows `deferred` on it) is in the union and is kept deferred — list it in
  §4 marked *(deferred: <reason>)* and never treat its missing drawing as a departure. A row
  the prior roll-call no longer lists (removed by the owner) is not in the union; do not re-add
  it. Never send a `components` list
  shorter than the prior one because of drawings: if the union is not complete, omit `components`
  from the `upsert_screen` call and say so in the report. List what still needs minting in the
  report under `unconfirmed — confirm in the app and re-run`, one line per distinct name with
  its instance count. The spec queue status is `draft`, not `specced`, while any proposal on
  the frame is unconfirmed — the roll-call is not closed until the user has ruled on every box.

**Exit checklist 2:** existing drawings read first, confirmed + linked ones untouched ✓ · every
element resolved to a linked drawing, a proposal, or omitted ✓ · legacy pool checked before
every new NAME ✓ · Consumed-by updated for linked rows ✓ · naming & scoping check passed (new
names + consumed rows) ✓ · **every linked row has artwork (or is `no-figma` / derived) ✓** ·
**`put_drawings` called once per frozen frame, reply read, rejects reported ✓** · unconfirmed
proposals listed for the user ✓ · deferred uses kept deferred, removed rows left out ✓ ·
ambiguities asked or parked as OQ# ✓

## 3. WRITE — the screen spec

`upsert_screen(...)` with exactly this skeleton. Every field is **partial** — what you do not
mention is left untouched, so restating §1 and §2 does not blank §7. The exception is a list you
*do* supply: `components` REPLACES the §4 roll-call (a closed list with one stale member is not
closed), and a row that leaves it is **struck**, not deleted, because why a component left a
screen is editorial content. (So, on a re-spec, it is the union phase 2 built — never a list
shrunk by what has no drawing yet.) The server keeps a deferred use deferred whether or not the
list names it, and keeps a removed row out until a drawing links it; its reply's warnings say
which. `instanceCount` keeps three answers apart: omit it to leave a
measured count alone, `null` clears it back to "nobody counted", and `0` **claims** a measurement
of zero. (an empty section means "verified none", never
"didn't look"):

```markdown
# <screen-id> — <human name>

Platform: <the project's platform vocabulary> · Status: <mirrors the queue> · Specced: <date>

## 1. Normative source
Figma node URL + node id + snapshot + capture date (or named doc source §).
**Deviations (closed list):** enumerated items, then the sentence
"Anything else that differs from the source is a defect."

## 2. Layout contract
Top→bottom structure; dimensions/spacings via token names; safe-area and scroll behavior;
per-element geometry from get_design_context.

## 3. Behavior contract
States as a CLOSED list (loading / empty / error / populated / edit-gating as applicable) with
how each renders; interactions (tap/drag/long-press → outcome); motion via motion tokens or
measured timings.

## 4. Components
The CLOSED list of registry IDs this screen renders (one line each: C-### Name — role here).
Then a full contract subsection for every row this screen INTRODUCES (status `new` — minted by
**Create N components** from this screen's drawings, with Defined-in here — or modified):
params/props with types and purpose, states, variants — the registry row's "Defined in" anchors
here.

## 5. Data & API
Models read/written; endpoints with method + path — each verified against the project's own API
index (cite the match) or marked `API-GAP: <what's missing>` for the backend work. New-model
needs described by shape, not schema.

## 6. Connections
Entry points (which screens/edges reach this), exits, overlays presented. Mirror every edge into
the screen map's edge table.

## 7. Legacy mapping
Which current screens/routes/capabilities this replaces: the files and route cases, with
per-item carried/merged/dropped-candidate notes. This pre-pays the gap-analysis sweeps.

## 8. Open questions
`OQ-<screen-id>-#` rows: question, why it blocks (or doesn't), who decides. Any OPEN blocking row
pins the queue status at `blocked (OQ…)`.
```

**Exit checklist 3:** all 8 sections filled ✓ · deviation list closed with the defect sentence ✓
· every §4 ID exists in the registry ✓ · endpoints verified or API-GAP'd ✓ · legacy mapping names
files + route cases ✓

## 4. UPDATE — shared artifacts, the queue last

1. Registry — new/modified rows enriched through `upsert_component` (always with `code`; a call
   without one would mint, and this run never mints), Consumed-by updated.
2. Tokens — already written in phase 1; re-verify with `get_tokens()`.
3. Screen map — node present, §6 edges mirrored into the edge table, dependency note if this
   screen gates others (`upsert_screen`).
4. **The spec queue, last:** `upsert_screen` with `status` → `specced` (or `blocked` with the
   blockers in `statusDetail`, or `draft` — honestly), `figmaSource`/`figmaText` updated,
   `queueOrdinal` moved or cleared (`null` is "not queued", which is not the same as queued
   last), `queuePrereqs` restated, and any NEW screens discovered via §6 connections added as
   rows with their own queue positions. The queue is how the next session continues, so it is the
   last thing that changes and it never claims more than the run did.
5. Tell the user: project + era, what was specced, the proposals written (N, K linked), the
   reply's warnings (a use kept deferred, a removed row not re-added) and the
   rows the user must still mint from them, the modified registry rows (IDs + names), open OQs
   needing their answer, and which screen the queue serves next.

**Exit checklist 4:** registry ✓ · tokens ✓ · screen map ✓ · queue updated last with honest
status ✓ · next queue item named ✓
