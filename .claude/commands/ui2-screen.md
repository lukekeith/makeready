---
description: Spec ONE UI 2.0 screen — ingest its Figma design (or doc source), decompose it against the program component registry, write the normative screen spec, and update the shared program artifacts (registry, tokens, screen map, README manifest). Spec-writing only, no app code. With no argument, takes the next item from docs/ui2/README.md's dependency-ordered spec queue. Designed to run in a FRESH session.
argument-hint: [screen-id from docs/ui2/README.md — omit to take the next queued item; optionally followed by a Figma URL to attach/refresh the design source]
---

# UI 2.0 screen spec — $ARGUMENTS

Spec the screen **$ARGUMENTS** for the UI 2.0 program. This is the SPEC phase of the
program: the output is documentation under `docs/ui2/`, never app code. Work ONE screen per
run; each phase ends with something verifiable.

**Arguments:** none → take the next queued screen. `<screen-id>` → target that screen.
`<screen-id> <figma-url>` → attach (or refresh) the Figma source for that screen, then spec
(or re-spec) it. A bare Figma URL with no id → ask the user which screen it is (or propose a
new `<area>-<name>` id from what the design shows) before proceeding.

**No screen id given?** Open `docs/ui2/README.md` → **Spec queue (dependency-ordered)** →
take the FIRST unchecked item whose prerequisites are `specced`, tell the user which one you
picked and why it's next, and proceed. If a prerequisite isn't `specced`, stop and surface
that instead of speccing out of order. If the queue is drained, say so and point at the
README's Phase gates (gap analysis is next).

## Hard rules (re-read before EVERY phase)

- **Docs only.** This command writes under `docs/ui2/` exclusively. No edits to `client/`,
  `server/`, `iphone/`, `capture/` — building happens later via `/build-spec` suites.
- **Figma is normative** where attached (DECISIONS.md D5): cite node URL + frozen snapshot +
  capture date; deviations are a CLOSED enumerated list ending "anything else that differs
  is a defect". Banned phrasings per build-spec REFERENCE.md §3c: "match as closely as
  possible", "similar to", "like the design".
- **Every visual element resolves to a registry row** (`docs/ui2/design-system/registry.md`,
  D6). Check the legacy candidate pool (`iphone/MakeReady/Components/`,
  `docs/ui/COMPONENT_INVENTORY.md`) before minting `new`. No element without a row; no row
  without a defining contract.
- **Tokens by name** (D7): raw values only as flagged per-screen literals.
- **No legacy blending** (D2): the spec describes the new UI on its own terms; legacy
  appears only in §7 Legacy mapping and in registry `existing` rows.
- **One screen per run.** Finish by updating `docs/ui2/README.md` — that file is how the
  next session continues. A session with leftover context may loop to another screen only
  if the user says so.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do not
advance with an ✗ — fix it or surface why to the user.

## 0. Load context (always, especially in a fresh session)

1. Read `docs/ui2/README.md` — find the screen's row (platform, Figma status, current
   status, notes) and its queue entry's prerequisites. If the screen isn't listed, add a row
   in the right section AND a queue entry first (position by dependencies), and tell the
   user you did.
2. Read `docs/ui2/DECISIONS.md` (all of it — it's short and binding) and
   `docs/ui2/screen-map.md`'s neighborhood of this screen (what links here, what it links to).
3. Read `docs/ui2/design-system/registry.md` — the rules header plus every category section
   plausibly relevant to this screen — and `docs/ui2/design-system/tokens.md`'s populated
   families.
4. If the screen's README notes name a doc source (activities analysis, navigation analysis,
   notes/memo DECISIONS), read it.
5. If a status other than `—` says part of the work is done (a `draft` spec exists), read
   the existing spec and continue it — don't restart.

**Exit checklist 0:** README row found (or added) ✓ · prerequisites specced ✓ · DECISIONS +
registry + tokens loaded ✓ · doc sources read ✓

**Read the screen's NOTES** before anything else in a re-spec:

```
node capture/lib/ui2-notes.mjs read <screen-id>
```

Notes are the owner's intent recorded since the last run — normative, and newer beats older
(`docs/features/ui2-component-notes/01-architecture.md` D3/D6). Always through the parser,
never by reading the markdown. A note that contradicts what this run is about to write is a
thing to raise, not to quietly overwrite.

## 1. INGEST — capture the normative source

**Figma screen** (URL provided now or in the README row):

1. `get_screenshot` on the node → save the image to
   `docs/ui2/screens/assets/<screen-id>.png` (append `-<variant>` for additional frames).
   This is the FROZEN snapshot the spec cites; a later Figma edit is a visible re-spec event
   (`/ui2-screen <id> <url>` re-runs this phase and diffs), never silent drift.
2. `get_metadata` → the layer/frame structure (feeds decomposition in phase 2).
3. `get_variable_defs` → diff against `docs/ui2/design-system/tokens.md`; append new tokens
   (name per D7 conventions, cite the Figma variable). Raw values with no variable: decide
   token vs flagged literal, per D7.
4. `get_design_context` → measurements, spacing, typography for the layout contract.
5. Record in the spec: full node URL, node id, snapshot filename(s), today's date.

Do NOT use the figma design-to-code / swiftui skills here — those are build-phase tools;
this phase only extracts facts into the spec.

**No-Figma screen:** the normative source is a named doc — an activities/navigation analysis
section, a notes/memo DECISIONS section, a legacy screen file (for a deliberately-similar
carry-over), or the user's description operationalized into closed acceptance criteria live
in this session (§3c: closed lists, measured values, enumerated deviations — never quoted
prompts). Mark the README row `no-figma`. The spec itself becomes the normative source.

**Exit checklist 1:** normative source pinned (node+snapshot+date, or named doc §) ✓ ·
snapshot file(s) saved ✓ · token diff folded into tokens.md ✓ · no unexplained raw values ✓

## 2. DECOMPOSE — resolve every element against the registry

Walk the design top-to-bottom and enumerate EVERY visual element. Each resolves to exactly
one of:

- **Existing registry row** → append this screen id to its Consumed-by column.
- **Registry row needing modification** → status `existing-modified` with a CLOSED change
  list in the row (and the delta detailed in this spec).
- **New row** → mint the next `C-###` (append-only) — but FIRST check the legacy candidate
  pool; a legacy component that genuinely fits becomes an `existing` row naming its file.
  Remember D2's copy rule: `existing-modified` means the build copies into the 2.0 namespace.

**State/variant coverage — MANDATORY per component instance.** A frame shows ONE
instantiation; never document it as the whole component. For every instance that becomes or
updates a registry row:
1. Inspect its `get_design_context` output for **variant props with default values** (e.g.
   `state?: "Activity 1"`, `style?: "Default"`, `aligned?: "Right"`) — each is evidence of
   OTHER designed variants not on this frame; probe the main component
   (`get_metadata`/`get_design_context` on its node) where reachable.
2. The spec's §4 contract carries an explicit **state-coverage line**: which states/variants
   the Figma source DEFINES, and which the contract needs but the source doesn't design
   (focused/filled/empty/pressed/error…). Undesigned states become **proposed defaults +
   an OQ** for the owner to ratify or answer with state frames — NEVER stated as fact.
3. Variant axes observed but not enumerated → an OQ listing them ("used variants are
   contracted; unenumerated variants may not be built without a ruling").
**The component sheet lives at Figma node `3632:4502`** (link in DECISIONS.md D9): probe it
for each consumed component's set (`get_metadata` on the sheet is too large whole — grep
the saved metadata dump or drill into the component's own set node). Per D9 the sheet is
NOT wholly normative — some entries are prototype-only; a sheet component matters only when
a screen consumes it, and its designed states then enter the consuming spec's contracts.

Ambiguities (is this one component or two? does this state exist? what does this button do?)
→ ask the user ONE at a time as they arise; anything the user defers becomes an
`OQ-<screen-id>-#` row in §8 and pins the screen at `blocked`.

**Naming & scoping check (registry rules header, owner-directed 2026-09-02):** every new
row's name follows the registry's "Naming & scoping rules" (role-based, no first-consumer
or Figma-layer names, family suffixes, no collisions); every CONSUMED row is re-checked
against its now-larger consumer set — if consumption outgrew the name, rename in place
(ID stable, dated "renamed from" note) and propagate via grep across `docs/ui2/` in the
same run.

**Component artwork — MANDATORY for every row this run touches.** A registry row that
nobody can SEE is a name, not a component: `/components/2.0/C-052` rendered blank for every
row a screen run minted, so the reader had no way to tell what the row referred to. Every
row this phase resolves therefore ends the run with a picture on disk.

Per resolved component, in this order:

1. **Already got artwork? Leave it alone.** Check
   `docs/ui2/design-system/components/assets/` for `C-###-*.png`. A row that has been
   BUILT, SPECCED (its contract cites a `Frozen snapshot:`) or captured by an earlier
   screen run is done — never overwrite it, and never re-point a contract's snapshot at a
   frame-local instance.
2. **No artwork? Capture the COMPONENT, never the screen.** `get_screenshot` on:
   - the row's **main component or set node** when the registry ref determines one — the
     isolated symbol, which is what a component browser should show; else
   - the **instance node inside this screen's frame** (`get_metadata` gives its id). That
     renders the component alone, trimmed to its own bounds, with the sample content the
     screen gave it — which is exactly the use-case view.
   Saving the whole screen frame as a component's artwork is a defect: at 440×2521 the
   component is invisible, and the file then blocks a real capture by rule 1.
3. **Save as** `docs/ui2/design-system/components/assets/C-###-<kebab-name>.png` — the
   registry name kebab-cased (`DayChip` → `C-052-day-chip.png`). The browser resolves a
   contract-less row's render by that exact filename, so a mismatched slug shows nothing.
   One PNG per row: several `C-###-*.png` files under one id are ambiguous and the browser
   deliberately shows neither.
4. **A row whose Figma ref is `no-figma`** (a DECISIONS-sourced component) has no design to
   capture — skip it, and say so in the exit note rather than inventing artwork.

The screen's OWN frozen frame(s) stay in `docs/ui2/screens/assets/` (phase 1) — the two
asset dirs are separate and the browser serves them from separate mounts.

**Write the ELEMENT MAP — MANDATORY, once per frozen snapshot.** This walk has just paired
every instance on the frame with a registry row; the map is that pairing written down, so it
costs the run nothing beyond serialising what it already decided. Without it the browser
cannot hit-test the screen: hovering draws no box, clicking selects nothing, and a comment
dropped on the render records coordinates instead of a component
(`docs/features/ui2-component-notes/03-data-and-api.md` §1.2).

Write `docs/ui2/screens/assets/<snapshot-stem>.elements.json`, one per frozen frame:

| Field | Value |
|---|---|
| `screen` / `snapshot` | the screen id, and the PNG this map describes |
| `node` | the node that was EXPORTED — a frame normally, a **section** when the snapshot is a multi-frame sheet |
| `size` | that exported image's own point space; for a section export, **including the export padding** (Figma pads a section PNG — 1096×3206 section → 1176×3286 file) |
| `generatedBy` | `ui2-screen@<date>` |
| `elements[]` | `{ ref, name, instance, x, y, w, h }` per instance |

- **Rects are fractions of the exported image.** `get_metadata` reports each node relative to
  its PARENT, so accumulate offsets down the tree; clamp to 0…1 (a horizontally scrolling rail
  is genuinely wider than the frame) and drop anything wholly outside.
- **Order matters for ties only:** write **smallest-area first, deepest-first within a tie**.
  The hit test takes the first containing entry it meets, and a parent frame and the child
  that fills it exactly are indistinguishable by area.
- **An element the walk could not resolve is OMITTED** (D5). Unmapped is better than
  mis-mapped: a wrong box attributes a note or a comment to the wrong component.
- Refs must be a **subset of this spec's §4 closed list** — by construction, since that list
  is what this phase just produced.

`capture/scripts/ui2-screen-elements.mjs` is the one-time backfill tool for the ten screens
specced before maps existed; it is **not** part of this run.

**Exit checklist 2:** every element resolved ✓ · legacy pool checked before every `new` ✓ ·
Consumed-by columns appended ✓ · naming & scoping check passed (new + consumed rows) ✓ ·
**every touched row has artwork on disk (or is `no-figma`) ✓** · **element map written for
every frozen snapshot, every §4 row that appears on the frame represented ✓** · ambiguities
asked or parked as OQ# ✓

## 3. WRITE — the screen spec

Write `docs/ui2/screens/<screen-id>.md` with exactly this skeleton (an empty section means
"verified none", never "didn't look"):

```markdown
# <screen-id> — <human name>

Platform: iphone | web-member · Status: <mirrors README> · Specced: <date>

## 1. Normative source
Figma node URL + node id + snapshot file + capture date (or named doc source §).
**Deviations (closed list):** enumerated items, then the sentence
"Anything else that differs from the source is a defect."

## 2. Layout contract
Top→bottom structure; dimensions/spacings via token names (tokens.md); safe-area and
scroll behavior; per-element geometry from get_design_context.

## 3. Behavior contract
States as a CLOSED list (loading / empty / error / populated / edit-gating as applicable)
with how each renders; interactions (tap/drag/long-press → outcome); motion via motion
tokens or measured timings.

## 4. Components
The CLOSED list of registry IDs this screen renders (one line each: C-### Name — role
here). Then a full contract subsection for every row this screen INTRODUCES (new or
modified): params/props with types and purpose, states, variants — the registry row's
"Defined in" anchors here.

## 5. Data & API
Models read/written; endpoints with method + path — each verified against the
makeready-api MCP (cite the match) or marked `API-GAP: <what's missing>` for the backend
suite. New-model needs described by shape, not schema (the build suite's 03 owns schema).

## 6. Connections
Entry points (which screens/edges reach this), exits, overlays presented. Mirror every
edge into screen-map.md's edge table.

## 7. Legacy mapping
Which current screens/routes/capabilities this replaces: `Pages/...` files and
`Route.swift` cases, with per-item carried/merged/dropped-candidate notes. This pre-pays
gap-analysis sweeps 1–2.

## 8. Open questions
`OQ-<screen-id>-#` rows: question, why it blocks (or doesn't), who decides. Any OPEN
blocking row pins the README status at `blocked(OQ…)`.
```

**Exit checklist 3:** all 8 sections filled ✓ · deviation list closed with the defect
sentence ✓ · every §4 ID exists in the registry ✓ · endpoints verified or API-GAP'd ✓ ·
legacy mapping names files + route cases ✓

## 4. UPDATE — shared artifacts, README last

1. `docs/ui2/design-system/registry.md` — new/modified rows landed, Consumed-by appended.
2. `docs/ui2/design-system/tokens.md` — already updated in phase 1; re-verify.
3. `docs/ui2/screen-map.md` — node present, §6 edges mirrored into the edge table,
   dependency note if this screen gates others.
4. `docs/ui2/README.md` — **the last act of every run**: screen row status → `specced` (or
   `blocked(OQ#)` / `draft` honestly), Figma column updated, spec link filled, queue item
   checked off (or annotated), and any NEW screens discovered via §6 connections added as
   rows + queue entries.
5. Tell the user: what was specced, the new/modified registry rows (IDs + names), open
   OQs needing their answer, and which screen the queue serves next.

**Exit checklist 4:** registry ✓ · tokens ✓ · screen-map ✓ · README updated last with
honest status ✓ · next queue item named ✓
