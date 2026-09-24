# ui2-component-notes — spec

> Converted to the builder layout 2026-09-24 from the numbered `/build-spec` suite. **The numbered
> docs are still on disk and are still the detail** — this file is the index the `/builder:*` pipeline
> reads, not a rewrite. See `plugins/builder/skills/resume/REFERENCE.md` §Condense, *Legacy layouts*.

## Overview

Point at a component on a 2.0 screen and talk about it. Three joined parts: **element targeting** (every
screen snapshot gains a map of component-instance rects, so hovering the render draws a labelled
bounding box and clicking selects that component); **the Component tab** (a fourth right-panel tab
showing the selected component *without leaving the screen* — identity, artwork, designed states, an
Open button, notes); and **notes** (a per-component/per-screen note file, appended through a composer
with `@` typeahead, read back as normative build input).

Full overview: [README.md](README.md) and [01-architecture.md](01-architecture.md).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server  | ⬜ | The production Express server is untouched. This feature lives entirely in the capture dev tool, which runs its own Express against its own Postgres | §Server |
| client  | ⬜ | No web-app change. Nothing in `client/` reads `docs/ui2`, and the 2.0 browser renders Figma PNGs, not web twins | §Client |
| iphone  | ⬜ | No app or harness change. `iphone/MakeReady/UI2Preview/` is read and edited **at command runtime** by `/ui2-component-build` and `/ui2-component-update`, which is those commands doing their job on the owner's notes, not part of building this feature | §iPhone |
| capture | ✅ | Backend: note read/append routes, a mention index route, element-map serving for screens, `buildUi2Screens`/index extensions, one migration script. Frontend: the Component tab, the hover/click targeting layer, the note card list, the notepad composer with `@` typeahead, and the chip-click behaviour change. No Prisma schema change — notes are files (D1) | §Capture |

Also in scope, outside the four apps: **one new command** (`.claude/commands/ui2-component-update.md`)
and edits to two existing ones; and **`docs/ui2`** gains two content directories
(`design-system/components/notes/`, `screens/notes/`) plus one new artifact class
(`screens/assets/<stem>.elements.json`). No existing normative doc is rewritten by this feature.

Detail: [02-app-impact.md](02-app-impact.md).

**Backward compatibility:** not applicable — nothing ships to a device or to production.

## Decisions

The decisions table is [01-architecture.md](01-architecture.md) §Decisions; rows settled during the
build are in [09-gaps-and-decisions.md](09-gaps-and-decisions.md). **No OPEN rows** at conversion.

<!-- The one place rulings live. Record the DECISION, not the conversation: a stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation. NEVER quote the user's prompt as the ruling — operationalize
     it into a closed list, a measured value, or an enumerated set of deviations.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

## Contract

The capture tool's own note, mention-index and element-map routes, produced and consumed **inside
capture**. Notes are files, not rows (D1). Table: [03-data-and-api.md](03-data-and-api.md).

🔴 **Notes are normative build input.** Read them with `node capture/lib/ui2-notes.mjs read`, never by
eye, and never write one as test data.

## Schema & API changes

No schema change (established 2026-09-10) — notes are files, not rows (D1).
[03-data-and-api.md](03-data-and-api.md).

## Server

Not affected — see §Apps. [04-server.md](04-server.md).

## Client

Not affected — see §Apps. [05-client.md](05-client.md).

## iPhone

Not affected (read/edited at command runtime, not by this build) — see §Apps.
[06-iphone.md](06-iphone.md).

## Capture

See [07-capture.md](07-capture.md) for the routes, the element-map serving, the Component tab, the
targeting layer and the composer.

## Testing

See [08-testing.md](08-testing.md).

## Findings & risks

The ledger is [09-gaps-and-decisions.md](09-gaps-and-decisions.md).

## Walk status (why `walk: none`)

🔴 **All six phases are VERIFIED, but this feature has never been exercised by a human.** The README
records it as *"signed off by the owner **without a human walk**: they authorised sign-off after being
shown the script and the one outstanding item. Everything below was verified by agents only."* The
suite's own verify gate reported **INCOMPLETE on 1 item** before that authorisation.

An authorisation to record a sign-off is not the same act as walking the feature, and a
`/builder:signoff` record's authority comes from the human typing that command on a build they
exercised (`plugins/builder/skills/signoff/SKILL.md` — a sign-off written any other way is void). The
converted manifest therefore reads `walk: none` and `verify: none`. Nothing about the work is in
question; what is missing is the walk.

## Fixes

- [ ] capture: the one item the suite's verify gate reported INCOMPLETE — see
  [09-gaps-and-decisions.md](09-gaps-and-decisions.md) and the phase-6 doc; clear it or record the
  owner's decision to accept it, then walk the feature.

## Plan

The plan is this folder's existing phase docs, left in place by the conversion:
[10-phase-1-notes-backend.md](10-phase-1-notes-backend.md) ·
[11-phase-2-element-maps-serving.md](11-phase-2-element-maps-serving.md) ·
[12-phase-3-backfill.md](12-phase-3-backfill.md) ·
[13-phase-4-targeting-ui.md](13-phase-4-targeting-ui.md) ·
[14-phase-5-component-tab.md](14-phase-5-component-tab.md) ·
[15-phase-6-commands.md](15-phase-6-commands.md) — all six carrying `## VERIFIED ✅`.
