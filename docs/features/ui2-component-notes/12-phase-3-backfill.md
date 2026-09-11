# Phase 3 — The element-map backfill  ·  app: capture (migration) + docs/ui2 (data)

> Preconditions: Phase 2 **VERIFIED** — the maps must be *served* before it is worth generating
> twelve of them. Needs the Figma MCP connection; if it is down, this phase stops and says so
> rather than hand-inventing rects.

## Goal

Every one of the **12** frozen screen snapshots (10 specced screens; `invite-home` and
`shared-edit-field` have two each) has an element map on disk whose refs are a subset of that
screen spec's §4 closed list, and an operator report naming what could not be resolved.

## Companion skills

`/ui2-screen` phase 2 is the authority on how an instance resolves to a registry row — this
generator mechanises exactly that walk (07 §1.1). Do not invent a second matching rule.

## Tasks (in order)

- [ ] 3.1 `capture/scripts/ui2-screen-elements.mjs` — the resolution ladder in 07 §1.1
      (metadata → registry Figma-ref lookup → node id, then case-folded name → §4 closed-list
      gate → unresolved to the report), incl. the absolute→fraction conversion of §1.1 step 1
- [ ] 3.2 `capture/scripts/out/` added to `capture/.gitignore` (09 §G-18)
- [ ] 3.3 Run it per screen and write the 12 maps to `docs/ui2/screens/assets/*.elements.json`,
      `generatedBy: backfill@2026-09-10`
- [ ] 3.4 **Read every `.unmapped.json`** and confirm the remainder is acceptable — the run is not
      finished until a human-readable summary of what each screen left unmapped is in the phase's
      VERIFIED note (07 §1.1, D5)
- [ ] 3.5 `shared-edit-field`'s two composite exports: map against the exported section/sheet node
      per 09 §G-5, not against an invented frame · tests: covered by E-6 + the checklist below

## Phase gates

- [ ] `cd capture && npm test` — E-1…E-7 still green with real files present
- [ ] Every map passes the aspect guard: request each screen's `screen-detail` and confirm
      `elements` is non-null for all 12 snapshots (a silent `null` here is the G-2 failure mode)

## Verification checklist

- [ ] For each of the 12 maps: every `ref` appears in that spec's §4 closed list (C-6's rule,
      applied to the backfill)
- [ ] No map contains a guessed ref — anything the ladder could not resolve is in the report, not
      in the map (D5)
- [ ] Rect sanity on one screen by eye: the KPI rail on `home-dashboard` maps to boxes in the
      upper third, not scattered
- [ ] The composite `shared-edit-field` maps describe the whole sheet, and its aspect check passes
- [ ] `git status docs/ui2` shows only `.elements.json` additions — no spec doc was touched

## VERIFIED

⬜ Not yet — do not open the next phase doc.
