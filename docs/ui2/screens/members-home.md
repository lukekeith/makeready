# members-home — Members (leader directory)

Platform: iphone · Status: specced · Specced: 2026-09-01

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3668-6801
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3668:6801` ("Members", 440×1892)
- Frozen snapshot: `assets/members-home.png` — captured 2026-09-01
- **Behavioral source for the filter menus:** `/Users/lukekeith/MakeReady/Filter.MP4`
  (1320×2868 @ 60fps, 9.55s — Robinhood prediction-markets filter, provided by the owner
  2026-09-01 as the normative filter-menu behavior). Timestamped outline (sampled at 4fps
  ±0.3s; **bold** ranges re-measured at 20fps ±0.05s):

  | t-range | Demonstrated |
  |---|---|
  | 0.0–0.9s | Page at rest; "Live ∨" filter chip below header |
  | **1.00–1.25s** | **Menu OPEN: pure crossfade ≈250–300ms — option list + bottom X fade in at fixed positions while page content dims to near-black; page header fades out; status bar persists; no slide/scale** |
  | 1.3–2.0s | Menu at rest: scrollable option list (icon + label rows), selected row bold, X floating bottom-center |
  | 2.0–3.8s | User scrolls the option list to the bottom (list scrolls under the fixed X) |
  | 4.0–4.8s | Scrolls back to top |
  | **5.10–5.35s** | **Menu CLOSE (X tap): reverse crossfade ≈250ms — menu fades out, page fades back; selection unchanged** |
  | 6.0–9.5s | Page at rest; user scrolls the page itself (verifies page is restored fully interactive) |

**Deviations (closed list):**
1. All values, names, dates, counts, and photos in the frame are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The nav row follows the `shell-topnav`/`shell-tabs` specs; this frame (Members active) is evidence only.
4. From the video reference, only the filter-menu **behavior** is normative (open/close choreography, dimmed full-screen list, fixed X, scroll, single-select); its visual chrome (icons, Robinhood styling, "Live/15 min" options) is not — MakeReady's menu renders plain labels per the owner decision (§3) and program tokens.

Anything else that differs from the source is a defect.

## 2. Layout contract

Page: vertical scroll on `color-layout-background`; content inset `space-page-margin` (16).
Status bar → collapsed nav (C-019, Members active) → header block → member list.

- **Header** (fixed content, 116pt): 16pt top inset → SearchField (C-034) 408×44 → 16pt →
  chip row: FilterChip (C-035) ×2 — "∨ All Groups", "∨ All Leaders" — 24pt tall, 8pt gap,
  left-aligned.
- **List**: full-width rows inset 16; MemberRow (C-037) 80pt each; 1px `color-layout-border`
  hairline between rows (flush with the 408pt content width, none above the first or below
  the last).

## 3. Behavior contract

**States (closed list):**
- `loading` — header renders immediately; list shows row skeletons.
- `populated` — rows sorted per §5 (default: most recent join first, matching the sample's
  "Joined …" prominence).
- `empty` — no members match the search + filters: an empty message in the list area;
  header stays interactive.
- `error` — inline list-area error with retry; header stays.

**Search:** typing in C-034 filters the list live (debounced ≥300ms, min 0 chars —
clearing restores the unfiltered list). Search combines AND-wise with both chip filters.

**Filter chips + menu (owner decisions 2026-09-01, behavior per Filter.MP4):**
- Each chip shows its current selection ("All Groups" / "All Leaders" defaults; a chosen
  option replaces the label, e.g. "Young professionals ∨").
- Tap a chip → **FilterMenuOverlay (C-036)** opens with the open choreography from §1's
  outline: ≈300ms crossfade (`motion-menu-fade-in`), page dims beneath, option list +
  X-close fade in at fixed positions.
- Options are **single-select, plain text labels** (owner decision): Groups menu = "All
  Groups" + every group of the leader's org the caller can see; Leaders menu = "All
  Leaders" + each leader in the org (filters members to that leader's groups — primarily
  useful to owners/admins). Selected row renders bold white; others `text/secondary`.
  The list scrolls under the fixed X when it overflows.
- Selecting an option applies the filter immediately, closes the menu with the ≈250ms
  reverse crossfade (`motion-menu-fade-out`), and updates the chip label. X closes with
  no change. There is no tap-outside dismissal surface — the menu is full-screen.
- The two chip filters and search compose (AND).

**Row interactions:** tap a MemberRow → the member screen (`members-profile`, Figma to be
provided — queued). No swipe actions on rows in v1.

**Motion:** `motion-menu-fade-in` ≈300ms / `motion-menu-fade-out` ≈250ms (measured from
Filter.MP4 at 20fps; curve reads as ease-out both ways). No other bespoke motion.

## 4. Components

Closed list of registry IDs rendered: **C-019 TopNav** (collapsed, Members active) ·
**C-034 SearchField** · **C-035 FilterChip** · **C-036 FilterMenuOverlay** · **C-037
MemberRow** · **C-038 Avatar**.

Contracts for rows this screen introduces (all `(new)`; measured from node `3668:6801` +
Filter.MP4, 2026-09-01):

### C-034 SearchField
**Contract relocated 2026-09-05** → `../design-system/components/C-034-search-field.md`
(full-set `/ui2-component` run on the owner-designated set `3561:33795`). That run also
**corrected the normative source**: the set cited here on 2026-09-01 (`3561:33757`) is a
different, glyph-less component, so the state coverage written here was measured off the
wrong node. This screen consumes `state=Default`, 408×44, placeholder "Search members";
its search *behavior* stays specced in §3 above.

### C-035 FilterChip
24pt-tall pill: 1px `color-neutral-600` border, radius 8, horizontal padding 8, 4pt gap;
**leading** 16pt chevron-down, then label SF Pro Bold 14/22 `text/navigation` (#8d9fa7).
Label = current selection. States: `default` (as measured) and `pressed` (standard
highlight); no distinct "filtered" treatment is in the source — a filtered chip simply
shows the chosen option's name. Props: `label: String`, `onTap`.

### C-036 FilterMenuOverlay
Full-screen single-select option menu, behavior normative from Filter.MP4 (§1 outline):
- **Chrome:** no card/sheet — the presenting page dims to ≈95% `color-layout-background`
  behind a vertically scrolling option list; the page header fades out entirely; the
  system status bar persists. Floating close button: white circle ~44pt with dark ✕,
  fixed bottom-center, safe-area-inset above the home indicator; list content scrolls
  beneath it.
- **Rows:** plain text labels (this program's variant — no icons), left-aligned at the
  page margin, ~48pt row height; selected row SF Pro Bold, `color-text-primary`; unselected
  SF Pro Regular, `color-text-secondary`.
- **Open:** `motion-menu-fade-in` ≈300ms crossfade — list + X fade in at their final fixed
  positions (no slide, no scale) while the page dims. **Close:** `motion-menu-fade-out`
  ≈250ms exact reverse; triggered by X (no change) or by selecting a row (applies then
  closes). No tap-outside dismissal.
- Presented via the program's typed overlay/route system (chrome registered once; the
  route mechanics land with the shell suites).
- Props: `options: [Option]` (closed list from the consumer), `selectedId`,
  `onSelect(Option)`, `onClose`.
- Consumers to date: both chips here; **C-028 InlineDropdown** (home-dashboard Sessions
  time-range) presents this same overlay — this component is the "option menu chrome"
  C-028's contract anticipated.

### C-037 MemberRow
80pt row (16pt vertical padding around 48pt content), 16pt gaps: Avatar (C-038, 32pt) →
info column (8pt gap): name SF Pro Bold 14/20 `color-text-primary`, single line ellipsized;
"Joined <label>" SF Pro Regular 14/20 `color-white-50` (relative for recent, absolute date
older — exact formatting per program date convention, sample shows both) → trailing:
group-count SF Pro Regular 14/20 `color-accent` (count of the leader's-org groups the
member belongs to; **hidden when 0** — evidence: rows show 2/1/3/—/3 and the 1 renders) →
18pt chevron-right glyph. Props: `name`, `avatar`, `joinedLabel`, `groupCount: Int`
(hidden at 0), `onTap`.

### C-038 Avatar
Circular member/person image primitive: sizes 32 (this screen), 40, 64; photo fill, or
initials fallback on `color-card-background` when no photo (program convention). Props:
`imageURL: URL?`, `initials: String`, `size`.

## 5. Data & API

Reads: the org's member directory with search + group + leader filtering and per-member
group counts; the groups and leaders option lists. Writes: none.

| Need | Endpoint | Status |
|---|---|---|
| Member list (name, avatar, joinedAt, per-member group count) | `GET /api/organizations/{organizationId}/members` (verified via makeready-api) | ✅ exists; **probable additive extension**: search `q`, `groupId`/`leaderId` filter params, and a per-member `groupCount` in one payload — the audit verifies the current response shape; anything missing is an additive param/field, flagged **API-GAP (additive)** for the build suite |
| Groups menu options | `GET /api/groups` — "List user's groups" (verified) | ✅ exists |
| Leaders menu options | `GET /api/group-leaders` — org leaders with content counts (verified) | ✅ exists |
| Member screen on row tap | `GET /api/members/{memberId}` / `{memberId}/profile` (verified) | ✅ exists — consumed by `members-profile`, not this screen |

RBAC note for the build suite: the leader-filter is only meaningful when the caller can see
beyond their own groups (owner/admin); the endpoint must scope rows per the caller's org
role (see the `group-leader-org-authorization` known issue — canManageOrgContent).

## 6. Connections

- **Entry:** `shell-tabs` → members-home (Members tab — this frame confirms Members as a
  top-level tab, OQ-home-dashboard-7's evidence).
- **Overlays:** chip tap → FilterMenuOverlay (component-level overlay, not a screen).
- **Exit:** MemberRow tap → `members-profile` (pending Figma, queued).

## 7. Legacy mapping

The legacy iPhone has no org-wide member directory tab; member lists live inside groups:

| Legacy element | Disposition |
|---|---|
| `Pages/Manage/Member/MemberHomePage.swift` (groups-tab member views) | partially carried: members-home is the new org-wide directory; group-scoped member lists remain `groups-home`-family scope — disposition finalized in gap-analysis sweep 2 |
| `Pages/Manage/Member/*` (7 files: member profile, requests, respond, change-membership flows) | not this screen — profile goes to `members-profile`; requests/respond flows to the groups area; gap-analysis sweep 2 dispositions each file |
| `Route.swift` member cases (member profile / respond / change-membership / confirmations) | not consumed here; carried by `members-profile` + groups-family specs |
| Legacy `Components/Card/CardMember` and `MemberListItem` | not reused (different row anatomy); retire at cutover |

## 8. Open questions

| # | Question | Blocking? | Decides |
|---|---|---|---|
| OQ-members-home-1 | "Joined" label formatting: the sample shows relative ("3 months ago") and absolute ("Jan 5, 2025") — the cutover rule (e.g. relative <30 days, absolute after) needs a closed ruling; becomes the program-wide date convention | No — build default proposed at suite draft | Owner |
| OQ-members-home-2 | Menu option list caps: an org with very many groups/leaders — plain scroll (per video) is assumed; confirm no search-within-menu is wanted at large N | No | Owner |
| OQ-members-home-3 | Chip layout at long selection names (e.g. a long group name): truncation width before the chip row wraps or scrolls | No — build default: single line, chips scroll horizontally if needed | Owner |
| OQ-members-home-4 | ~~SearchField states undesigned~~ **CLOSED 2026-09-05** — superseded by the C-034 contract (`../design-system/components/C-034-search-field.md`), which re-ingested the correct set `3561:33795`: states are Default / Focus / Has value. Residual (a) is answered there — the two placeholder grays are two designed states of one component, not a cross-set inconsistency (re-posed as OQ-C-034-2); residual (b) carries over unchanged as OQ-C-034-3 | No | Owner |
