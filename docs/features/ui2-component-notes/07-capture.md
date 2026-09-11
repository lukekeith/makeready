# 07 — Capture

Everything this feature builds. Sections 1–6 are the capture app; section 7 is the three
command files under root `.claude/`.

## 1. Element maps for screens

### 1.1 The backfill generator (one-time migration)

`capture/scripts/ui2-screen-elements.mjs` — a **migration tool**, not a runtime dependency.
Run per screen; writes one map per snapshot (03 §1.2).

**§1.0 — what "the frame" means (decided 2026-09-10 — 09 §G-5).** Ten screens are specced but
**twelve** snapshots back them, and two are not single frames: `shared-edit-field` freezes
`edit-field-group-fields.png` (1176×3286, exported from **section** `3875:8253`, six frames
inside) and `edit-field-overview.png` (2048×738, several frames side by side). The ruling: the
map describes **the exported image's own coordinate space**, whatever node produced it.

| Field | Single frame | Composite (section / multi-frame sheet) |
|---|---|---|
| `node` | the frame's node id | the exported **section** or sheet node id |
| `size` | the frame's point size | the exported node's point size |
| rects | fractions of the frame | fractions of the whole image |
| aspect guard | frame ratio vs PNG ratio | exported-node ratio vs PNG ratio — identical arithmetic |
| §4 closed-list gate | unchanged | unchanged: every kept ref must appear in that screen spec's §4 |

Nothing else changes: the browser hit-tests fractions of the image it is showing, which is exactly
what it has. The backfill therefore runs over **12 snapshots**, not 10 screens.

Resolution, in order, per Figma instance in the frame:

1. Read the exported node's `get_metadata` tree; keep every `<instance>` node with its `name`,
   node id, and rect. **The rect conversion is the step that gets this wrong if it is left
   implicit.** **Corrected 2026-09-10 (build phase 3, against the live MCP):** `get_metadata`
   reports each node's rect **relative to its PARENT**, not in absolute canvas coordinates — only
   the root carries a canvas position (`<frame id="3622:5487" x="22215" y="5495" …>` with children
   at `x="0"`). So the walk **accumulates offsets down the tree**: a node's frame-space origin is
   the sum of its ancestors' `x`/`y` below the root, and each instance becomes
   `x = (ox / root.w)`, `y = (oy / root.h)`, `w = w / root.w`, `h = h / root.h`.
   Values are clamped to `0…1` — horizontally scrolling rails are genuinely wider than the frame
   (`home-dashboard`'s KPI rail is 468pt inside a 440pt frame, and its third card starts at 312)
   — and an instance lying **wholly** outside the root's box is dropped rather than clamped to an
   edge.

   Since the metadata comes from the Figma MCP, which only the agent can call, the generator takes
   a **saved metadata dump** as input rather than fetching it — the same pattern `/ui2-screen`
   already uses ("grep the saved metadata dump", `.claude/commands/ui2-screen.md:91-168`).
2. Build a lookup from the registry's **Figma ref** column: each row's cited set/node ids and
   the parenthesised sheet name (`set 3668:7440 (sheet, Search results)` → `C-037` keyed by
   both `3668:7440` and `search results`).
3. Match an instance by **node id first** (the instance's main-component id, when the metadata
   exposes it), then by **case-folded name**.
4. Keep a match **only if** the resolved `C-###` appears in that screen spec's §4 closed list.
   This is the hand-check gate from D5, mechanised: the spec already states which rows the
   screen renders, so a match outside that list is wrong by construction.
5. Anything unresolved is **written to a `.unmapped.json` report, not to the map** (D5). The
   report is the operator's worklist, not an artifact the browser reads. **It is written to
   `capture/scripts/out/<snapshot-stem>.unmapped.json`** (delta audit 2026-09-10, 09 §G-18) with
   `capture/scripts/out/` added to `capture/.gitignore` — beside the map under `docs/ui2` it would
   commit operator scratch into the program's normative tree and churn the screen index's
   `dirStamp` on every generator run.

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
  `buildUi2Index()` (03 §2.4). **Resolution is per UNIQUE ref** (09 §X-3): a screen renders
  fourteen `C-052` chips, and `built` costs an `isBuilt()` fs check (`server.mjs:1278`). Build one
  `Map<ref, resolved>` for the screen and reuse it for **both** `elements[].resolved` and the
  existing `components[]` array (`server.mjs:1543-1546`), so the two can never disagree — that
  array gains `built` in the same move.
- **PNG dimensions** (09 §G-3): `pngSize()` moves from `server.mjs:1190` into
  `capture/lib/png-size.mjs`, `buildUi2Screens` records `{ width, height }` on each snapshot, and
  the aspect guard runs in the lib where E-2 can test it.

## 2. Notes storage

`capture/lib/ui2-notes.mjs` (new). Pure functions over the two note directories, unit-tested
without the server.

| Export | Contract |
|---|---|
| *CLI:* `node capture/lib/ui2-notes.mjs read <target>` | Prints `{ exists, file, notes, parseError }` as JSON on stdout and exits 0 (exit 2 on an unknown target). **This is how the two skills read notes** (09 §X-2) — the module runs standalone with no server and no DB, so "one parser" is true in practice and not just in intent. |
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
| `GET /api/ui2/mentions` | 03 §2.3. Built from `buildUi2Index()` + `buildUi2Screens()`, both already cached. `hasNotes` comes from **one `readdir` per notes directory** turned into a `Set` — never a stat per row (09 §G-15). The directories' own `README.md` (03 §1.1) is filtered out, and a missing directory yields an empty set rather than an error. |

`capture/src/api.js` gains `fetchUi2Notes(target)`, `postUi2Note(target, body)`,
`fetchUi2Mentions()` in the same style as the existing fetchers.

## 4. Screen render targeting

### 4.1 Hit source

`Ui2Layout.jsx:183` currently derives `elements` from `vdata?.elements?.elements` and gates it on
`activeShot.platform === 'iphone'` — a built component's render. Screens take the parallel
path: `activeVariant.elements?.elements`, gated on `isScreen`, feeding the **same** `elements`
const (D2 of the decisions gate, 2026-09-10 — see §4.4).

**Corrected 2026-09-10 (audit pass 1) — `hitTest` is not reusable as it stands.** D8 *is* already
its rule, but the function is an inline `useCallback` (`Ui2Layout.jsx:200-208`) that builds its
`label`/`path` from `e.name` and returns no `ref`, while R2 requires the label to come from the
live registry and R3 requires the `ref` to set `?c=`.

**It is extracted to `capture/src/lib/hit-test.js`** — one exported pure function, no React:

```js
export function hitTest(elements, fx, fy) // → null | { ref, name, path, selector, rect }
```

| Rule | Behavior |
|---|---|
| Containment | `fx >= e.x && fx <= e.x + e.w && fy >= e.y && fy <= e.y + e.h` |
| Winner | smallest area among the hits (D8) |
| Tie | the entry appearing **first** in the array wins — a stable sort preserves map order, and both producers emit the innermost first (D8, corrected 2026-09-10) |
| `ref` | `el.ref ?? null` — screens carry it, the iOS harness maps do not |
| `name` | `el.name` (the map's stored name; the caller resolves the live registry name for display) |
| `path` / `selector` | unchanged from today: hits reversed, outermost → innermost, joined ` › ` |
| Empty / null / no hit | `null`, never a throw |

`Ui2Layout` keeps a one-line `useCallback` wrapper over it so the component's memoisation is
unchanged, and the 2.0 comment path keeps the exact behavior it has today.

### 4.2 Pointer plumbing (the part the draft missed — 09 §C-3, §C-4)

Hover and click do **not** reach this feature through the existing props. Both need additive
changes to two components shared with the 1.0 era, so both are written here in full.

**`ZoomPane.jsx` — two additive changes.**

| Today | Change |
|---|---|
| `onMouseMove` reports hover only in comment mode: `if (commentMode && …) onHoverInspect?.(fx, fy)` (`:104`) | Add a second, independent call: `if (!commentMode && onHoverTarget && inBounds) onHoverTarget(fx, fy)`. The comment-mode branch is untouched, so 1.0 and the 2.0 component path behave exactly as today. |
| `onMouseLeave` clears only in comment mode (`:141`) | Also call `onClearTarget?.()` unconditionally. |
| `onMouseDown` starts a pan drag whenever comment mode is off (`:77-93`) | Record the down point. On `mouseup`, when `onSelectTarget` is provided, comment mode is off, the button was primary, and the pointer moved **≤ 4px** in both axes, call `onSelectTarget(fx, fy)` with the up point's fractions. A pan (any drag over 4px) therefore never selects, and the existing drag code is unchanged. |

`onHoverTarget` / `onClearTarget` / `onSelectTarget` / `componentBox` default to `undefined`, so
`CompareDetail.jsx:523,536` and `ComponentsLayout.jsx:351` — which never pass them — are
byte-for-byte unaffected. That is the regression 08's 1.0 check covers.

**`RenderPane.jsx` — pass-through only.** It gains the same four props and adds `componentBox` to
the `commentProps` object it assembles (`:119-139`); the three handlers go to `ZoomPane` beside
`onHoverInspect`/`onClearInspect` (`:280`).

**`CommentLayer.jsx` — one new box.** `componentBox` renders the `--component` variant (§4.3).
It is NOT gated on comment mode (the host already forces it null there) and sits directly above
`--inspect` in the same stacking band, below the comment boxes.

### 4.3 Interaction

A new `componentTarget` state on `Ui2Layout`, distinct from the comment-mode `hoverTarget`:

| Condition | Behavior |
|---|---|
| `isScreen`, map present, **comment mode OFF**, pointer over the render | `onHoverTarget` hit-tests; `componentTarget` = the smallest containing element, or `null` |
| Pointer leaves the render | `componentTarget = null` |
| **Comment mode ON** | `componentTarget` forced `null` by the same effect that clears `hoverTarget` (`Ui2Layout.jsx:217-219`), and `ZoomPane` never calls `onHoverTarget` — comment mode owns the pointer, and its own `hoverBox` behaves as today |
| Primary click inside a mapped rect, comment mode OFF, ≤4px of movement | `?c=<ref>` on the URL, right panel switches to the Component tab (R3) |
| Click outside every rect | Clears the selection: `?c=` is removed and the Component tab returns to its empty state (09 §G-10 — this replaces the draft's reference to a clear control the tab does not have) |
| Any drag over 4px | Pan, exactly as today. No selection, no box change |

Comment mode remains the sole owner of click-to-place (`CommentLayer`'s `handleClick`); the
component click path runs only when comment mode is off, so the two can never both fire.

### 4.4 What this does to comments (decided 2026-09-10 — 09 §G-8)

Feeding screens through the same `elements` const means `placeDraft` (`Ui2Layout.jsx:231-232`)
starts attaching `target` to comments placed on a **screen**, and comment mode's own `hoverBox`
starts drawing element boxes there. **This is adopted deliberately**, not tolerated:

- A screen comment records `targetSelector` (the containment path) and `targetLabel`.
- `targetLabel` for a screen map is **`C-### Name` resolved against the live registry**, falling
  back to the map's stored `name` — the same rule as R2, so a pin and a hover box never disagree.
- Existing screen comments have no target and keep rendering exactly as they do now
  (`CommentLayer.jsx:34` already treats a missing `targetMeta` as "no box").
- 02 §Backward compatibility and 03 §4 carry the amendment: the comment *channel* is untouched
  (D2), but screen comments gain target metadata they did not have before.

### 4.5 The box

`CommentLayer.jsx` gains a third variant beside `--inspect` and `--hover`:

```jsx
{componentBox && (
  <div className="cmp-target-box cmp-target-box--component" style={{ …percentages… }}>
    <span className={`cmp-target-box__label${insideFlip ? ' cmp-target-box__label--inside' : ''}`}>
      {componentBox.label}
    </span>
  </div>
)}
```

- Drawn **below** the comment boxes in stacking order, so an open thread's target still wins.
- `pointer-events: none` on the box and its label — the hit test reads the render's own pointer
  events, and a box that ate them would flicker at its own edges.
- Label content is `C-### Name` from the live registry (R2); it falls back to the map's stored
  `name` only when the ref no longer resolves.
- Label sits above the box; when there is not `LABEL_CLEARANCE` (24px) of room above it, it flips
  inside the box's top edge (R2). **Corrected 2026-09-10 (build phase 4):** the draft had the host
  compute this from the rect's `y` fraction, which cannot be right — the same box at 40% zoom and
  at 200% zoom has the same fraction and very different room above it. `CommentLayer` measures its
  own height (it is `inset: 0` over the render, so its height IS the render's on-screen height)
  and decides in pixels.
- Zero DOM at rest: `componentBox` is null unless hovering (R1).

## 5. The Component tab

`capture/src/pages/components/Ui2ComponentTab.jsx` (new). Tab order for a screen becomes
**Screen · Component · Comments** (R4); for a component the existing order is untouched.

### 5.0 Making the tab controllable (09 §C-5)

`SidePanel` owns its tab in local state today (`SidePanel.jsx:25`), derives the tab list per era
and kind (`:34-40`) and falls back to `comments` when the current one is not in the list (`:41`).
R3 (a click on the render activates Component) and R5 (reload and the same component is still
selected) both need it set from outside. The change is additive:

| Change | Detail |
|---|---|
| New optional props | `tab` + `onTab`. When `tab` is given, `SidePanel` is controlled: `activeTab = tabs.includes(tab) ? tab : 'comments'` reads the prop instead of the state, and every tab button calls `onTab(t)`. When it is absent — every 1.0 caller and the 2.0 component path — the existing local state runs unchanged. **`Ui2Layout` passes them only when `isScreen`** (delta audit 2026-09-10): passing a controlled `component` tab on a component row, whose tab list has no such entry, would pin the panel to the `comments` fallback and break tab switching on every 2.0 component. |
| Tab list for a screen | `['screen', 'component', 'comments']` (R4). `TAB_LABEL.component = 'Component'`. Component rows are untouched. |
| `!ready` branch (`:53`) | Add `component` beside `details` and `screen`, so a screen with no frozen frames still renders the tab rather than "Select a component and variant". |
| Chip callback | `Ui2ScreenTab` gains an `onSelectComponent` prop; `SidePanel` passes the host's handler through. §5.6. |

`Ui2Layout` derives the active tab from the URL: `?c=` present and the panel not explicitly moved
elsewhere → `component`. Explicitly clicking another tab wins until the next selection event
(a render click or a chip click), which sets it back to `component`.

### 5.1 Content (D4)

**The tab's identity source is the registry, not the map (delta audit 2026-09-10, 09 §G-17).**
A `.cmp-ui2s__chip` click (R6) can select a component the map does not contain — the Screen tab
lists every row in the spec's §4 closed list, while D5 deliberately omits any instance the
generator could not resolve. A tab that read its identity from `elements[].resolved` would show an
empty state for exactly those components. So: `fetchUi2Detail(ref)` is the source of truth, and
`elements[].resolved` is only an **instant first paint** while that request is in flight.

| Block | Source |
|---|---|
| Title: `C-###` + registry name + status chips (`specced` / `built` / `artwork`) | `fetchUi2Detail(ref)`; painted immediately from `elements[].resolved` when the selection came from the render and that entry exists |
| Frozen artwork thumbnail | the component's `snapshot.url` |
| **Open component →** | `navigate('/components/2.0/' + ref)` (R6) |
| Designed states | the contract's state list, or "not specced yet" |
| Notes list | §5.2 |
| No selection | Empty state naming both ways to select: hover-and-click the render, or click a chip in the Screen tab |

**View states (09 §G-13).** Every one of these is specified because the tab has four independent
data sources and three of them can be slow or absent:

| State | Rendering |
|---|---|
| Selection set, `fetchUi2Detail(ref)` in flight | Title block renders immediately from `elements[].resolved` (already on the screen detail); the designed-state list shows a muted "loading states…" line. Never a whole-tab spinner — the identity is already known. |
| `fetchUi2Detail(ref)` failed | The state list is replaced by an inline error line with a Retry button. Title, artwork, Open and notes stay usable. |
| `GET /api/ui2/notes` failed | The notes list is replaced by an inline error line with a Retry button. The Add note control stays enabled — a failed read must not block writing. |
| `parseError` on the notes response (03 §2.1) | A visible banner above the list: "This note file could not be read — `<parseError>`" plus the file path. **Never silently renders as "No notes yet"**: that is the one outcome that loses the owner's words without telling them. |
| `detail.canCapture === false` (production mode — 09 §X-1) | The Add note control is not rendered. Reading notes still works. |
| Ref no longer in the registry | Title falls back to the map's stored `name` with an "unknown component" chip; Open is disabled; notes still load (the file is keyed on the id, not the registry). |

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

**Surviving the app's own navigation (decided 2026-09-10 — 09 §G-9).** As written in the draft the
selection could not survive a single frame switch, because `variantPath` builds a bare path
(`Ui2Layout.jsx:94`) and the canonicalising effect rewrites the URL with `{ replace: true }`
whenever the key is not the canonical slug (`:126-128`) — so even `/components/2.0/home-dashboard?c=C-023`,
the exact form a person pastes, lost its selection before anything read it. Three changes:

| Change | File |
|---|---|
| `variantPath(v)` appends `location.search` — the state path carries every query param forward | `Ui2Layout.jsx:94` |
| The per-key reset effect (`:130`) keeps clearing version/comment state but **does not touch `c`** | `Ui2Layout.jsx:130` |
| Switching to a different SCREEN or component (the tree's `navigate`, `:548`) drops `c`, because a selection is meaningless on another screen | `Ui2Layout.jsx:548` |

`capture/src/lib/ui2-url.js` (new) holds the one helper both call — `withSearch(path, search)` —
so the rule is tested (H-6) rather than repeated.

### 5.6 Chip behavior change (R6)

`Ui2ScreenTab.jsx:73`'s `.cmp-ui2s__chip` currently calls `navigate('/components/2.0/' + id)`
through its own `useNavigate` (`:22`). It becomes a selection: the component takes an
`onSelectComponent(id)` prop (threaded through `SidePanel`, §5.0) and calls it; the host sets
`?c=<id>` and switches to the Component tab. `useNavigate` leaves `Ui2ScreenTab` entirely, so the
tab has no navigation of its own. This is the one
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
| 0 — Load context | Add: load notes for the target **and for every dependency resolved in phase 1**, plus **every screen whose §4 closed list names the target** (09 §G-14 — a note written while looking at a screen is the most natural note to write, and the draft left it invisible to the build). Notes are loaded by running `node capture/lib/ui2-notes.mjs read <target>` (09 §X-2), never by reading the markdown by eye — the module is the parser, so the skill and the browser cannot disagree about what a note says. |
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

**Binding rules.** The command **inherits `/ui2-component-build`'s entire Hard-rules block
verbatim** (`.claude/commands/ui2-component-build.md:105-147`) and re-prints it at the head of
every phase — it edits the same preview lane, so the same rules bind it (09 §G-12): wired into
nothing · legacy untouched and the exact file-write allow-list · tokens by name (SwiftLint bans
`Color(hex:)`, raw `.system(size:)`, `print`/`NSLog`, `LazyVStack`/`LazyVGrid`) · value sets have
one owner · every prop traces · states are the contract's states · no `#if DEBUG`, no `#Preview` ·
idempotent and visible · never fudge.

On top of those, four of its own: notes win over the contract and newer notes win over older, per
property (D3/R13) · the pixel diff against Figma is not the oracle when the drift list explains
the difference · `docs/ui2` is read-only · one component per run.

**Capture asks first (decided 2026-09-10 — 09 §O-5).** `iphone/.claude/CLAUDE.md:86-98` permits
running `capture/runners/ui2/capture.mjs` without asking, but justifies it with "Running
`/ui2-component-build` IS the permission". That reasoning does not transfer to a second command,
so phase 4 **asks before it captures**. If the owner later extends the carve-out's wording to name
this command too, this line is deleted in the same edit.

### 7.3 `ui2-screen.md` (edit)

Phase 2 gains a step beside the existing component-artwork step: **write the element map**.
The decomposition walk already pairs every instance with a registry row; serialise those pairs
plus each instance's rect to `docs/ui2/screens/assets/<snapshot-stem>.elements.json` per
03 §1.2, `generatedBy: ui2-screen@<date>`. An element the walk could not resolve is omitted
(D5), and the phase-2 exit checklist gains: *element map written, every §4 row represented ✓*.

Phase 0 also gains: read the screen's own notes via `node capture/lib/ui2-notes.mjs read <id>`
(09 §X-2) — on a re-spec they are owner intent recorded since the last run.

Phase 2's map step writes the rects per §1.0's conversion, records `generatedBy:
ui2-screen@<date>`, and — when the exported node is a section or a multi-frame sheet — records
that node rather than inventing a frame.

## 8. Component manifest (REFERENCE.md §3 rule 7)

Added 2026-09-10 at the decisions gate (09 §C-2). **The build may not create, substitute, or
extend a unit that has no row here.** A mid-build discovery is a dated amendment to this table
plus a delta audit, before the code is written.

### 8.1 New units

| Unit | Path | Parameters | States it renders | Used by / pattern it copies |
|---|---|---|---|---|
| `Ui2ComponentTab` | `capture/src/pages/components/Ui2ComponentTab.jsx` | `detail` (screen detail), `ref` (`string\|null`), `resolved` (`{name,specced,built,hasSnapshot}\|null`), `onOpen(ref)`, `onSelectComponent(ref)`, `canWrite` (bool) | no-selection · loading-states · states-error · notes-loading · notes-error · parse-error · unknown-ref · composing | `SidePanel` (screen kind only). Copies `Ui2ContractTab.jsx`'s block/field structure and `.cmp-ui2c__*` class family |
| `NoteList` | `capture/src/pages/components/NoteList.jsx` | `notes` (`[{id,at,body,refs}]`), `parseError` (`string\|null`), `onMention(kind,id)`, `onAdd()` | empty · list · parse-error · one-card-expanded | `Ui2ComponentTab`, and the Screen tab for screen notes (D6). New markup — no existing card list clamps to 2 lines |
| `NoteComposer` | `capture/src/pages/components/NoteComposer.jsx` | `mentions` (index), `busy` (bool), `error` (`string\|null`), `onSave(body)`, `onCancel()` | empty · typing · typeahead-open · saving · save-error · confirm-discard | `Ui2ComponentTab` (R8). Button bar copies the `ConfirmDialog` action-row pattern; discard prompt uses `ConfirmDialog` itself, never `window.confirm` |
| `MentionTypeahead` | `capture/src/pages/components/MentionTypeahead.jsx` | `items`, `query`, `anchor` (`{top,left}`), `onCommit(token)`, `onDismiss()` | hidden · list · no-match · active-row | `NoteComposer` (R9). Copies the keyboard/active-row behavior of `IconSelect.jsx` |
| `hitTest` | `capture/src/lib/hit-test.js` | `(elements, fx, fy)` | — (pure) | `Ui2Layout` for both the comment path and the component path (§4.1). Extracted from `Ui2Layout.jsx:200-208`; precedent `src/lib/ui2-layout.js` |
| `withSearch` | `capture/src/lib/ui2-url.js` | `(path, search)` | — (pure) | `Ui2Layout`'s `variantPath` + tree navigation (§5.5) |
| `filterMentions` / `commitToken` | `capture/src/lib/mentions.js` | `(items, query)` · `(text, caret, token)` | — (pure) | `NoteComposer` + `MentionTypeahead` (§5.4) |
| `ui2-notes` module | `capture/lib/ui2-notes.mjs` | §2's export table + the `read` CLI | — | routes (§3) and both skills (§7) |
| `png-size` | `capture/lib/png-size.mjs` | `(absPath)` → `{width,height}` | — | `buildUi2Screens`'s aspect guard (§3). Moved from `server.mjs:1190` |
| backfill generator | `capture/scripts/ui2-screen-elements.mjs` | CLI: `<screen-id>` | — | one-time migration (§1.1) |

### 8.2 Modified units (every change additive — these are shared with the 1.0 era)

| Unit | Change | Callers that must keep working unchanged |
|---|---|---|
| `SidePanel.jsx` | optional `tab`/`onTab` (controlled mode), `component` in the screen tab list + `TAB_LABEL`, `component` in the `!ready` branch, `onSelectComponent` pass-through | `ComponentsLayout.jsx` (1.0, `mode="code"`), the 2.0 component path — neither passes `tab`, so both keep local state |
| `Ui2Layout.jsx` | `componentTarget` state, `?c=` read/write, tab derivation, screen `elements` source, `variantPath` carries search, wires the four new render props | — |
| `Ui2ScreenTab.jsx` | `onSelectComponent` prop replaces its own `useNavigate` (R6) | — |
| `RenderPane.jsx` | four new optional props passed through; `componentBox` added to `commentProps` | `ComponentsLayout.jsx:351`, `CompareDetail.jsx:523,536` — omit them all |
| `ZoomPane.jsx` | non-comment-mode hover call, unconditional leave-clear, click-vs-drag select (§4.2) | same two 1.0 callers — every new prop defaults `undefined` |
| `CommentLayer.jsx` | renders `componentBox` as `--component` with a label | 1.0 compare + 1.0 components never pass it |
| `styles.css` | `.cmp-target-box--component`, `.cmp-target-box__label(--inside)`, `.cmp-ui2n__*` | — |
| `api.js` | `fetchUi2Notes`, `postUi2Note`, `fetchUi2Mentions` | — |
| `lib/ui2-index.mjs` | element-map attach + aspect guard + snapshot dimensions | — |
| `server.mjs` | 3 routes + `elements` on `screen-detail` + `pngSize` moved out | — |
