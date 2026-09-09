# UI 2.0 Component Registry

**The repo-wide component manifest for UI 2.0 — the exhaustive component universe**
(DECISIONS.md D6). Every visual element in every screen spec (`../screens/<id>.md`) resolves
to exactly one row here. Later, each `/build-spec` suite's `05`/`06` component manifest is a
**closed subset of these IDs** (plus suite-internal supporting units); the build may render
nothing outside the cited rows — needing an unlisted component is a spec defect resolved by a
dated row addition here + a spec amendment, never an inline invention (build-spec
REFERENCE.md §3 rule 7 / §3d).

## Rules

- **IDs are `C-###`, append-only, never reused.** A removed component keeps its row, struck
  through with a dated note.
- **Status** is one of:
  - `new` — does not exist; the defining screen spec carries its full prop/state contract.
  - `existing` — reuse as-is; the row names the legacy file (verified to exist).
  - `existing-modified` — reuse with a **closed change list** in the row; anything not listed
    stays as-is.
- **"Defined in"** anchors the screen spec section (or feature DECISIONS doc, or a
  `components/C-###-<name>.md` contract from a `/ui2-component` run — D10) that carries
  the component's full contract — the registry row is the index, not the contract.
- **"Consumed by"** grows as later screen specs reuse the row (`/ui2-screen` phase 2 appends).
- Check the **legacy candidate pool** before minting `new`:
  `iphone/MakeReady/Components/` (123 components; `CARD_ARCHITECTURE.md` for the card
  system) and `docs/ui/COMPONENT_INVENTORY.md` (web catalog derived from iOS). Those docs
  are reference, **not normative** for 2.0 — Figma is (DECISIONS.md D5).
- **The Figma component sheet** (node `3632:4502` in the design file) is where the owner
  parks all components — but it is **not wholly normative**: some entries exist only for
  Figma prototyping (DECISIONS.md D9). Consult it to enumerate a consumed component's
  designed states/variants; never bulk-absorb it into this registry.

## Naming & scoping rules (2026-09-02, owner-directed)

Every `/ui2-screen` run checks new AND consumed rows against these before finishing
(phase-2 exit checklist):

1. **Name the role, not the first consumer and not the Figma layer.** The Figma name
   (typos, collisions and all) lives only in the Figma-ref column; the registry name says
   what the component renders/does (`SectionHeader`, not "Title"; `MetaChip`, not
   "Metadta").
2. **Scope no narrower than the known consumer set.** When consumption outgrows a name
   (a "profile" row appearing on group screens), **rename in place** — ID stays stable, the
   row gains a dated "renamed from X" note, and every spec's prose is updated in the same
   run. Never mint a duplicate row to dodge a rename, and never leave a misleading name
   because renaming is work.
3. **No program prefixes** (`UI2…`) — this registry *is* the 2.0 namespace.
4. **Family suffixes mean something.** `-Chip` small rounded label/selector · `-Card`
   bordered content container · `-Row` full-width list/table row · `-Bar` linear
   value/progress element · `-Badge` state pill · `-Header` section/page heading ·
   `-Overlay` presented surface · `-Button` tappable control · `-Chart` data-series
   visualization (2026-09-03 owner ruling, C-024 run: every chart component ends
   `-Chart`; the qualifier names form/scale, `Spark-` = in-card miniature; C-029
   RadialDayClock retained as-is pending an owner call). Pick the suffix that matches
   the anatomy; qualify the noun enough that no two rows collide without a distinguishing
   qualifier (check the whole registry before minting).
5. **Renames propagate the same run:** grep `docs/ui2/` for the old name and update prose;
   `C-###` citations stay valid, which is why IDs never change.

*First full audit: 2026-09-02 (all 57 rows).* Six renames landed (C-019 TopNav, C-022
MetaPair, C-042 EditableFieldRow, C-052 DayChip, C-053 StatusBadge, C-055
CategoryBarTable — each row carries its dated note); reviewed and kept: C-031
EnrollmentStatusRow (note in row), C-039 ClearSearchButton (scoped to its only designed
context, C-034 composition), C-041 DetailPair / C-046 FieldGroup (sibling/distinction
notes added). The audit re-runs as a gap-analysis sweep when the registry is complete.

## Row format

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |

Platform: `ios` / `web` / `both`. Figma ref: node URL (+ id) or `no-figma`.

---

## Primitives

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-021 | GlyphButton | new | ios | set 3499:27547 (sheet, Button) | 9 designed glyphs: export/settings/back/add/send/arrow-forward/three-dots/search/calendar; purple tint; 44pt hit target. **2026-09-07 full-set run:** contract relocated to its own file; per-symbol node ids pinned, frozen snapshot `assets/C-021-glyph-button.png`, and all nine vectors exported to `assets/C-021-glyph-<glyph>.svg` (the first 2.0 glyph artwork on disk — until now the vectors existed only in Figma). Designed-unconsumed narrowed to `send` + `search`. New OQ-C-021-1 (pressed/disabled), OQ-C-021-2 (44pt hit target vs C-069's 40pt slot and C-040's 24pt box), OQ-C-021-3 (tint-neutral artwork). Consumed: add, arrow-forward, three-dots, back, export, settings, calendar (2026-09-02 enrollment-home) (2026-09-01 amendment: home's plus/arrowRight/ellipsis = add/arrow-forward/three-dots; study-program-home consumes export+settings via C-040 and flags an icon-swapped Add slot — OQ-study-program-home-2) | glyph, action | `design-system/components/C-021-glyph-button.md` (relocated 2026-09-07 from `screens/home-dashboard.md` §4 + `screens/members-profile.md` §4 amendment) | home-dashboard, members-profile (+C-040), study-program-home, enrollments-home (arrowRight), enrollment-home (calendar), C-069 (add, 2026-09-05 — in a 40pt slot vs this row's stated 44pt hit target: OQ-C-019-3), C-040 (back + export + settings at 24pt visual in a 56pt bar — same hit-target question, OQ-C-040-7) |
| C-052 | DayChip (renamed from DayCell 2026-09-02; ID stable — "cell" reserved for future calendar day cells) | new | ios | mains 3495:2777 / 3495:2787 (frame-local, not on sheet) | states Default (`color-white-20`) / Active (`color-accent`) — both designed; 32×40 r4, day number 14pt; further states undesigned (OQ-study-program-home-7) | day, state, onTap | `screens/study-program-home.md` §4 | study-program-home (day rail) |
| C-053 | StatusBadge (renamed from PublishStateBadge 2026-09-02; ID stable — generalized; state list stays closed) | new | ios | nodes 3524:29722 (frame-local, no sheet set) | `published` designed (green pill, black bold 12 @70%); `draft` = proposed default (OQ-study-program-home-4) | state | `screens/study-program-home.md` §4 | study-program-home (cover) |
| C-057 | PercentBar | new | ios | set 3526:30471 (sheet, Percentages) | style {Thick 16pt, Thin 2pt} × aligned {Right, Left} — all designed (Percent axis = sample fills). Formalizes the bar unit already cited inside C-031/C-044; Thick/Right consumed (C-031, C-054), Thin/Left consumed (C-044). Fill-green literal anomaly: OQ-home-dashboard-6 | progress, fillColor, style, aligned | `screens/study-program-home.md` §4 (C-031/C-044 contracts still bind their usage) | C-031, C-044, C-054, C-059 (Thin/Left) |
| C-062 | PercentDisc | new | ios | set 3822:34382 (sheet, Percent and size) | color AND size encode the band: Green 1 (80) / Green 2 / Yellow 1 (56, #ffb53e) / Yellow 2 / Red 1 (44) / size6; 20%-tint fill, number 14 + % 9. Consumed: Green 1, Yellow 1, Red 1; rest designed-unconsumed (OQ-enrollment-home-8); thresholds undesigned (OQ-enrollment-home-3). Fixed-size sibling: C-031 64pt circle | percent, band | `screens/enrollment-home.md` §4 | enrollment-home (C-025 Percent circle) |
| C-064 | DateSpanIndicator | new | ios | 3836:7920 (sheet, Text metadata) | single static variant: arrow glyphs + C-022 MetaPair ×2 ("n months", "n days"); interactivity undesigned (OQ-enrollment-home-5) | months, days | `screens/enrollment-home.md` §4 | enrollment-home (schedule span) |
| C-041 | DetailPair | new | ios | node 3499:27339 (sheet, Detail) | STACKED label-over-value, single Default variant (inline sibling: C-022 MetaPair) | label, value | `screens/members-profile.md` §4 | members-profile (2×2 grid), study-program-home (2×2 grid), enrollment-home (2×2 grid), invite-home (meta pairs + member block) |
| C-022 | MetaPair (renamed from MetaLabel 2026-09-02; ID stable) | new | ios | node 3673:12445 (in 3622:5487) | INLINE value(white)+label(secondary) 12pt pair (stacked sibling: C-041 DetailPair); study-program-home's frame renders value Bold + label White/50% — Figma drift, OQ-study-program-home-9 | value, label | `screens/home-dashboard.md` §4 | home-dashboard, study-program-home, enrollment-home (C-064 — renders Regular like home, evidence on OQ-study-program-home-9), C-030 (tick row ×4, 2026-09-03) |
| C-027 | LegendItem | new | ios | node 3673:12013 (in 3622:5487) | series dot + 12pt secondary label | color, label | `screens/home-dashboard.md` §4 | home-dashboard |
| C-038 | Avatar | new | ios | node 147:1513 (Avatar) | circular photo, sizes 32/40/54/64/164 (54 added 2026-09-02, invite-home linked-member block); initials fallback | imageURL, initials, size | `screens/members-home.md` §4 | members-home (C-037), members-profile (164), groups-home (C-037), study-program-home (C-054, 64), enrollments-home (C-058, 40), invite-home (54) |

## Forms & input

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-001 | MarkdownTextEditor | new | ios | no-figma | edit/read; title auto-style; list continue/escape | text, activeStyles, onEvent | `docs/features/notes/DECISIONS.md` §4b | notes editor |
| C-002 | FormatStrip | new | ios | no-figma | 5 controls, scrollable, keyboard-docked | activeStyles, onToggle, onListMenu | `docs/features/notes/DECISIONS.md` §4b | notes editor |
| C-003 | FormatStripButton | new | ios | no-figma | plain glyph ⇄ filled accent circle | glyph, isActive, action | `docs/features/notes/DECISIONS.md` §4b | C-002 |
| C-004 | ScrubTrack | new | ios | no-figma | drag = seek; elapsed/remaining labels | progress, elapsedLabel, remainingLabel | `docs/features/memo/DECISIONS.md` §4b | memo inline player |
| C-028 | InlineDropdown | new | ios | node 3676:12452 (in 3622:5487) | label + 14pt chevron; presents C-036 FilterMenuOverlay; closed option list per consumer | options, selected, onSelect | `screens/home-dashboard.md` §4 | home-dashboard (Sessions time range) |
| C-034 | SearchField | new | ios | set 3561:33795 (sheet, Search; owner-designated 2026-09-05 — **source corrected**: the previously cited `3561:33757` is a different glyph-less component, a duplicate of C-045's `Single` column, OQ-C-034-5); instance 3668:7387 | `state` {Default, Focus, Has value} — all 3 designed, single axis (2026-09-05 correction: the old "Default / Has value / Has value + Focus" list came from the wrong set). 12pt search glyph in ALL states; Default is the only FILLED state (`color-card-background`) — Focus and Has value are unfilled with a white border; Focus = empty+caret, Has value = value + C-039 clear (no caret). Only Default is consumed; valued-and-focused, error and disabled undesigned (OQ-C-034-1/-3) | text, placeholder, focused, onChange, onClear | `design-system/components/C-034-search-field.md` (relocated 2026-09-05 from members-home §4) | members-home, groups-home, enrollments-home (all `Default`) |
| C-039 | ClearSearchButton | new | ios | node 3561:33857 (sheet, Clear search; instanced as `3561:33861` inside C-034's Has value symbol) | 32pt clear glyph (14pt close vector, inset 9); single variant `Property 1=Default`; placed trailing-inset 7 / top 5 in a 44pt field — not optically centred (OQ-C-034-4) | action | `design-system/components/C-034-search-field.md` §5 (repointed 2026-09-05 from members-home §4) | C-034 (Has value) → members-home, groups-home, enrollments-home |
| C-035 | FilterChip | new | ios | node 3668:7390 (Fitler tags) | 24pt pill, leading chevron; label = current selection | label, onTap | `screens/members-home.md` §4 | members-home (×2), groups-home (×2), enrollments-home (×4) |
| C-045 | TextInput | new | ios | set 3524:30063 (sheet, Text input — 6 symbols; ref corrected 2026-09-03: 3547:31813 is inside this set) | state {Default, Has value, Has value+Focus} × lines {Single 44pt, Multi 88pt} — all designed; focus = overlay state (white border + 2×24 accent caret; set samples empty content — OQ-C-045-1); error/disabled undesigned (OQ-C-045-2) | text, placeholder, lines, focused | `design-system/components/C-045-text-input.md` (relocated 2026-09-03 from shared-edit-field §4) | shared-edit-field (C-046), create-study-program (C-046) |
| C-046 | FieldGroup | new | ios | set 3524:30092 (sheet) | Field {Text 70, Multiline 114} × style {Default, Focus} — all 4 designed; label constant, focus = inner C-045 state | label + C-045 pass-through | `screens/shared-edit-field.md` §4 | shared-edit-field, create-study-program (Text/Default) |
| C-047 | RadioOptionRow | new | ios | set 3770:6532 (sheet, Radio) | Default / Selected (glyph set 3770:6508); optional description (content-driven 54/100pt) | title, description, selected, onSelect | `screens/shared-edit-field.md` §4 | shared-edit-field |
| C-048 | PageActionButton | new | ios | sets 3517:29389 (Green/Red) + 3547:31761 (sheet, Page buton ×2 — hygiene flag) | disabled / affirmative (green) / destructive (red, designed-unconsumed); 2026-09-02 sheet re-probe: color set 3517:29389 now designs {Red, Green, White, Muted}; White (FILLED white, black 12 label) consumed 2026-09-03 by C-066 "Done"; Muted designed-unconsumed | label, state, action | `screens/shared-edit-field.md` §4 | shared-edit-field, C-066 (White), create-study-program ("Create") |
| C-049 | LinkButton | new | ios | set 3525:30224 (sheet, Link button) | single style: purple semibold 14 + 0.5px underline; home "Jump to today" renders secondary — OQ-shared-edit-field-4 | label, action | `screens/shared-edit-field.md` §4 | shared-edit-field (C-051), home-dashboard (C-020 text-link) |
| C-050 | SuggestionRow | new | ios | set 3526:30792 (sheet, Suggestion) | single Default; 56pt text + C-021 add | title, onAdd | `screens/shared-edit-field.md` §4 | shared-edit-field (C-051) |
| C-051 | AISuggestionsBlock | new | ios | frames in 3860:8218; spinner = sheet 3526:30644 (Donut) | 3-state machine: prompt / generating / list (≤3 C-050) | state, promptCopy, suggestions, onGenerate, onPick | `screens/shared-edit-field.md` §4 | shared-edit-field |

## Cards & rows

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-005 | NoteListRow | new | ios | no-figma | 3-line layout (title / date+preview / context) | title, preview, dateLabel, contextLabel, onTap | `docs/features/notes/DECISIONS.md` §4b | notes list |
| C-006 | MemoListRow | new | ios | no-figma | collapsed / expanded-in-place | title, dateLabel, durationLabel, hasTranscript, isExpanded, onTap | `docs/features/memo/DECISIONS.md` §4b | memo list |
| C-007 | MemoInlineRowPlayer | new | ios | no-figma | playing/paused; scrub; ±15s | memoId, playback, transport callbacks | `docs/features/memo/DECISIONS.md` §4b | C-006 (expanded) |
| C-023 | KpiCard | new | ios | node 3673:12248 (KPI v2) | 140×192 r4; title/sparkline/value/±% (green up, red down); annotation semantic corrected 2026-09-03: average line, not max | title, series, averageLabel (renamed from maxAnnotation 2026-09-03), value, change | `screens/home-dashboard.md` §4 | home-dashboard (Overview rail) |
| C-025 | DayActivityCard | new | ios | node 3673:12007 (Day) | 131×192, shared L/R borders; populated / zero-dimmed; caption line consumer-defined (home: lessons `color-positive`; profile: last-active time `text/secondary`). 2026-09-02 amendment (enrollment-home): sheet states body `Percent circle` (centers C-062), Date `Today` (`color-highlight` marker), Activity details `Lesson day` (count accent + time) move to consumed | date, series, minutesLabel, captionLine, isZero | `screens/home-dashboard.md` §4 (+ members-profile amendment, + enrollment-home amendment) | home-dashboard, members-profile, enrollment-home (Percent circle rail) |
| C-031 | EnrollmentStatusRow | new | ios | node 3622:5617; sheet set 3526:30288 (single state=Default); bar = C-057 | 64pt row: % circle (20% tint) + C-057 PercentBar (Thick/Right) + subtitle. Name reviewed 2026-09-02 audit and KEPT: both consumers (home engagement, program members-current) are enrollment-derived aggregates | percent, label, count, progress, subtitle, statusColor | `screens/home-dashboard.md` §4 | home-dashboard (Engagement), study-program-home (Group Activity) |
| C-054 | GroupEnrollmentCard | new | ios | set 3526:30373 (sheet, Group card) | status {Default, Progress} — Progress consumed (88pt: C-038 64 + title + %-complete line w/ C-057 Thick/Right + C-043 chips); Default designed-unconsumed (OQ-study-program-home-5); completion color banding undesigned (same OQ) | groupName, photoURL, completionPercent, statusColor, enrolledLabel, memberCount, onTap | `screens/study-program-home.md` §4 | study-program-home (Recent activity) |
| C-059 | EnrollmentProgressRow | new | ios | main 3823:35035 area (frame-local, single variant) | 96pt: program title + C-057 Thin/Left (status-color fill; 3 observed band literals incl. NEW yellow #e3eb4b — OQ-enrollments-home-3) + enrolled-date meta + 64×64 r8 cover thumb; parallels C-044 state=Progress (consolidation = owner call). NOT C-031 (that row is the aggregate percent-circle summary; this is one enrollment's progress) | programTitle, progress, statusColor, enrolledLabel, coverURL, onTap | `screens/enrollments-home.md` §4 | enrollments-home |
| C-065 | TimelineEventRow | new | ios | set 3526:30939 (sheet, History) + line 3526:31009 | single designed state; contracted tone {default, positive} (dot glyph + optional `color-positive` text span); 36/56pt content-driven; connector line is consumer layout; further tones undesigned (OQ-invite-home-3/5) | dateLabel, text(+highlight range), tone | `screens/invite-home.md` §4 | invite-home (Invitation timeline) |
| C-060 | CalendarDateCard | new | ios | 3836:7851 (sheet, Calendar date) | single state=Default: 96×88 r8 card bg/border; month Bold12 `color-negative` + weekday secondary over hairline; date Regular 40 (month-red semantics: OQ-enrollment-home-6) | month, weekday, date | `screens/enrollment-home.md` §4 | enrollment-home (schedule span ×2) |
| C-063 | LessonCard | new | ios | frame-local 3821:33713… | title row (number `color-accent` + title + relative-date meta) × {plain, withProgress (2pt bar, track `color-white-20` — drift vs C-057, OQ-enrollment-home-4)} + C-061 slide rail; completed/locked undesigned (OQ-8) | lessonNumber, title, dateLabel, progress?, slides, onOpen | `screens/enrollment-home.md` §4 | enrollment-home (×3) |
| C-033 | GroupFollowCard | new | ios | node 3622:5628 (Group) | 179×228 r8; linked/unlinked glyph; completion color bands (OQ-home-dashboard-3) | name, photoURL, memberCount, completionPercent, isLinked, onTap | `screens/home-dashboard.md` §4 | home-dashboard (Following rails) |
| C-037 | ListResultRow (renamed from MemberRow 2026-09-01; ID stable) | new | ios | set 3668:7440 (sheet, Search results) | type {Member 80pt (members-home) / Member+tags 84 / Group 96 / Group+tags 96 (members-profile) / Group+tags+Cancel / **Group+status 96 (2026-09-02, invite-home: status C-043 chip + optional 18pt chevron — set symbols 3832:313xx)**} — Member+tags, Group, Group+tags+Cancel designed-unconsumed | per type: avatar/image, title, meta or MetaChip row, trailing count/chevron | `screens/members-home.md` §4 + `screens/members-profile.md` §4 | members-home, members-profile, groups-home (Group+tags), invite-home (Group+status) |
| C-042 | EditableFieldRow (renamed from ProfileField 2026-09-02; ID stable — consumption outgrew "profile": group/program/member home hosts) | new | ios | set 3517:29304 (sheet, Field) | one `state` axis, 6 designed: Default / Green indicator / Red indicator (consumed, members-profile) / Tags (C-068 chips) / Age (zero-delta exemplar, OQ-C-042-1) / Multiline — full matrix in the contract file (2026-09-03); tap → `shared-edit-field` instantiation | label, value?, tags?, indicator?, multiline, onTap | `design-system/components/C-042-editable-field-row.md` (relocated 2026-09-03 from members-profile §4) + `screens/shared-edit-field.md` (behavior) | members-profile (×8) + every future field host |
| C-043 | MetaChip | new | ios | set 3518:29457 (sheet, Metadta) | 24pt bordered chip; type {Single, Key value} × state {Default, Purple, Complete} × align {L, R}; align=Right consumed 2026-09-01 (study-program-home C-054 "Enrolled «date»"); Complete×KeyValue×Right consumed 2026-09-02 (invite-home "Accepted «date»", sheet symbol 3832:31341); Purple still designed-unconsumed | type, state, value, label | `screens/members-profile.md` §4 | members-profile (C-037 Group+tags, C-044), groups-home (C-037), study-program-home (C-054), invite-home (C-037 Group+status) |
| C-068 | TagChip | new | ios | set 3526:30837 (sheet, Tag) | style {Default (filled `color-white-20`, r16, px8 py4, label 12/14 `color-white-70`), Solid (designed-unconsumed)} | label | `design-system/components/C-042-editable-field-row.md` §5 | C-042 (Tags state) |
| C-044 | StudyProgramCard | new | ios | set 3502:28948 (sheet, Study Program Card v2) | state=Progress consumed (96pt: title + Percentages Thin/Left + MetaChips + image r8); Default 284 / Condensed 120 / state4 designed-unconsumed | title, progress, completeCount, hoursLabel, imageURL, isComplete | `screens/members-profile.md` §4 | members-profile (Engagement) |

## Navigation & chrome

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-008 | NotesBottomBar | new | ios | no-figma | floating search capsule + compose circle | searchText, onCompose | `docs/features/notes/DECISIONS.md` §4b | notes list |
| C-009 | EditorNavChrome | new | ios | no-figma | back · undo (conditional) · Done (edit mode) | canUndo, onBack, onUndo, onDone | `docs/features/notes/DECISIONS.md` §4b | notes editor |
| C-019 | TopNav (renamed from UI2TopNav 2026-09-02; ID stable) | new | ios | set 3555:32772 (Top navigation; owner-designated 2026-09-05 — node 3622:5499 is a home-frame instance, frame 3556:33191 is a per-page instance sheet) | `state` {Default=collapsed 32pt label row (consumed), Expanded=96pt card row (designed-unconsumed)}; closed 8-tab set Home·Library·Groups·Members·Enrollments·Invites·Programs·Media (2026-09-05 — resolves OQ-home-dashboard-7 + OQ-enrollments-home-4); morph/gesture/switch behavior stays owned by the Nav.MP4 analysis; add action is PER-TAB (owner 2026-09-05 — Library's list closed at Record video/audio/note, Home has none); pressed/disabled + morph intermediates undesigned (OQ-C-019-4/5) | tabs, selectedTab, expansion 0→1, scrollOffset, onSelect, onToggleExpansion, onAdd | `design-system/components/C-019-top-nav.md` (2026-09-05; behavior source `docs/features/navigation/01-account-switcher-analysis.md`; shell placement → shell-topnav) | home-dashboard, members-home, groups-home, enrollments-home (all collapsed) |
| C-069 | NavTabButton | new | ios | set 3555:32733 (Top nav button; owner-designated 2026-09-05) | `state` {Collapsed, Expanded} × `active` {false, true} — all 4 designed. Collapsed: p8, label `type-nav-label`, active delta is COLOR ONLY (`color-nav-text` → `color-text-primary`; no pill/underline/weight change). Expanded: 124×96 r8 p16, border `color-nav-border` → active `color-nav-border-active` + `color-nav-tab-background` fill; 40pt add slot bottom-right (C-021 `add`, hidden on Home in the row — OQ-C-019-2) | label, presentation, active, addAction? | `design-system/components/C-019-top-nav.md` §2b | C-019 (×8) |
| C-020 | SectionHeader | new | ios | node 3636:5051 (Title) | accessory: meta-button / text-link / dropdown / text-link+button (2026-09-02, enrollment-home) / none; size {section 18/24 Semibold 24pt, subsection 14/20 Semibold 20pt} (2026-09-01 amendment, measured on study-program-home; supersedes home's "~16 Bold" approximation — OQ-study-program-home-9) | title, accessory, size | `screens/home-dashboard.md` §4 + `screens/study-program-home.md` §4 amendment | home-dashboard (×5), study-program-home (×3 + subsection), enrollment-home (Schedule), invite-home (×2, accessory none) |
| C-032 | FollowedProgramHeader | new | ios | node 3622:5797 (in 3622:5487) | title + author·created meta + ellipsis | title, author, createdLabel, onMenu | `screens/home-dashboard.md` §4 | home-dashboard (Following) |
| C-040 | PageHeader | new | ios | set 3313:7615 (sheet, Header; owner-designated 2026-09-05 — symbol 3524:29584 is the `Two icons` member of this set) | 56pt transparent bar for a PUSHED page (owner 2026-09-05: these pages slide in from the trailing edge over the caller; mutually exclusive with C-019). `style` {Default, Text buttons, Two icons} × booleans `showTitle` / `showIcons` = 8 designed combinations; only two are consumed — Two icons+title+icons (study-program-home) and Two icons+title, icons off (the other five). 2026-09-05 finding: `showIcons` does NOT gate `Default`'s settings icon, which is why plain back+title consumers use `Two icons`+`showIcons=false` (OQ-C-040-1). Scroll/elevated, long-title and pressed states undesigned | style, title, showTitle, showIcons, rightButtons, onBack, onExport/onSettings, onCancel/onDone | `design-system/components/C-040-page-header.md` (relocated 2026-09-05 from members-profile §4 + study-program-home §4 amendment) | members-profile, study-program-home (icons on), shared-edit-field, enrollment-home, invite-home, create-study-program (all others: Two icons + showIcons=false) |
| C-058 | GroupSectionHeader | new | ios | nodes 3823:34882… (frame-local, no set) | single state: 42pt — C-038 Avatar 40 + group name over leader name (White/50%) + C-021 arrowRight; distinct from C-032 (program title + created meta + ellipsis) | groupName, leaderName, photoURL, onOpen | `screens/enrollments-home.md` §4 | enrollments-home |

## Display

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-010 | NoteSectionHeader | new | ios | no-figma | flush-left date-section label | title | `docs/features/notes/DECISIONS.md` §4b | notes list |
| C-011 | LiveWaveformView | new | ios | no-figma | right-anchored live bars, ~20 Hz | samples, style | `docs/features/memo/DECISIONS.md` §4b | recorder sheet |
| C-012 | PlayheadWaveformView | new | ios | no-figma | center playhead + tick ruler | samples, elapsed | `docs/features/memo/DECISIONS.md` §4b | recorder sheet |
| C-024 | SparkBarChart (renamed from MiniBarSparkline 2026-09-03; ID stable — owner naming ruling: charts end -Chart, Spark- = in-card miniature) | new | ios | set 3672:9689 (sheet, mini day chart; owner-designated 2026-09-03) | align {center consumed (C-025), bottom consumed (C-023), top owner-required undesigned (OQ-C-024-1)} × designed No-activity zero state (all 2pt dots); dashed annotation = series AVERAGE + label (corrected from "max" 2026-09-03), side left/right (left undesigned, OQ-C-024-4); owner capabilities: container-fill sizing, targetBars aggregation (OQ-C-024-2), width-fill modes (OQ-C-024-3) | series, targetBars, align, widthFill, showAverage, averageLabel, averageLabelSide | `design-system/components/C-024-spark-bar-chart.md` (relocated 2026-09-03 from home-dashboard §4) | C-023, C-025 |
| C-026 | DualSeriesBarChart | new | ios | set 3633:4505 (Bar chart; owner-designated 2026-09-03 — home's frame node 3673:12011 is a state=Today instance) | state {Default, Today}: Today consumed (solid `color-highlight` today rule + label; future columns track-only); Default designed-unconsumed (fully-past window). 2026-09-03 set corrections vs home §4: high gridline `color-highlight`, low `color-white-50` (both 0.5pt dash-2/2), today rule solid not dashed. Empty window / today-fill / pan-badge semantics undesigned (OQ-C-026-1..3) | days, window, onPan (state derived: today ∈ window) | `design-system/components/C-026-dual-series-bar-chart.md` (relocated 2026-09-03 from home-dashboard §4) | home-dashboard (Activity) |
| C-029 | RadialDayClock | new | ios | frame 3634:4871 (Time chart; owner-designated 2026-09-03 — a plain frame, no variant axes; home's chart node 3636:5161 is a sibling copy) | single designed rendering consumed; 280pt ring (`color-white-10` base, 10pt) + arcs in THREE purple opacity bands 100/50/20 encoding concentration + 24 ticks `color-white-20` + 8 Inter Bold 12 `text/navigation` labels + Inter center key value (2026-09-03 corrections vs home §4: Inter not SF Pro, value Regular 24, caption Bold 18). Banding/empty/quantization undesigned (OQ-C-029-1..3) | hourValues, centerValue, centerUnit, centerCaption | `design-system/components/C-029-radial-day-clock.md` (relocated 2026-09-03 from home-dashboard §4) | home-dashboard (Sessions) |
| C-030 | TimeActivityChart (renamed from GradientHistogram 2026-09-03; ID stable — owner axis ruling: x = time within a fixed non-panning period, not a session-length distribution) | new | ios | main 3636:6337 (Week completions; owner-designated 2026-09-03 — home's chart node 3636:6548 is its instance) | single style=Default consumed; 88 mask bars (3px r1.5, 2px gap) over red→`color-accent`→`color-positive` gradient (red stop literal #ff4759, OQ-C-030-3); ticks = C-022 ×4 (sample "mins" labels — real 24-hr labeling OQ-C-030-2); empty state undesigned (OQ-C-030-1) | bins, tickLabels | `design-system/components/C-030-time-activity-chart.md` (relocated 2026-09-03 from home-dashboard §4) | home-dashboard (Sessions) |
| C-055 | CategoryBarTable (renamed from DemographicsBarTable 2026-09-02; ID stable — generic role; age bins are consumer content) | new | ios | nodes 3524:29777… (frame-local, no sheet set) | single populated design: column-label row + 5 closed age bins (label 100pt / right-aligned 16pt bar ∝ %completion / count 100pt); bar palette = flagged per-screen literals (OQ-study-program-home-6); zero-data undesigned (OQ-7) | rows [(binLabel, percent, lessonsLabel)] | `screens/study-program-home.md` §4 | study-program-home (Demographics) |

## Buttons

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-013 | RecordButton | new | ios | no-figma | enabled/disabled; 56pt red circle | isEnabled, action | `docs/features/memo/DECISIONS.md` §4b | memo list |
| C-014 | TransportControls | new | ios | no-figma | play/pause + skip ±15 | isPlaying, transport callbacks | `docs/features/memo/DECISIONS.md` §4b | C-007 |

## Overlays

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-015 | ListStyleMenu | new | ios | no-figma | two-row popover (Bulleted/Numbered) | onSelect | `docs/features/notes/DECISIONS.md` §4b | notes editor |
| C-016 | RecorderSheet | new | ios | no-figma | two-detent, undimmed, finger-tracked | detent, session | `docs/features/memo/DECISIONS.md` §4b | memo list |
| C-017 | RecorderCompactView | new | ios | no-figma | title · timer · live waveform · stop | title, elapsed, samples, onStop | `docs/features/memo/DECISIONS.md` §4b | C-016 |
| C-018 | RecorderExpandedView | new | ios | no-figma | editable title · playhead waveform · pause/Done | title, elapsed, samples, isPaused, callbacks | `docs/features/memo/DECISIONS.md` §4b | C-016 |
| C-036 | FilterMenuOverlay | new | ios | behavior: Filter.MP4 (see members-home §1); visual: program tokens, plain-label variant | full-screen dim + fixed X; single-select; motion-menu-fade in/out ≈300/250ms crossfade, no slide | options, selectedId, onSelect, onClose | `screens/members-home.md` §4 | members-home (both chips), groups-home (both chips), C-028, enrollments-home (all 4 chips) |
| C-066 | ActionMenuOverlay | new | ios | node 3883:9315 (lone component; not on the 2026-09-01 sheet dump — owner-designated per D10) | single designed variant: `color-modal-background` r16 p24, C-067 rows w/ hairlines + C-048 White "Done"; presentation chrome undesigned (OQ-C-066-1: proposed dim scrim + motion-menu-fade per C-036 precedent) | actions, onSelect, onDone | `design-system/components/C-066-action-menu-overlay.md` | (none yet — anticipated: invite-home actions, general action-sheet chrome) |
| C-067 | ActionMenuRow | new | ios | main 3832:31480 (Action button, single Default) | 56pt: 24pt glyph content-slot + `type-action-item` 18/24 label + chevron-right; pressed/disabled/destructive undesigned (OQ-C-066-2/3) | glyph, label, onTap | `design-system/components/C-066-action-menu-overlay.md` §2 | C-066 |

## Media

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|

## Activities

*Rows minted when `activities-player` / `activities-editor` are specced — the pager, dot
rail, page backgrounds, action buttons, completion checkmark, floating exegesis note card
(`docs/features/activities/03-proposed-architecture.md` et al. are the doc sources).*

| ID | Name | Status | Platform | Figma ref | Variants / states | Props (summary) | Defined in | Consumed by |
|---|---|---|---|---|---|---|---|---|
| C-056 | ActivityThumbnail | new | ios | nodes 3524:29763–65 (frame-local) | populated image card only (140×249 r8, elevation-thumbnail); non-video thumbnail source + fallback undesigned (OQ-study-program-home-8); activities-editor/player specs may extend; **consolidation flag with C-061 ActivitySlide** (OQ-enrollment-home-2) | imageURL, onTap | `screens/study-program-home.md` §4 | study-program-home (activities strip) |
| C-061 | ActivitySlide | new | ios | set 3312:1429 (sheet, Slide) | state {Empty, Add, Fill, Incomplete} × active {false, true} — 7 designed; consumed Fill/inactive (112×244, inner r8, bg #2e2e2e literal); rest reserved for `activities-editor` (OQ-enrollment-home-8). **Consolidation flag with C-056** (same role, different geometry — OQ-enrollment-home-2) | state, active, imageURL?, onTap | `screens/enrollment-home.md` §4 | enrollment-home (C-063 rails) |

---

*Absorbed provenance note: C-001…C-018 come from the notes and memo feature suites'
normative §4b component manifests (2026-08-31). Those DECISIONS.md files remain
authoritative for behavior; the registry unifies the inventory. Their supporting non-UI
units (codecs, controllers, Actions, models) stay in their §4b tables — the registry tracks
UI units only.*
