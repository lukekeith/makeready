# Phase 5 — The Component tab, notes and the composer  ·  app: capture (frontend)

> Preconditions: Phase 4 **VERIFIED** — the tab is where a selection lands, so selection must work
> first. Phase 1's routes are what it reads and writes.

## Goal

A fourth right-panel tab shows the selected component without leaving the screen — identity,
artwork, designed states, Open, and its notes — and a full-height composer with `@` typeahead
appends a note that is on disk in the format 03 §1.1 defines. R4–R9 are demonstrable.

## Companion skills

None. Reuse `Ui2ContractTab.jsx`'s block structure, `IconSelect.jsx`'s keyboard list behavior, and
`ConfirmDialog` for the discard prompt — **never `window.confirm`** (house rule).

## Tasks (in order)

- [x] 5.1 `SidePanel.jsx` — optional controlled `tab`/`onTab`, `component` in the screen tab list,
      `TAB_LABEL.component`, `component` in the `!ready` branch, `onSelectComponent`
      pass-through; passed **only when `isScreen`** (07 §5.0)
- [x] 5.2 `Ui2ComponentTab.jsx` — the D4 block list, identity from `fetchUi2Detail(ref)` with
      `elements[].resolved` as first paint (07 §5.1, 09 §G-17), and **every view state in §5.1's
      table**, `parseError` banner included
- [x] 5.3 `NoteList.jsx` — newest-first cards, 2-line clamp, expand in place, mention chips
      resolving to current names (07 §5.2, R7)
- [x] 5.4 `capture/src/lib/mentions.js` — `filterMentions` + `commitToken` · tests: H-4, H-5
- [x] 5.5 `MentionTypeahead.jsx` — caret-anchored popup, ↑/↓/Enter/Tab/Escape, components then
      screens (07 §5.4, R9)
- [x] 5.6 `NoteComposer.jsx` — full-height textarea below the tab strip, pinned Cancel/Save bar,
      `after` sent with the POST, failed save keeps the text, `ConfirmDialog` on discard
      (07 §5.3, R8)
- [x] 5.7 `Ui2ScreenTab.jsx` — `onSelectComponent` replaces its own `useNavigate` (R6, 07 §5.6)
- [x] 5.8 Screen notes in the Screen tab, same components, same format (D6)
- [x] 5.9 `styles.css` — `.cmp-ui2n__*` (card, clamp, timestamp, expand, mention chip, pad, bar,
      typeahead) (07 §6)

## Phase gates

- [x] `cd capture && npm test` — **103 / 102 pass / 1 pre-existing** (+3 this phase: H-4, H-5, activeMention)
- [x] `cd capture && npx vite build` — clean
- [x] Browser console clean through the whole walk — selection, composer, typeahead, save, discard

## Verification checklist

- [x] Human script steps 4–10 (selection → tab → title → chip behavior → note cards → composer →
      typeahead → saved note on disk)
- [x] Add note is absent when `canCapture` is false (09 §X-1)
- [x] A chip for an **unmapped** component still opens a full Component tab (09 §G-17)
- [x] A corrupt note file shows the parse banner, never "No notes yet" (09 §G-13)
- [x] Cancel with text prompts through `ConfirmDialog`, never a browser dialog
- [x] Spec parity: R7's two-line clamp, R8's exactly-two buttons, R9's canonical token insertion

## VERIFIED

✅ **2026-09-10** — walked live in Chrome.

| What | Result |
|---|---|
| **R4** tab order | The screen's right panel reads **Screen · Component · Comments**. A component row's tabs are untouched |
| **R3/R5** selection → tab | Clicking a KpiCard on the render activates Component, titled `C-023 KpiCard` with `not specced / not built / artwork` chips, the frozen artwork, `Open component →`, its designed states, and its notes |
| **R6** chip behaviour | A `.cmp-ui2s__chip` click **selects** (`?c=C-029`, tab switches, screen stays put); `Open component →` is what navigates — it landed on `/components/2.0/C-024/align-center` |
| **09 §G-17** | Selecting `C-024 SparkBarChart` — which is in the spec's §4 list but **not in the element map**, because it is nested inside a KpiCard — opens a *full* tab, not an empty state. This is exactly the delta-audit finding, demonstrated |
| **R9** typeahead | Typing `@day` listed `C-052 DayChip`, `C-025 DayActivityCard`, `C-029 RadialDayClock`; Enter inserted the canonical `@C-052 ` and closed the popup, leaving the caret after the token |
| **R7** note cards | The saved note renders newest-first with a local-time stamp, clamped to two lines with Show more, and its mention rendered as a chip reading **DayChip** — the current display name, not the stored token (D10) |
| **R8** notepad | Add note replaced everything below the tab strip, with exactly Cancel and Save pinned at the bottom. Cancel with text raised the in-app **ConfirmDialog** ("Discard this note?"), never a browser dialog; discarding restored the list unchanged |
| **On disk** | The file matched 03 §1.1 exactly — `# C-023 KpiCard — notes`, the preamble, one `##` ISO heading — and `node capture/lib/ui2-notes.mjs read C-023` parsed it back identically |

**Verification notes were deleted afterwards.** A note is normative build input; leaving an
invented one on disk would make `/ui2-component-build` honour a requirement nobody asked for.

**One defect found and fixed in this phase's own tests.** `H-2b` asserted on the real
`home-dashboard.elements.json` from `ui2-target.test.mjs` while `ui2-elements.test.mjs` swaps that
same file in and out — and node runs test *files* in parallel processes, so the two raced. Moved
into the file that owns the swapping, where it is serialised; three consecutive runs are now
identical.
