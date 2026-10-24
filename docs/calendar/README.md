# Calendar (`calendar-home`) — UI 2.0

A root-level Calendar tab modelled on Apple Calendar's Month view: a month grid that scrolls
continuously, a "curtain" that opens a tapped week into a week strip and one day's timeline,
paging between days and weeks, Today, and event search. The calendar body keeps the reference's
look. The chrome uses MakeReady 2.0 components (C-105 Button, C-102 IconButton, C-034 SearchField,
C-084 TabBar).

| File | What it is |
|---|---|
| [`SPEC.md`](SPEC.md) | **The build spec**, in `/builder` shape: apps, decisions, API contract, per-app work, testing, findings |
| [`02-design.md`](02-design.md) | **Normative design**: layout, component map, geometry, states, the navigation and gesture state machine, motion values |
| [`01-video-analysis.md`](01-video-analysis.md) | Evidence: source video metadata, the timestamped outline, transition timings measured at 20 fps, and measured anatomy |
| [`frames/`](frames/) | 12 reference stills, 440 pt wide (1 px = 1 pt) |

## Hand-off

- **/builder:** `/builder:resume --path docs/calendar`, or `/builder:brainstorm` pointing at this folder.
  The SPEC is already in the pipeline's section order. The next step is the audit. The decisions
  marked *proposed Claude* are recommendations the owner should confirm, or overrule in §Decisions,
  before the go-ahead.
- **/superpowers:** hand `SPEC.md` + `02-design.md` to `superpowers:writing-plans`.

## Source
`/Users/lukekeith/MakeReady/Design reference/calendar/calendar.MP4`: 61 s, 60 fps, 1320×2868. Analysed 2026-10-20.
