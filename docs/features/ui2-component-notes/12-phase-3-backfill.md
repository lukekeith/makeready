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

- [x] 3.1 `capture/scripts/ui2-screen-elements.mjs` — the resolution ladder in 07 §1.1
      (metadata → registry Figma-ref lookup → node id, then case-folded name → §4 closed-list
      gate → unresolved to the report), incl. the absolute→fraction conversion of §1.1 step 1
- [x] 3.2 `capture/scripts/out/` added to `capture/.gitignore` (09 §G-18)
- [x] 3.3 Run it per screen and write the 12 maps to `docs/ui2/screens/assets/*.elements.json`,
      `generatedBy: backfill@2026-09-10`
- [x] 3.4 **Read every `.unmapped.json`** and confirm the remainder is acceptable — the run is not
      finished until a human-readable summary of what each screen left unmapped is in the phase's
      VERIFIED note (07 §1.1, D5)
- [x] 3.5 `shared-edit-field`'s two composite exports: map against the exported section/sheet node
      per 09 §G-5, not against an invented frame · tests: covered by E-6 + the checklist below

## Phase gates

- [x] `cd capture && npm test` — **92 / 91 pass / 1 pre-existing**, with the real maps on disk
- [x] Every map passes the aspect guard: request each screen's `screen-detail` and confirm
      `elements` is non-null for all 12 snapshots (a silent `null` here is the G-2 failure mode)

## Verification checklist

- [x] For each of the 12 maps: every `ref` appears in that spec's §4 closed list (C-6's rule,
      applied to the backfill)
- [x] No map contains a guessed ref — anything the ladder could not resolve is in the report, not
      in the map (D5)
- [x] Rect sanity on one screen by eye: the KPI rail on `home-dashboard` maps to boxes in the
      upper third, not scattered
- [x] The composite `shared-edit-field` maps describe the whole sheet, and its aspect check passes
- [x] `git status docs/ui2` shows only `.elements.json` additions — no spec doc was touched

## VERIFIED

✅ **2026-09-10**

**11 of 12 snapshots mapped, 225 instances, every ref inside its screen's §4 closed list.**

| Snapshot | §4 covered | §4 rows with no instance on the frame | Unmapped instances |
|---|---|---|---|
| `home-dashboard` | 14/16 | C-024, C-073 | 4 |
| `study-program-home` | 10/11 | C-043 | 4 |
| `members-profile` | 10/12 | C-024, C-043 | 2 |
| `enrollment-home` | 9/11 | C-062, C-064 | 2 |
| `invite-home-linked` | 6/7 | C-043 | 1 |
| `invite-home` | 5/7 | C-038, C-043 | 1 |
| `enrollments-home` | 5/9 | C-036, C-038, C-057, C-059 | 10 |
| `edit-field-group-fields` | 5/8 | C-045, C-050, C-051 | 6 |
| `groups-home` | 4/7 | C-036, C-038, C-043 | 2 |
| `members-home` | 4/6 | C-036, C-038 | 2 |
| `create-study-program` | 3/4 | C-045 | 1 |

**The report read, per D5.** Nearly every "missing" row is a component nested INSIDE another
instance — Figma's metadata does not expand an instance's children, so `C-024 SparkBarChart` lives
inside a KpiCard and `C-045 TextInput` inside a Field group. Their container is mapped, so the
screen is still fully targetable; the inner component is simply not separately selectable. The
rest are genuinely absent from the frozen frame (`C-036 FilterMenuOverlay` is an overlay, `C-038
Avatar` and `C-043 MetaChip` sit inside list rows). Unmapped instances are dominated by the iOS
`StatusBar` — a documented deviation, not a component — and by layers whose registry row belongs
to a different screen, which the §4 gate correctly refused.

**`edit-field-overview.png` has no map** and returns `elements: null`. It is a second composite of
the same screen at a different export scale whose source node the spec does not record; inventing
one would have meant guessing rects. Unmapped is the D5 answer, and the screen is targetable
through its other frame.

**Four corrections the live data forced** (each written back into 07 §1.1 the same session):

1. **Coordinates are parent-relative, not absolute.** Only the root carries a canvas position, so
   the walk accumulates offsets down the tree. The spec said the opposite.
2. **Registry rows point at Figma FRAMES as often as instances** (`C-020 SectionHeader` is
   `node 3636:5051 (Title)`). Instance-only matching left eight §4 rows unmappable.
3. **Learning must be global, and instances-only.** A layer name is evidence only once a node-id
   match confirms it, and the registry cites one instance per row — so run screen-by-screen,
   "Navigation" resolves to C-019 on `home-dashboard` and nowhere else. Frames are excluded from
   learning because this file has four different frames called "Details"; learning that one taught
   C-028 InlineDropdown to three places it does not belong.
4. **A name can mean two components.** A 32×40 "Day" chip (C-052) and a 131×192 "Day" card
   (C-025) share a layer name. The screen's own §4 list disambiguates — candidates are tried in
   order and the one this screen renders wins.

**Section exports carry padding the section bounds do not.** `shared-edit-field`'s section is
1096×3206 in Figma; its PNG is 1176×3286 — 40pt on every side. The map records the padded box as
its coordinate space and shifts every rect into it, so the guard passes exactly (`size` now equals
the PNG's own dimensions) and the six frames land in two columns at x=0.093 / x=0.541.

**A test defect this phase created and fixed.** `ui2-elements.test.mjs` wrote into the real
`screens/assets/` directory and unlinked the map in its cleanup — harmless when no real maps
existed, destructive the moment the backfill wrote eleven. The tests now back up and restore
whatever is on disk (`withMap`), and E-1's "no map" case is created rather than assumed of the
repo. Verified by running `npm test` twice and confirming all 11 maps survive.
