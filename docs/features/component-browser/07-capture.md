# 07 — Capture (the build)

All feature work lands here: the capture backend, the capture SPA, the MCP server, and the
root `.claude/commands/component-resolve.md`. Contract shapes are in 03; decisions cited as
D# are in 01.

## 1. Backend units

| Unit | File | What it does |
|---|---|---|
| fs index | `capture/lib/fs-index.mjs` **(new)** | Walks `iphone/MakeReady/Components/` → `{tree, byPath, byName}`; joins comparisons by basename OR kebab-case(basename) and wiring cases by `component.<Name>`/`component.<kebab>` (D3 as corrected CR1); caches ONLY the fs walk + ViewRegistry parse (`fs.watch(dir,{recursive:true})` + registry mtime — G4/CR13); fixture/adapter fields re-derive per request; exports `getIndex()`, `resolveScope(scope)` (D6 grammar incl. bare unique name), `wiringFor(name)`. Collisions flagged per D17. |
| routes | `capture/server.mjs` | §2 of 03: `/api/components/tree`, `/detail`, `/version/:id`, `PUT /fixture`, `/scope`. Follow the file's existing route style (inline async handlers, `syncComparison` where a comparison is touched). Fixture write per 03 §2.4. |
| retention | `capture/db/index.mjs` | DB-1: delete the pruning block in `finalizeVariantVersion()`, keep re-parenting. DB-2: `createComment` accepts `versionId`. DB-3: `listVersions(comparisonId, variantName)` newest-first with screenshots. |
| MCP | `capture/mcp/comments.mjs` | New `resolve_scope` tool = 03 §2.5 with absolute screenshot paths + `versionLabel` (D5). Existing tools untouched. |

## 2. SPA route & layout

`/components/*` (React Router v6 splat — the app is on v6, `App.jsx`; corrected G2 audit
2026-09-03) in `capture/src/App.jsx` → `ComponentsLayout`, which parses the splat as
`<path…>/<variant?>` against the fs index (a trailing segment matching a variant name of the
resolved component is the variant; otherwise the whole splat is the path). Deep link: path +
variant in the URL (R1); selecting in cols 1–2 navigates.
Live updates: subscribe to socket `compare:shot`/`compare:done` exactly as
`CompareLayout.jsx` does, debounced into a reload of the affected detail + tree counts.

**Shared-viewer extraction (targeted refactor, additive):** `ZoomPane`, `CommentLayer`, and
`Thread` move out of `capture/src/pages/compare/CompareDetail.jsx` (≈118–380) into
`capture/src/components/viewer/` and are imported by BOTH pages. No behavior change for
`/compare`; the iframe hit-test (`capture-inspect` postMessage) becomes an optional prop the
browser simply doesn't pass (D14).

## 3. The four columns

### 3.1 Column 1 — component tree
`ComponentTree` fetches `GET /api/components/tree`, holds the filter string (D11 matching,
pruning to matching leaves + ancestors), and renders `TreeView` (D12). Rows: folder rows with
chevrons; component rows with name, unresolved-comment count badge, and a gray "not
capturable" badge when any wiring check fails (D2); collision rows get an error badge and are
unselectable (D17). Hover/context actions per row copy the resolve command (D13). Selection
drives the route.

### 3.2 Column 2 — variants
`VariantList` renders `detail.variants[].name` with per-variant unresolved-comment counts; a
fixture without variants shows the single `default` entry (R3). Unwired component: the column
shows one line — "no variants — component not capturable yet". Selection drives the route.

### 3.3 Column 3 — render
`RenderPane`: ZoomPane (R4) showing the **selected version's** PNG; `VersionTimeline` strip
(newest first, thumbnails + capture date + gitSha, D4) — selecting an old version loads
`GET /api/components/version/:id` and shows that render with its comments; a "current" chip
marks the newest. `DevicePicker` appears only when `viewports.length > 1` (D10).
**Recapture** button = D15 (capture POST **with `platform:"iphone"`** + SSE `CaptureLogDock` + socket refresh); the DevicePicker refetches `detail` with the chosen viewport (03 §2.2, CR9).
Never-captured (wired) component: empty state with the Recapture button. Comment mode: the
`c` key / Comment button + pin placement work exactly as in `/compare`, minus element
hit-testing; the POST includes the on-screen `versionId` (DB-2).

### 3.4 Column 3, unwired — wiring checklist
`WiringChecklist` replaces the render: the three D16 checks with pass/fail, the Swift file
path, and a copyable `/capture-add <kebab-case(Name)>` command (03 §2.2 `wiring`, D20).

### 3.5 Column 4 — side panel
`SidePanel` with two tabs (Figma-style, reusing the `cmp-tab-switch` pattern):
- **Comments** (`CommentsTab`): thread list for the selected variant — pins made on the
  version being viewed render on the canvas; the list groups "this version" first, then
  "other versions" (each labeled with its capture date, D5); resolved comments dimmed with ✓
  (D14). Reply/resolve per thread.
- **Data** (`DataEditor`): recursive key/value form over the variant's `shared` (D9) built
  from `FieldRow` units; dirty-state tracking; **Save** → `PUT /api/components/fixture`
  (D8); **Save & Recapture** → save, then D15. A failed save surfaces the route's error
  verbatim.

## 4. Component manifest (exhaustive — building anything without a row here is a spec defect)

| Component | File (capture/src/…) | Props | States | Usage / pattern copied |
|---|---|---|---|---|
| ComponentsLayout **(new)** | `pages/components/ComponentsLayout.jsx` | — (route params) | loading, loaded, load-error | Route shell + 4-col CSS grid; socket sub per `CompareLayout.jsx` |
| ComponentTree **(new)** | `pages/components/ComponentTree.jsx` | `tree, selectedPath, onSelect, onCopyCommand` | filtered/unfiltered, empty-filter-result | Col 1 host; filter per D11; badges; copy per D13 |
| TreeView **(new)** | `components/tree/TreeView.jsx` (+ styles in `styles.css`) | `nodes:[{id,label,icon?,children?,muted?}], selectedId, onSelect, defaultExpandedDepth` | expanded/collapsed per node, selected, keyboard focus | D12 port of fai-cd `tree-view.tsx`: flat rows, roving tabindex, ARIA tree keys, chevron-vs-row split |
| TreeSearchInput **(new)** | `pages/components/TreeSearchInput.jsx` | `value, onChange` | empty, active | Same matching/clear affordance as `components/grid/` SearchInput |
| VariantList **(new)** | `pages/components/VariantList.jsx` | `variants:[{name,unresolvedComments}], selected, onSelect` | list, single-default, unwired-empty | Col 2; visual pattern of CompareLayout's variant nav |
| RenderPane **(new)** | `pages/components/RenderPane.jsx` | `detail, variant, versionId, onSelectVersion, onRecapture, commentMode, onToggleCommentMode, comments, onAddComment(screenshotId-anchored), onReply, onResolve, onDelete` (comment props amended G5, audit 2026-09-03) | render, never-captured, unwired, capturing, comment-mode | Col 3 host |
| ZoomPane **(existing-modified)** | `components/viewer/ZoomPane.jsx` | as today — fully CONTROLLED (`view/setView`, `hover/setHover`, `natural/fallbackNatural`, `onReset`, `animating/clearAnim`); img mode only in the browser | fit, zoomed, panning | EXTRACTED verbatim from `CompareDetail.jsx` 216-371; hosts own view state + the `c`/`0`/`Esc` keybindings (CR6); `/compare` re-imports |
| CommentLayer **(existing-modified)** | `components/viewer/CommentLayer.jsx` | as today (NO new props — the capture-inspect hit-test lives in CompareDetail's host code and stays there; CR6/D14) | pins, draft, popover thread | EXTRACTED verbatim 118-195; `/compare` re-imports |
| Thread **(existing-modified)** | `components/viewer/Thread.jsx` | as today | open, resolved | EXTRACTED; unchanged |
| VersionTimeline **(new)** | `pages/components/VersionTimeline.jsx` | `versions, selectedId, onSelect` | current-selected, old-selected, single-version | Newest-first strip per D4/R8 |
| DevicePicker **(new)** | `pages/components/DevicePicker.jsx` | `viewports, selected, onSelect` | hidden (1 viewport), shown | D10; segmented control per `cmp-tab-switch` styling |
| WiringChecklist **(new)** | `pages/components/WiringChecklist.jsx` | `wired, name, file, addCommand` | 1–3 checks failing | §3.4 |
| SidePanel **(new)** | `pages/components/SidePanel.jsx` | `tab, onTab, children` | comments-tab, data-tab | `cmp-tab-switch` segmented pattern |
| CommentsTab **(new)** | `pages/components/CommentsTab.jsx` | `comments, versionId, onReply, onResolve` | empty, grouped this/other-version, resolved-dimmed | Composes Thread; grouping per D5 |
| DataEditor **(new)** | `pages/components/DataEditor.jsx` | `shared, onSave, onSaveAndRecapture, saving` | clean, dirty, saving, save-error | D8/D9 |
| FieldRow **(new)** | `pages/components/FieldRow.jsx` | `k, value, onChange, depth` | string/number/boolean input, collapsible object/array group, raw-JSON fallback | D9 recursion unit |
| CaptureLogDock **(new)** | `pages/components/CaptureLogDock.jsx` | `lines, capturing, viewportLabel` | streaming, done, error | NEW — copies the inline `cmp-log--docked` JSX pattern (CompareDetail.jsx:906-911; there is no existing component to extract — CR7); `/compare` keeps its inline block untouched |

Supporting non-UI units: `capture/lib/fs-index.mjs`, the 03 §2 routes, `db/index.mjs` DB-1..3,
MCP `resolve_scope`, `.claude/commands/component-resolve.md`. Styling: extend
`capture/src/styles.css` with `cmp-tree-*`, `cmp-cols-*`, `cmp-timeline-*`, `cmp-fields-*`
rules in the existing dark-token idiom; no new styling system.

## 5. Live update + error behavior

- Socket `compare:shot` matching the selected comparison refreshes col 3 (new version appears
  at timeline head, auto-selected only if "current" was selected); tree/variant badge counts
  refetch on `compare:done`.
- Capture spawn failure or non-zero runner exit → the docked log shows the stream; the
  Recapture button re-enables; no Version row is created by a failed run (existing runner
  behavior).
- Tree/detail fetch failures render an inline error with a retry button (no blank columns).

## 6. `.claude/commands/component-resolve.md` (new, root repo)

Modeled on `compare-resolve.md`; the invocation is `<scope>` only (D7). Procedure it encodes:

1. Parse scope (D6 grammar). Call MCP `resolve_scope {scope}`. Zero components → say so, stop.
   Zero unresolved comments → report scope size and stop.
2. Comments arriving from `resolve_scope` are iPhone-platform only (03 §2.5 — web pins belong
   to `/compare-resolve`). Group by component, oldest first within a component. For each comment:
   read `pinnedScreenshot` (the version it was left on) and `latestScreenshot`; old-version
   comments are treated as references against the current render (`versionLabel`, D5).
3. **The iPhone component is the thing being edited** (inverse of `/compare-resolve`): make
   the change in the component's `swiftFile` (or in `fixtureFile` when the comment is about
   fixture data). Never edit web code from this command. Ambiguous/tradeoff comments →
   `reply_comment` with options, leave unresolved, continue.
4. After each addressed comment: `reply_comment` describing the change, then
   `resolve_comment`.
5. When all components in scope are processed: batch-recapture every touched component —
   `cd capture && node runners/compare/capture-batch.mjs <viewport> <id> <id> …` (viewport
   FIRST — capture-batch.mjs:74), one run per distinct viewport among the resolved comments,
   default `pro-max` (03 §4, CR12) — so fresh versions land (R7). Verify via `get_latest_screenshots` + reading the
   new PNGs against the resolved comments.
6. Summary: per component — resolved / replied-awaiting-decision / failed-verification; point
   the user at `http://localhost:5950/components/<path>`.

Gate note: the command edits Swift → it must run `npm run ios:build-check` before the batch
recapture (a broken build would burn an xcodebuild cycle) and report lint per the iphone gate
conventions (REFERENCE.md §7).
