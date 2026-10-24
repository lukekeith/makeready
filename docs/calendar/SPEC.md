# calendar-home — spec
> lg · no ticket · design source: screen recording (no Figma) — evidence `01-video-analysis.md`, normative design `02-design.md`

## Idea

**Why.** Leaders need to see what is happening across their groups — lessons from enrollments,
meetings, deadlines — by month and by day. The UI 2.0 TabBar (C-084, D51) already has a Calendar
tab, but `calendar-home` has never been designed: `docs/ui2/README.md` lists it as `pending-figma`.
This spec designs it from a recording of Apple Calendar's Month view, which the owner wants
mimicked closely.

**What success looks like.** A leader taps the Calendar tab and gets a month grid that scrolls
continuously through the year, with coloured indicators under days that have events. Tapping a day
opens the "curtain": that week becomes a strip at the top and the day's hour timeline opens below it.
They can swipe between days, swipe the strip between weeks, tap Back to fold the grid closed again,
jump to Today from anywhere, and search events. The motion matches the reference closely enough
that a side-by-side recording of the two looks the same.

**In your words.**
- "The calendar page is a root level page so there is no pageheader, the only thing that will exist
  is the bottom navigation" → D3, 02-design §2
- "We don't need the two icons at the bottom right … the only buttons we need top right is the plus
  icon button and search" → D2, D3
- "Tapping on a day only shows the day that was tapped" → D4
- "Pay extra close attention to the way navigation works, swiping up and down, left and right,
  navigating days and weeks" → 02-design §7 (the state machine), D10, D11
- "I really like the calendar day and week day header styling, the only thing that will change …
  are the button styles at the top of the screen along with the Today button" → D3, D4

**The concept.** One screen, three modes — `month`, `day(date)` and `search`. The modes and their
transitions are defined in 02-design §1 and §7.
The month grid and the week strip use the same seven full-width columns. That is what lets the
tapped week row slide straight into the strip with no horizontal shift (the curtain).
Data comes from one new date-range endpoint plus one new search endpoint. Both return events from
every group the leader can manage.

**How it fits today.** The legacy calendar `Pages/Main/MainCalendar.swift` (a SplitMonthCalendar
plus a curtain-split list of lessons) is replaced at the UI 2.0 cutover. This is the same rule as
every other 2.0 screen: this feature builds a preview-module screen and wires no route. The `Event`
model already carries what the timeline needs: `date`, `startTime`, `endTime`, `isAllDay`,
`timezone`, `type`, `locationName` and recurrence. The only existing reads are per-group
(`GET /api/groups/:groupId/events`, in both `routes/events.ts:452` and `routes/enrollments.ts:2724`)
and org search (`routes/search.ts:479`). The search read returns newest first and has no times.

**Approaches considered.**
- **Chosen:** a native SwiftUI month grid in one `ScrollView`/`LazyVStack` with a section per
  month, plus a separate paged day view. The curtain is a matched-geometry transition between the
  tapped week row and the strip.
- **Rejected — reuse the legacy UIKit SplitMonthCalendar:** it uses 56 pt cells with padded margins,
  purple dots and a snapshot-slice curtain, which is the wrong look and a different interaction.
- **Rejected — fan out over the per-group endpoint** (what the legacy screen does): it costs N
  requests per month and has no cross-group search.

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | 2 new read endpoints: calendar range and calendar search, across manageable groups | §server |
| iphone | ✅ | `calendar-home` UI 2.0 preview screen + 11 new preview components + the event layout/state logic | §iphone |
| client | ⬜ | UI 2.0 is iPhone-only (members stay on web; the web LeaderApp parity project is frozen, D3 of `docs/ui2`) | — |
| capture | ✅ | `calendar-home` + new-component fixtures for the d2m capture lane | §capture |

**Sequencing:** contract (§Contract) → server implements and verifies (contract FREEZES) → iphone
builds the components and screen against fixtures shaped exactly like the frozen responses → capture
→ the walk.

**Backward compatibility:** additive only. The new routes live under `/api/calendar/*`, and no
existing route or response changes. Released iPhone builds are unaffected.

**Blast radius:** read-only access to `Event`, `Group`, `Enrollment`. The authorization filter is
reused from `groupManageFilter`.

## Decisions
<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Where it lives | The screen is `CalendarHomeScreen` in `iphone/MakeReady/UI2Preview/Screens/Calendar/`, in the preview module, and is referenced by no app route, tab or flag (preview-build.md §3 rule 1). It reads events through a `CalendarEventSource` protocol. The preview uses a fixture source; the live source is wired at the 2.0 cutover. Rejected: wiring into `MainView` now, because it breaks the parallel-shell + hard-cutover rule. | proposed Claude 2026-10-20 |
| D2 | Control-row left slot | `month`: empty. `day`: C-105 Back button labelled with the selected date's month. The large title appends the year (`color-text-secondary`) only when the top-most month is not in the current year. Rejected: the reference's "‹ 2026" year pill, because there is no year view to go back to. | owner 2026-10-20 (no year view) · year-in-title proposed Claude |
| D3 | Chrome components | This is the closed list of 2.0 substitutions. Back pill → C-105 Button (`chevron-left` + label). Search → C-102 IconButton outlined `search-carbon`. Add → C-102 IconButton outlined `add-large-carbon`. Today → C-105 Button "Today". Search field → C-034. Close search → C-102 outlined `x`. Bottom → C-084 TabBar `selected: .calendar`. There is no C-040 PageHeader. The reference's bottom-right icon pair and its month-style toggle are not built. | owner 2026-10-20 |
| D4 | Body styling | MonthDayCell, WeekdayHeader, WeekStrip, EventIndicator, DayTimeline, CalendarEventBlock, AllDayEventChip, NowIndicator, CalendarEventRow and CalendarEmptyState reproduce the reference geometry in 02-design §2–§6, adapted only to 2.0 colour tokens. There is no list mode and no multi-day view: a date tap always opens exactly one day. | owner 2026-10-20 |
| D5 | Event colour | Colour comes from `Event.type`, using the table in 02-design §8. `color-negative` is reserved for today/now. Rejected: colour by group, because `Group` has no colour field and adding one is a schema change for a cosmetic need. | proposed Claude 2026-10-20 |
| D6 | "+" button | Fires `onAddEvent(date: Date)`. The date is the selected date in `day` and today in `month`. The preview wires it to a no-op. Its destination is the future create-event screen, which is out of scope here. Rejected: reusing the legacy create-event flow inside a 2.0 screen, because it mixes the 1.0 and 2.0 shells. | proposed Claude 2026-10-20 |
| D7 | Event tap | `CalendarEventBlock`, `AllDayEventChip` and `CalendarEventRow` fire `onOpenEvent(event)`, which is a no-op in the preview. The destination is decided with the event-detail screen (out of scope). | proposed Claude 2026-10-20 |
| D8 | Data window | The month grid fetches by calendar month. On scroll it fetches the visible month ±1 (one request per 3-month window), caches by month and serves cache-then-refresh. The scroll range starts at ±24 months and extends by 12 months within 3 months of either end. | proposed Claude 2026-10-20 |
| D9 | Week start | Weeks start on Sunday, matching the reference. Rejected: locale `firstWeekday`, because the owner asked for the reference look and the curtain geometry assumes one fixed column order. | proposed Claude 2026-10-20 |
| D10 | Day scroll anchor | Today's page opens with the current time at 70% of the timeline viewport. Any other day opens with `min(5 AM, earliest timed start − 1 h)` at the top. Day↔day paging within a week keeps the hour offset; week paging and Today use the anchor. This is measured behaviour (analysis §3.2–§3.3). | proposed Claude 2026-10-20 |
| D11 | No other gestures | Month: vertical scroll and taps only. Day: horizontal page on content, horizontal page on the strip, and vertical scroll of the timeline. There is no edge-swipe back, no pull-down to month and no pinch-zoom of the timeline. Rejected: an edge-swipe back, because the screen is a tab root. | proposed Claude 2026-10-20 |
| D12 | Data scope | Events where `isActive`, the group is active, and the group passes `groupManageFilter(userId)` in the user's current organization, for every `EventType`. Rejected: member-joined groups, because UI 2.0 is the leader app. | proposed Claude 2026-10-20 |
| D13 | Search source | Search uses the new `GET /api/calendar/search`, sorted ascending with times. Rejected: `GET /api/search?types=event`, because it sorts by date descending, omits `startTime`/`endTime`/`isAllDay`, and its cursor order can't serve the ascending list with a Today jump. | proposed Claude 2026-10-20 |
| D14 | Time semantics | Times display as wall-clock values: `startTime`/`endTime` exactly as stored (HH:mm), with no device time-zone conversion. The day an event belongs to is the server-computed `localDate`. An `endTime` earlier than `startTime` means the event runs past midnight: it draws on its own day to 12 AM and on the next day from 12 AM. Rejected: converting to device tz, because Events store local HH:mm strings and conversion would shift lessons across days (the known compare date-shift bug). | proposed Claude 2026-10-20 |

## Contract

Shared type **CalendarEvent**:
`{ id: string, groupId: string, groupName: string, type: "LESSON"|"MEETING"|"ONLINE"|"DEADLINE"|"SOCIAL"|"OTHER", title: string, localDate: "YYYY-MM-DD", startTime: "HH:mm"|null, endTime: "HH:mm"|null, isAllDay: boolean, timezone: string|null, locationName: string|null, externalUrl: string|null, isRecurring: boolean, enrollmentId: string|null, lessonScheduleId: string|null, dayNumber: number|null }`
- `isAllDay` is true when `Event.isAllDay`, or when `startTime` is null.
- `isRecurring = recurrenceGroupId != null`.
- `localDate` is `Event.date` formatted in `Event.timezone`, falling back to the group's enrollment timezone, then UTC (F2).

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `GET /api/calendar/events` | server | iphone (`CalendarEventSource` live impl, at cutover; fixtures now) · capture (fixture shape) | session (`requireAuth`) | `start=YYYY-MM-DD&end=YYYY-MM-DD`, inclusive, span ≤ 186 days | `200 { success: true, events: CalendarEvent[] }`, sorted by `localDate`, then all-day first, then `startTime`, then `title` | `400 { success:false, error:"Invalid date range" }` (missing, malformed, end < start, or span > 186) · `401` |
| `GET /api/calendar/search` | server | iphone (search mode) · capture | session | `q` (trimmed, ≥ 2 chars), `limit` 1–200 (default 100), `cursor?` | `200 { success: true, events: CalendarEvent[], pagination: { hasMore, nextCursor } }`, sorted **ascending** by `localDate`, `startTime`. Matching is word-AND over `title`, `description`, `locationName` (the same `wordMatchConditions` as `/api/search`) | `400 { success:false, error:"Query too short" }` · `401` |

## Schema & API changes

| # | Change | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| A1 | ADD | — | `GET /api/calendar/events` | cross-group date-range read for the calendar | planned |
| A2 | ADD | — | `GET /api/calendar/search` | ascending, timed event search | planned |

No schema change (established 2026-10-20). `Event` already has `@@index([groupId, date])`.

**Data plan:** none. This is read-only and touches no existing rows.

## server
- New `src/routes/calendar.ts`, mounted at `/api`. The logic goes in `src/services/calendarService.ts`:
  `listEvents(userId, start, end)` and `searchEvents(userId, q, limit, cursor)`, plus a pure
  `toCalendarEvent(row, fallbackTz)` mapper that computes `localDate` and `isAllDay`.
- Authorization: `groupManageFilter(userId)` plus the current-organization scope, as in
  `enrollments.ts:2724`. There are no per-event permission checks.
- Range query on `Event.date`: pad the range by ±1 day in UTC, then filter by computed `localDate`, so
  that tz edges are neither dropped nor duplicated.
- OpenAPI annotations like the neighbouring routes. Restart the container after edits
  (`docker restart makeready-server`, which has no hot reload). For curl checks, send a non-bot User-Agent.
- Gates: the server gate set from `.claude/builder.md`.

## iphone
All files go under `iphone/MakeReady/UI2Preview/`. Commits, simulator launches and archives are
user calls (builder.md).
- **Models / logic** (pure, unit-tested): `CalendarEvent` (Codable, mirrors §Contract);
  `CalendarLayout` with `monthRows(for:)` (week rows plus each row's occupied column span, for the
  separators), `indicatorWidth(count:)`, `overlapColumns(_:)` (greedy column packing, 02-design §5.4),
  `defaultAnchor(for:events:now:)` (D10) and `weekPage(from:by:)` (keeps the weekday);
  `CalendarEventSource` protocol + `FixtureCalendarEventSource`.
- **New components** (one file each; IDs minted at build): WeekdayHeader, MonthGrid, MonthDayCell,
  EventIndicator, WeekStrip, DayTimeline, CalendarEventBlock, AllDayEventChip, NowIndicator,
  CalendarEventRow, CalendarEmptyState. Geometry and states are in 02-design §2–§6, and each file
  cites the section it implements.
- **Screen** `Screens/Calendar/CalendarHomeScreen.swift`:
  - The mode state machine from 02-design §7.
  - The curtain via `matchedGeometryEffect` keyed on the tapped week, with spring response 0.5 and
    damping 0.85.
  - Day paging with a custom drag (35% / 300 pt·s⁻¹ commit), not `TabView(.page)`, so strip and
    content can be coupled as §7.2–§7.3 require.
  - Reduce Motion fallback (§7.8).
  - Injected `now: Date` and `calendar: Calendar` for deterministic captures.
- Re-use without edits: C-034, C-076, C-084, C-102, C-105. Glyphs used: `chevron-left`, `search-carbon`,
  `add-large-carbon`, `x`, `map-pin`, `repeat-arrows`, all of which already exist in `Glyph.swift`.
- Motion values with no token yet (spring 0.5/0.85, page 0.3 s ease-out, collapse 0.45 s, title
  crossfade 0.15 s) are written as `FLAGGED LITERAL` constants, citing 02-design §7 (F4).
- Run the `transition-review` skill on the diff before handing over for the walk.

## capture
- Fixtures for the screen states, through the d2m capture lane (paths come from `project_info`).
  `now` is fixed at 2026-10-20 22:42 local for all of them.
- The states are: `month-current` (Oct 2026, today ring) · `month-next-year` (Apr 2027,
  "April 2027" title) · `month-dense` (indicator widths 1–4+) · `day-past` (Jul 29 2026, 2 timed
  events) · `day-today` (Oct 20, now line) · `day-overlap` (Jul 31, 2 overlapping blocks) ·
  `day-allday` (Jul 22, all-day chip) · `search-focused-empty` · `search-no-results` ·
  `search-results`.
- Each new component gets its own fixture states, matching its §3 state table.

## Testing
- **server:** integration tests for both routes. Cases:
  - range bounds inclusive; span 187 → 400;
  - events from an unmanaged group excluded; an inactive event excluded;
  - `localDate` for an event whose UTC date differs from its tz date;
  - all-day ordering; search ascending order and cursor continuity; `q` of 1 char → 400.
- **iphone:** unit tests for every `CalendarLayout` function. Cases:
  - Sep 2026 → 5 rows, first-row span starting Tue;
  - Oct 2026 first row spanning Thu–Sat;
  - 3 overlapping events → 3 columns;
  - week page from Wed Jul 29 → Wed Jul 22;
  - default anchor today vs other day;
  - overnight event split.
  Then capture every state above and compare against `frames/` by eye.
- **Cross-app E2E walk:** run the server with seeded events across 2 groups. Point the screen's
  source at the live endpoint through a debug toggle, then confirm a lesson event appears on the
  same day in the grid, the day view and search.
- **Human-verification script:** replay 01-video-analysis §2 row by row on device. Each row passes
  when the motion matches the reference's measured timing (§3) by eye:
  1. Flick the month.
  2. Tap a date (curtain).
  3. Scroll the hours.
  4. Swipe the strip (same weekday kept).
  5. Swipe days.
  6. Tap a strip date.
  7. Tap Back (reverse curtain).
  8. Flick a year ahead, then tap Today (instant jump).
  9. Search a nonsense word (No Results), then a real word (ascending list with Today).
  10. Tap ✕.

## Out of scope
- Event creation, event detail or edit, and RSVP: these are D6/D7 hooks only.
- Year view, week view, list mode and multi-day views.
- Web client and member experience.
- Wiring into `MainView` / replacing `MainCalendar.swift`: that happens at the UI 2.0 cutover.
- Drag-to-reschedule and long-press-to-create on the timeline.
- Calendar subscriptions and colour customisation.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | `mcp__d2m__get_component` fails on 2026-10-20 (`P2021: table public.Note does not exist`), so C-102 / C-105 / C-084 / C-034 were read from their built Swift views instead. | Before minting new rows, fix the d2m DB migration. build-time risk: first iphone task. |
| F2 | It is unconfirmed how `Event.date` is written: midnight UTC vs local midnight, for lesson events created in `enrollments.ts` Step 3 and for custom events. | The audit reads both writers and fixes the `localDate` derivation. build-time risk: server task 1. |
| F3 | Range performance across many groups is unmeasured. | `@@index([groupId, date])` already exists on `Event`. Verify with seeded data of 50 groups × 2 years that the query stays < 200 ms. |
| F4 | No motion tokens exist for spring or paging (`Token.Motion` has only 3 easeOut entries). | Use flagged literals now. Tokenizing them is a `/d2m-*` job, not a builder task. |
| F5 | `docs/ui2/README.md` still says Calendar "is NOT a 2.0 tab". C-084 (D51) since added a calendar tab. | This is stale text in a doc the `/ui2-*` / `/d2m-*` commands own. Report it; don't edit it here. |
| F6 | The design has no Figma source. The registry rows minted for the new components have no snapshot, so `/ui2-component-build` pixel-diffing cannot run. | Visual acceptance is the human walk against `frames/`. |
| F7 | Grid geometry assumes a 440 pt width (columns = width/7, fixed 69 pt rows). | Rows stay at 69 pt on all devices and columns scale. Check iPhone SE (375 pt) and 15 Pro (393 pt) in capture. |
