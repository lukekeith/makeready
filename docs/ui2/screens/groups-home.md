# groups-home — Groups (leader directory)

Platform: iphone · Status: specced · Specced: 2026-09-01

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3668-7676
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3668:7676` ("Groups", 440×1892)
- Frozen snapshot: `assets/groups-home.png` — captured 2026-09-01
- Filter-menu behavior inherits `screens/members-home.md` §1's normative video source
  (Filter.MP4) via C-036.

**Deviations (closed list):**
1. All names, counts, and photos are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The nav row follows the `shell-topnav`/`shell-tabs` specs; this frame (Groups active) is
   evidence only.
4. The "All Orgs" chip renders **only for callers belonging to more than one organization**
   (owner decision 2026-09-01); single-org callers see just the Leaders chip. The frame
   shows the multi-org presentation.

Anything else that differs from the source is a defect.

## 2. Layout contract

Identical skeleton to `members-home` §2: status bar → collapsed nav (C-019, Groups active) →
header block (116pt: 16 inset → SearchField 408×44 "Search groups" → 16 → chip row:
FilterChip ×2 "∨ All Orgs" (95pt), "∨ All Leaders" (117pt), 8 gap) → list: ListResultRow
(C-037) `type=Group + tags`, 96pt rows, 1px `color-layout-border` hairlines between rows
(none first/last), inset 16.

Row content (per node `3668:7696`): 64pt group image (rounded-full, C-038 fallback rules) →
info (8 gap): group name SF Pro Bold 14/20 white ellipsized → chip row (4 gap): MetaChip
(C-043) `Single/Default` = leader short-name ("L. Keith") + MetaChip `Key value/Default` =
member count ("3" + "members") → 18pt chevron-right.

## 3. Behavior contract

**States (closed list):** `loading` (header immediate, row skeletons) · `populated`
(default sort: alphabetical by group name — no ordering signal in source, proposed default
pending OQ-groups-home-1) · `empty` (no groups match search+filters: empty message in the
list area, header interactive) · `error` (inline list-area error + retry).

**Search:** live filter, debounced ≥300ms, clears to unfiltered; ANDs with both chips
(same contract as members-home §3).

**Filter chips + menu:**
- "All Orgs" (multi-org callers only): C-036 FilterMenuOverlay, single-select, plain
  labels — "All Orgs" + each organization the caller belongs to.
- "All Leaders": identical to members-home — "All Leaders" + each leader in scope; filters
  groups to those the selected leader manages.
- Selection/chip-label/motion behavior identical to members-home §3 (`motion-menu-fade-in`/
  `-out`).

**Row tap** → the group's screen (`groups-detail`, Figma to come — queued).

**Group creation is deliberately absent from this screen** (owner, 2026-09-01): it lives on
a future surface whose frame is coming. Tracked as OQ-groups-home-2 so gap analysis doesn't
mark it lost.

**Motion:** none beyond C-036's tokens and system scroll.

## 4. Components

Closed list rendered — **all existing, no new rows minted**: **C-019 TopNav** (collapsed,
Groups active) · **C-034 SearchField** ("Search groups") · **C-035 FilterChip** (×2) ·
**C-036 FilterMenuOverlay** (both chips) · **C-037 ListResultRow** (`type=Group + tags`) ·
**C-038 Avatar** (64pt group image inside C-037) · **C-043 MetaChip** (`Single` leader,
`Key value` member count).

State coverage: every consumed variant above was already enumerated against the component
sheet in `members-home.md` / `members-profile.md`; this frame introduces no new variants
(verified on node `3668:7696`: chips resolve to the existing `Single/Default` and
`Key value/Default` symbols).

## 5. Data & API

Reads: the caller's groups with leader + member counts, filtered by search + org + leader;
the org and leader option lists. Writes: none.

| Need | Endpoint | Status |
|---|---|---|
| Groups list (name, photo, leader, member count) | `GET /api/groups` — "List user's groups" (verified via makeready-api) | ✅ exists; audit confirms leader name + memberCount in the payload and search/filter params — anything missing is **API-GAP (additive)** |
| Leaders menu options | `GET /api/group-leaders` (verified) | ✅ exists |
| Orgs menu options (multi-org callers) | `GET /api/organizations/my/organization` (verified) returns ONE org | **API-GAP (additive): a "my organizations" list** for multi-org callers (the `MemberOrganization`/user-org relations exist server-side) |
| Org/leader scoping RBAC | same caveat as members-home §5 (`canManageOrgContent`) | flagged for the build suite |

## 6. Connections

- **Entry:** `shell-tabs` → groups-home (Groups tab).
- **Overlays:** chip taps → C-036 (component-level).
- **Exit:** row tap → `groups-detail` (pending Figma, queued). This is also the
  destination `members-profile` OQ-2's group-row tap will share.

## 7. Legacy mapping

| Legacy element | Disposition |
|---|---|
| `Pages/Main/MainGroups.swift` + coordinator sub-tabs (`coordinator.groupsSubTab`: groups / members / requests tabs) | partially carried: groups-home is the new Groups tab root (flat filtered list, no sub-tabs). The members sub-tab's role moves to `members-home`; the **requests** surface has no 2.0 home yet — gap candidate for sweep 2 |
| `Pages/Manage/Group/*` (8+ files: group home, edit, invite, members, requests…) | not this screen — flow to `groups-detail` + its family when those frames arrive |
| `Route.swift` group cases (groupHome modal, editGroup, invite, members panes…) | carried by the `groups-detail` family, not here |
| Group creation (legacy create-group flow) | **deliberately absent here** — lands on a future surface (OQ-groups-home-2); gap analysis must confirm it exists somewhere before cutover |

## 8. Open questions

| # | Question | Blocking? | Decides |
|---|---|---|---|
| OQ-groups-home-1 | List ordering: no signal in the source — proposed default: alphabetical by name; confirm (or recency/activity) | No — proposed default stands | Owner |
| OQ-groups-home-2 | Where group creation lives in 2.0 (owner: "elsewhere, future frame") — unresolved until that frame arrives; gap analysis blocks cutover on it | No for this screen; YES for cutover | Owner (frame to come) |
| OQ-groups-home-3 | Join-requests surface: legacy Groups tab exposed pending requests; no 2.0 home for them yet | No for this screen; gap-analysis item | Owner (frame to come) |
