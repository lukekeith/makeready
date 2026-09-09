# 01 — Top Navigation Analysis (Robinhood account switcher)

**Purpose:** a complete behavioral spec of the top navigation captured in `Nav.MP4` — the
Robinhood app's account-switcher header (dark theme, 2025 generation). Scope is **the top
navigation only**: its states, geometry, transitions, and touch behavior, detailed enough to
build something very similar. Everything below the nav is referenced only where it reacts to
the nav (content push, page switch transitions).

**Source:** `/Users/lukekeith/Makeready/Nav.MP4` — 16.92s, 60fps, 1320×2868 (3x → 440×956pt).
Analysis method: 4fps full-run contact sheets → 12–15fps crops of the nav region at every
transition → full-res stills of the three resting states.

---

## 1. What it is

A horizontally scrollable **tab row of accounts** ("Investing, Trust, Agentic, Strategies,
Joint, Custodial, Credit Card, Retirement, + Add") pinned at the top of the screen, directly
under the status bar. It has **two presentations of the same row**:

- **Compact** — a plain text-label row (like a tab bar), ~36pt tall.
- **Expanded** — the labels grow into **account cards** (~124pt wide, ~70–80pt tall) showing
  per-account content (balance + day change on funded accounts, a ⊕ affordance on unfunded
  ones).

The two are not separate components that crossfade — **the labels morph in place into the
cards** (same x-positions, same text nodes visually), and the page content below is pushed
down/pulled up in sync with the row's height. Selection (which account's page is shown) is
completely independent of both the scroll position of the row and its expansion state.

## 2. State inventory

| State | What it looks like |
|---|---|
| Compact, at rest | Text labels on black; **active = white semibold**, inactive = cool gray (#8C9196-ish), same size. No pill, no underline, no other active marker. |
| Compact, scrolled | Same row panned left/right freely; labels clip at both screen edges (no fade mask). The active label can scroll fully off-screen. A thin scrollbar indicator appears under the row while panning, then fades. |
| Morphing (drag-tracked) | Labels acquire hugging pill outlines → pills grow in height/width into cards. Progress is continuous and reversible (see §4). |
| Expanded, at rest | Row of rounded-rect cards. **Selected card:** elevated fill (≈#1E2023) + 1px lighter border (≈#3A3D42), label white. **Unselected:** near-black fill, dim border (≈#26282B), label gray. |
| Expanded card, funded account | Label top-left; below it the account value (≈15pt) and day change (green ▲ %, ≈13pt). Only the funded account (Investing $90.58 ▲0.45%) shows values. |
| Expanded card, unfunded account | Label top-left + **⊕ outline icon bottom-right** (~24pt) — the "fund/set up this account" affordance. |
| Expanded, scrolled | Card row pans horizontally exactly like the compact row. After a selection change it **auto-scrolls to bring the selected card to the leading edge**. |
| Card pressed | Brief brightening of the tapped card before selection commits. |
| End of row | A final "Add ⊕" tab (create account) terminates the row in both presentations. |

Geometry (440pt width): compact labels ≈17pt semibold, first label at **24pt left margin**,
~28–30pt gaps; row ≈36pt tall. Cards ≈**124pt wide** (≈3.3 visible), **14pt gaps**, corner
radius ≈16pt, card height ≈70–80pt; card label 17pt semibold at ~16pt inset.

## 3. Expansion / collapse — the signature interaction

Timed from the 12–15fps passes (±0.07s):

- **Expand** (first seen 0.83→1.6s ≈ **700ms** full choreography; later toggles run faster,
  ~300–400ms, consistent with flick velocity feeding the spring):
  1. Every visible label simultaneously acquires a **hugging rounded-rect outline** (a pill
     around the text).
  2. Pills grow in height and width into cards; label stays pinned to the card's top-left;
     the whole row's spacing widens to card gaps. Content below is pushed down in sync.
  3. **Progressive disclosure near the end**: the value/▲% (funded) and ⊕ (unfunded) fade in
     only in the last ~30% of the morph. Collapse hides them first, in reverse.
- **Collapse** is the exact mirror (~250–350ms on a flick): adornments fade out first, cards
  shrink back to bare labels, content rises.

**The morph is finger-tracked and interruptible.** At 11.13→11.22s the row shrinks to
mid-height and then grows back without reaching compact — the user reversed direction
mid-gesture. So this is a **drag-scrubbed progressive transition with a spring settle to the
nearest end state** (the toggles at 14.0–15.1s — expanded→compact→expanded within a second —
are flicks). Treat expansion progress as a 0→1 value driven by vertical drag on the header
region, with velocity-based settle, not as a fire-and-forget animation.

No touch overlay is recorded, so the exact trigger surface is inferred: vertical drag/flick on
the nav row itself scrubs the morph (matches the reversible frames), and a plain tap on the
row (in production Robinhood, tapping the active account label) toggles it. Content never
scrolls independently before a collapse in this recording — the morph is standalone, not a
scroll-linked stretchy header.

## 4. Horizontal scrolling

- Both presentations pan horizontally with normal momentum; **panning never changes
  selection** (the user scrolls to the far end and back at 3–9s while Investing stays the
  active page).
- No snapping/paging is visible in compact; cards appear to settle on card boundaries
  (leading-edge alignment) when momentum ends.
- Labels/cards clip at the raw screen edges — no gradient fade mask.
- The row keeps **one shared scroll position across the two presentations** (the morph happens
  wherever you've scrolled to; positions map 1:1).

## 5. Switching accounts (observed in the expanded state)

Tap an account card (Trust at ≈12.1s, Agentic at ≈13.3s):

1. **Selection highlight moves immediately** — tapped card gets the elevated fill + bright
   border; previous selected card dims to the unselected treatment.
2. **Content switches with a crossfade + small lateral slide** (~500ms): outgoing page fades
   while shifting left, incoming page fades in from the right. It reads as "the page is
   replaced", not as a full-width paging slide.
3. **The card row auto-scrolls** so the newly selected card lands at the leading (left) edge —
   this runs concurrently with the content transition.
4. The nav **stays expanded** after switching (no auto-collapse); the user collapses it
   manually later.
5. The header content below the nav belongs to the page, not the nav (the big $90.58 title,
   Gold Card chip, chart are page content and get replaced by the switch; on the unfunded
   accounts the page is a marketing/setup page).

Tapping an inactive label in the **compact** state isn't demonstrated, but the row is the same
control — assume compact tap = same switch with the same content transition, minus the card
choreography.

## 6. Touch feature summary

| Gesture | Where | Effect |
|---|---|---|
| Horizontal pan/flick | nav row (both states) | Scrolls the row; never changes selection; scrollbar indicator while active |
| Vertical drag | nav row | Scrubs the compact⇄expanded morph continuously; reversible mid-gesture |
| Vertical flick / tap | nav row | Commits the morph to the nearest/target state with a spring (~300ms) |
| Tap unselected card | expanded row | Switches account: instant highlight move, ~500ms content crossfade+slide, row auto-scrolls selected card to leading edge |
| Tap "Add ⊕" | end of row | Create-account flow (not shown in recording) |
| Content vertical scroll | page below | Does not affect the nav's state in this recording (nav stays as-is; it's sticky) |

## 7. Timestamped outline

Source 60fps; outline sampled at 4fps (±0.25s), **bold** rows measured at 12–15fps (±0.07s).

| t (s) | What happens |
|---|---|
| 0.0–0.8 | Compact at rest: Investing active (white), 6 labels visible, Investing page below |
| **0.83–1.6** | **Expand morph**: labels → pills → cards; value/⊕ fade in near the end; content pushed down |
| 1.6–2.5 | Expanded at rest (Investing card selected with value; Trust/Agentic ⊕) |
| 2.5–2.9 | Collapse back to compact |
| 3.0–5.5 | Horizontal pan of compact row left through Custodial, Credit Card, Retirement to trailing "Add ⊕"; selection unchanged |
| 6.0–8.2 | Rests at the trailing end (Retirement, Add ⊕) |
| 8.2–8.9 | Pan back right to the leading edge (Investing …) |
| **9.9–10.3** | **Expand morph again** (same choreography) |
| 10.3–11.0 | Expanded holds |
| **11.1–11.3** | **Reversible morph demo**: shrinks to mid-height, then re-grows without reaching compact — finger-tracked scrubbing |
| 11.3–12.0 | Expanded at rest |
| **12.1–12.8** | **Tap Trust card**: highlight moves instantly; content crossfade+slide to Trust setup page; row auto-scrolls Trust to leading edge |
| **13.3–13.9** | **Tap Agentic card**: same pattern → "Introducing agentic trading" page; Agentic to leading edge |
| **14.0–14.3** | Flick-collapse to compact (Agentic active white among gray labels) |
| 14.3–14.7 | Compact holds |
| **14.7–15.1** | Flick-expand again |
| 15.1–15.4 | Expanded; 15.25–15.75 quick compact↔pill flutter (user toggling) |
| 16.0–16.9 | Ends expanded at rest (Agentic ⊕ card selected, Strategies/Joint next) |

## 8. Notes for building ours

1. **One row, two projections.** Model the switcher as a single horizontal list with an
   `expansion` value 0→1. Label position/size interpolates into card position/size; the same
   scroll offset applies at every expansion value. Don't build two components that swap.
2. **Drive expansion by gesture, settle by spring.** Vertical drag on the header scrubs
   `expansion`; release settles to 0 or 1 by position+velocity. Tap toggles. Everything must
   be interruptible mid-flight (SwiftUI: gesture-driven state + spring; web: pointer events +
   a spring lib or WAAPI with manual progress).
3. **Progressive disclosure of card internals** — secondary content (values, ⊕) lives in the
   last ~30% of the morph, fading opacity only (no layout jump). This is what makes the morph
   read clean at speed.
4. **Selection ≠ scroll ≠ expansion.** Three independent axes of state; the only coupling is
   the auto-scroll-to-leading on selection change.
5. **Content transition on switch** is a ~500ms crossfade with a small lateral shift, cheaper
   and calmer than full paging; run it concurrently with the row's auto-scroll.
6. **Active-tab treatment in compact is typographic only** (white vs gray, same weight/size
   change only in color) — no underline/pill; the pill exists solely as the morph's first frame.
7. MakeReady mapping: this pattern fits any "peer contexts of the same page" switcher — e.g.
   groups in the leader app, or member enrollments — where each context has a status worth
   glancing (the card face) without committing to a switch.
