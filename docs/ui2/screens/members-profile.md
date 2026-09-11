# members-profile — Member detail

Platform: iphone · Status: specced · Specced: 2026-09-01

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3668-8120
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3668:8120` ("Member home", 440×2730)
- Frozen snapshot: `assets/members-profile.png` — captured 2026-09-01
- Component states verified against the component sheet (D9): Field set `3517:29304`,
  Metadta set `3518:29457`, Study Program Card v2 set `3502:28948`, Button set
  `3499:27547`, Search results set `3668:7440`, Header set (`3524:29584` family).

Owner scope statement (2026-09-01): **this is the member page that appears when tapping any
member anywhere in the app** — one screen, all entry points.

**Deviations (closed list):**
1. All values, names, dates, and photos are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The frame's trailing content area below the Engagement section is empty canvas, not a
   designed region.

Anything else that differs from the source is a defect.

## 2. Layout contract

A pushed detail page (no top nav / no tab chrome): status bar → PageHeader (C-040, 56pt:
back chevron left, member name centered, no right icons) → vertically scrolling content on
`color-layout-background`, inset `space-page-margin` (16):

1. **Identity block** — Avatar (C-038) 164pt circle, left-aligned, 16pt top → 32pt → name
   (SF Pro Bold ~24/32 white) over email (SF Pro Regular 14/20 `text/secondary`), 8pt gap.
2. **Quick stats** — 2×2 DetailPair (C-041) grid: cells 196×36, 16pt column gutter, 16pt
   row gap. Sample cells: Age / Role / Birthday / Joined.
3. Hairline (`color-layout-border`) with `space-section-gap` (32) above/below.
4. **Fields** — 8 stacked EditableFieldRow (C-042) rows, 74pt each, no separators between
   rows: Organization, Role, Phone number (Green indicator "Verified"), Email address
   (Red indicator "Unverified"), Birthday, Gender, Address, Emergency contact.
5. Hairline. **Activity** — C-020 SectionHeader (title + `text-link` accessory "Jump to
   today") → Day rail: DayActivityCard (C-025) ×N, 131×192, shared 1px borders, horizontal
   scroll (single rail — no column chart on this screen).
6. Hairline. **Membership** — C-020 (title + MetaPair "2 groups" + GlyphButton `add`) →
   ListResultRow (C-037) `type=Group + tags` rows, 96pt each.
7. Hairline. **Engagement** — C-020 (title + MetaPair "2 programs" + GlyphButton `add`) →
   StudyProgramCard (C-044) `state=Progress` rows, 96pt each.

## 3. Behavior contract

**States (closed list):**
- `loading` — header renders with the name when already known (came from a row tap),
  skeletons elsewhere.
- `populated` — as laid out; Membership/Engagement sections list ALL rows (no cap shown in
  source; counts in the headers).
- `partial` — any absent field value renders the EditableFieldRow with an empty value line
  (label persists); absent avatar → initials fallback (C-038); zero groups/programs → the
  section renders header-only with count "0".
- `error` — full-content inline error + retry below the header (header stays for back).

**Interactions:**
- Back (header) pops to the presenting screen.
- EditableFieldRow tap (chevron) → per-field edit flow — deferred (OQ-members-profile-1).
- Verified/Unverified indicator is display-only (the edit flow owns re-verification).
- "Jump to today" recenters the day rail to today (rail scrolls freely; most recent day
  trailing).
- Day rail second line = time of last activity that day (`text/secondary`); zero days
  render the dimmed zero state (C-025).
- Membership `add` → add-this-member-to-a-group picker — deferred (OQ-members-profile-2).
- ListResultRow tap → the group's screen — deferred until the groups-area frames arrive
  (OQ-members-profile-2).
- Engagement `add` → enroll/follow action — deferred (OQ-members-profile-2).
- StudyProgramCard tap — no affordance shown in source (no chevron): not tappable in v1.

**Motion:** standard push/pop chrome per the program's shell conventions (specced with the
shell suites); no bespoke motion on this screen.

## 4. Components

Closed list rendered: **C-020 SectionHeader** · **C-021 GlyphButton** (glyphs `back` in
C-040, `add` in section headers) · **C-022 MetaPair** · **C-024 SparkBarChart** (inside
C-025) · **C-025 DayActivityCard** (amended) · **C-037 ListResultRow** (amended; `type=
Group + tags`) · **C-038 Avatar** (amended; 164) · **C-040 PageHeader** (new) · **C-041
DetailPair** (new) · **C-042 EditableFieldRow** (new) · **C-043 MetaChip** (new) · **C-044
StudyProgramCard** (new).

### C-040 PageHeader (new)
**Contract relocated 2026-09-05** → `../design-system/components/C-040-page-header.md`
(full-set `/ui2-component` run on the owner-designated set `3313:7615`, which also records
the pushed-page presentation). This screen consumes `style=Two icons` with
`showTitle=true, showIcons=false` — back + centred member name, no right icons.

### C-041 DetailPair (new)
Label-over-value pair (sheet component `3499:27339`, single `Default` variant): label SF
Pro Regular 14 `text/secondary` over value SF Pro Regular 14 white, 8pt gap, left-aligned.
Grid-consumed at 196×36. Props: `label`, `value`.

### C-042 EditableFieldRow
**Contract relocated 2026-09-03** → `../design-system/components/C-042-editable-field-row.md`
(full six-state matrix incl. Tags/Age/Multiline + C-068 TagChip). This screen consumes
`Default` (×5), `Green indicator` ("Verified"), `Red indicator` ("Unverified") at 408pt
width; nothing else here changed.

### C-043 MetaChip (new)
Bordered chip (sheet set `3518:29457` "Metadta"): 24pt, 1px `color-white-20` border,
radius 4, padding 8×4, SF Pro Regular 14. Axes: `type` {Single (one white text), Key value
(label `color-white-50` + value white, 2pt gap)} × `state` {Default, Purple, Complete} ×
`align` {Left, Right}. **Consumed here:** Default/Single ("L. Keith"), Default/Key-value
("Joined Jul 3, 2025", "12 complete", "15 hours"), Complete/Key-value ("31 complete" —
`color-positive` treatment when a program is fully complete). `Purple` and `align=Right`
variants designed-unconsumed. Props: `type`, `state`, `value`, `label?`.

### C-044 StudyProgramCard (new)
Program row (sheet set `3502:28948` "Study Program Card v2"): **consumed variant
`state=Progress`**, 408×96, 16pt vertical padding: details column (title SF Pro Bold 14/20
white ellipsized → 2pt-thin progress line = Percentages `style=Thin, aligned=Left` (fill
#4deb4b, tracks completion %) → MetaChip row: "N complete" + "N hours") + trailing 64pt
image, radius 8. **Designed, unconsumed:** `Default` (284pt large card), `Condensed`
(120pt), `state4` (96pt) — future consumers (library/program screens) claim them. Props:
`title`, `progress: Double`, `completeCount`, `hoursLabel`, `imageURL`, `isComplete`
(drives MetaChip `Complete` state).

### Amendments to existing rows (dated 2026-09-01)
- **C-021 GlyphButton** — identified here as the sheet's Button set `3499:27547`; that
  identification is now the **contract** at
  `../design-system/components/C-021-glyph-button.md` (relocated 2026-09-07, with the full
  nine-glyph matrix, per-symbol node ids and exported vector assets). This screen consumes
  `back` via C-040. The designed-unconsumed list recorded here has since shrunk to **`send`
  and `search` only** — `export`/`settings` are consumed by C-040 → study-program-home and
  `calendar` by enrollment-home (2026-09-02); the contract's §3 is authoritative.
- **C-025 DayActivityCard** — the second caption line is consumer-defined `(text, color)`:
  home-dashboard = lesson count in `color-positive`; members-profile = last-activity time
  in `text/secondary`. Zero state unchanged. Props: `captionLine: (String, Color)` replaces
  `lessonsLabel`.
  **Superseded 2026-09-10** by `../design-system/components/C-025-day-activity-card.md`: the
  caption line is not consumer-defined colour but a designed 7-state axis on its own set,
  now **C-071 ValuePair**. This screen's two usages are its `Muted` (white over
  `color-text-secondary`) and `Nothing` (both lines `color-white-20`) states; the card is
  C-025 `state=Transparent` with C-070 DateBlock `Default`.
- **C-037 ListResultRow** (renamed from MemberRow; ID stable) — the Figma set `3668:7440`
  defines `type` {Member (80pt — members-home), Member + tags (84), Group (96), **Group +
  tags (96 — consumed here**: 64pt group image, title, MetaChip row, chevron), Group +
  tags + Cancel}. Member+tags / Group / Group+tags+Cancel designed-unconsumed.
- **C-038 Avatar** — designed sizes now 32/40/64/**164** (this screen's identity block).

## 5. Data & API

Reads: full member profile, member's groups (with leader + joined date), member-scoped
activity per day, member's program engagement. Writes: none on this screen (edit flows are
separate).

| Need | Endpoint | Status |
|---|---|---|
| Member core profile (name, email, phone+verified, birthday, gender, photo, org, role, joined) | `GET /api/members/{memberId}` (userSession — verified via makeready-api); `Member` model verified in `server/prisma/schema.prisma` | ✅ mostly exists. **API-GAP (additive schema + payload): `address`, `emergencyContact`, and `emailVerified` have no Member fields today** — plus whatever email-verification flow "Unverified→Verified" implies (flagged for the build suite; OQ-3) |
| Member's groups with leader name + joined date | `GET /api/members/{memberId}/groups` (verified) + `MembershipEvent` history exists | ✅ exists; audit confirms leader-name + joinedAt are in the payload (additive if not) |
| Per-day member activity (minutes + last-activity time) | `POST /api/analytics/query` — the layer is filterable by member (analytics spec goal §3) | ✅ layer exists; member-scoped registry metrics are additions (same expansion path as home-dashboard) |
| Program engagement rows (complete count, hours, % progress per enrolled program) | — | **API-GAP: per-member program-engagement assembly** — overlaps `docs/features/analytics/member-evaluation.md` (deferred Phase D); the build suite decides registry metrics vs an assembled endpoint |
| Quick-stat Age | computed client-side from `birthday` | ✅ |

## 6. Connections

- **Entry: universal** (owner) — tapping any member anywhere opens this screen. Current
  specced entries: members-home row tap. Every future spec that renders a member (group
  members, requests, search results…) adds its edge here.
- **Exits/overlays (all deferred, §8):** EditableFieldRow tap → per-field edit flow ·
  Membership add → group picker · Engagement add → enroll action · group row tap → group
  screen.

## 7. Legacy mapping

Replaces the legacy member-detail surface:

| Legacy element | Disposition |
|---|---|
| `Pages/Manage/Member/MemberProfilePage.swift` (full-bleed hero modal — see `parity-member-profile` memory: hero photo, circleBlur actions, InfoPanel values, CardGroup removed-state) | carried: members-profile (new anatomy — pushed page, not modal; hero → 164pt avatar; InfoPanel → DetailPair grid + EditableFieldRow list) |
| `Route.swift` member-profile modal case + respond/change-membership modal cases | profile case carried here as a push; respond/change-membership flows NOT on this screen — dispositioned with the groups-area specs (gap-analysis sweep 1) |
| Member edit affordances (phone verify via Twilio) | carried into the deferred per-field edit flows (OQ-1) |
| `Components/` member InfoPanel/CardGroup profile pieces | not reused; retire at cutover |

## 8. Open questions

| # | Question | Blocking? | Decides |
|---|---|---|---|
| OQ-members-profile-1 | ~~Per-field edit flows~~ **RESOLVED 2026-09-01** — each EditableFieldRow tap pushes a single-field edit screen per the `shared-edit-field` pattern spec (Figma section 3860:8218). Residual: phone/email verification-step UX → OQ-shared-edit-field-2 | No | — |
| OQ-members-profile-2 | Destinations for: Membership `add` (group picker), Engagement `add` (enroll action), group row tap (group screen) | No — edges recorded as deferred in screen-map | Owner (frames to come) |
| OQ-members-profile-3 | Email verification: the design shows Verified/Unverified for email, but no `emailVerified` field or email-verify flow exists server-side — confirm email verification is a real 2.0 feature (it becomes backend-suite scope) or the badge is phone-only | No for UI; gates the API-GAP's size | Owner |
| OQ-members-profile-4 | "Role" appears twice (quick-stat grid AND field list) — intentional duplication, or should one show something else? | No — built as designed until ruled | Owner |
