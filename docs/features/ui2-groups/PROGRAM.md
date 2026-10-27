# ui2-groups — program
> tier: program · design ref `--ui2 groups-home,groups-detail,edit-text-single-field,edit-text-multi-field,edit-option-field,edit-options-custom-field` + `create-group` (d2m era 2.0, intake 2026-10-27)

## Overview

Leaders get a working **Groups** tab in the iPhone UI 2.0 shell. They can search and filter the groups they manage, create a new group by name, and push into any group's page. That page shows the cover, quick stats, the six settings, the next lesson, the group's daily activity, members with any join requests, enrollments and the latest history. Each setting then edits on its own pushed page, and Delete Group archives the group behind a confirmation.

Every screen and component is already built as a MakeReadyUI preview in d2m. This program wires those previews to live data through app-side containers, and adds the server data the design reads that does not exist yet. The push, the field-edit pattern and the invite flow are reused from ui2-members and invite-member.

Intake record: `.builder/ui2-groups/brainstorm.md` — 8 of 8 settled. It found 7 places where the design and the code disagree, and each has a ruling.

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | ui2-groups-browse | lg | server+iphone | A leader opens Groups, searches and filters, creates a group by name, and pushes into any group's live page: stats, settings values, next lesson, activity rail and chart, members and join requests, enrollments and the latest 5 history events. Member rows open the member page, and Members `add` opens invite | — |
| 2 | ui2-groups-edit | md | server+iphone | On a group's page the leader taps any of the six settings and edits it on its own pushed page (name, description, visibility, age range, maximum members, member directory access), and Save pops back with the new value. Delete Group archives the group after a red action-menu confirm | 1 |

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | Scope of exits | **Wired:** groups-home, groups-detail, the six field edits, create-group, member row → `.memberDetail`, Members `add` → `.inviteMember(groupId)`, and members-profile group row → groups-detail. **Inert (no-op):** join-request rows (invite-home), enrollment rows and the LessonCard (enrollment-home), Enrollments `add` (groups-enroll-program), Timeline "All history" (groups-history), and the chart pan. Rejected: groups only (it leaves no way to create a group); also wiring invite-home; everything designed (that is a program of its own) | Luke 2026-10-27 |
| P2 | Groups-home chrome | `GroupsHomeScreen` drops its own C-019 row, because the shell's TopNav is the only one (ui2-shell D11, ui2-members-browse D4). ~~This is routed to `/ui2-resolve` and is a prerequisite of child 1's iPhone phase. Builder never edits `iphone/MakeReadyUI/`~~ **Superseded 2026-10-27 (ui2-groups-browse D2):** the build removes the row itself (ui2-members-browse D4 precedent) and routes the change to `/ui2-resolve` afterwards so d2m matches; not a prerequisite | (assumed at brainstorm) · superseded Luke 2026-10-27 |
| P3 | Create-group entry | The shell TopNav `+` on the Groups tab opens create-group. This follows the precedent of the Members `+` opening invite (owner, 2026-10-26). A successful Create replaces the form with the new group's groups-detail (OQ-create-group-001 default). The creating and create-failed states use the OQ-create-group-002 defaults | (assumed at brainstorm) |
| P4 | Groups-home data | Filtering and sorting run on the phone, over the cached `AppState.groups`, in alphabetical order (OQ-groups-home-1 default). The Leaders filter matches the group's creator. `GET /api/groups` gains `organizationId` and `organizationName` (additive). The Orgs chip lists `GET /api/organizations/my/organizations` and shows only for callers in more than one org. Rejected: server-side filter params, which are unneeded at this list size | (assumed at brainstorm) |
| P5 | Activity data | The day rail uses `GET /api/home/days` with a new `groupId` filter beside `memberId` (additive), mapped the same way as Home and the member page. The chart uses `POST /api/analytics/query` with `filters.groupId`, `scheduled_lessons` and `lesson_completions` by `day`. Rejected: a rail that shows counts only (no minutes); leaving the section empty | Luke 2026-10-27 |
| P6 | Timeline source | New `GET /api/groups/:id/history?limit=`. It merges `MembershipEvent` rows with the group's `trackActivity` rows, newest first, and is access-checked with `groupManageFilter`. Each event carries `occurredAt`, a server-formatted `text`, the `highlight` span (a member or event name) and a `kind`. `POST /groups/:id/cover-image` starts calling `trackActivity`. groups-detail asks for `limit=5`, and groups-history reuses the endpoint later. Rejected: merging on the phone (the logic would be duplicated later); membership events only (falls short of the design) | Luke 2026-10-27 |
| P7 | Lessons up next | `GET /api/groups/:id/next-study` gains the lesson `title` (`LessonSchedule.title`) and a `thumbnailUrl` per activity (additive). C-063 shows the title, the relative day, the program name, and slides for the first 3 activities, each with an image when one exists and otherwise a label only. A 204 response renders "No lessons scheduled". Rejected: "Day N" with label-only slides; leaving the section empty | Luke 2026-10-27 |
| P8 | Member directory access | New `Group.memberDirectoryAccess` enum: `ALLOWED`, `NAMES_ONLY`, `NOT_ALLOWED`. It is backfilled from `memberDirectoryEnabled` (true → `ALLOWED`, false → `NOT_ALLOWED`). Every write keeps the Boolean in sync (`ALLOWED` = true, otherwise false), so the web admin, LeaderApp and legacy iPhone keep working. Nothing is enforced, as today. Child 1 reads and shows the value; child 2 writes it. Rejected: two options in the design (drops "Names only"); also enforcing it (that crosses into the web member pages) | Luke 2026-10-27 |
| P9 | Delete Group | `onDeleteGroup` presents the built C-066 ActionMenuOverlay through the shell's overlay host. It has one destructive row, "Delete «Group name»", plus Done to cancel. Confirming calls `DELETE /api/groups/:id` (archive, `isActive=false`), removes the group from the store, and pops to groups-home. The button label stays "Delete Group" (OQ-groups-detail-007), and no restore is promised. Approval of this as the 2.0 confirm pattern is routed to the design owner. No native dialog is used. Rejected: designing a confirm first, with Delete inert meanwhile; the label "Archive Group" | Luke 2026-10-27 |
| P10 | Field identity and edit pages | A C-042 tap maps the display label to a `GroupField` key (`name`, `description`, `visibility`, `ageRange`, `maxMembers`, `directoryAccess`), via a new `.editGroupField(groupId:field:)` destination. This mirrors the member pattern: a pure model, a container, `popIfTop`, and an inline error on save failure. **Maximum members** uses edit-text-single-field with a number pad; blank = Unlimited (`null`) and the minimum is 1. Back discards silently. Saving shows Save disabled with a spinner. A failed save shows an inline error and keeps the value (OQ-shared-edit-field-3 proposals) | (assumed at brainstorm) |
| P11 | AI suggestions | Hidden on name and description (`showsAISuggestions: false`), because there is no field-suggestion endpoint. This is the same call ui2-members made | (assumed at brainstorm) |
| P12 | Access checks | `GET /api/groups/:id/members` and `/membership-history` gain `groupManageFilter` checks. Callers outside the group's manage scope get 404, the same as every other group route | (assumed at brainstorm) |
| P13 | Leader name | `GET /api/groups/:id` and the PATCH response include `creatorName` (additive), with the leader being the creator. The cover is display-only, because the design has no way to upload one | (assumed at brainstorm) |
| P14 | Age range validation | PATCH rejects `ageRange.min > ageRange.max` with a 400. Edits always send both bounds | (assumed at brainstorm) |
| P15 | Fixtures | Each new UI2 screen adds its `server/fixtures/screens/<id>.ts` layer (ui2-fixtures rule). Groups get join requests, a next lesson with activity thumbnails, membership, setting and cover history, and enough lesson completions to fill the activity chart | (assumed at spec) 2026-10-27 |

## Out of scope

- Wiring for invite-home, enrollment-home, groups-enroll-program and groups-history (P1). Those taps stay inert.
- Cover-photo upload from the group page.
- Enforcing member directory access for members.
- Restoring an archived group, and an archived-groups list (API-GAP noted in d2m).
- AI suggestions on group fields.
- The web client. UI 2.0 leader screens are iPhone-only, and web and LeaderApp keep using the Boolean `memberDirectory`.
- Re-speccing groups-detail in d2m (`updateNeeded`: its Figma ref was re-added after the spec). A drift check is recommended before child 1's iPhone phase; it is the design owner's job.
