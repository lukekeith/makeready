# ui2-members-browse — spec
> lg · child 1 of program `ui2-members` (docs/features/ui2-members/PROGRAM.md)

## Idea

**Why.** Leaders on the iPhone UI 2.0 app have an empty Members section (ui2-shell D10). They need the
org's member directory and each member's page — who they are, how to reach them, which groups they
are in, how they are doing — without falling back to the 1.0 app. This child also gives the UI2
shell its push navigation, which ~20 already-built pushed pages will reuse.

**What success looks like.** A leader opens Home → Members, searches and filters the list, taps a
member and the member page slides in the way the owner's Robinhood reference does (the system push:
the new page arrives fast from the right on one spring, the page under it shifts left ~30% and dims),
swipes back from the left edge, and every number on the page is live: fields, the activity day rail,
groups, program progress. A Group Leader sees only members of the groups they lead.

**In your words.** "notice how the current page moves a little to the left and the new page slides
faster from the right" → P1 (PROGRAM) · D1.

**The concept.** One `NavigationStack` per tab inside the shell's content area: the Home tab's stack
roots at the Home-tab sections; a Members row pushes `memberDetail(id)`. The system navigation bar is
hidden; each pushed page draws its own C-040 PageHeader. TopNav belongs to the Home stack's root page,
so a pushed page covers it and it slides left with the root; the TabBar stays.

```mermaid
flowchart LR
  TabBar --> HomeStack["Home tab NavigationStack(path)"]
  HomeStack --> Sections["root: HomeSectionLayout (TopNav + section page)"]
  Sections -->|Members row tap| Detail["memberDetail(id) — C-040 + MembersProfileScreen"]
  Detail -->|back / edge swipe| Sections
  Sections --> MembersC["MembersHomeContainer → MemberActions → /api/organizations/:id/members"]
  Detail --> ProfileC["MemberProfileContainer → MemberActions → /api/members/:id(/groups,/engagement), /api/home/days?memberId"]
```

**How it fits today.** Screens and components are built MakeReadyUI previews (members-home,
members-profile; resolver 2026-10-25). The shell routes only `.tab`/`.section` and has no push (D5 took
the legacy OverlayManager out of the target). The members list endpoint returns raw member columns
only; `member.read` (held by Owner, Admin, Group Leader, Contributor) lets any leader list the whole
org.[^1] Member has no address/emergency columns.[^2] No per-member engagement endpoint exists; the
analytics layer supports a member filter.[^3]

**Approaches considered.** Chosen: iOS native push (P1). Rejected: a custom push container — rebuilds
the system push; interruptible swipe-back is the risky part.

[^1]: `server/src/routes/organizations.ts:723`, `server/prisma/seed.ts:88,123,148,167`
[^2]: `server/prisma/schema.prisma:327-367`
[^3]: `server/src/services/analytics.service.ts:387`

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Member columns (address, emergency name/phone); members list extension (groupCount, joinedAt, groupId/leaderId filters); role scoping on the list and member reads; new engagement endpoint; `memberId` on `/api/home/days`; fixtures | §server |
| client | ⬜ | UI 2.0 leader screens are iPhone-only (docs/ui2/README.md); web leader pages read only `/api/members/:id/profile` (`leader-member.store.ts:122`, `members.domain.ts:78`), which D7 leaves unscoped (F4); the one web call to `/:id/groups` is a member self-read (`CheckMemberSession.php:71`), unchanged by D7; no web caller of the list or `/:id` | — |
| iphone | ✅ | Shell push stack per tab; Members section + member page wired (containers, mappers, MemberActions, AppState stores); MembersHomeScreen drops its own nav; EditableFieldRow non-tappable form | §iphone |
| capture | ⬜ | Member screens capture from fixture JSON (ViewRegistry), not the live API; no capture case changes | — |

**Sequencing:** contract settled → server (schema, endpoints, scoping, fixtures) verifies → contract
FREEZES → iphone builds against it → the walk on Fixtures.

**Backward compatibility:** the new columns and fields are additive. The non-additive change is D7's
role scoping: on the list, a released 1.0 build's `OrgHomePage` member count (`OrgActions.swift:47`,
decodes `id` only) drops to a Group Leader's own groups' members — accepted, it is the D7 rule; on
`/:id` and `/:id/groups` there is no released leader-side caller (F1 settled). Release builds run 1.0
screens, not the UI2 shell.

**Blast radius:** `Member` reads anywhere (new nullable columns); every caller of the members list
endpoint and the two member read endpoints (F1).

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
| D0 | Program decisions | PROGRAM.md §Shared decisions P1–P14 bind this spec; the rows below apply them to this child or add to them | Luke 2026-10-25 |
| D1 | Push (P1) | Each tab owns a `NavigationStack(path:)` held in `UI2ShellModel`; the system nav bar is hidden (`.toolbar(.hidden, for: .navigationBar)`) on every page; pushed pages draw C-040 with back = pop; the interactive left-edge pop gesture stays enabled despite the hidden bar. Motion is the system push — no custom curve, duration or scrim. TopNav is part of the Home stack's root page (the stack wraps `HomeSectionLayout`, above `TabBar`), so while a page is pushed TopNav is covered — not visible — and slides left with the root; no hide logic, which would collapse the root ~48pt mid-push (audit 2026-10-25). TabBar stays. Rejected: custom push container (rebuilds the system push) | Luke 2026-10-25 |
| D2 | Tab switch while pushed | iOS standard: each tab keeps its own path; leaving and returning restores it; tapping the selected tab pops that tab's path to empty, animated. Rejected: reset on leave (loses your place) | Luke 2026-10-25 |
| D3 | Field-row taps in this child | Every C-042 row on the member page renders non-tappable with its chevron hidden; child 2 enables them. Rejected: a placeholder page (throwaway); shipping with child 2 (undoes the split) | Luke 2026-10-25 |
| D4 | Members screen chrome (P2) | `MembersHomeScreen` no longer draws C-019 or takes `onSelectTab`/`onToggleNav`; the shell's TopNav is the only one, as on Home. Rejected: two nav rows (duplicate chrome) | (assumed at brainstorm) |
| D5 | Rows with no destination yet | Membership group rows, Engagement program rows, both section `add` buttons, and the Activity rail's day cards render normally and do nothing on tap (OQ-members-profile-2 deferred). Rejected: hiding them (loses the designed layout) | (assumed at brainstorm) |
| D6 | List presentation | Sort: most recent `joinedAt` first. "Joined" label = "Joined " + by local calendar-day age d: 0 → "Today", 1 → "Yesterday", 2–6 → "d days ago", 7–29 → "⌊d/7⌋ week(s) ago" (1 → "1 week ago"), ≥ 30 → "MMM d, yyyy" ("Jan 5, 2025"). Order = the server's `joinedAt`-desc order; the mapper does not re-sort. Search: debounced 300ms, server `search` param, AND-combined with both chips. Rejected: alphabetical (the design leads with recency) | (assumed at brainstorm) |
| D7 | Who sees which members (B3) | Owner (org owner), Admin and Super Admin: every member of the org. Any other leader role: only members with an active GroupMember row in a group the caller created (`Group.creatorId` = caller) — on `GET /api/organizations/:id/members`, `GET /api/members/:id`, `/:id/groups` and `/:id/engagement`; a member outside that set is 404 to them. The Leaders chip is hidden for them. Member sessions reading themselves are unchanged. Rejected: everyone in the org (today) — personal details belong with the responsible leaders | Luke 2026-10-25 |
| D8 | Role and Organization rows (P4) | Organization = the names of the member's orgs within the caller's scope, comma-joined. Role = "Group leader" when the member's linked user (`Member.userId`) created any group in the org, else "Member"; the quick-stat grid's Role shows the same value. Both rows are display-only | Luke 2026-10-25 (rows) · (assumed at spec) 2026-10-25 (derivation) |
| D9 | Email row (P5) | Email shows its value with no indicator; Phone shows "Verified" (positive) when `phoneVerified`, else "Unverified" (negative) | Luke 2026-10-25 |
| D10 | Empty values | An absent field renders the row with an empty value line (label kept); absent photo → C-038 initials; zero groups/programs → section header with count 0 and no rows (members-profile §3 `partial`) | (assumed at spec) 2026-10-25 |
| D11 | Engagement payload (P13) | `GET /api/members/:id/engagement` → `{programs:[{enrollmentId, programId, title, coverImageUrl|null, completedCount, hoursLabel, percent}]}` for every enrollment of a group the member is active in, within D16's scope (Enrollment has no removed flag; lessons = its `LessonSchedule` rows with `removedAt` null); `completedCount` = the member's `MemberLessonProgress.completedAt` non-null on those lessons; `hours:int` per D17, rounded to whole hours (the iPhone formats it); `percent` = round(completed ÷ lessons with `scheduledDate` before today in `tz` × 100), capped at 100, 0 when that denominator is 0; `tz?` query param, default UTC (as `/api/home/engagement`) | (assumed at spec) 2026-10-25 |
| D12 | Activity rail (P14) | The member page's day rail calls `GET /api/home/days` with `memberId` for the 30 local days today−29 … today, today the trailing card, the rail opened scrolled to today; card line 1 = `sessionSeconds` → "N mins", line 2 = `lastActivityAt` as local "h:mm a" (C-071 `Muted`) or the `Nothing` state on zero days | (assumed at spec) 2026-10-25 |
| D13 | Fixtures (P8) | Every fixture member gets email (`first.last@example.org`), birthday (ages 19–67), gender, a city address, emergency name/phone; 13 of 24 members get photos from the d2m `avatar`-tagged images through the D22 image path, the rest fall back to initials | Luke 2026-10-25 (fill) · (assumed at spec) 2026-10-25 (values) |
| D14 | Engagement row `Complete` state (C-059 `state`) | OPEN — recommended: D11's payload gains `totalCount` (the enrollment's LessonSchedule rows with `removedAt` null); the row renders `Complete` iff `totalCount > 0` and `completedCount ≥ totalCount`, else `Progress` with D11's `percent`. Why: `percent` is against lessons scheduled *to date*, so 100% mid-program would wrongly read as finished. Rejected: `Complete` when `percent == 100` (mislabels an up-to-date member as done) | align 2026-10-25 |
| D15 | How the iPhone learns the caller's D7 scope | OPEN — recommended: the list response adds `viewerScope: {all:boolean, groupIds:string[]}` from `memberAccessScope`; the iPhone hides the Leaders chip when `!all` and limits the Groups chip options to `groupIds` (`/api/groups` returns every org group to any role-holder, `permission.ts:322`). Rejected: a separate role endpoint (an extra round-trip); filtering by `creatorId` on the phone (duplicates the server rule) | audit 2026-10-25 |
| D16 | Which groups `/:id/groups` and `/:id/engagement` return | OPEN — recommended: only the member's groups (and their enrollments) in the caller's D7-scoped orgs; a Group Leader sees every group of that member inside the org, so Membership stays complete. Today `getMemberGroups` returns all orgs (`member.ts:316`) — a cross-tenant leak once D8 filters `organizations[]`. Rejected: only the caller's own groups (the profile reads partial) | audit 2026-10-25 |
| D17 | Hours per enrollment (D11) | OPEN — recommended: sessionize only the member's moments tied to that enrollment — client events with that `enrollmentId` plus lesson/video progress whose `lessonSchedule.enrollmentId` matches — with home-dashboard-data's session rule, Σ seconds ÷ 3600 rounded. Why: a `Session` (`home-sessions.ts:12`) carries no lesson link. Rejected: time-overlap with all sessions (double-counts across enrollments) | audit 2026-10-25 |
| D18 | Org id for a non-owner leader | OPEN — recommended: new `GET /api/organizations/my/organizations` (orgs the caller owns or holds a role in, owned first); `AppState` adopts the first when `/my/organization` returns none. Why: `AppState.organizationId` comes only from the owner-only `/my/organization` (`AppState.swift:902`, `organization.ts:73`), so an Admin or Group Leader cannot reach the list at all. Rejected: Members owner-only in UI2 (drops D7's main case) | audit 2026-10-25 |
| D19 | A typeable search field | OPEN — recommended: C-034 gains its editable form — a `TextField` styled as the drawn text with `@FocusState` driving `focused` — implementing its existing contract (`onChange`, `focused`, `onClear`), plus `.scrollDismissesKeyboard(.interactively)` on the list; routed to `/ui2-resolve` after the build (F3). Why: the built view is display-only (`SearchField.swift:28-37`, no `TextField`). Rejected: a container-side overlay field (two inputs to keep aligned) | audit 2026-10-25 |
| D20 | Re-tapping the selected tab (refines D2) | OPEN — recommended: with a non-empty path the tap pops that tab's path to empty, animated; with an empty path it keeps today's behaviour (`apply(.tab)` resets Home to its first section, `UI2ShellModel.swift:26`). Rejected: always reset the section (loses the pushed page and the section in one tap) | audit 2026-10-25 |
| D21 | Member stores on disk | OPEN — recommended: `orgMembersByOrgId` and `memberDetails` are in memory only (personal data), cache-first within the session, cleared in `clearInMemory()`; never written by the disk cache. Rejected: disk-cached like Home (keeps addresses and emergency contacts on the device) | audit 2026-10-25 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `GET /api/organizations/:organizationId/members` (extended) | server | iphone | `requireAuth` + `member.read`; D7 scoping | `search?` (whitespace-separated tokens, each matching first/last/phone/email, AND-combined), `groupId?`, `leaderId?`, `includeInactive?` — a `groupId`/`leaderId` outside the org or the caller's scope → empty 200 | `{success, data:[{id, firstName, lastName, profilePicture|null, googlePicture|null, joinedAt (ISO), groupCount:int}], count}` — existing fields kept; `joinedAt` = this org's `MemberOrganization.joinedAt`; ordered `joinedAt` desc (D6); explicit `select` (the SC1–SC3 columns never appear in the list); + top-level `viewerScope:{all, groupIds}` (D15); `search` keeps its name (the design's `q` is the app's `search`); `leaderId` is a `User.id` from `/api/group-leaders` → members of groups with that `creatorId` | 401 · 403 |
| `GET /api/members/:memberId` (scoped) | server | iphone | `requireMemberOrOrgOwner` + D7 | — | existing payload + `address`, `emergencyContactName`, `emergencyContactPhone` (string|null) + `isGroupLeader:boolean` (D8, derived: `userId` non-null and that user created ≥1 active group in a caller-scoped org); `organizations[]` filtered to the caller's D7 orgs (D8) | 401 · 403 · 404 (incl. outside D7 scope) |
| `GET /api/members/:memberId/groups` (scoped) | server | iphone | as above + D7 | — | existing payload | 401 · 403 · 404 |
| `GET /api/members/:memberId/engagement` (new) | server | iphone | as above + D7 | `tz?` (default UTC) | D11, keys verbatim (`title` ← `StudyProgram.name`, `coverImageUrl` ← `StudyProgram.coverImageUrl`) + `totalCount:int` (D14); `hours:int` (not a label) | 401 · 403 · 404 |
| `GET /api/home/days` (+ `memberId`) | server | iphone | `requireAuth` + D9 scope of home-dashboard-data + D7 | existing + `memberId?` (declared in `daysQuery` — zod `z.object` strips undeclared keys) | existing `{days:[{day, sessionSeconds, blocks[12]}]}` + per day `lastActivityAt` (ISO|null — end of the day's last session; D12 line 2), filtered to that member's sessions when `memberId` is set; `memberId` outside the caller's D7 scope → 404 (D7 is checked here, not taken from `deriveAnalyticsScope`, which gives a role-holding Group Leader the whole org) | 400 · 401 · 404 |
| `GET /api/organizations/my/organizations` (new, D18) | server | iphone | `requireAuth` | — | `{success, data:[{id, name, ownerId, …OrganizationData fields}]}` — orgs owned or role-held, owned first | 401 |
| `GET /api/groups`, `GET /api/group-leaders` (unchanged) | server | iphone | `requireAuth` | — | existing (chip options) | existing |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Member.address` (text, null) | member payload | P7 | open (T1) |
| SC2 | ADD | `Member.emergencyContactName` (text, null) | member payload | P6 | open (T1) |
| SC3 | ADD | `Member.emergencyContactPhone` (text, null) | member payload | P6 | open (T1) |
| SC4 | EDIT | members list response | `groupCount`, `joinedAt`, filters | P12 | open (T2) |
| SC5 | ADD | `GET /api/members/:id/engagement` | §Contract | P13 | open (T4) |
| SC6 | EDIT | `/api/home/days` `memberId` param | §Contract | P14 | open (T5) |
| SC7 | EDIT | `HomeDay.lastActivityAt` (wire only, derived from sessions) | `/api/home/days` days[] | members-profile §3: day rail line 2 = time of last activity; D12 | open (T5) |
| SC8 | EDIT | member payload `isGroupLeader` (wire only, derived) + `organizations[]` scope filter | `GET /api/members/:id` | members-profile §2.2/§2.4 Role + Organization; D8 | open (T6) |
| SC9 | EDIT | members list `viewerScope` (wire only) | list response | members-home §3 Leaders menu "primarily useful to owners/admins"; D15 | open (T2) |
| SC10 | ADD | `GET /api/organizations/my/organizations` | §Contract | members-home §5 list needs an org id for every leader role; D18 | open (T15) |

**Data plan:** SC1–SC3 are nullable adds through `server/schema/*.yaml` → `schema:diff` → one Atlas
migration; no backfill, existing rows read null. SC4–SC10 are additive API changes (SC7 is additive on a payload the Home screen already decodes — `HomeDay` decodes with `decodeIfPresent`, so released and current builds ignore it). Independent ordering.

## server

- Schema: SC1–SC3 via the YAML source of truth and an Atlas migration (house rules).
- `getOrganizationMembers` gains `groupId`/`leaderId` filters, per-member `groupCount` (active
  GroupMember rows in groups of this org) and `joinedAt` (MemberOrganization.joinedAt), and D7 scoping.
- D7 scoping as one service (`memberAccessScope(userId, orgId)` → all | groupIds), used by the list,
  the member reads and engagement, and by `/api/home/days` when `memberId` is present.
- `GET /api/members/:id/engagement` per D11.
- Fixtures: D13 on the base members; photos through `fixtures/images.ts` (D22 path).

## iphone

- **Shell:** `UI2ShellModel` gains `paths: [TabBar.Tab: [UI2Destination]]` with `UI2Destination.memberDetail(id)`;
  `UI2Shell` wraps each tab's root (Home: `HomeSectionLayout`, which today renders `content` inside
  `SectionPageScroll`'s ScrollView — a stack there has no height) in `NavigationStack(path:)` above `TabBar`,
  with `.navigationDestination`; TopNav rides on the root page (D1, no hide logic); re-selecting the
  current tab per D20; the hidden-bar edge-swipe pop stays enabled (D1, F2). The pushed page owns its
  ScrollView (the screen has no root scroll).
- **Members:** `MembersHomeContainer` + `MembersHomeMapper` (P12, D6, D7 chip); `MembersHomeScreen`
  drops its C-019 row (D4) — MakeReadyUI edit under this spec's ruling.
- **Member page:** `MemberProfileContainer` + `MemberProfileMapper` (D8–D12), pushed with the
  member's name known for the header (loading state); C-042 gains a non-tappable form (chevron hidden,
  no action) for D3 — **(new)** prop on a built component.
- **State:** `MemberActions` (loadDirectory, loadMember, loadMemberGroups, loadEngagement,
  loadMemberDays) writing `AppState` (`memberDirectory`, `memberDetails[id]`), cleared in
  `clearInMemory()`; 401 → sign-out, other failures `recordError` (D28 of ui2-shell).

## Testing

- **server:** route tests for the list (filters, groupCount, joinedAt, D7 for Group Leader vs Owner),
  member reads (D7 404 outside scope, 403 outside every org; D16 org filter), engagement (D11/D14/D17 math, `tz`, zero denominator), days `memberId` (+ `lastActivityAt`, midnight crossing, out-of-scope 404), `/my/organizations` (owned + role-held), list `viewerScope` + token search; fixtures DB tests for D13;
  `migrate:status` clean on a fresh DB.
- **iphone:** mapper tests (D6 labels incl. the 30-day cut, D8 role/org, D9 indicators, D10 empties,
  D12 rail, D14 state, index→id resolution), decode tests for the new payloads incl. `.SSSZ` dates, shell model tests (per-tab paths, D20 re-tap), org adoption fallback (D18),
  `ios:build-check --test`, swiftlint baseline.
- **Cross-app E2E:** as Fixtures on the walk env — Members lists 24, search and both chips filter;
  tap → member page live (fields, rail, groups, programs); a Group-Leader-role session sees only its
  groups' members and gets 404 for another.
- **Human walk (on device):** the push and swipe-back feel against the reference; tab switch keeps
  the page, re-tap pops; TopNav hides while pushed.

## Out of scope

- Field edits and the date arrangement (child 2, `ui2-members-edit`).
- Membership add, enroll, group-row and program-row destinations (OQ-members-profile-2).
- Email verification; AI suggestions; the web client.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | D7 narrows `GET /api/members/:id` and `/:id/groups` for non-owner/admin leaders — a released 1.0 build calling them as a Group Leader for a member outside their groups would now get 404 | settled (audit 2026-10-25): no released leader-side caller of `/:id` or `/:id/groups` — 1.0 iPhone calls `/profile` (`GroupActions.swift:456`) and the list as a count (`OrgActions.swift:47`); web leader pages call `/profile`. Both scoped as specced; the list count change is recorded in §Apps *Backward compatibility* |
| F2 | Hiding the system nav bar disables the interactive pop gesture by default | build-time risk on the shell task: re-enable it and verify on device |
| F3 | `MakeReadyUI/` is d2m-owned; D3, D4, D7 (Leaders chip), P5/D9 (no email indicator) and P6 (Emergency phone row) change two built screens and one component | route all five to `/ui2-resolve` after the build so the design records them (T11, T12) |
| F4 | `GET /api/members/:id/profile` (`requireAuth` + `groupManageFilter`) is a third leader-side member read that D7 does not list; it is the one the released 1.0 iPhone build calls (`GroupActions.swift:456`) — it does **not** call `/:id` or `/:id/groups` | settled (audit 2026-10-25): `/profile` stays unscoped in this child — it carries none of SC1–SC3, the same leader can already list those members via `/api/groups/:id/members` (F12), and narrowing it changes the released 1.0 iPhone and the web LeaderApp (it would flip the client ⬜ row). Follow-up ticket, not this feature |
| F5 | Unbuilt design states: `MembersHomeScreen.State` has no `loading`/`empty`/`error`; `MembersProfileScreen` builds `populated` + `partial` only (`loading`/`error` named, unbuilt) | build-time risk on T12/T13: the shell has no loading/error surface (ui2-shell D28 — Home is cache-first, failures `recordError(surface: false)`): loading renders the cached or empty State (profile: header with the list-known name), a failure keeps the last State; the designed skeleton/error states go to `/ui2-component-build` — never built here to make a check pass |
| F6 | D7 scopes non-admin leaders by `Group.creatorId`; the house rule warns that creator-identity checks lock out org leaders | settled (audit 2026-10-25): D7 is a visibility rule, not an authorization gate. The all-members test is `isSuperAdmin` OR `Organization.ownerId == caller` OR a UserRole whose system role name is Owner or Admin — **not** `canManageOrgContent`/`getManageableOrgIds`, which admit every role-holder (`permission.ts:305`). Every other role, custom roles included, gets the `creatorId` groups. T3 writes it |
| F7 | contract: Prisma's `.SSSZ` dates and the app's `.iso8601` decoder (home-dashboard-data F5) | T9 decodes date strings and parses in the mapper |
| F8 | A session crossing local midnight is bucketed by `start` (`bucketDays`, `home-dashboard.ts:218`), so its day's `lastActivityAt` can read the next day's time | build-time risk on T5: accept, and test the crossing case |
| F9 | The list has no pagination and returns whole rows; production org size is unknown | build-time risk on T2: no pagination in this child; explicit `select` keeps the payload to the contract's keys |
| F10 | `/api/group-leaders` resolves the org with `getUserOrgId`, not the shell's org (`programs.ts:593`); a leader who holds a role but created no group never appears as a filter | note — a multi-org owner may see another org's leaders; unchanged here |
| F11 | `updateMemberSchema` (`members.ts:1178`) is a plain `z.object` and would silently strip `address`/`emergencyContact*` | child 2 (`ui2-members-edit`) must add them; child 2 also applies D7 to PATCH |
| F12 | Adjacent, not caused here: `GET /api/groups/:groupId/members` (`group-members.ts:188`) is `requireAuth`-only, so any user lists any group's members, undercutting D7; `AdminController.php:27` passes `User.id` as `memberId` to `/profile` | out of scope — follow-up ticket (decider: owner) |
| F13 | C-038 initials at 164pt (OQ-C-038-2/-3) are undesigned; C-035's applied state is designed but no screen draws it (OQ-C-035-1); the C-036 dim is an overlay inside the shell's scroll, so it may not cover TopNav/TabBar | build-time risk on T11/T12: verify on the walk; carried OQs, no ruling here |
| F14 | Built-screen render vs frozen Figma snapshot (audit item 8) was not diffed: the capture API (:5951) did not answer and the audit starts no server | build-time risk on T11/T12: both screens are edited in this build and re-captured + diffed through the d2m harness after their edits, superseding a pre-build diff |
| R1 | repoint (iphone): none — UI2 is a parallel shell (ui2-shell); legacy `MemberProfilePage.swift`/`MemberHomePage.swift` and the `Route` member cases stay live until the hard cutover; no surface is REPLACED or ABSORBED by this child | nothing to repoint |
| OQ | Screen/component OQs: members-home OQ-1 → D6; OQ-2 (menus scroll, no search) and OQ-3 (chips one line, scroll) → build defaults; OQ-4 closed. members-profile OQ-1 → D3 (child 2); OQ-2 → D5; OQ-3 → P5/D9; OQ-4 → D8. OQ-C-040-2 → P1; OQ-C-040-5 (long-name ellipsis) carried; OQ-C-042-3 (no disabled rows) contradicts D3 → `/ui2-resolve` with F3; OQ-C-042-2 carried; OQ-C-059-7 carried; members-profile §2 still names C-025 DayActivityCard, merged into C-023 RailCard (`RailCard.swift:10`) → `/ui2-resolve` | dispositioned (audit 2026-10-25) |
| T1 | server: `Member.address`, `emergencyContactName`, `emergencyContactPhone` in `server/schema/*.yaml` → `schema:diff` → Atlas migration (SC1–SC3) | blocking |
| T2 | server: `getOrganizationMembers` — `groupId`/`leaderId` filters, `groupCount` (filtered `_count` of active memberships in active groups of this org), `joinedAt`, `joinedAt`-desc order (query `memberOrganization` — Prisma cannot order by a filtered to-many), explicit `select`, token-AND search, `viewerScope` (SC4, SC9) | blocking |
| T3 | server: `memberAccessScope(userId, orgId)` service (all · groupIds, per F6) applied in the service layer from the list, `/:id`, `/:id/groups` (+ D16 org filter), `/:id/engagement` and `/api/home/days?memberId` — not inside `requireMemberOrOrgOwner`, which also guards PATCH/DELETE/link-google/history (`members.ts:1189,1267,1682,1875`); outside every caller org stays 403 (middleware), in-org but out of scope → 404 (D7) | blocking |
| T4 | server: `GET /api/members/:id/engagement` per D11 + D14 `totalCount` (SC5) | blocking |
| T5 | server: `/api/home/days` — `memberId` in `daysQuery`, member-filtered `loadSessions`, per-day `lastActivityAt` in `bucketDays` (SC6, SC7) | blocking |
| T6 | server: `getMember` — `isGroupLeader` and the caller-scoped `organizations[]` (SC8) | blocking |
| T7 | server: fixtures D13 on the 24 base members (`base.ts:24`) + `server/fixtures/screens/members-home.ts` and `members-profile.ts` whose `full` scenario fills every wired section (house rule: fixtures); avatar slots for the 13 `Use: avatar` d2m images with a square resize in `images.ts`; 2–3 multi-group memberships (`groupCount` > 1); and in **base.ts** (screen layers may not create users or groups) a second fixture user with a Group Leader role who created one group — the E2E Group-Leader step needs it | blocking |
| T8 | iphone: shell push — `UI2ShellModel.paths`, `UI2Destination.memberDetail(id)`, per-tab `NavigationStack`, TopNav hide, re-tap pop (D1, D2, F2) | trailing |
| T9 | iphone: models — org-member list item (+ `viewerScope`), `MemberDetail` (+ `address`, `emergencyContactName`, `emergencyContactPhone`, `isGroupLeader`), engagement, `HomeDay.lastActivityAt`; every new key `decodeIfPresent`; dates (`joinedAt`, `birthday`, `lastActivityAt`) decoded as `String` and parsed in the mapper with the fractional-then-plain fallback (`HomeDashboardMapper.swift:111`) — the app decoder's `.iso8601` rejects Prisma's `.SSSZ`; `MemberProfile` (holds `Date`s) is not reused | trailing |
| T10 | iphone: `MemberActions` + `AppState` stores — `orgMembersByOrgId` and `let memberDetails = EntityStore<MemberDetail>()` (identity → EntityStore; `AppState.members` is already `EntityStore<GroupMember>`; not `memberDirectory`, an unrelated `Group` Bool); in memory only (D21), cleared in `clearInMemory()` | trailing |
| T11 | iphone: `MembersHomeScreen` — drop C-019 + `onSelectTab`/`onToggleNav` (D4); `showsLeaderFilter` flag hiding the Leaders chip (D7, D15); `memberInitials` passed to C-037 (no initials fallback today, `MembersHomeScreen.swift:213`) | trailing |
| T12 | iphone: `MembersProfileScreen` — drop `emailVerified`, Email passes `indicator: nil` (P5/D9); `emergencyContact` splits into "Emergency contact" + "Emergency phone" rows (P6, 9 rows); C-042 gains a non-tappable form, chevron hidden (D3 — the row is always a `SwiftUI.Button` today, `EditableFieldRow.swift:74`); Address passes the existing `multiline: true` (P7); `age` becomes a String so a missing birthday renders empty (D10); the day rail scrolls to today on open and on "Jump to today" (`ScrollViewReader`, as `HomeDashboardScreen.swift:283`) | trailing |
| T13 | iphone: `MembersHomeContainer`/`Mapper` + `MemberProfileContainer`/`Mapper` — the mapper returns the row `[id]`s beside `State` and resolves `onOpenMember(Int)` and filter-option picks against the snapshot it rendered; search debounced in the container with Task cancel + `Task.sleep(300ms)` (never `asyncAfter`); the pushed page's header name comes from the list store by id; D6 labels, D8 Role/Org (from `isGroupLeader`, `organizations[].organization.name`), D9, D10, D12 rail (line 1 = `sessionSeconds`→minutes, line 2 = `lastActivityAt` local time), D14 state; email = `email ?? googleEmail` (the `MemberProfile.displayEmail` precedent); gender capitalized (stored lowercase) | trailing |
| T14 | iphone: C-034 `SearchField` editable form per D19 | trailing |
| T15 | server: `GET /api/organizations/my/organizations` (D18, SC10), declared beside `/my/organization` (`organizations.ts:452`; two segments, no clash with `/:organizationId`) | blocking |
| T16 | iphone: `AppState` org adoption falls back to `/my/organizations` for a non-owner leader (D18), generation-guarded like `adoptOrganization` | trailing |

**Alignment (2026-10-25)** — 16 persisted fields ALIGNED (name ×2, profilePicture/googlePicture, email, phoneNumber, phoneVerified, birthday, gender, org name, org joinedAt, group name/cover/leader `creator.name`/joinedAt, day `sessionSeconds`/`blocks`); MISSING: list `joinedAt` + `groupCount` (SC4), `address` (SC1), emergency name/phone (SC2/SC3, RESHAPE of the design's one `emergencyContact`), Role (SC8), day `lastActivityAt` (SC7), the five engagement values (SC5); RESHAPE: list sort (server `lastName` asc → D6), C-059 state (D14); DESIGN-ONLY: `emailVerified` (P5); RENAME resolved app-side: `q` → `search`, `title` ← `StudyProgram.name`. Released iPhone build: caches none of these fields (1.0 reads `/profile` into `MemberProfile`, untouched) — no on-device migration.
