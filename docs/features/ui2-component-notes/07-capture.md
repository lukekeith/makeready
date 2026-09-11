# 07 — Capture

Everything this feature builds. Sections 1–6 are the capture app; section 7 is the three
command files under root `.claude/`.

## 1. Element maps for screens

### 1.1 The backfill generator (one-time migration)

`capture/scripts/ui2-screen-elements.mjs` — a **migration tool**, not a runtime dependency.
Run per screen; writes one map per snapshot (03 §1.2).

Resolution, in order, per Figma instance in the frame:

1. Read the frame's `get_metadata` tree; keep every `<instance>` node with its `name`, node
   id, and rect (converted to fractions of the frame).
2. Build a lookup from the registry's **Figma ref** column: each row's cited set/node ids and
   the parenthesised sheet name (`set 3668:7440 (sheet, Search results)` → `C-037` keyed by
   both `3668:7440` and `search results`).
3. Match an instance by **node id first** (the instance's main-component id, when the metadata
   exposes it), then by **case-folded name**.
4. Keep a match **only if** the resolved `C-###` appears in that screen spec's §4 closed list.
   This is the hand-check gate from D5, mechanised: the spec already states which rows the
   screen renders, so a match outside that list is wrong by construction.
5. Anything unresolved is **written to a `.unmapped.json` report, not to the map** (D5). The
   report is the operator's worklist, not an artifact the browser reads.

The run is not finished until a human has read the `.unmapped.json` for each screen and
confirmed the remainder is acceptable. Screens whose §4 list is fully covered need no review.

### 1.2 `/ui2-screen` authors the map going forward

See §7.3. Phase 2 already resolves every element to a registry row — the map is that
resolution written down, so it costs the spec run nothing beyond serialising what it decided.

### 1.3 Serving

`capture/lib/ui2-index.mjs`:

- `buildUi2Screens()` (`lib/ui2-index.mjs:817`) — for each snapshot, look for
  `<stem>.elements.json` beside it, parse, apply the aspect-ratio guard against the PNG's real
  dimensions, and attach it to that variant.
- **Cache key: nothing to add. Corrected 2026-09-10 (audit pass 1):** the stamp already calls
  `dirStamp(screenAssetsDir)` unfiltered (`lib/ui2-index.mjs:821`), so editing a `.elements.json`
  in that directory already changes it. E-5 stays as a regression test of that existing behavior,
  not as a test of new code.
- **PNG dimensions are not available here yet (09 §G-3).** The snapshot records `sha` and
  `capturedAt` only (`lib/ui2-index.mjs:853-859`), and the one IHDR reader in the repo is
  `pngSize()` at `server.mjs:1190` — module-local and unexported. The guard needs it moved into a
  lib module and `{ width, height }` recorded per snapshot.
- Malformed / mismatched / absent all collapse to `null`.

`capture/server.mjs`:

- `/api/ui2/screen-detail` attaches `variants[].elements` and resolves each `ref` against
  `buildUi2Index()` (03 §2.4).

## 2. Notes storage

`capture/lib/ui2-notes.mjs` (new). Pure functions over the two note directories, unit-tested
without the server.

| Export | Contract |
|---|---|
| `notesPath(target)` | `C-###` → `docs/ui2/design-system/components/notes/C-###.md`; screen id → `docs/ui2/screens/notes/<id>.md`. Throws on a target matching neither shape. |
| `parseNotes(md)` | → `[{ id, at, body }]` in **file order** (oldest first). Splits on `^## ` where the heading parses as an ISO instant; a `##` that does not is body text, not a boundary. |
| `formatNote(at, body)` | → the exact appended block, so the writer and the parser cannot disagree. |
| `readNotes(target)` | → `{ exists, file, notes, parseError }`. Never throws on content. |
| `appendNote(target, body, now)` | Creates the file with title + preamble if absent; advances `now` past the last heading on collision; writes temp-then-rename. Returns the created note. |
| `extractMentions(body)` | → `[{ token, id }]` for every `@id` matching 03 §1.1's pattern. Resolution against the index happens in the server, not here. |

**Why a separate module:** the two skills read these files directly from the repo without the
capture server running. The parser is the contract, so it is one implementation with tests,
and the skills' instructions cite 03 §1.1 rather than re-deriving a format.

## 3. Routes

`capture/server.mjs`, in the existing UI 2.0 section:

| Route | Notes |
|---|---|
| `GET /api/ui2/notes` | 03 §2.1. Resolves `refs` against the mention index. |
| `POST /api/ui2/notes` | 03 §2.2. Inside the `if (!isProduction)` block, like the fixture-write route. |
| `GET /api/ui2/mentions` | 03 §2.3. Built from `buildUi2Index()` + `buildUi2Screens()`, both already cached. |

`capture/src/api.js` gains `fetchUi2Notes(target)`, `postUi2Note(target, body)`,
`fetchUi2Mentions()` in the same style as the existing fetchers.

## 4. Screen render targeting

### 4.1 Hit source

`Ui2Layout.jsx:183` currently derives `elements` from `vdata?.elements?.elements` and gates it on
`activeShot.platform === 'iphone'` — a built component's render. Screens take the parallel
path: `activeVariant.elements?.elements`, gated on `isScreen`.

**Corrected 2026-09-10 (audit pass 1) — `hitTest` is not reusable as it stands.** D8 *is* already
its rule, but the function is an inline `useCallback` (`Ui2Layout.jsx:200-208`) that builds its
`label`/`path` from `e.name` and returns no `ref`, while R2 requires the label to come from the
live registry and R3 requires the `ref` to set `?c=`. It is extracted to `capture/src/lib/` and
gains `ref` in its return (09 §C-6). Two further consequences the original text missed: feeding
screens through the SAME `elements` const also changes comment placement (09 §G-8), and nothing
currently routes a non-comment-mode pointer to it at all (09 §C-3, §C-4).

### 4.2 Interaction

A new `componentTarget` hover state, distinct from the comment-mode `hoverTarget`:

| Condition | Behavior |
|---|---|
| `isScreen`, map present, **comment mode OFF**, pointer over the render | Hit-test on pointer move; set `componentTarget` to the smallest containing element, or `null` |
| Pointer leaves the render | `componentTarget = null` |
| **Comment mode ON** | `componentTarget` forced `null` and the layer ignores pointer moves — comment mode owns the pointer, and its own `hoverBox` behaves as today |
| Click inside a mapped rect, comment mode OFF | `?c=<ref>` on the URL, right panel switches to the Component tab (R3) |
| Click outside every rect | No-op. Selection is cleared only by the Component tab's own clear control |

Comment mode remains the sole owner of click-to-place (`CommentLayer`'s `handleClick`); the
component click handler runs only when comment mode is off, so the two can never both fire.

### 4.3 The box

`CommentLayer.jsx` gains a third variant beside `--inspect` and `--hover`:

```jsx
{componentBox && (
  <div className="cmp-target-box cmp-target-box--component" style={{ …percentages… }}>
    <span className="cmp-target-box__label">{label}</span>
  </div>
)}
```

- Drawn **below** the comment boxes in stacking order, so an open thread's target still wins.
- `pointer-events: none` on the box and its label — the hit test reads the render's own pointer
  events, and a box that ate them would flicker at its own edges.
- Label content is `C-### Name` from the live registry (R2); it falls back to the map's stored
  `name` only when the ref no longer resolves.
- Label sits above the box; when `box.y` is less than the label's height as a fraction of the
  render, it flips inside the box's top edge (R2).
- Zero DOM at rest: `componentBox` is null unless hovering (R1).

## 5. The Component tab

`capture/src/pages/components/Ui2ComponentTab.jsx` (new). Tab order for a screen becomes
**Screen · Component · Comments** (R4); for a component the existing order is untouched.

### 5.1 Content (D4)

| Block | Source |
|---|---|
| Title: `C-###` + registry name + status chips (`specced` / `built` / `artwork`) | `elements[].resolved` on the screen detail, refreshed by a `fetchUi2Detail(ref)` when the tab needs the state list |
| Frozen artwork thumbnail | the component's `snapshot.url` |
| **Open component →** | `navigate('/components/2.0/' + ref)` (R6) |
| Designed states | the contract's state list, or "not specced yet" |
| Notes list | §5.2 |
| No selection | Empty state naming both ways to select: hover-and-click the render, or click a chip in the Screen tab |

### 5.2 Note cards (R7)

- Newest first. Each card: a timestamp line (local time, `toLocaleString`) and the body clamped
  to 2 lines (`-webkit-line-clamp: 2`).
- A clamped card shows an expand affordance; expanding toggles the clamp **in place**. It never
  navigates and never opens the composer.
- Mentions render as inline chips showing the **current** display name; clicking a component
  chip selects it in this tab, clicking a screen chip navigates to that screen.
- Empty state: "No notes yet" plus the Add note control.

### 5.3 The notepad (R8)

Add note replaces the entire right-panel region **below the tab strip** — the tab strip stays
visible so the context is never lost.

- Full-height `textarea`, autofocused.
- A button bar pinned to the bottom with exactly **Cancel** and **Save**. Save is disabled while
  the body is empty or a request is in flight.
- **Cancel with a non-empty body prompts** through `ConfirmDialog` (never `window.confirm` —
  house rule), because the notepad is the one place in this feature where work can be lost.
- Save `POST`s, then restores the list with the new note first. A failed save keeps the
  composer open with the text intact and shows the error inline.
- Escape closes an open typeahead; a second Escape is Cancel.

### 5.4 `@` typeahead (R9)

- Triggered by `@` at a word boundary; the query is the characters between `@` and the caret.
- Filters the mention index locally (fetched once per session) over id **and** name, so `@day`
  finds `C-052 DayChip` and `@C-05` finds the C-05x block.
- Rendered in a popup anchored to the caret, components then screens, keyboard-navigable
  (↑/↓ move, Enter/Tab commit, Escape dismiss), mouse-clickable.
- Commit replaces `@<query>` with the canonical token plus a trailing space (D10).
- Closes on whitespace, on a non-matching query, and on caret movement out of the token.

### 5.5 Selection plumbing

- `?c=<C-###>` on the screen route (D9). `Ui2Layout` reads it with `useSearchParams`.
- Setting it does **not** touch the path, so the screen, its state, and the version timeline are
  undisturbed.
- An invalid or unknown `c` is dropped from the URL and the tab shows its empty state.

### 5.6 Chip behavior change (R6)

`Ui2ScreenTab.jsx`'s `.cmp-ui2s__chip` currently calls `navigate('/components/2.0/' + id)`.
It becomes a selection: set `?c=<id>` and switch to the Component tab. This is the one
deliberate behavior regression in the feature (02 §Backward compatibility); the Component tab's
Open control is the replacement affordance.

## 6. Styles

`capture/src/styles.css`, beside the existing `.cmp-target-box` rules:

- `.cmp-target-box--component` — accent outline, no fill, `pointer-events: none`.
- `.cmp-target-box__label` — small accent-on-dark pill, `white-space: nowrap`,
  `pointer-events: none`, positioned above the box with a `--inside` modifier for the flip.
- `.cmp-ui2n__*` — note card, clamp, timestamp, expand control, mention chip.
- `.cmp-ui2n__pad` / `__bar` — the composer and its pinned button bar.
- `.cmp-ui2n__ta` — the typeahead popup, list and active row.

## 7. Commands (root `.claude/`)

### 7.1 `ui2-component-build.md` (edit)

| Phase | Change |
|---|---|
| 0 — Load context | Add: read `docs/ui2/design-system/components/notes/C-###.md` for the target **and for every dependency resolved in phase 1**. A note on a dependency binds its hosts. |
| 1 — Resolve | The dependency walk already lists deps; note-loading rides on it. |
| 3 — Write the view / 4 — Fixture | State that notes are **binding** and that where a note and the contract disagree, the note wins (D3), with the note's timestamp cited in the code comment that implements it. |
| 6 — Diff and report | Add the classification rule from 03 §3: a render/Figma difference **caused by a note** is EXPECTED and reported in a separate "note-driven divergence" list. Only unexplained differences count against the diff. |

The queue printer gains a `notes` column so a build's cost includes "has requirements beyond
the contract".

### 7.2 `ui2-component-update.md` (new)

`/ui2-component-update <C-###>` — verify a built preview against **spec + notes**, fix what
fails, recapture, report. Same phase-with-exit-checklist shape as its siblings; designed to run
in a fresh session.

| Phase | Contents |
|---|---|
| **0 — Load** | Contract file (or defining screen spec §4), registry row, frozen snapshot, notes for the target and each dependency, the fixture, the built view, the current render. No argument → list components that have notes, newest-note-first, and ask. |
| **1 — Derive** | Build the effective requirement set and the drift list per 03 §3. **Print both before changing anything** — the derivation is the reviewable artifact, and a wrong reading here corrupts everything after it. Not built → stop here, print the set, point at `/ui2-component-build`. |
| **2 — Verify** | Check the built view and fixture against each requirement. Each gets PASS / FAIL / UNVERIFIABLE with file:line or a measured value. UNVERIFIABLE (a behavior no still render can show — a gesture, a transition) is reported, never guessed into a pass. |
| **3 — Fix** | Edit only `iphone/MakeReady/UI2Preview/` and `capture/fixtures/ui2/`. **Never** edit `docs/ui2` (D3) — a spec the notes have overtaken is reported, not rewritten. One edit per FAIL, each citing the requirement and its source note id. |
| **4 — Recapture + re-verify** | Re-run the capture, re-diff, confirm each FAIL is now PASS. A fix that does not close its requirement is reported as such, not retried indefinitely. |
| **5 — Report** | What changed; the drift list (note-vs-spec overrides) as the owner's action list; anything still failing or unverifiable; and whether `docs/ui2` now lags its notes badly enough to want a `/ui2-component` re-spec. |

**Binding rules** (mirroring the sibling commands' "Hard rules" block): notes win over the
contract and newer notes win over older, per property (D3/R13) · the pixel diff against Figma
is not the oracle when the drift list explains the difference · `docs/ui2` is read-only ·
one component per run.

### 7.3 `ui2-screen.md` (edit)

Phase 2 gains a step beside the existing component-artwork step: **write the element map**.
The decomposition walk already pairs every instance with a registry row; serialise those pairs
plus each instance's rect to `docs/ui2/screens/assets/<snapshot-stem>.elements.json` per
03 §1.2, `generatedBy: ui2-screen@<date>`. An element the walk could not resolve is omitted
(D5), and the phase-2 exit checklist gains: *element map written, every §4 row represented ✓*.

Phase 0 also gains: read the screen's own notes (`docs/ui2/screens/notes/<id>.md`) — on a
re-spec they are owner intent recorded since the last run.
