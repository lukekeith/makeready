# C-066 ActionMenuOverlay — modal menu of contextual actions with a Done dismissal

Status: new · Specced: 2026-09-03 · Owner-designated: `/ui2-component modal-action-menu
<url>` (D10 — the set is not on the 2026-09-01 sheet dump; the owner's paste designates it
normative). Includes sub-component **C-067 ActionMenuRow** (own registry row, contract
below in one file — they ship together).

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3883-9315
  — node `3883:9315` ("Modal action menu", lone component, 432×212 at 2 sample actions)
- Row main component: `3832:31480` ("Action button", single `property1=Default`)
- Frozen snapshot: `assets/C-066-action-menu-overlay.png` — captured 2026-09-03

**Deviations (closed list):**
1. The two sample actions ("Withdraw invitation" / "Resend invitation") and their glyphs
   are per-instantiation content — each presenting surface supplies its own closed action
   list.
2. The withdraw row's glyph slot is named "Send--filled" in Figma with an X-circle
   ("Misuse") asset swapped in — the glyph slot is a content slot; the rendered glyph is
   normative, the slot name is Figma hygiene.
3. Height is content-driven (56pt per row + hairlines + button); 212 is the 2-action
   sample, not a fixed size.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Container: `color-modal-background` fill, `radius-modal` (16 — new token this run), p24,
internal gap 16, 432pt wide in the frame (content 384). Contents top→bottom:

1. **Actions list** — N × **C-067 ActionMenuRow**, each followed by a 1px
   `color-layout-border` hairline (including after the last row, per the frame).
2. **C-048 PageActionButton**, `color=White` — 36pt, white FILL (not bordered), r8,
   centered label "Done" (SF Pro Text Regular 12/20, ls −0.24, `color-black`).

**C-067 ActionMenuRow anatomy:** 56pt row (py16), gap 16: 24pt glyph (content slot, white)
· label `type-action-item` (SF Pro Regular 18/24 white — new observed token this run),
flex · 24pt chevron-right glyph.

## 3. Variant & state matrix

| Unit | Axis | Values | Consumption |
|---|---|---|---|
| C-066 container | — | single designed variant | unconsumed (no screen yet; anticipated first consumer: invite-home actions — see §5) |
| C-067 row | `property1` | `Default` (only) | unconsumed (inside C-066) |
| C-067 row | pressed / disabled / destructive styling | — undesigned | **proposed defaults + OQ-C-066-2/3:** pressed = system highlight; no disabled rows (omit instead); destructive actions render identically until frames say otherwise |
| C-066 presentation | scrim / position / motion | — undesigned | **proposed default + OQ-C-066-1:** dim scrim + `motion-menu-fade-in/out`, consistent with C-036 FilterMenuOverlay as the program's menu chrome |

Variants not in this table may not be built without a ruling.

## 4. Props contract

**C-066 ActionMenuOverlay:** `actions: [ActionItem]` (closed per instantiation), `onDone`
(dismiss), `onSelect(action)`. Done always dismisses; whether row-select auto-dismisses is
the presenting surface's contract (default: yes after the action's flow completes).

**C-067 ActionMenuRow:** `glyph`, `label`, `onTap`. The trailing chevron is fixed anatomy
(semantics: OQ-C-066-3).

## 5. Composition

- **Consumes:** C-067 ActionMenuRow (×N) · C-048 PageActionButton (`color=White` — first
  consumer of the White variant found in the 2026-09-02 sheet re-probe).
- **Consumed by:** none yet. Anticipated: `invite-home` invite actions — the sample
  actions are exactly the Withdraw/Resend that OQ-invite-home-4 flagged as undesigned
  (annotated there this run; the *trigger* affordance on invite-home is still undesigned).
  General role: the program's action-sheet chrome for contextual actions on any detail
  surface.

## 6. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-C-066-1 | Presentation chrome: position (bottom sheet vs centered), scrim, and motion are undesigned — proposed: dim scrim + `motion-menu-fade` per the C-036 precedent | No — default proposed | owner |
| OQ-C-066-2 | Destructive styling: "Withdraw invitation" renders identically to "Resend" — is a red/destructive row variant wanted? | No — as-designed stands | owner |
| OQ-C-066-3 | Chevron semantics: every row carries a chevron-right — does selecting always lead to a follow-on step (confirm/detail), and does a terminal action drop the chevron? | No — proposed: chevron is fixed anatomy | owner |
| OQ-C-066-4 | Trigger affordances: which control opens this on each consuming surface (invite-home designs none today) | No here; each consuming spec must add its designed trigger | owner (frames) |
