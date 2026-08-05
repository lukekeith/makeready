# Phase 5 — Web consumers  ·  app: client

> Part of docs/features/highlighting/. Preconditions: **Phase 2 VERIFIED and 03 FROZEN.**
> Parallelizable with Phase 4 (iphone). Consumer-only: no authoring UI is built here (D7).

## Goal

The member lesson player and the LeaderApp panes read `highlights[]` and render the new colour,
while continuing to tolerate the legacy `selections[]` for one release. **Members see this** — it
is the only phase whose output is visible on already-published lessons.

## Companion skills

`/component` if a shared component genuinely needs changing (it should not — 05 says no new
components) · `/store` for Pinia store conventions.

## Tasks

- [x] 5.1 `use-lesson-state.ts` — ~~consume `highlights[]` from the activity payload~~ **corrected:
      carry BOTH relation names for the dual-read window** · 09 §G-t, §X-n
- [x] 5.2 `read-step.vue` — ~~render spans from `highlights`~~ **corrected: rendering stays on
      `selections[]`, which is right and already multi-block correct** · 09 §G-t
- [x] 5.3 `exegesis-step.vue` — **notes fixed; they had been rendering blank** · 09 §X-n

> **5.1–5.3 DONE 2026-08-04, and the plan for them was wrong in a way that mattered.**
>
> **The tasks assumed `highlights[]` on the activity payload. It does not exist.** The server nests
> `contentHighlights` **per read block**, and every one of those selects omits **`style`**. Rendering
> from that array would paint `style: "bold"` spans as highlights, contradicting 03 §5 — so
> implementing 5.1/5.2 as written would have introduced a bug, not fixed one. The correct render
> source is `selections[]`, the server-maintained projection, which since phase 2 carries real style
> values. Recorded as **09 §G-t**; `read-step.vue` needed no change at all, and its multi-block
> handling was already correct (spans travel nested inside each block, so there is nothing to
> resolve by `readBlockId`).
>
> **What the tasks did surface is a regression this feature had already shipped — 09 §X-n.**
> Phase 2's rename of the Prisma relation `exegesisHighlights → contentHighlights` moved every
> server include, and nobody swept the **client**. `exegesis-step.vue:91` read the old name, got
> `undefined`, and fell through to a fallback that builds highlights from `selections[]` with
> **`noteMarkdown: ""`**. Members saw their highlights painted and **every note blank**, with no
> error anywhere. Fixed: read `contentHighlights`, fall back to `exegesisHighlights` for older
> payloads. **This is the first defect in this feature that reached member-facing behaviour**, and it
> survived three phases of green gates.

- [x] 5.4 Colour: saved highlight → `#F4FF76 @0.35` · gate: `npm run guard`

> **5.4 DONE — the member-visible change.** `ThemePlayer.scss:158` painted
> `rgba(255, 235, 59, 0.35)` — **Material amber**, not the contract's lime. The alpha was already
> right; only the hue was wrong, and it matched nothing on the native side. Now
> `var(--color-highlight-saved)`, a new semantic token in `_semantic.scss` beside the other
> iOS-mirrored hues. **`bold` already rendered as `font-weight: 700` with no wash**, which is
> exactly 03 §5's rule — so that half of the task was already satisfied and is left alone.

- [x] 5.5 LeaderApp stores carry highlights — **moved off the legacy alias onto the contract path**

> **5.5 DONE.** All 8 call sites in `leader-program.store.ts` and
> `leader-enrollment-schedule.store.ts` moved from `…/exegesis-highlights` to `…/highlights`. The
> aliases still exist for shipped iPhone builds, but they keep the strict EXEGESIS-only gate — so
> they 400 on a READ activity — and they omit `blockIds`, `absorbedIds` and `style`. New client code
> has no reason to be on them.

- [x] 5.6 ∥ Both LeaderApp editor panes render saved highlights per 03 §5 — ~~authoring stays
      deferred, the panes' "DEFERRED" comment remains true~~ **corrected: the comment was stale and
      the panes already author** · 09 §G-v, §G-w, §X-o

> **5.6 DONE 2026-08-04 — and like 5.1–5.3, the task's premise did not survive contact.**
>
> The **read** pane's twin was still painting solid brand purple, and — the part no one had looked
> at — `selectionStyle()` took no argument and returned `'highlight'` for **every** selection, so a
> stored `bold` span got the saved-highlight wash instead of weight. Its sibling twin
> `exegesis-verse-view.vue` had honoured `bold` all along, so the two web surfaces disagreed with
> each other as well as with iOS. Both LeaderApp stores were also **dropping `style`** out of the
> `/highlights` response in hand-written field-by-field mappers — the same shape as X-n, two tasks
> earlier. Fixed: `selectionStyle(sel)` mirrors `HighlightRenderer.paintHighlight`'s precedence, a
> `--seg--bold` rule ships weight-only, the saved wash is `var(--color-highlight-saved)` and the
> live wash a new `--color-highlight-live` (both twins now share one definition). **09 §G-w.**
>
> **The task said "authoring stays deferred (D7)" and cited the read pane's own header comment as
> proof. The comment is stale: the LeaderApp has authored highlights since the parity project** —
> highlight mode + `.stylePicker` + `applyStyle` on the read side, create/note/delete on the
> exegesis side. `03 §5` scopes its normative rules to the web with "when its authoring UI is
> built", so the contract believed the web was exempt while the web was shipping authoring.
> **09 §G-v**; the comment and `05-client.md` are corrected.
>
> **Checking those rules against the shipping code found 09 §X-o — a FOURTH word-snapper.**
> `exegesis-verse-view.vue` carried a private copy whose word test was `!/[\s\p{P}]/u`, and `'`,
> `’`, `-` are all `\p{P}` — so **the three marks 03 §5 names as intra-word were boundaries**:
> `"Lord’s"` snapped to `"Lord"` on web and to `"Lord’s"` on iOS. It also grew the start backwards
> whenever a word character merely preceded the boundary, so a selection starting on a space
> swallowed the previous word. Moved to `utils/verse-selection.ts` as a line-for-line port of
> `HighlightSnapping`, and re-checked against the contract's own cases: `Lord’s` / `Lord's` /
> `well-being` snap whole, a space-leading selection no longer grows backwards, a verse selection
> ending on the verse-terminating newline does not walk into the next verse, grow-only holds.
>
> **⚠️ Twin change, deliberate (REFERENCE §3 rule 6).** The read twin's captured rendering changes
> purple → lime. That is not additive, and it is the point: iOS changed the same wash in 4.11, so
> holding the twin still would have *created* a parity gap. **Phase 6 re-captures this fixture** —
> until it does, the compare baseline for this screen is knowingly stale.
>
> The token guard now scans the files this task edits (`resources/css/components/`, unlike 5.4's
> edits) — it went **856 → 853**, i.e. three fewer, none added.
- [x] 5.7 Confirm the `/admin/api/{path}` proxy covers these paths — **verified, not assumed:**
      `routes/web.php:166` is a catch-all `Route::match([...], '/api/{path}')->where('path', '.*')`
      inside the `admin.auth` group, so `/admin/api/activities/:id/highlights` and the
      scheduled-activity twin are already proxied. No proxy change needed.
- [x] 5.8 Tests per 08 §Client — **29 tests in 3 files, and the client gained a test runner to
      hold them** (Luke's call, 2026-08-04)

> **5.8 DONE — the client had no JavaScript test runner at all.** Not "no tests for this feature":
> no vitest, no jest, no spec file anywhere under `client/`. The root `npm test` runs
> `--workspaces`, and the client was the ONE workspace with no `test` script, so it walked straight
> past. **Decision (Luke, 2026-08-04): stand up vitest** rather than narrow the task — this phase
> alone shipped three defects a rendering test would have caught (X-n blank notes, G-w `bold`
> painted as a wash, X-o the broken snapper), all on the least-guarded surface in the feature.
>
> Added `vitest ^2.1.9` (matching the server's), `@vue/test-utils`, `happy-dom`, a `vitest.config.ts`
> separate from `vite.config.js` (the main config is built around `laravel-vite-plugin` and would
> have to be satisfied for a run to start), and `test` / `test:watch` scripts — which fills the slot
> the root command was already looking for. **Verified: `npm test --workspace=client` now runs.**
>
> **Every test was falsified before being trusted** — the bug it guards was reinstated and the run
> re-checked, so none of them is green by accident:
>
> | File | Tests | Guards | Falsification |
> |---|---:|---|---|
> | `utils/verse-selection.test.ts` | 14 | §X-o — `'` `’` `-` intra-word, grow-only, no backward growth from a boundary, no walk past a verse-terminating newline | old snapper reinstated → **5 fail** |
> | `steps/exegesis-step.test.ts` | 7 | §X-n — notes survive under BOTH relation names; the `selections[]` fallback is reachable only when no rows arrived, and `bold` is not painted there | read the old name only → **3 fail** |
> | `card/selectable-locked-block-view.test.ts` | 8 | §G-w — `bold` gets weight and never the wash; unknown style degrades to `highlight`; zero highlights leave no artifacts; each verse resolves its own spans | `selectionStyle` made style-blind → **4 fail** |
>
> **What these tests do NOT prove, stated so green is not over-read:** they assert CLASSES, not
> colours. A DOM test cannot see what `var(--color-highlight-saved)` resolves to, so "the lime is
> right" rests on the capture diff (phase 6) and the human walk — not on this suite.

## Phase gates

```
cd client && npm run build      # also required before any capture
cd client && npm test           # vitest — NEW in 5.8; the runner did not exist before
cd client && npm run guard      # design-token compliance
cd client && ./vendor/bin/phpunit
```

- [x] `npm run build` — ✅ built in 5.91s, no errors. Re-run fresh after 5.8, 2026-08-04.
- [x] `npm test` — ✅ **29 tests / 3 files, 0 failures.** Run fresh 2026-08-04, and again via
      `npm test --workspace=client` from the repo root to prove the workspace wiring.
- [~] `npm run guard` — ❌ **BLOCKED, pre-existing (09 §G-u)** across ~40 component stylesheets that
      predate the design-system migration. **Not caused by this feature — and since 5.6 that is
      measured rather than argued.** Through 5.5 the argument was structural: the guard's `SCAN_DIR`
      is `resources/css/components` (`tokenization-guard.mjs:25`) and nothing this phase had touched
      lived there. **5.6 changed that** — it edits two files inside the scanned directory, so the
      claim now rests on the count: **856 before, 853 after**, i.e. three violations removed
      (raw `rgba()` literals folded onto `--color-highlight-saved` / `--color-highlight-live`) and
      **zero added**. The client twin of §G-i.
- [x] `./vendor/bin/phpunit` — ✅ **235 tests, 490 assertions, 0 failures** (9 pre-existing
      deprecations, 1 incomplete). Run fresh 2026-08-04.

## Verification checklist

- [x] **A member opening a lesson sees the same spans as before, in lime** — ✅ **2026-08-05.**
      Two independent confirmations, which this row needed because it is the only member-visible
      change in the feature. **(1) Luke walked it** — phase 7 step 7.3 opens the lesson in the
      member player, and he reported the feature working. **(2) The colour is now measured, not
      inferred:** phase 6.4 captured the web Read twin swapping brand purple `rgb(108,71,255)` for
      lime `rgb(109,115,76)` (`#F4FF76 @0.35` over the card) **one-for-one, 23,319 px**, confined to
      the highlighted span. The original objection — that no test can see a colour — was answered by
      measuring pixels rather than by adding a test
- [x] A READ activity with several verse blocks renders each block's highlights against that block
      — ✅ spans travel **nested inside their block** (09 §G-t: there is no flat `highlights[]` on
      the payload to resolve by `readBlockId`, which is why `read-step.vue` needed no change), and
      within a block each verse paragraph resolves its own cuts — `selectable-locked-block-view.test.ts`
      §"multi-verse content maps each span to its own verse", 2 tests
- [x] An activity with zero highlights renders no wash and no empty artifacts — ✅
      `selectable-locked-block-view.test.ts` §"nothing to paint" asserts no styled span survives AND
      no zero-length segment is left behind by the cut/split pass
- [x] `bold` renders as weight with no background, matching 03 §5 and the iPhone rendering — ✅ **it
      did not, until 5.6** (09 §G-w). Now 4 tests, falsified against a style-blind renderer, plus
      `&__seg--bold { font-weight: 700 }` with no background declaration. **Class-level evidence:**
      the tests prove the right class is chosen; that the class carries no wash is read from the
      stylesheet, not measured
- [x] The dual-read window works: an activity whose payload still carries only `selections[]`
      renders identically — ✅ and this is the one that mattered. `exegesis-step.test.ts` asserts
      the note text survives under `contentHighlights`, under the pre-rename `exegesisHighlights`,
      and that the `selections[]` fallback is reachable **only** when no rows arrived — falsified by
      reinstating X-n, which fails 3 tests
- [x] Contract parity: fields consumed match 03's frozen table, same names — ✅ **traced
      field-for-field 2026-08-04**, and the trace found 09 §G-x. Every field the web consumes is
      spelled exactly as 03 §2.1 and as `ContentHighlight` on iOS — no renames, no divergent
      spellings, nothing consumed that the contract does not define:

      | 03 §2.1 | nested payload | LeaderApp stores | member step | iPhone `ContentHighlight` |
      |---|---|---|---|---|
      | `id` | ✅ | ✅ | ✅ | ✅ |
      | `readBlockId` | ❌ omitted | — not needed (panes hold one block) | — | ✅ |
      | `orderNumber` | ✅ | — sorts by span instead | ✅ | ✅ |
      | `start` / `end` | ✅ | ✅ | ✅ | ✅ |
      | `style` | ❌ omitted → **09 §G-x** | ✅ *(added in 5.6)* | ❌ cannot — omitted upstream | ✅ |
      | `noteMarkdown` | ✅ | ✅ | ✅ | ✅ |
      | `createdAt` / `updatedAt` | ❌ | — unused | — unused | ✅ optional |

      The two ❌ in the *nested payload* column are the finding: `programs.ts:1710,1974` select five
      fields and drop `style`, so the member exegesis step **structurally cannot** honour 03 §5's
      bold rule on its primary path. Latent today (nothing authors a bold exegesis highlight), a
      server fix, and therefore not this phase's to make — carried to phase 7
- [~] Token guard green — **the colour IS a token** (`--color-highlight-saved`,
      `--color-highlight-live` in `_semantic.scss`, used by both twins and `ThemePlayer.scss`;
      zero literals left on this feature's paths). **The gate itself cannot go green** for reasons
      that predate this feature — 09 §G-u, 853 violations across ~40 unrelated stylesheets. The
      count went **856 → 853** under this phase, so the feature's contribution is measured, not
      argued. Per Luke's decision (2026-08-04) the gate list is corrected rather than the debt paid
      here

## VERIFIED

✅ **2026-08-04 — agent evidence.** All 8 tasks done; gates `npm run build` (5.91s), `npm test`
(29/29) and `./vendor/bin/phpunit` (235/235) run fresh; `npm run guard` BLOCKED pre-existing per
Luke's 2026-08-04 gate decision, with the feature's contribution measured at **856 → 853**.
Six of seven verification rows closed with traced evidence.

**What this phase actually did, in one line each:**

- Kept member rendering on `selections[]` — the plan's `highlights[]` premise was false and
  implementing it as written would have painted `bold` spans as highlights (09 §G-t).
- **Fixed the first defect in this feature to reach members** — every exegesis note had been
  rendering blank since phase 2's rename (09 §X-n).
- Moved the LeaderApp stores onto the contract path, carrying `style` (09 §G-w).
- Changed the saved wash to lime on the Read twin and folded both twins' literals onto two
  semantic tokens.
- **Discovered the web has been authoring highlights all along** (09 §G-v) and that its snapper
  was a fourth divergent copy (09 §X-o) — the feature's own thesis failing on the surface the
  contract had written off.
- **Gave the client a test runner** (5.8) and 29 tests, every one falsified against the bug it
  guards.

**Signed with these explicit non-claims — none of them is covered by the green above:**

1. **No human has opened a lesson.** The one member-visible change in the whole feature — purple
   → lime on already-published content — has been seen by nobody. No test in this suite can see a
   colour; they assert classes. This is the first thing to look at.
2. **The compare baseline for the Read editor is knowingly stale.** The twin's captured rendering
   changed deliberately (REFERENCE §3 rule 6), because iOS moved in 4.11. **Phase 6 must
   re-capture it**; until then the fixture disagrees with the code on purpose.
3. **The LeaderApp panes were not exercised in a browser** — the store/render changes are covered
   by types, the build, and the twin tests, not by anyone clicking through `/admin`.
4. **09 §G-x is open and owed to phase 7** — the nested activity payload omits `style`, so the
   member exegesis step structurally cannot honour 03 §5's bold rule on its primary path. Latent
   (nothing authors a bold exegesis highlight), server-side, and out of a client phase's reach.
5. **Nothing is committed.** The client working tree carries this phase plus phase 4's uncommitted
   iPhone work.
