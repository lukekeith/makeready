# C-019 TopNav — the app's primary switcher: one scrollable tab row in two presentations

Status: new · Specced: 2026-09-05 · Owner-designated: `/ui2-component navigation bar <url>` —
the owner pasted the per-page instance frame `3556:33191`, then corrected the normative source
to the main component `3555:32772` ("this is the main navigation component, that defines the
two primary states") and supplied the per-button set `3555:32733` ("provides a reference for
the state of each button in the nav"). Both corrections are honored below: the instance frame
is cited as evidence only.

This file **relocates** C-019's contract. It previously pointed at
`docs/features/navigation/01-account-switcher-analysis.md` with "full contract → shell-topnav".
That analysis remains normative for the **interaction** (it is the owner's reference recording,
`Nav.MP4`); Figma is now normative for the **two resting states**. `shell-topnav` keeps the
shell-level questions (placement, safe area, stickiness, what the row does to page content).

## 1. Normative source

**Row** — component set `3555:32772` "Top navigation", one axis `state`:
- `state=Default` — symbol `3555:32771`, content 656×32
- `state=Expanded` — symbol `3555:32807`, content 1048×96 (= 8 × 124 card + 7 × 8 gap)

**Tab** — component set `3555:32733` "Top nav button" (→ C-069 NavTabButton, §2b), axes
`state` {Collapsed, Expanded} × `active` {false, true}, all four symbols designed:
`3555:32732` / `3555:32934` / `3555:32926` / `3555:32734`.

- Frozen snapshot: `assets/C-019-top-nav.png` (row set, whole set — captured 2026-09-05).
- Second frozen asset: `assets/C-069-nav-tab-button.png` (the C-069 tab set's four symbols,
  same capture date).
- Figma file `nVva9a2WvYmcWQo6zlHupO`; row set
  https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3555-32772
- **Evidence, not normative:** frame `3556:33191` "Navigation" — nine per-page instances
  (`state=Collapsed|Expanded, tab=<name>`) showing which tab is active on each page. It is an
  instance frame, so it defines nothing; it is the only place the active-tab treatment and the
  scrolled positions are shown in situ.
- **Behavior source:** `docs/features/navigation/01-account-switcher-analysis.md` (Robinhood
  account switcher, `Nav.MP4`, 16.92s) — the morph, gesture model, and switch choreography.
  Figma designs the two end states only; every transition rule comes from that document.

**Deviations (closed list):**

1. The two sets disagree on the axis value name for the same presentation — the row says
   `state=Default`, the tab says `state=Collapsed`. This contract uses **collapsed** and
   **expanded** throughout; the Figma names live only in the citations above.
2. The row's `Default` symbol renders **every** label inactive (`color-nav-text`). Exactly one
   tab is active in use; the active treatment is defined by C-069 `active=true` and evidenced
   by the instance frame, not by the row's sample.
3. The row's expanded symbol hides the add affordance on **Home only**; C-069 designs it on
   every expanded tab (§2b, OQ-C-019-2).
4. Tab labels, their order, and which tab is active are content, not design: the closed set is
   contracted in §3 because it is a program-level fact, not because the symbols fix it.
5. The dashed purple rectangle in both snapshots is Figma's component-set boundary, present in
   the export. It is not a design element — do not measure geometry from it.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

**Row** (both presentations): horizontal flex, `gap` = `space-element-gap` (8),
`items: center`, on `color-layout-background`. Content width exceeds the 440pt device in both
presentations (656 / 1048), so the row is horizontally scrollable and clips at the raw edges —
no fade mask (analysis §4).

| | collapsed | expanded |
|---|---|---|
| Row height | 32 | 96 |
| Row leading/trailing inset | 8 (`px-8`, in the component) | none in the component; the home-dashboard instance adds 16 (OQ-C-019-1) |
| Item | C-069 collapsed (58×32 at the "Home" sample; width is label-driven) | C-069 expanded (124×96, fixed) |

**Row order (closed, 8 tabs):** Home · Library · Groups · Members · Enrollments · Invites ·
Programs · Media.

### 2b. C-069 NavTabButton

One tab, in either presentation. Registry row C-069; this section is its contract.

**Collapsed** — `padding` 8 on all sides; label `type-nav-label` (SF Pro Bold 14/16); height
32 = 8 + 16 + 8. `active=false` → `color-nav-text`; `active=true` → `color-text-primary`.
**The active delta is color only** — no pill, no underline, no weight or size change. (This
matches the analysis §8 note 6 independently.)

**Expanded** — 124×96 card, `radius-card` (8), `padding` `space-card-padding` (16), 1px solid
border, label pinned top-left (`items: start`), same `type-nav-label`.

| | `active=false` | `active=true` |
|---|---|---|
| Fill | none (shows `color-layout-background`) | `color-nav-tab-background` |
| Border | `color-nav-border` | `color-nav-border-active` |
| Label | `color-nav-text` | `color-text-primary` |

**Add slot** (`3555:32883` "Nav add button") — a 40×40 hit area anchored to the card's
bottom-right, offset `-1` on both axes so it aligns to the card's outer edge over the 1px
border, containing **C-021 GlyphButton** `glyph=add` at 24pt in `color-accent`. Designed on
every expanded tab in C-069; hidden on Home in the row (§1 deviation 3). Its 40pt box is
smaller than C-021's stated 44pt hit target — OQ-C-019-3.

**Add action — known option list (owner, 2026-09-05):** the nav's add action offers exactly
three options — **Record video · Record audio · Write a note** — and everything it creates
lands in Library. The add action is **per-tab** (owner, 2026-09-05): each expanded card creates for its own surface, and Home has none. Library's list is closed; its *presentation* is undesigned (no menu frame exists;
C-066 ActionMenuOverlay is the program's only designed menu chrome and is the proposed
default), and which card hosts this list is OQ-C-019-2. The three options are the entry point
to the `docs/features/notes/` and `docs/features/memo/` suites, whose component manifests
already hold C-001–C-018.

A `gap: 10` is set on the expanded card between the label and the add slot; the add slot is
absolutely positioned, so the gap has no layout effect. Recorded, not tokenized — OQ-C-019-7.

## 3. Variant & state matrix

| Unit | Variant | Delta | Consumption |
|---|---|---|---|
| C-019 row | collapsed | 32pt label row, `px-8` | **consumed** — home-dashboard, members-home, groups-home, enrollments-home |
| C-019 row | expanded | 96pt card row, no inset in-component | designed-unconsumed — no screen spec describes the expanded row yet (it belongs to `shell-topnav`) |
| C-069 tab | collapsed × inactive | label `color-nav-text` | **consumed** — every non-active tab |
| C-069 tab | collapsed × active | label `color-text-primary`; no other delta | **consumed** — the active tab (evidenced per page in frame `3556:33191`) |
| C-069 tab | expanded × inactive | 124×96 card, `color-nav-border`, label `color-nav-text`, add slot | designed-unconsumed |
| C-069 tab | expanded × active | + `color-nav-tab-background` fill, `color-nav-border-active` border, label `color-text-primary` | designed-unconsumed |
| C-019 / C-069 | pressed / disabled | undesigned | proposed defaults: press = system highlight on the tapped unit; no disabled tab (omit it instead) — OQ-C-019-4 |
| C-019 | morph intermediate | undesigned in Figma; the analysis designs it (labels acquire hugging pill outlines, then grow) | proposed default: interpolate the two designed end states, pill-first per analysis §3 — OQ-C-019-5 |
| C-019 | scroll indicator | undesigned | proposed default: the analysis's thin indicator under the row while panning, then fades — OQ-C-019-6 |

Variants not in this table may not be built without a ruling.

## 4. Props contract

**C-019 TopNav**

| Prop | Type | Purpose |
|---|---|---|
| `tabs` | closed list of 8 (§2) | Order is the designed order |
| `selectedTab` | tab | Exactly one; sets C-069 `active=true` on that tab |
| `expansion` | 0…1 | The morph as a continuous value, NOT a boolean — the analysis's finger-tracked, reversible, spring-settled model (§8 note 2). `state=collapsed` is 0, `expanded` is 1; the designed symbols are the two endpoints |
| `scrollOffset` | pt | One shared offset across both presentations (analysis §4); panning never changes selection |
| `onSelect(tab)` | action | Switch; per analysis §5 the row auto-scrolls the selected tab to the leading edge and the nav stays expanded |
| `onToggleExpansion` | action | Tap toggles; vertical drag scrubs `expansion` |
| `onAdd(tab)` | action? | The expanded card's add slot; absent for Home (OQ-C-019-2) |

**C-069 NavTabButton** — `label`, `presentation` {collapsed, expanded}, `active` bool,
`addAction?`. Selection, scroll and expansion are three independent axes (analysis §8 note 4);
C-069 owns none of them.

## 5. Composition

- **Consumes:** C-069 NavTabButton ×8 → which consumes C-021 GlyphButton (`glyph=add`) in the
  expanded presentation.
- **Consumed by:** home-dashboard, members-home, groups-home, enrollments-home (all collapsed).
  `shell-topnav` will own the shell contract (placement, stickiness, safe-area, what the row's
  height change does to page content — the analysis has content pushed down in sync) and is the
  first spec expected to consume the expanded presentation.
- **Answers, this run:** the tab set is closed at 8 (Home · Library · Groups · Members ·
  Enrollments · Invites · Programs · Media), resolving OQ-home-dashboard-7 and
  OQ-enrollments-home-4 — both are annotated in their specs with this contract as the source.

## 6. Open questions

| OQ | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-019-1 | Leading inset asymmetry: collapsed carries `px-8` inside the component while expanded carries none and the home-dashboard instance adds 16 — so the first label sits 16pt from the edge collapsed and 32pt expanded. Is that intended (cards inset further), or should the two presentations share one inset so labels morph without a lateral jump? | No — geometry is captured either way | owner |
| OQ-C-019-2 | ~~Is the add slot per-tab, and is Home's absence contracted?~~ **RESOLVED 2026-09-05 (owner): the add action is PER-TAB.** Each expanded card carries its own creation action for its own surface; Home has none. Library's list is closed at three — Record video · Record audio · Write a note (§2b). Every other tab's list is opened by its own screen spec (Programs → create program is the strongest candidate, tying to OQ-create-study-program-3). Presentation of the list stays undesigned (OQ-C-019-5) | Closed | — |
| OQ-C-019-3 | The add slot's hit area is 40×40; C-021 GlyphButton's contract states a 44pt hit target. Reconcile (widen the slot, or scope C-021's 44 to its other hosts) | No | owner |
| OQ-C-019-4 | Pressed/disabled undesigned for both the tab and the card — proposed defaults in §3 | No — defaults proposed | owner |
| OQ-C-019-5 | The morph's intermediate frames are undesigned in Figma. Adopt the analysis's choreography wholesale (pill outline first, card internals fading in over the last ~30%), or design our own? Our card's only internal is the add glyph, so "progressive disclosure" may reduce to fading it | No — default proposed | owner (frames) |
| OQ-C-019-6 | Scroll indicator and auto-scroll-to-leading-on-selection come from the analysis and are undesigned here — confirm both for ours | No | owner |
| OQ-C-019-7 | The expanded card sets `gap: 10` with an absolutely-positioned add slot, so it has no effect. Figma hygiene — remove, or is a layout change intended? | No | owner (Figma) |
| OQ-C-019-8 | ~~Library, Programs and Media as siblings — is Library a parent coexisting with its own children?~~ **RESOLVED 2026-09-05 (owner):** they are unrelated surfaces, and the premise was wrong — 2.0's **Library is not the legacy MainLibrary**. Library holds the leader's own captured content (video · audio · notes) created by the nav's add action, organized by content type derived from **transcripts**; **Programs** is the study-program (curriculum) list, whose row tap opens `study-program-home`. Undesigned as of this ruling. Residual: the **Media** tab's role is now unaccounted for — see OQ-C-019-9 | Closed | — |
| OQ-C-019-9 | ~~If video/audio/notes live in Library, what does Media hold?~~ **RESOLVED 2026-09-05 (owner):** Media holds **curriculum assets used inside programs and lessons** (the legacy MainLibrary "Media" sense) — distinct from Library's leader-captured content. Screen row `media-home` added to the README | Closed | — |
