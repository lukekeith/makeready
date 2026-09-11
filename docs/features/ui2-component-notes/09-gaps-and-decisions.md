# 09 — Gaps & decisions ledger

Seeded by the draft 2026-09-11. Owned by `/build-spec-audit` from its first pass onward.

**Status: audit pass 1 complete (2026-09-10) — 16 new findings, 3 of them blocking.**
Not clean. The plan step is blocked until the rows marked **BLOCKING** are ruled at the
decisions gate.

**Legend (REFERENCE.md §12).** `G` gap · `D` decision needed · `O` non-technical/owner blocker ·
`C` component-coverage hole · `X` cross-app contract risk.
*Convention note (2026-09-10): the draft seeded this file with a local legend where `C` meant
"correction" and `X` meant "closed". Row `C-1` below was written under that legend and keeps its
id (ids are never reused or renumbered); every row from `C-2` and `X-1` onward carries the
REFERENCE.md §12 meaning. `D-1…D-6` are the draft's closed decisions, which live in 01's Decisions
table as D1–D6.*

*Date note: the draft stamped itself 2026-09-11 (UTC); this audit ran on 2026-09-10 local, the same
calendar day the files were written. The audit is after the draft, not before it.*

## Decisions & open items carried from the draft

| # | Kind | Row | Status |
|---|---|---|---|
| D-1 | D | Note storage — git-tracked markdown | ✅ CLOSED (owner 2026-09-11) → 01 D1 |
| D-2 | D | Notes and comments are separate channels, both retained | ✅ CLOSED (owner 2026-09-11) → 01 D2 |
| D-3 | D | Note beats spec; newer note beats older; overrides are reported, never auto-written into `docs/ui2` | ✅ CLOSED (owner 2026-09-11) → 01 D3 |
| D-4 | D | Component-tab depth: title + artwork + states + Open + notes | ✅ CLOSED (owner 2026-09-11) → 01 D4 |
| D-5 | D | Element maps: generate now for the 10 specced screens, hand-checked against §4; `/ui2-screen` authors them thereafter | ✅ CLOSED (owner 2026-09-11) → 01 D5 |
| D-6 | D | Screens carry notes as well as components | ✅ CLOSED (owner 2026-09-11) → 01 D6 |
| O-1 | O | **Note deletion.** D7 makes notes append-only, so a note written in error can only be retracted by a newer note saying so — which still leaves the mistake in the effective-requirement derivation's input. Does the UI eventually need a "retract" that marks a note inactive (not a delete), and should `/ui2-component-update` honor a retraction marker? | OPEN — non-blocking; append-only ships and this is revisited once the note volume is real |
| O-2 | O | **Per-property supersession is a judgement call.** 03 §3 step 4 says a later statement about "the same property" replaces an earlier one, but two prose notes do not declare which property they are about — the skill infers it. Does the composer eventually need light structure (an optional `property:` prefix, or a tag) so supersession is mechanical instead of inferred? | OPEN — non-blocking; prose + inference ships first, and C-4's behavior on real notes is the evidence for whether structure is needed |
| O-3 | O | **Unmapped instances.** D5 deliberately omits anything the generator cannot resolve, so parts of a screen will have no box. Is a visible affordance wanted (e.g. the Screen tab listing "N elements unmapped") so the gap is known rather than silently absent? | OPEN — non-blocking; the `.unmapped.json` report covers the operator, not the browsing owner |
| O-4 | O | **Notes on a component read from a screen.** A note is global to the component (01 Out of scope), with `@<screen-id>` as the scoping device. If it turns out most notes written from a screen are screen-specific, the model may need a real scope field rather than a convention. | OPEN — non-blocking; the convention ships and the note corpus is the evidence |
| G-1 | G | **The mention index does not include a component's own dependencies as first-class suggestions.** `@` lists everything alphabetically; when annotating `C-063` the useful mentions are usually `C-061` and its hosts. A relevance ranking (dependencies and consumers first) is not specified. | OPEN — cosmetic; alphabetical ships |
| G-2 | G | **No test asserts the aspect-ratio guard against a real screen PNG**, only against a fixture (E-2). A real Figma export at scale 2 or 3 is the case that matters, and the guard silently discards a map when it trips — a false positive would make the whole feature look unbuilt. | **SHARPENED 2026-09-10:** the risk is real and was already live in the doc — 03 §1.2's worked example would have been discarded (see G-4). All 12 screen PNGs were measured this pass; exports run 1×, 2× and dimension-capped (`home-dashboard.png` 331×2048 for a 440×2730 frame), and aspect survives all three. Fixture from a real export still owed in phase 1. |
| C-1 | C *(old legend: correction)* | `04-server.md` originally risked reading as "the capture server is out of scope". Corrected in-draft: the doc now states explicitly that "server" in this suite means `capture/server.mjs`, whose changes are in 07 §3. | ✅ CLOSED (draft, 2026-09-11) |

## X — cross-app / contract risks (audit pass 1)

| # | Row | Status |
|---|---|---|
| X-1 | **"Capture has no production surface" is false.** 02's backward-compatibility section claimed nothing deploys; `capture/server.mjs:79` treats `NODE_ENV=production` or `RAILWAY=true` as production and `:1883-1890` serves the committed `capture/dist/` bundle with an SPA fallback. The new GET routes run there; the POST is correctly inside the `!isProduction` block. **Two consequences the suite must carry:** (a) 07 §5.3 must hide the Add-note control when `detail.canCapture === false` (the existing convention for every write control in this app), and (b) 03 must state that a production instance without the `docs/ui2` tree returns `exists:false` / `elements:null` rather than 500. | 02 **corrected in place 2026-09-10**; (a) + (b) owed as spec edits |
| X-2 | **"One parser, so the browser and the skills cannot disagree" does not hold as written.** 07 §2 justifies `capture/lib/ui2-notes.mjs` as the single implementation, but the skills are prose instructions read by a model, not importers of the module — they re-derive the format from 03 §1.1, which is exactly the divergence the module was meant to prevent. **Recommended:** give the module a CLI entry (`node capture/lib/ui2-notes.mjs read <target>` → JSON on stdout) and have `/ui2-component-build` phase 0 and `/ui2-component-update` phase 0 call it instead of reading markdown by eye. Then the claim is true. | OPEN |
| X-3 | **`resolved.built` has no cheap source.** 03 §2.4 gives each element `resolved: { name, specced, built, hasSnapshot }`, but `built` is not an index field — it comes from `isBuilt(row.id)` (`server.mjs:1278`), an fs check per component, and screen-detail's existing `components[]` (`server.mjs:1543-1546`) deliberately omits it. A screen with fourteen `C-052` chips must not make fourteen fs checks. **Recommended:** resolve once per UNIQUE ref into a map and reuse it for both `components[]` and `elements[].resolved`, so the two can never disagree. | OPEN |

## G — gaps (audit pass 1)

| # | Row | Status |
|---|---|---|
| G-3 | **The aspect-ratio guard is specified where the PNG's dimensions do not exist.** 07 §1.3 puts it in `buildUi2Screens()` (`lib/ui2-index.mjs:817`), whose snapshot records only `file`/`repoPath`/`sha`/`capturedAt` (`:846-856`). The repo's one IHDR reader is `pngSize()` at `server.mjs:1190` — module-local, unexported. **Recommended:** move `pngSize` into a lib module, record `{ width, height }` per snapshot in `buildUi2Screens`, and let E-2 test the lib directly. | 07 **corrected in place 2026-09-10** (the gap is now stated in the doc); implementation task owed to the plan |
| G-4 | **03 §1.2's worked example would have been discarded by 03 §1.2's own guard.** It gave home-dashboard `size: {w:440,h:2126}`; the spec records the frame as 440×2730 (`docs/ui2/screens/home-dashboard.md` §1) and the PNG on disk is 331×2048 — a 28% aspect divergence against a 1% tolerance. A generator author copying the example would have written the content height instead of the frame height and produced maps that silently vanish. | ✅ **Fixed in the spec (2026-09-10)** — example corrected to 440×2730 with the arithmetic stated |
| G-5 | **BLOCKING — the contract assumes one snapshot = one Figma frame; two of the twelve are multi-frame composites.** `shared-edit-field` freezes `edit-field-group-fields.png` (1176×3286, exported from **section** `3875:8253`, which holds 6 frames) and `edit-field-overview.png` (2048×738, landscape, several frames side by side) — `docs/ui2/screens/shared-edit-field.md:22-23`. For those, `node` + `size` cannot mean "the frame", rects are not fractions of a frame, and the aspect guard compares against a section. `parseScreenSpec` makes each PNG a state, so both appear in the browser as targetable screens. **Recommended ruling:** `size` is the exported image's own coordinate space (frame OR section), `node` is whatever node was exported, rects are fractions of that image, and the backfill's §4-closed-list gate is unchanged — the guard then holds for both shapes. The alternative (skip maps for composite exports) leaves a specced screen permanently untargetable. | **OPEN — blocks the plan step** |
| G-6 | **Cache invalidation needs no new code.** 07 §1.3 asked for the map's mtime+sha to be added to the index stamp; `dirStamp(screenAssetsDir)` is already unfiltered (`lib/ui2-index.mjs:821`) and stamps every file in that directory, `.elements.json` included. Writing the "new" key would be redundant code around existing behavior. | ✅ **Fixed in the spec (2026-09-10)** — 07 now says so; E-5 is retained as a regression test |
| G-7 | **The 409 had no mechanism.** 03 §2.2 defined `409 — the file changed on disk between read and write (see below)`, and neither "below" nor 07 §2's `appendNote` contract said how that is detected, nor did the request carry anything to detect it with. **Audit default applied (veto-able):** the body gains `after` — the newest note id the client held when it opened the composer — and the server 409s when the file's last heading differs. The alternative is dropping the 409 (single-user dev tool; the duplicate-timestamp rule already prevents id collision). | **OPEN — ruling wanted at the gate**; a default is in 03 so the build is not blocked |
| G-8 | **BLOCKING — feeding screens through the same `elements` const silently changes the comment system, which 02 claims is untouched.** `placeDraft` attaches `target: hitTest(x,y)` whenever `elements?.length` (`Ui2Layout.jsx:231-232`), and the comment-mode hover box is driven by the same hit test — so the moment a screen has a map, screen comments start recording `targetLabel`/`targetSelector` and comment mode starts drawing element boxes on screens. **Recommended:** adopt it deliberately (a comment that names the component it sits on is strictly better) with the label rule from R2 — `C-### Name` from the live registry, not the map's stored `name` — and amend 02's "the comment system is untouched" plus 03 §4. The alternative is a separate `componentElements` const so comments are literally untouched. Either way it is a ruling, not an accident. | **OPEN — blocks the plan step** |
| G-9 | **BLOCKING — `?c=` does not survive the app's own navigation, so D9 fails as specified.** `variantPath` is `` `/components/2.0/${id}/${v.slug}` `` with no search string (`Ui2Layout.jsx:94`), and the canonicalising effect rewrites the URL with `{replace:true}` whenever the key is not the canonical slug (`:126-128`). So `/components/2.0/home-dashboard?c=C-023` — the exact form a person pastes to share a selection — is rewritten to `…/default` and the selection is dropped before anything reads it; switching states drops it the same way, and `:130` resets panel state on every key change. **Recommended:** `variantPath` carries `location.search` through, the reset effect leaves `c` alone, and H-6 (below) locks it. | **OPEN — blocks the plan step** |
| G-10 | **Internal contradiction: the clear control.** 07 §4.2 says selection "is cleared only by the Component tab's own clear control"; §5.1's block list (D4) has no such control — title, artwork, Open, states, notes. Add it to §5.1 or change §4.2 to "clicking outside every rect clears". | OPEN |
| G-11 | **C-5 would fail on a correct run.** It verified "never writes under `docs/ui2`" with a bare `git status docs/ui2`, but notes live under `docs/ui2/**/notes/` and the browser writes them, so that path is routinely dirty. | ✅ **Fixed in the spec (2026-09-10)** — scoped to exclude `/notes/` and compared before/after |
| G-12 | **`/ui2-component-update` edits SwiftUI with none of the preview lane's hard rules.** 07 §7.2 phase 3 edits `iphone/MakeReady/UI2Preview/` and phase 4 recaptures, but its Binding-rules block covers only note precedence and `docs/ui2` read-only. `/ui2-component-build` carries eight more that any editor of that lane must obey (`.claude/commands/ui2-component-build.md:105-147`): wired into nothing, legacy untouched + the exact file-write allow-list, tokens by name (SwiftLint bans `Color(hex:)`, raw `.system(size:)`, `print`/`NSLog`, `LazyVStack`/`LazyVGrid`), value sets have one owner, every prop traces, states are the contract's states, no `#if DEBUG`/`#Preview`, idempotent-and-visible, never fudge. **Recommended:** 07 §7.2 states that the update command inherits `/ui2-component-build`'s Hard rules verbatim, and its phase 3 exit checklist re-prints them. | OPEN |
| G-13 | **Unspecified view states in the Component tab.** No loading state while `fetchUi2Detail(ref)` resolves for the designed-state list; no error state when `GET /api/ui2/notes` fails (only the failed *save* is specified, §5.3); and `parseError` (03 §2.1) has no UI treatment, so a corrupt note file reads as "No notes yet" — the one outcome that loses the owner's words silently. **Recommended:** skeleton on load, inline retry on notes-fetch failure, and a visible "this file could not be parsed" banner carrying `parseError`. | OPEN |
| G-14 | **No component-side skill reads screen notes.** D6 gives screens notes and `/ui2-screen` phase 0 reads them (07 §7.3), but a note written while looking at a screen — "on `@home-dashboard` this chip pins to the leading edge" — is invisible to `/ui2-component-build` and `/ui2-component-update`, which read component notes only. That is the most natural note to write and the likeliest to be silently ignored, and it puts a hole in D3's supersession. **Recommended:** both component skills also read the notes of every screen whose §4 closed list names the target, merged into the same oldest→newest timeline. | OPEN |
| G-15 | **`GET /api/ui2/mentions` has no cost statement.** `hasNotes` implies an existence check per target (98 today). **Recommended:** one `readdir` per notes directory plus the existing `buildUi2Index`/`buildUi2Screens` caches — never a stat per row — stated in 03 §2.3 so the implementation does not reach for the obvious loop. | OPEN |
| G-16 | **08 does not test the two things this pass found most likely to break.** Add: **H-6** — the state-path helper preserves `?c=` across a state switch and across the canonicalising replace (G-9); **H-7** — click-vs-drag discrimination returns no selection when the pointer moved more than the threshold (C-4); and a 1.0 regression check that `CompareDetail` (`:523,536`) and the 1.0 `ComponentsLayout` (`:351`) still hover-inspect in comment mode after ZoomPane changes (C-3). | OPEN |

## C — component-coverage holes (audit pass 1)

| # | Row | Status |
|---|---|---|
| C-2 | **07 has no component manifest** (REFERENCE.md §3 rule 7). The new UI units — `Ui2ComponentTab`, the note card, the notepad composer, the typeahead popup — have no rows naming path, props with types, states rendered, and which view consumes them; the **modified** units are not listed as a set at all. An under-specified manifest row is where mid-build invention starts, and this suite has none. **Recommended:** a manifest table in 07 covering, at minimum: `Ui2ComponentTab.jsx` (new), `NoteList`/note card (new), `NoteComposer` (new), `MentionTypeahead` (new), `src/lib/hit-test.js` (new), `src/lib/mentions.js` (new), and modified `Ui2Layout.jsx`, `SidePanel.jsx`, `Ui2ScreenTab.jsx`, `RenderPane.jsx`, `ZoomPane.jsx`, `CommentLayer.jsx`, `styles.css`, `api.js`. | OPEN |
| C-3 | **`ZoomPane.jsx` must change and appears nowhere in the suite.** Hover is reported only in comment mode — `if (commentMode && …) onHoverInspect?.(fx, fy)` (`ZoomPane.jsx:104`), and `onMouseLeave` clears only in comment mode (`:141`) — the exact inverse of R1. `RenderPane` also assembles `commentProps` explicitly (`:119-139`), so the `componentBox` + label need a key there; they cannot ride the existing `hoverBox`, which is a bare rect drawn only when `commentMode && !draft && !selectedId` (`CommentLayer.jsx:49`). Both files are shared with the 1.0 era (`CompareDetail.jsx:523,536`, `ComponentsLayout.jsx:351`), so every change is additive and regression-checked there. | 01 **corrected in place 2026-09-10**; manifest rows + the design owed |
| C-4 | **Click-to-select has no host element, and pan owns the pointer.** `.cmp-commentlayer` is `pointer-events: none` unless placing (`styles.css:1428-1432`), so a click with comment mode off never reaches the comment layer; meanwhile the viewport's `onMouseDown` starts a pan drag whenever comment mode is off (`ZoomPane.jsx:77-93`). 07 §4.2 states the behavior but names no element, no drag threshold, and no coexistence rule — a drag across the render would select whatever is under the mouse-up. **Recommended:** click handled on the ZoomPane viewport, suppressed when the pointer moved more than 4px between down and up, primary button only, reusing the existing fx/fy math at `:95-105`. | OPEN |
| C-5 | **The right-panel tab cannot be set from outside.** `SidePanel` owns `tab` in local state (`SidePanel.jsx:25`), derives `tabs` per era/kind (`:34-40`) and falls back to `comments` (`:41`). R3 (a click on the render activates Component) and R5 (reload and the same component is still selected — i.e. the tab is active on load) both require a controlled tab. R6 additionally needs the chip click to call back instead of navigating, but `Ui2ScreenTab` holds its own `useNavigate` (`Ui2ScreenTab.jsx:22,73`), so a callback must be threaded through `SidePanel`. The `!ready` branch (`:53`) also needs a `component` case, or a screen with no frames shows "Select a component and variant" on the new tab. None of this is specified. | OPEN |
| C-6 | **`hitTest` is not reusable where it sits, and returns the wrong things.** Inline `useCallback` at `Ui2Layout.jsx:200-208`, label and path built from `e.name`, no `ref` in the return — while R2 needs the live-registry name and R3 needs the `ref`. 08's H-1…H-3 test it "without a DOM", which requires extraction to `capture/src/lib/` (precedent `src/lib/ui2-layout.js` + `test/ui2-layout.test.mjs`). Neither the extraction nor the return-shape change is in 07. | 01 + 07 **corrected in place 2026-09-10**; the task itself is owed to the plan |

## O — owner blockers (audit pass 1)

| # | Row | Status |
|---|---|---|
| O-5 | **Does the capture carve-out extend to a second command?** `iphone/.claude/CLAUDE.md:86-98` permits running `capture/runners/ui2/capture.mjs` without asking, and says the carve-out "names ONE script" — but justifies it with "Running `/ui2-component-build` IS the permission". `/ui2-component-update` phase 4 runs the same script from a different command, on the owner's machine, driving `xcodebuild`/`simctl`. Either extend the carve-out's wording in the same run, or the update command asks before capturing. This is a permission ruling, not a technical one. | **OPEN — owner** |

## Audit pass log

| Pass | Date | Result |
|---|---|---|
| 1 | 2026-09-10 | **Not clean — 16 new findings** (X-1…X-3, G-3…G-16, C-2…C-6, O-5; G-4, G-6, G-11 fixed in the spec during the pass). Phases A–F all run; four claims verified in code and marked; six suite statements the code contradicted corrected in place. **3 blocking rows: G-5, G-8, G-9.** |

### Verified in code this pass (2026-09-10)

| Claim | Where | Verdict |
|---|---|---|
| Test baseline "72 pass / 1 fail" | 08 §1 | ✅ verified — `cd capture && npm test` → 73 tests, 72 pass, 1 fail (`parseContract handles the axis-shaped matrix`) |
| Mention index "~98 rows" | 03 §2.3 | ✅ verified — 73 registry `C-###` ids + 25 README screen rows = 98 |
| "10 already-specced screens" (D5) | 01 D5 | ✅ verified — 10 screen specs + 1 companion doc (`study-program-home-superseded-contracts.md`, correctly ignored by `buildUi2Screens`); **12 frozen snapshots**, so the backfill's unit is 12 maps, not 10 |
| Sidecar `.elements.json` convention + aspect guard | 01 baselines, 03 §1.2 | ✅ verified — `server.mjs:1168-1187`; note it is gated on `platform === 'iphone'` and reads from `compareRoot`, so screens genuinely need the parallel path 07 §1.3 describes |
| `POST` guarded like the fixture write | 07 §3 | ✅ verified — `server.mjs:1635`, `:1677` |
| Command phase numbers cited by 07 §7.1 (0/1/3/4/6) | 07 §7.1 | ✅ verified — `.claude/commands/ui2-component-build.md:150,175,256,325,550` |
| `/ui2-screen` phase 2 resolves every instance to a registry row | 07 §7.3 | ⚠️ partly — the walk resolves instances and reads `get_metadata` for node ids (`.claude/commands/ui2-screen.md:91-168`), but it never records **rects**, and the absolute→frame-fraction conversion 07 §7.3 assumes is not written anywhere. Folded into the plan as an explicit step, not a finding of its own |
| `ConfirmDialog`, `api.js` fetcher style, `src/lib/` | 07 §3, §5.3 | ✅ verified — `src/components/ConfirmDialog.jsx`, `src/api.js:270-362`, `src/lib/ui2-layout.js` |

### Phase F — language & operationalization

Clean. 01–08 carry no banned vagueness (`as closely as possible`, `similar to`, `roughly`,
`ideally`, `TBD`, `PROPOSED`, trailing `etc.`), every requirement in 01's provenance table is an
acceptance criterion, the fidelity requirements name normative sources (Figma frames, the registry,
03 §1.1) with closed deviation lists, and the owner's words appear exactly once each, in the
provenance table. The one `PROPOSED`-shaped string is the README's "Proposed phases" heading, which
is the plan step's input rather than a normative claim.

## Blocking status

**The plan step is BLOCKED.** Three rows must be ruled first — **G-5** (composite multi-frame
snapshots), **G-8** (screen comments gaining element targets), **G-9** (`?c=` surviving
navigation) — plus the veto-able default in **G-7** and the owner permission in **O-5**. The
remaining rows are spec edits the decisions gate can fold in without a ruling.

Per REFERENCE.md §3b, every edit made at that gate is itself delta-audited in the same session
(`/build-spec-audit ui2-component-notes --delta`) before the plan step opens.
