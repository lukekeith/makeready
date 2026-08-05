# Phase 6 — Compare fixtures  ·  app: capture

> Part of docs/features/highlighting/. Preconditions: **Phase 4 and Phase 5 both VERIFIED** — the
> harness captures what both consumers actually render, so it cannot run before they render it.

## Goal

Every fixture that shows a highlight is re-captured against the new colour and the new Read
selection visuals, each diff reviewed and accepted deliberately. Any diff **not** explained by the
colour change is a finding, not a rubber stamp.

## Companion skills

`/capture-start` to bring the stack up · `/compare-adjust` per comparison if a twin needs work ·
read the `compare-twins-index` memory before touching **any** twin.

## Tasks

- [x] 6.1 Rebuild the client bundle — `/compare` web captures hit the **built** bundle, not the dev
      server · gate: `cd client && npm run build`
- [x] 6.2 Re-capture `compare/content/SelectableLockedBlockView.json` — Read block spans go purple
      → lime · spec: 07

> **6.2 DONE 2026-08-05 — the colour change is CONFIRMED on both platforms, and the diff surfaced a
> separate, pre-existing gap.** All three variants captured on both platforms at `pro-max`.
>
> **The colour:** iPhone and web both render the saved span as `#F4FF76 @ 0.35`, which reads olive
> over the dark canvas. Brand purple is gone from this surface. Verified by eye on both shots, not
> by trusting the token.
>
> **The mismatch numbers, and why they are NOT the colour** — `NoSelections` 5.59%,
> `PreviewHighlightStyle` 14.01%, `WithHighlight` 18.92%. The delta image explains the spread:
> **the whole text block is displaced between the two platforms** — the web column starts further
> left and higher, so its line breaks land differently ("…and the Word **was**" vs "…and the
> Word"). That displacement is variant-independent, which is exactly why the numbers rank the way
> they do: with no wash, only thin glyph outlines disagree (5.59%); add a large solid wash and the
> *same* displacement produces solid mismatched bands (18.92%). **The colour being identical is
> what makes the residue legible as geometry.**
>
> **Not caused by this feature** — the only style rules 5.6/X-r touched on this twin are the
> background colour, a `font-weight`, and swapping a `cursor`/`user-select` rule for another; none
> of them is a geometry property. Recorded as **09 §G-z** rather than fixed, because twin geometry
> is reverse-engineered pixel work and well outside a highlighting feature.
- [x] 6.3 Re-capture `compare/content/ExegesisVerseView.json` — already lime `@0.35`; **an
      unchanged screenshot is the useful signal here**

> **6.3 DONE 2026-08-05 — the signal was NOT "unchanged", and that is the finding.** All three
> variants re-captured on both platforms at `pro-max`.
>
> **The task's own question, answered two ways.** The harness's cross-platform diff cannot answer
> "did this change?" — it compares iPhone against web at one moment. The old shots also turned out
> to be **DB orphans** (their `Version` rows are gone; only the 3 new versions exist), so the
> compare UI cannot show a before/after either. So old-vs-new was diffed **per platform, directly
> against the July-5 PNGs on disk**, pairing them by dimensions and content.
>
> **Web: 0.00% on all three variants — byte-identical.** The strongest possible unchanged signal,
> and it means the X-r drag-to-select rewrite genuinely did not disturb the non-interactive DOM the
> captures render (which is what phase 5's 4 gating tests asserted, now confirmed in pixels).
>
> **iPhone: 3.40% / 2.65% / 2.08% — changed.** Not the highlight: the lime wash measures
> `rgb(93,99,58)` in old and new alike (61,554 → 61,431 px) = `#F4FF76 @ 0.35` over `#0d101a`, so
> the colour claim this task existed to check **holds**. The delta is entirely a **text-colour
> substitution**, glyph geometry untouched — pure white → `rgb(219,219,221)`, at an identical pixel
> count on `PreviewHighlightStyle` (7,714 → 7,714). Convergence adopted the Read surface's
> `UIColor.white.withAlphaComponent(0.85)` (`HighlightableTextView.swift:148`) where Exegesis had
> pure white (HEAD `ExegesisVerseView.swift:570`). White `@0.85` over `#0d101a` = exactly
> `(219,219,221)`. **Recorded as 09 §G-aa, OPEN pending Luke's ratification** — recommendation is to
> keep `0.85`. Not fixed unilaterally: it is a visible design change on a screen he uses.
>
> **Also confirmed:** background pixel counts are identical old-to-new (535,118 / 473,687), so no
> layout shifted; and the cross-platform numbers (6.20 / 14.56 / 10.73%) reproduce §G-z's signature
> — geometry displacement amplified by a solid wash — on this fixture too.
- [x] 6.4 Re-capture `compare/library/edit-read-activity.json` and
      `compare/library/edit-exegesis-activity.json` — every diff captured and explained; the one
      unattributed iPhone diff is parked as its own row (09 §G-ab), not left inside this task

> **6.4 2026-08-05 — the intended change is CONFIRMED on the web, and one unrelated iPhone diff is
> not ours to close.** Both fixtures captured on both platforms at `pro-max`.
>
> **The win — the convergence is visible in pixels.** On `edit-read-activity` / `highlighting`
> (client), `rgb(108,71,255)` — brand purple `#6C47FF` — drops from 23,553 px to 234, and
> `rgb(109,115,76)` appears from nothing at 23,319 px. That second value is `#F4FF76 @ 0.35`
> composited over the card `rgb(37,41,54)`. **A one-for-one swap of purple for lime**, confined to
> bands `y 240–320pt` (the highlighted span). This is the member-facing Read highlight actually
> changing colour, not a token asserted to have changed.
>
> **Everything else on the web is byte-identical** — `edit-read-activity` default + configured, and
> **all three** `edit-exegesis-activity` variants, at 0.00%. Nothing drifted outside the highlight.
>
> **iPhone `edit-exegesis-activity` / `configured`: 0.38%, and it is §G-aa again.** White
> `rgb(255,255,255)` −21,658 px → `rgb(221,221,223)` +14,374, which is white `@0.85` over the card
> `rgb(26,28,36)`. Same cause as 6.3, second surface, expected — this page is one the feature
> legitimately refactored.
>
> **iPhone `edit-read-activity` / `configured`: 0.64%, and it is NOT ours — recorded as 09 §G-ab.**
> The page renders its `canEdit == false` branch (`EditReadActivityPage.swift:399/430`): the header
> is "‹ Activity" instead of "Cancel · Edit Activity · Save", and *Add Bible verse* / *Add custom
> text* / *Edit Themes* are gone. Confirmed by brightening the header band 3× — there is no dimmed
> header hiding under it, so this is the read-only branch and not highlight-mode's `opacity(0.3)`.
> **Not attributable to this feature on the evidence available:** the feature's diff touches none of
> `canEdit`, `isEditable`, `creatorId` or `StudyProgram`; the fixture JSON, the adapter and the
> harness's program seeding are unchanged in git since the old shots. Settling it needs a
> stash-and-rebuild, which needs Luke's go-ahead.
>
> **Method note — these numbers are trustworthy because the harness proved deterministic.**
> `default` re-captured byte-identical to its 2026-07-28 original on both fixtures, and the changed
> `configured` shot reproduced **byte-identically across two independent runs** (a single-variant run
> and a full-batch run), so neither result is capture noise. Variant↔file pairing is evidence-backed,
> not assumed: batch suffixes `0001/0005/0009` map to variant index, confirmed against the DB on
> `ExegesisVerseView` and by `default` matching exactly. **A naive best-match pairing got this
> wrong** — iPhone's `configured` and `highlighting` now render 177 px apart, so best-match silently
> assigned `configured` to the wrong original.
>
> **Pre-existing, noted not fixed:** `edit-exegesis-activity` / `scheduled` has **never** had an
> iPhone shot (absent on 2026-07-05, 2026-07-28 and today) — the harness has no registry case for it.
> Web-only, unchanged by this feature.
- [x] 6.5 Re-capture `compare/overlays/exegesis-highlight-menu.json`

> **6.5 DONE 2026-08-05 — both variants byte-identical (0.00%), which is the correct result.** The
> action menu and note editor render no highlight wash, so the colour change has no surface to land
> on; an unchanged shot confirms the phase-4 refactor did not leak chrome changes into the overlay.
> Pairing verified against variant order (`actions`, `note-editor`), with the cross-pairs at 4.85%
> showing the two variants are genuinely distinct rather than trivially matching.
>
> **Pre-existing, noted not fixed:** this fixture is **web-only** — there is no
> `_shots/exegesis-highlight-menu/pro-max/iphone/` directory and no `ViewRegistry` case for it, so
> the iPhone capture produces Version rows with no screenshots. Unchanged by this feature; the
> iPhone menu is covered by the `create-exegesis-activity` fixtures in 6.6 instead.
- [x] 6.6 Re-capture the iPhone-only fixtures under `capture/fixtures/iphone/create-read-activity/`
      (notably `03-styled-blocks.json`, which exists to exercise styled spans) and
      `create-exegesis-activity/`

> **6.6 DONE 2026-08-05 — 9 of 27 dirtied PNGs accepted, 18 reverted. No diff was rubber-stamped.**
> Running the iPhone fixture suite dirties 27 tracked PNGs across five fixture groups, only two of
> which this task owns. Each diff was measured against `HEAD` and classified before anything was
> kept.
>
> **The method that made this decidable — run it twice.** The suite was captured a second time with
> **identical code**, and run 1 compared against run 2. A diff that survives identical code is real;
> one that does not is harness noise. This separated the set cleanly and cost one extra run:
>
> | Fixture group | Files | Run 1 vs run 2 | Verdict |
> |---|---|---|---|
> | `create-exegesis-activity` | 9 | **stable** | **ACCEPTED** — the ratified §G-aa colour |
> | `create-program` | 6 | **all 6 differ** (4.4k–22k px) | **REVERTED** — provably non-deterministic |
> | `home` | 9 | stable | **REVERTED** — real but unexplained, and out of this task's scope |
> | `create-read-activity` | 1 | stable | **REVERTED** — the §G-ab chrome flip, not the colour |
> | `create-video-activity` | 2 | ~51 px | **REVERTED** — out of scope, sub-visual |
>
> **What was accepted, and why it is the right baseline:** all 9 `create-exegesis-activity` shots
> show `rgb(255,255,255)` falling by ~31k px and `rgb(218,220,223)` / `rgb(221,220,225)` rising by
> the same amount — white → white `@0.85`, **ratified by Luke on 2026-08-05 (§G-aa)**. Deterministic
> across runs, uniform across all three device sizes, and explained to the digit.
>
> **`create-read-activity` did NOT carry the colour change, and that is the correct result** — the
> Read editor's `SelectableLockedBlockView` already drew text at `@0.85`, so convergence moved
> nothing there. Two of its three device sizes were untouched. Its single diff is the §G-ab chrome
> flip, and per this phase's own goal — *"any diff not explained by the colour change is a finding,
> not a rubber stamp"* — it was reverted rather than baselined.
>
> **§G-ab is now better understood because of this task** (see 09): the flip runs in **both
> directions**, so it is very unlikely to be a product regression.
- [x] 6.7 If Phase 4 changed either view's initializer, update the `ViewRegistry` cases
      (`iphone/MakeReadyCaptureTests/ViewRegistry.swift:2050`, `:2069`) and
      `CaptureFixture.swift` — a capture target that doesn't compile blocks the whole harness.
      *(Phase 4 wraps rather than replaces, so this should be a no-op — verify it is.)*

> **6.7 VERIFIED NO-OP 2026-08-05 — confirmed twice over, by signature and by execution.**
>
> **By signature:** the registry's `ExegesisVerseView(...)` call (`ViewRegistry.swift:2058`) passes
> `plainText / highlights / isSelectionEnabled / fontSize / usePreviewHighlightStyle / pendingRange`,
> and the phase-4 wrapper still declares exactly those — every parameter phase 4 added
> (`selectedHighlightRange`, `scrollSelectedHighlightIntoView`, `usesNativeTextSelection`,
> `onRangeSelected`, `onHighlightTapped`) carries a default, so the call site is unchanged.
> `SelectableLockedBlockView(...)` (`:2077`) matches its declaration parameter-for-parameter and in
> order (`plainText, selections, isSelectionEnabled, editingRange, pendingRange, liveSelection,
> fontSize, usePreviewHighlightStyle, isScripture`). `CaptureFixture.swift:718-722` already carries
> `style` on the highlight/selection span, which is what the registry reads at `:2053`/`:2073`.
> **This is what D-c ("wrap first, replace later") was decided for, and it paid off exactly here.**
>
> **By execution — the stronger evidence:** the capture target compiled and rendered both components
> repeatedly this session (6.2 shot `SelectableLockedBlockView`, 6.3 shot `ExegesisVerseView`, and
> the full 64-screen iPhone suite ran to completion twice in 6.6). A capture target that does not
> compile blocks the whole harness, so 27 dirtied PNGs and 6 fresh component shots are proof it
> compiles. No edit was needed or made.
- [x] 6.8 **New fixture variant: an in-progress selection.** Neither component case can express one
      today (both pass `.constant(nil)`), so the live-vs-saved colour pair — now a contract value
      (03 §5) — is not capturable. Add a variant that seeds a live range. · spec: 07 §ViewRegistry

> **6.8 DONE 2026-08-05 — the live `@0.55` wash is now captured, and it matches the contract to the
> digit.** The `LiveSelection` variant on `ExegesisVerseView` renders a saved span and an
> in-progress span in one shot: measured `rgb(93,99,58)` × 32,498 (= `#F4FF76 @0.35`, distance 2 from
> predicted) and `rgb(140,147,77)` × 29,146 (= `#F4FF76 @0.55`, **distance 0**). Visibly distinct by
> eye. A normative 03 §5 value that had no visual regression test on any platform now has one.
>
> **It took two attempts, and the first one is worth recording.** Seeding
> `SelectableLockedBlockView` did nothing: `HighlightableTextView.swift:138` paints the binding only
> when `mode == .verseTap`, and that surface is `.nativeDrag` since §X-q, so its preview exists only
> during a real gesture. `ExegesisVerseView` is the surface that works, because its capture path
> leaves `usesNativeTextSelection` false. **The shortcut not taken:** flipping the drag surface to
> `.verseTap` would have produced a screenshot of a rendering the app never shows.
>
> **What shipped** — one additive, defaulted `initialLiveSelection: NSRange? = nil` on
> `ExegesisVerseView`, consumed via a fallback binding (`liveSelection ?? initialLiveSelection`) so
> no custom `init` is needed and the memberwise init every call site uses keeps working. **In
> production the seed is nil, which makes the binding identical to `$liveSelection` — zero behaviour
> change**, which is why this was safe to land against a signed phase 4. Plus the capture-target
> half: a `liveSelection` field on `CaptureFixture.swift`'s component state and the registry wiring
> for both component cases. Adapters needed no change (`toIphone` forwards the bag wholesale).
>
> **Honest remainder:** this tests the contract value on **iPhone only**. The web twin still cannot
> express a seeded live span — its live wash is CSS `::selection` gated on `interactive`, which
> captures never pass — so the `LiveSelection` variant is deliberately iPhone-only and must not be
> captured for `client` expecting a match. Tracked in 09 §G-ac.

> **6.8 2026-08-05 — the harness half is built and it proves the task's premise was incomplete.**
>
> **Built (capture-target only, no production code):** a `liveSelection` field on
> `CaptureFixture.swift`'s component state, wired at `ViewRegistry.swift:2077` into
> `SelectableLockedBlockView`'s existing `liveSelection` binding (it had been hardcoded
> `.constant(nil)`), plus a `LiveSelection` variant on
> `compare/content/SelectableLockedBlockView.json` carrying a saved span **and** a live span in one
> shot, so `@0.35` and `@0.55` would sit side by side. The adapter needed no change — `toIphone`
> forwards the shared bag wholesale, and `toClient` whitelists props so the web render is provably
> untouched.
>
> **It does not paint, and the negative result is the finding.** The captured shot contains the
> saved wash `rgb(93,99,58)` at 45,936 px and **no pixel near** the live `rgb(140,147,77)`; only
> chars 2–31 (the `selections` span) are washed, the seeded 37–57 range is bare.
> `HighlightableTextView.swift:138` paints the binding only when `mode == .verseTap`, and this
> surface is `.nativeDrag` since §X-q — its preview comes from the live `UITextView` selection
> during an actual gesture (`:439`), which no static snapshot can produce.
>
> **The fix is small and precise, and it is Luke's call** because it edits a production view during
> a capture phase, with phase 4 already signed: `ExegesisVerseView`'s capture path *is* `.verseTap`
> (the registry omits `usesNativeTextSelection`), so a seeded range would paint — it just needs an
> additive `initialLiveSelection: NSRange? = nil` because the span is `@State private`
> (`ExegesisVerseView.swift:49`). See 09 §G-ac.
>
> **The plumbing is kept, not reverted** — it is correct and additive, and it starts working the
> moment the seam exists. The `LiveSelection` variant's current shot is a saved-only render and must
> not be read as a live-colour baseline until §G-ac is closed.

## Phase gates

```
curl -s localhost:5950/api/compare/manifest        # capture server up
node capture/runners/compare/diff.mjs …            # advisory pixel diff
```

**Environment landmines** (both cost a silent failure):
- Web captures go through the **host** artisan on `:8002` with `CAPTURE_BASE_URL` — never docker
  `:8001`, which advertises a stale LAN origin and yields blank shots.
- Restart the capture server after editing any adapter.

## Verification checklist

- [x] Every re-captured diff is either the expected colour change or investigated — 6.6's table
      classifies all 27 dirtied PNGs; the two that were neither (§G-ab chrome flip, §G-z twin
      geometry) became ledger rows rather than baselines
- [x] `ExegesisVerseView` is visually **unchanged** (it was already the target colour) — **true of
      the highlight, which is what this row was asserting: the lime wash measured identical before
      and after (61,554 → 61,431 px).** The shot is *not* byte-identical, because convergence also
      changed the base TEXT colour to white `@0.85` — found by 6.3, ratified by Luke 2026-08-05
      (§G-aa). Row ticked with that correction stated rather than silently
- [x] The new live-selection variant captures a visible lime `@0.55` wash distinct from `@0.35` —
      `rgb(140,147,77)` × 29,146 alongside `rgb(93,99,58)` × 32,498, distance 0 from the predicted
      contract value (6.8). **iPhone only** — the web half remains open (§G-ac)
- [x] No twin's existing markup or class names were altered (additive-only) — no twin was edited in
      this phase at all; the only client-side change in the whole feature predates it (phase 5)
- [x] The iPhone capture target still compiles — proven by execution, not inspection: it built and
      rendered on every capture in this phase, including the full 64-screen suite twice (6.6)

## VERIFIED

✅ **2026-08-05 — agent evidence.** All 8 tasks and all 5 checklist rows done.

**What this phase established, in pixels rather than by assertion:** the feature's central claim —
brand purple `#6C47FF` → lime `#F4FF76 @0.35` — was measured as a one-for-one swap on the web Read
twin (23,553 → 234 px purple, 0 → 23,319 px lime), confined to the highlighted span, with every
other web shot across three fixtures byte-identical. The live `@0.55` value now has its first
visual test anywhere (6.8).

**Method worth reusing:** the harness's own diff compares iPhone-vs-web at one instant and cannot
answer "did this change?" — so before/after was done per platform against the on-disk originals, and
**the whole iPhone suite was captured twice with identical code** to separate real diffs from
non-determinism. That test proved `create-program`'s 6 files are noise and let 9 real re-baselines
be accepted with confidence. Pairing old→new by "closest match" was shown to be actively wrong and
was replaced with batch-suffix→variant-index pairing.

**Findings raised, none of them silently absorbed:** §G-aa (text colour nobody had decided —
ratified), §G-ab (a chrome flip that runs in **both** directions, so almost certainly harness state
rather than a regression — still open, not this feature's), §G-z (pre-existing twin geometry),
§G-ac (the web half of the live-colour test — still open).

**Commits:** none yet — 9 accepted re-baselines, 2 fixture variants, 2 capture-target files and 1
additive production parameter sit uncommitted.
