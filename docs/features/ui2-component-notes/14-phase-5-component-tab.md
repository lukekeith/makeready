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

- [ ] 5.1 `SidePanel.jsx` — optional controlled `tab`/`onTab`, `component` in the screen tab list,
      `TAB_LABEL.component`, `component` in the `!ready` branch, `onSelectComponent`
      pass-through; passed **only when `isScreen`** (07 §5.0)
- [ ] 5.2 `Ui2ComponentTab.jsx` — the D4 block list, identity from `fetchUi2Detail(ref)` with
      `elements[].resolved` as first paint (07 §5.1, 09 §G-17), and **every view state in §5.1's
      table**, `parseError` banner included
- [ ] 5.3 `NoteList.jsx` — newest-first cards, 2-line clamp, expand in place, mention chips
      resolving to current names (07 §5.2, R7)
- [ ] 5.4 `capture/src/lib/mentions.js` — `filterMentions` + `commitToken` · tests: H-4, H-5
- [ ] 5.5 `MentionTypeahead.jsx` — caret-anchored popup, ↑/↓/Enter/Tab/Escape, components then
      screens (07 §5.4, R9)
- [ ] 5.6 `NoteComposer.jsx` — full-height textarea below the tab strip, pinned Cancel/Save bar,
      `after` sent with the POST, failed save keeps the text, `ConfirmDialog` on discard
      (07 §5.3, R8)
- [ ] 5.7 `Ui2ScreenTab.jsx` — `onSelectComponent` replaces its own `useNavigate` (R6, 07 §5.6)
- [ ] 5.8 Screen notes in the Screen tab, same components, same format (D6)
- [ ] 5.9 `styles.css` — `.cmp-ui2n__*` (card, clamp, timestamp, expand, mention chip, pad, bar,
      typeahead) (07 §6)

## Phase gates

- [ ] `cd capture && npm test`
- [ ] `cd capture && npx vite build`
- [ ] Browser console clean on a screen with a selection and on the composer

## Verification checklist

- [ ] Human script steps 4–10 (selection → tab → title → chip behavior → note cards → composer →
      typeahead → saved note on disk)
- [ ] Add note is absent when `canCapture` is false (09 §X-1)
- [ ] A chip for an **unmapped** component still opens a full Component tab (09 §G-17)
- [ ] A corrupt note file shows the parse banner, never "No notes yet" (09 §G-13)
- [ ] Cancel with text prompts through `ConfirmDialog`, never a browser dialog
- [ ] Spec parity: R7's two-line clamp, R8's exactly-two buttons, R9's canonical token insertion

## VERIFIED

⬜ Not yet — do not open the next phase doc.
