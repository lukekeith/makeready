# ui2-groups-edit — spec
> md · child 2 of program `ui2-groups` (docs/features/ui2-groups/PROGRAM.md)

## Idea

**Why.** ui2-groups-browse (shipped 2026-10-27, 46db344) gave leaders a live group page, but its six
setting rows and its Delete Group button do nothing (browse D6). Leaders on iPhone 2.0 still cannot
rename a group, change who can see it, set its age range or member cap, choose directory access, or
remove it. Every edit page is already built in MakeReadyUI (`Screens/Fields/*`); this child wires them
and the delete confirmation.

**What success looks like.** On the walk env as the fixtures owner: on the rich fixture group, each of
the six rows opens its edit page with the current value, Save stays disabled until the value changes,
Save pops back with the new value shown on the group page and in the Groups list; an invalid age range
cannot be saved; Delete Group → the red action menu → confirm returns to Groups without that group,
and Done cancels.

**In your words.** "build the groups experience, which is the home groups page, group detail page, and
edit screens for group data" → D0 (this child is the edit half).

**The concept.** The member edit pattern (`MemberFieldEditor` + `MemberFieldEditContainer`) cloned for
groups: a `GroupField` enum, a pure `GroupFieldEditModel` (field → page state, validate, patch body), a
`GroupFieldEditContainer` behind a `.editGroupField` route; Delete through the built C-066 menu.

**How it fits today.** `GroupDetailContainer` maps `onEditField(label)` and `onDeleteGroup` to no-ops.
`GroupActions.updateGroup` sends PATCH with optional fields where nil means "not sent", so it cannot
clear `maxMembers` or `ageRange` to null today; `deleteGroup` removes the group from `AppState.groups`
(`GroupActions.swift:268`). The server PATCH (`groups.ts` ~1000) takes every field but has no
`memberDirectoryAccess` input and no min ≤ max check.

**Approaches considered.** Chosen: a separate group editor mirroring the member one. Rejected:
generalising `MemberFieldEditor` into a shared editor now (touches a shipped, walked feature for a
second consumer; extract when a third arrives).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | PATCH `/api/groups/:id` accepts `memberDirectoryAccess` (keeps the Boolean in step) and rejects `ageRange.min > ageRange.max` | §server |
| client | ⬜ | UI 2.0 leader screens are iPhone-only; web keeps writing the Boolean `memberDirectory`, which still syncs the enum (browse D11) | — |
| iphone | ✅ | group field editor (route, container, model), delete confirmation, GroupActions patch that can clear fields | §iphone |
| capture | ⬜ | edit pages capture from fixture JSON via ViewRegistry; no case changes | — |

**Sequencing:** contract settled → server verifies → contract FREEZES → iphone builds → the walk.

**Backward compatibility:** additive. Released 1.0 builds send the Boolean and never `memberDirectoryAccess`;
their PATCH behaves as today except (a) an inverted age range now returns 400 instead of saving (1.0's
EditGroupPage cannot produce one — F1) and (b) their `memberDirectory: false` no longer overwrites a stored
Names only (D12) — both server-side, no client change.

**Blast radius:** every PATCH caller (web admin, LeaderApp, legacy iPhone); readers of `Group` see the
same columns.

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
| D0 | Program decisions | PROGRAM.md §Shared decisions P1–P15 bind this spec; browse's shipped rulings stand. This child: the six field edits, the directory-access write, the age validation and Delete Group. Rejected: one spec for both halves (owner chose the split) | Luke 2026-10-27 |
| D1 | Field identity (P10) | `GroupField` = `name`, `description`, `visibility`, `ageRange`, `maxMembers`, `directoryAccess`; `GroupDetailContainer.onEditField(label)` maps the screen's labels "Group name", "Description", "Visibility", "Age", "Maximum members", "Member directory access" to them (an unknown label is a no-op) and pushes `.editGroupField(groupId:, field:)`. Rejected: passing labels through (label copy is design-owned) | (assumed at brainstorm) |
| D2 | Page per field (P10, shared-edit-field §2b) | name → `EditTextSingleFieldScreen` (title "Group name", trimmed of leading/trailing whitespace before validation and sending, 1–200 chars after trimming); description → `EditTextMultiFieldScreen` ("Description", ≤ 2000, empty saves `null`); visibility → `EditOptionFieldScreen` ("Visibility", options Private / Public with the §2b descriptions); ageRange → `EditOptionsCustomFieldScreen` (title "Age range" per shared-edit-field §2b, opened from the "Age" row; options "Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range", labels "Minimum age" / "Maximum age"); maxMembers → `EditTextSingleFieldScreen` ("Maximum members", number pad, digits only, `allowsEmpty`, empty = Unlimited, else an integer ≥ 1); directoryAccess → `EditOptionFieldScreen` ("Member directory access", Allowed / Names only / Not allowed with the §2b descriptions). Every page: `showsAISuggestions: false` (P11). Rejected: a multi-field form (the design is one field per page) | (assumed at brainstorm) |
| D3 | Copy | Titles, descriptions and option descriptions verbatim from shared-edit-field §2b; the two the design left blank: Maximum members — "The most members this group can have. Leave it blank for no limit."; Member directory access — "Choose what members of this group can see about each other." Both drafts routed to the design owner (F2) | (assumed at brainstorm) |
| D4 | Age range rules (P14) | Selection derived from the stored bounds (both null → Any age; equal to a preset → that preset; else Custom range). Save enabled only when the effective bounds differ from the stored ones and pass: each bound a whole number 0–120, min ≤ max when both set, Custom range with both inputs empty is invalid. Any age saves `ageRange: null`; otherwise `{min, max}` with an empty input sent as null. Rejected: an inline error message (C-046 has no error slot; the button stays disabled, OQ-edit-options-custom-field-3 default) | (assumed at brainstorm) |
| D5 | Save behaviour (P10) | Save → PATCH the one field → on success merge the response into `AppState.groups[id]` and `popIfTop`; saving = Save disabled + spinner, inputs read-only; failure = inline error "Couldn't save. Try again." above Save (age page: the shell error banner, its screen has no error slot), value kept; 401 → sign-out; 404 → the D10 local cleanup for that group (no DELETE call), then pop to Groups (the group is gone or out of scope). Back discards silently | (assumed at brainstorm) |
| D6 | Patch that can clear (iphone) | `GroupActions.updateGroup` takes a `GroupPatch` whose fields are tri-state (absent · null · value) so `maxMembers: null` and `ageRange: null` reach the server; existing callers keep their behaviour. Rejected: separate clear methods (one per field) | (assumed at spec) 2026-10-27 |
| D7 | Directory write (E1, P8) | PATCH accepts `memberDirectoryAccess ∈ {ALLOWED, NAMES_ONLY, NOT_ALLOWED}` and sets `memberDirectoryEnabled = (value == ALLOWED)`; `memberDirectory` alone keeps today's sync; both sent and disagreeing (`true` with anything but ALLOWED, `false` with ALLOWED) → 400. The iPhone sends only `memberDirectoryAccess`. Rejected: Boolean-only writes (cannot store Names only) | (assumed at brainstorm) |
| D8 | Age validation (server, P14) | PATCH with `ageRange.min` and `ageRange.max` both non-null and `min > max` → 400 `{error: "Minimum age must not exceed maximum age"}`; nothing saved | (assumed at brainstorm) |
| D9 | Delete Group (P9) | `onDeleteGroup` presents C-066 `ActionMenuOverlay` via `actionMenuPresentation` under the shell's `.ui2OverlayHost()`: one row, glyph `trash`, label "Delete «group name»", tone `destructive` (D13), no other text (D14); Done = cancel. Confirm → `GroupActions.deleteGroup` → pop the Groups stack to its root; failure → banner "Couldn't delete the group", page stays. Rejected: native confirmation dialog (house rule) | Luke 2026-10-27 |
| D10 | After delete (E3) | `deleteGroup` removes the group from `AppState.groups` and, in the same call, from every store keyed by or listing it: group-detail stores (members, requests, enrollments, history, days, chart), `memberGroupsById` rows, and Home's followed-groups data (refetch `loadFollowing` if the group appears there). Rejected: leaving stale rows until the next refresh (a deleted group would still be tappable) | (assumed at brainstorm) |
| D11 | Who may edit/delete | Server unchanged: PATCH and DELETE already require `groupManageFilter`; the iPhone shows the same rows to anyone who can open the page (only managers can) | (assumed at spec) 2026-10-27 |
| D12 | Boolean-only writes keep Names only (F3) | PATCH with `memberDirectory` and no `memberDirectoryAccess`: `true` → `ALLOWED` + Boolean true; `false` → Boolean false, and the enum becomes `NOT_ALLOWED` **only when it is stored as `ALLOWED`** (a stored `NAMES_ONLY` or `NOT_ALLOWED` is kept). Binds every caller: LeaderApp `group-home-modal.vue:240`, iPhone 1.0 `EditGroupPage.swift:252` and `GroupHomePage.swift:1086` send `memberDirectory` on every save. Rejected: today's sync (`false` → `NOT_ALLOWED` always, `groups.ts:1046`), which turns a Names-only group into Not allowed whenever anyone renames it on the web or on 1.0; changing those callers (1.0 is released) | auto (recommended) 2026-10-27 — raised by audit |
| D13 | Destructive row through C-066 (D9) | `ActionMenuOverlay.ActionItem` gains `tone: ActionMenuRow.Tone = .standard`, which the overlay passes to `ActionMenuRow` (`ActionMenuOverlay.swift:93`); the default keeps the frozen C-066 snapshot and the shell's Add menu unchanged. The build edits `iphone/MakeReadyUI/` for this (ui2-groups-browse D2 precedent) and routes it to `/ui2-resolve C-066` afterwards so d2m matches. Rejected: a container-local copy of the overlay (an inline copy of a MakeReadyUI view collides with the real one); a standard-tone row (D9 and owner G5 rule it destructive) | auto (recommended) 2026-10-27 — raised by audit |
| D14 | Delete copy (G5b) | The menu carries exactly D9's row label "Delete «group name»" and Done, with no other text: C-066 has no message slot (`ActionMenuOverlay.swift:43-65`), and nothing on it promises a restore. Enumerated deviation from owner ruling G5b (copy says members lose access): **not shown in this build**, routed to the design owner with F2 for a message slot on C-066. Rejected: putting the warning in the row label (G5 fixes the label); inventing a message view (no design) | auto (recommended) 2026-10-27 — raised by audit |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `PATCH /api/groups/:id` (extended) | server | iphone | `requireAuth` + `groupManageFilter` | existing fields + `memberDirectoryAccess?` (D7); `memberDirectory` alone per D12; `ageRange` min ≤ max (D8); the iPhone sends one field per request, `null` clearing `description`, `maxMembers`, `ageRange` or a bound (D6) | unchanged (browse: + `creatorName`, `memberDirectoryAccess`) | 400 (D7 conflict, D8, existing zod) · 401 · 404 |
| `DELETE /api/groups/:id` (unchanged) | server | iphone | as today | — | `{success, message}` | 401 · 404 |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | EDIT | PATCH body `memberDirectoryAccess` (writes `Group.memberDirectoryAccess` + `memberDirectoryEnabled`) | §Contract | groups-detail "Member directory access" edit page (shared-edit-field §2b, three options); D7 | landed cb5708f (no migration — wire only) |
| SC3 | EDIT | PATCH `memberDirectory` Boolean-only write keeps a stored `NAMES_ONLY` (`memberDirectoryAccess` sync) | §Contract | the "Names only" option must survive the full-form saves of LeaderApp and 1.0 (F3); D12 | landed cb5708f (no migration — wire only) |
| SC2 | EDIT | PATCH `ageRange` validation | §Contract | edit-options-custom-field §3 validation (min ≤ max); D8 | landed cb5708f (no migration — wire only) |

**Data plan:** no schema change — the column landed in browse (SC1 there). Existing rows untouched.

**Field trace (align 2026-10-27)** — design field → `Group` column → PATCH zod → wire → iPhone `UserGroup`
property → write path (`GroupActions.updateGroup`):

| Design field (page) | Column | PATCH zod | Wire (response) | iPhone property | Verdict |
|---|---|---|---|---|---|
| Group name (single) | `name` | `string 1–200` | `name` | `name` | ALIGNED — screen `maxLength` 200 = zod max |
| Description (multi) | `description` | `string ≤2000 \| null` | `description` | `description` | ALIGNED for set; iPhone cannot send `null` (nil = not sent) → T3 |
| Visibility (option) | `isPrivate` | `boolean` | `isPrivate` | `isPrivate` | ALIGNED — layer transform Private ↔ `true`, Public ↔ `false`, written in D2 |
| Age (options-custom) | `ageRangeMin`/`ageRangeMax` | `{min?,max?} 0–120 \| null` | `ageRange {min,max} \| null` | `ageRange: AgeRange?` | server ALIGNED but no min ≤ max (SC2/T2); iPhone cannot send `null` or a null bound (drops nil keys) → T3 |
| Maximum members (single) | `maxMembers` | `int ≥1 \| null` | `maxMembers` | `maxMembers` | server ALIGNED; iPhone cannot send `null` (Unlimited) → T3 |
| Member directory access (option) | `memberDirectoryAccess` + `memberDirectoryEnabled` | **absent** — zod strips it | `memberDirectoryAccess` (browse) | `memberDirectoryAccess: String?` | MISSING at the server (SC1/T1) and on the iPhone write path (T3) |
| Delete Group | `isActive` (DELETE archives) | — | `{success,message}` | `groups` + group-keyed stores | ALIGNED on the server; iPhone leaves 7 stores stale → T4 |

Not a field, persisted nowhere (checked for N1): an edit in progress — Back discards (D5), so nothing
survives the app closing. The PATCH response has no `organizationId`/`organizationName`;
`upsertKeepingOrganization` (`GroupActions.swift:141`) already carries them over — ALIGNED. No pending
owner notes on any of the five items (`ui2-notes.mjs read`, 2026-10-27). The iPhone stores
`memberDirectoryAccess` as a `String?`, so 1.0 builds (which never decode it) are unaffected.

## server

- `groups.ts` PATCH: zod `memberDirectoryAccess: z.enum([...]).optional()`; D7 sync + conflict check;
  D12 Boolean-only rule (reads the stored enum from `existingGroup`); D8 refine on `ageRange`.
- `server/fixtures/screens/groups-detail.ts` `full`: the rich group (Tuesday Men's Group) gets a
  description, age range 26–35, maximum members 40 and `NAMES_ONLY` (Boolean false), so every edit page
  opens on a stored value; Empty Group keeps every default (null description, Any age, Unlimited,
  Allowed) — T5.

## iphone

- **Route:** `UI2Destination.editGroupField(groupId: String, field: GroupField)` → `GroupFieldEditContainer`.
- **Model:** `GroupFieldEditModel` (pure): page state per D2/D3/D4, validate, `GroupPatch` builder.
- **Container:** `GroupFieldEditContainer` per D5, mirroring `MemberFieldEditContainer`.
- **Group page:** `GroupDetailContainer` wires `onEditField` (D1) and `onDeleteGroup` (D9).
- **State:** `GroupPatch` + `GroupActions.updateGroup(id:patch:)` (D6); `deleteGroup` per D10.
- **MakeReadyUI:** `ActionMenuOverlay.ActionItem.tone` (D13), routed to `/ui2-resolve C-066` after.

## Testing

- **server:** PATCH `memberDirectoryAccess` each value (enum + Boolean after), Boolean-only still syncs,
  D12 (`false` on a stored NAMES_ONLY keeps it; `false` on ALLOWED → NOT_ALLOWED; `true` → ALLOWED),
  D7 conflict 400, D8 400 and equal bounds OK, partial bounds, non-manager 404.
- **iphone:** `GroupFieldEditModel` tests — label → field, each page's initial state from a group,
  dirty/valid rules (D2 name/maxMembers, D4 every invalid case), patch bodies incl. nulls; `GroupPatch`
  encoding (absent vs null); D10 store cleanup; `ios:build-check --test`, swiftlint baseline.
- **Cross-app E2E (Fixtures):** edit each of the six fields on the rich group and see it on the page
  and in Groups; Age 30/20 cannot save; Maximum members blank → "Unlimited"; Directory "Names only"
  persists across a reload; Delete runs LAST and on **Empty Group** (the rich group stays for the other
  items): Delete → menu → Done keeps it, confirm removes it from Groups. `fixtures:reset` restores both.
- **Human walk (on device):** keyboard types per page, the menu's look and dismiss.

## Out of scope

- Cover upload, AI suggestions, directory enforcement, restore (PROGRAM §Out of scope).
- invite-home, enrollment-home, enroll-program, groups-history destinations (P1).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | D8 makes an inverted age range a 400 for every PATCH caller | confirmed safe: 1.0 `AgeRangeInput.swift:16-23` limits min options to ≤ max and max to ≥ min; LeaderApp's twin (`group-home-modal.vue:241`) copies it; 1.0 `GroupHomePage.swift:1088` resends the stored range, which only fails on a row already inverted — none can be written after D8 |
| F2 | D3's two drafted descriptions and D9's menu-as-confirm are design gaps | route to `/ui2-resolve` (copy) and the design owner (P9 ratification) after the build |
| T1 | server: PATCH `/api/groups/:id` zod gains `memberDirectoryAccess: z.enum(['ALLOWED','NAMES_ONLY','NOT_ALLOWED']).optional()`; writes the enum and `memberDirectoryEnabled = (value == 'ALLOWED')`; D7 conflict → 400 (SC1) | blocking |
| T2 | server: PATCH `ageRange` refine — both bounds non-null and `min > max` → 400 `"Minimum age must not exceed maximum age"`, nothing written (SC2, D8) | blocking |
| T3 | iphone: `GroupPatch` with tri-state fields (absent · null · value) and `GroupActions.updateGroup(id:patch:)` — must encode `description: null`, `maxMembers: null`, `ageRange: null`, a bound as `null`, and `memberDirectoryAccess`; the existing labelled `updateGroup(...)` keeps its body for its callers (D6) | trailing |
| T4 | iphone: `GroupActions.deleteGroup` also clears `nextStudyByGroupId`, `historyByGroupId`, `groupDaysByGroupId`, `groupChartByGroupId`, `pendingJoinRequestsByGroupId`, `groupInvitesByGroupId` for the id, drops the group's rows from every `memberGroupsById` list, and refetches Home `following` when it lists the group (D10) | trailing |
| F3 | contract: data integrity — LeaderApp (`group-home-modal.vue:240`) and iPhone 1.0 (`EditGroupPage.swift:252`, `GroupHomePage.swift:1086`) send `memberDirectory` on every save; today's sync (`groups.ts:1046`) would turn a Names-only group into Not allowed on any unrelated edit there | resolved by D12 + SC3 (server only; no released-build change) |
| F4 | C-066 `ActionItem` has no `tone` (`ActionMenuOverlay.swift:43-47`), so D9's destructive row cannot render through the overlay as specced | resolved by D13 (T6) |
| F5 | Owner ruling G5b (confirmation says members lose access) has no slot in C-066 | D14 — deviation recorded, routed to the design owner with F2 |
| F6 | Base fixture groups carry only defaults (`base.ts:155-185`), so every edit page would open on Any age / Unlimited / Allowed and the walk could not see a stored value | T5; build-time risk on T5 — browse's fixture tests may assert the rich group's defaults (`server/fixtures/__tests__/`); adjust them in the same task |
| F7 | Render diff (audit item 8) not run: capture (:5951) not answering and this audit starts no server. All five edit screens, groups-detail and C-066 are BUILT MakeReadyUI previews (`Screens/Fields/*`, `Screens/Groups/GroupsDetailScreen.swift`, `ActionMenuOverlay.swift`) | build-time risk — T6's task re-captures C-066 after the tone change and diffs it against its frozen snapshot (default tone must be pixel-identical) |
| F8 | Design open questions disposed: OQ-shared-edit-field-1 → D1/D2 (group field list) · -3 → D5 · -5 → D2 `showsAISuggestions: false` (P11) · -6 → D4 (built screen behaviour) · -2, -4 → not in this child (phone/email; LinkButton colour) · OQ-groups-detail-007 → P9/G5b (label kept) · OQ-edit-options-custom-field-3 → D4 · OQ-C-046-1 → not touched (no new FieldGroup use). No pending owner notes on any item (`ui2-notes.mjs read`, 2026-10-27) | disposed |
| F9 | Maximum members may be saved below the current member count — the server never enforces `maxMembers`, the design shows no warning | rides as today's behaviour; enforcement is out of scope (PROGRAM) |
| R1 | repoint: none — §Replaced surfaces is empty; the feature fills `GroupDetailContainer`'s two no-op closures and replaces no live surface. Legacy 1.0 `EditGroupPage`/`GroupHomePage` stay for the 1.0 shell | nothing to repoint |
| T5 | server: `server/fixtures/screens/groups-detail.ts` `full` sets the rich group's description, `ageRangeMin/Max` 26/35, `maxMembers` 40, `memberDirectoryAccess` NAMES_ONLY + `memberDirectoryEnabled` false; Empty Group untouched (F6) | trailing |
| T6 | iphone: `ActionMenuOverlay.ActionItem.tone` passed to `ActionMenuRow` (D13), default `.standard` | trailing |

## Plan

The plan, with its code: `docs/features/ui2-groups-edit/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · PATCH directory access + age validation (SC1, SC2, SC3)
- Phase 1 · Task 2 · Fixture values on the rich group (T5) + contract freeze
- Phase 2 · Task 3 · C-066 destructive row tone (T6, D13)
- Phase 2 · Task 4 · GroupPatch + GroupActions.updateGroup(id:patch:) (T3, D6)
- Phase 2 · Task 5 · deleteGroup clears every group-keyed store (T4, D10)
- Phase 2 · Task 6 · GroupField + GroupFieldEditModel (D1–D5)
- Phase 2 · Task 7 · `.editGroupField` route + GroupFieldEditContainer + group page wiring (D1, D2, D5)
- Phase 2 · Task 8 · Delete Group through the red C-066 menu (D9, D13, D14)
