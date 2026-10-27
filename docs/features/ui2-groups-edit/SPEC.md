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
their PATCH behaves as today except an inverted age range now returns 400 instead of saving (1.0's
EditGroupPage cannot produce one — F1).

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
| D2 | Page per field (P10, shared-edit-field §2b) | name → `EditTextSingleFieldScreen` (title "Group name", 1–200 chars, not empty); description → `EditTextMultiFieldScreen` ("Description", ≤ 2000, empty saves `null`); visibility → `EditOptionFieldScreen` ("Visibility", options Private / Public with the §2b descriptions); ageRange → `EditOptionsCustomFieldScreen` (options "Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range", labels "Minimum age" / "Maximum age"); maxMembers → `EditTextSingleFieldScreen` ("Maximum members", number pad, digits only, `allowsEmpty`, empty = Unlimited, else an integer ≥ 1); directoryAccess → `EditOptionFieldScreen` ("Member directory access", Allowed / Names only / Not allowed with the §2b descriptions). Every page: `showsAISuggestions: false` (P11). Rejected: a multi-field form (the design is one field per page) | (assumed at brainstorm) |
| D3 | Copy | Titles, descriptions and option descriptions verbatim from shared-edit-field §2b; the two the design left blank: Maximum members — "The most members this group can have. Leave it blank for no limit."; Member directory access — "Choose what members of this group can see about each other." Both drafts routed to the design owner (F2) | (assumed at brainstorm) |
| D4 | Age range rules (P14) | Selection derived from the stored bounds (both null → Any age; equal to a preset → that preset; else Custom range). Save enabled only when the effective bounds differ from the stored ones and pass: each bound a whole number 0–120, min ≤ max when both set, Custom range with both inputs empty is invalid. Any age saves `ageRange: null`; otherwise `{min, max}` with an empty input sent as null. Rejected: an inline error message (C-046 has no error slot; the button stays disabled, OQ-edit-options-custom-field-3 default) | (assumed at brainstorm) |
| D5 | Save behaviour (P10) | Save → PATCH the one field → on success merge the response into `AppState.groups[id]` and `popIfTop`; saving = Save disabled + spinner, inputs read-only; failure = inline error "Couldn't save. Try again." above Save (age page: the shell error banner, its screen has no error slot), value kept; 401 → sign-out; 404 → pop to Groups (the group is gone or out of scope). Back discards silently | (assumed at brainstorm) |
| D6 | Patch that can clear (iphone) | `GroupActions.updateGroup` takes a `GroupPatch` whose fields are tri-state (absent · null · value) so `maxMembers: null` and `ageRange: null` reach the server; existing callers keep their behaviour. Rejected: separate clear methods (one per field) | (assumed at spec) 2026-10-27 |
| D7 | Directory write (E1, P8) | PATCH accepts `memberDirectoryAccess ∈ {ALLOWED, NAMES_ONLY, NOT_ALLOWED}` and sets `memberDirectoryEnabled = (value == ALLOWED)`; `memberDirectory` alone keeps today's sync; both sent and disagreeing (`true` with anything but ALLOWED, `false` with ALLOWED) → 400. The iPhone sends only `memberDirectoryAccess`. Rejected: Boolean-only writes (cannot store Names only) | (assumed at brainstorm) |
| D8 | Age validation (server, P14) | PATCH with `ageRange.min` and `ageRange.max` both non-null and `min > max` → 400 `{error: "Minimum age must not exceed maximum age"}`; nothing saved | (assumed at brainstorm) |
| D9 | Delete Group (P9) | `onDeleteGroup` presents C-066 `ActionMenuOverlay` via `actionMenuPresentation` under the shell's `.ui2OverlayHost()`: one row, glyph `trash`, label "Delete «group name»", tone `destructive`; Done = cancel. Confirm → `GroupActions.deleteGroup` → pop the Groups stack to its root; failure → banner "Couldn't delete the group", page stays. Rejected: native confirmation dialog (house rule) | Luke 2026-10-27 |
| D10 | After delete (E3) | `deleteGroup` removes the group from `AppState.groups` and, in the same call, from every store keyed by or listing it: group-detail stores (members, requests, enrollments, history, days, chart), `memberGroupsById` rows, and Home's followed-groups data (refetch `loadFollowing` if the group appears there). Rejected: leaving stale rows until the next refresh (a deleted group would still be tappable) | (assumed at brainstorm) |
| D11 | Who may edit/delete | Server unchanged: PATCH and DELETE already require `groupManageFilter`; the iPhone shows the same rows to anyone who can open the page (only managers can) | (assumed at spec) 2026-10-27 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `PATCH /api/groups/:id` (extended) | server | iphone | `requireAuth` + `groupManageFilter` | existing fields + `memberDirectoryAccess?` (D7); `ageRange` min ≤ max (D8) | unchanged (browse: + `creatorName`, `memberDirectoryAccess`) | 400 (D7 conflict, D8, existing zod) · 401 · 404 |
| `DELETE /api/groups/:id` (unchanged) | server | iphone | as today | — | `{success, message}` | 401 · 404 |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | EDIT | PATCH body `memberDirectoryAccess` (writes `Group.memberDirectoryAccess` + `memberDirectoryEnabled`) | §Contract | groups-detail "Member directory access" edit page (shared-edit-field §2b, three options); D7 | planned |
| SC2 | EDIT | PATCH `ageRange` validation | §Contract | edit-options-custom-field §3 validation (min ≤ max); D8 | planned |

**Data plan:** no schema change — the column landed in browse (SC1 there). Existing rows untouched.

## server

- `groups.ts` PATCH: zod `memberDirectoryAccess: z.enum([...]).optional()`; D7 sync + conflict check;
  D8 refine on `ageRange`.

## iphone

- **Route:** `UI2Destination.editGroupField(groupId: String, field: GroupField)` → `GroupFieldEditContainer`.
- **Model:** `GroupFieldEditModel` (pure): page state per D2/D3/D4, validate, `GroupPatch` builder.
- **Container:** `GroupFieldEditContainer` per D5, mirroring `MemberFieldEditContainer`.
- **Group page:** `GroupDetailContainer` wires `onEditField` (D1) and `onDeleteGroup` (D9).
- **State:** `GroupPatch` + `GroupActions.updateGroup(id:patch:)` (D6); `deleteGroup` per D10.

## Testing

- **server:** PATCH `memberDirectoryAccess` each value (enum + Boolean after), Boolean-only still syncs,
  D7 conflict 400, D8 400 and equal bounds OK, partial bounds, non-manager 404.
- **iphone:** `GroupFieldEditModel` tests — label → field, each page's initial state from a group,
  dirty/valid rules (D2 name/maxMembers, D4 every invalid case), patch bodies incl. nulls; `GroupPatch`
  encoding (absent vs null); D10 store cleanup; `ios:build-check --test`, swiftlint baseline.
- **Cross-app E2E (Fixtures):** edit each of the six fields on the rich group and see it on the page
  and in Groups; Age 30/20 cannot save; Maximum members blank → "Unlimited"; Directory "Names only"
  persists across a reload; Delete → menu → Done keeps it, confirm removes it from Groups.
- **Human walk (on device):** keyboard types per page, the menu's look and dismiss.

## Out of scope

- Cover upload, AI suggestions, directory enforcement, restore (PROGRAM §Out of scope).
- invite-home, enrollment-home, enroll-program, groups-history destinations (P1).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | D8 makes an inverted age range a 400 for every PATCH caller | audit confirms web admin / LeaderApp / 1.0 EditGroupPage never send one |
| F2 | D3's two drafted descriptions and D9's menu-as-confirm are design gaps | route to `/ui2-resolve` (copy) and the design owner (P9 ratification) after the build |
