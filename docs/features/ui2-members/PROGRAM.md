# ui2-members — program
> tier: program · design ref `--ui2 members-home,members-profile,shared-edit-field` (intake 2026-10-25)

## Overview

Leaders get a working **Members** tab in the iPhone UI 2.0 shell: search and filter the org's member
directory, push into any member's detail page, and edit that member's fields one field per page —
every push using the iOS system push the owner showed in his Robinhood reference (measured at 60fps:
the new page enters from the right on one critically-damped spring, ~⅔ across in 67ms and settled by
~420ms; the page beneath shifts left ~30% of the width and dims ~10%). All three screens and their 22
components are already built as MakeReadyUI previews; this program wires them to live data and adds
the shell's push, which ~20 other built pushed pages will reuse.

Intake record: `.builder/ui2-members/brainstorm.md` (12 of 12 settled; 6 design-vs-code contradictions
found and ruled).

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | ui2-members-browse | lg | server+iphone | A leader opens Members, searches and filters the directory, and pushes into any member's full detail page (identity, fields, activity, groups, program progress) with the reference push and swipe-back | — |
| 2 | ui2-members-edit | md | server+iphone | On a member's detail page the leader taps a field and edits it on its own pushed page — email, phone, emergency contact name and phone, address, gender, birthday — and Save pops back with the new value | 1 |

Both wait on `home-dashboard-data` merging into `ui2-preview-build` (its shell changes — TopNav drag
fix, pull-to-refresh, `HomeSectionLayout` — are what child 1 extends).

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | How a page is pushed (OQ-C-040-2) | A `NavigationStack` inside the shell's content area is the shell's one push mechanism: the system navigation bar is hidden, every pushed page draws its own C-040 PageHeader, back = pop, interactive left-edge swipe-back stays enabled (the hidden-bar workaround is a build-time risk). The TopNav hides while any page is pushed; the TabBar stays. The system push is the motion — no custom curve. Why: the reference measures as the system push; swipe-back, VoiceOver and the interruptible spring come free. Rejected: a custom push container — rebuilds the system push, swipe-back the risky part | Luke 2026-10-25 |
| P2 | Members screen chrome | MembersHomeScreen drops its own C-019 row; the shell's TopNav is the only one (ui2-shell D11) | (assumed at brainstorm) |
| P3 | Field identity | A C-042 tap reports a field key (`email`, `phone`, `birthday`, `gender`, `address`, `emergencyName`, `emergencyPhone`), never the display label | (assumed at brainstorm) |
| P4 | Organization and Role rows | Read-only: Organization = the member's org name(s); Role = "Group leader" when the member leads any group, else "Member". Neither tappable; chevron hidden. Rejected: removing Organization; a new editable org role (new column + enforcement) | Luke 2026-10-25 |
| P5 | Email indicator | No Verified/Unverified badge on Email until email verification is its own feature. Rejected: building email verification now | Luke 2026-10-25 |
| P6 | Emergency contact | Two fields — `Member.emergencyContactName` and `Member.emergencyContactPhone` (new nullable columns, child 1 adds and shows them; child 2 writes them), shown as two C-042 rows "Emergency contact" / "Emergency phone". Rejected: one free-text field | Luke 2026-10-25 |
| P7 | Address | `Member.address` — new nullable text column, multi-line (child 1 adds and shows; child 2 writes) | Luke 2026-10-25 |
| P8 | Fixtures | Fixture members carry email, birthday, gender, address, emergency name/phone, and photos taken from the d2m image set's `avatar`-tagged images (the D22 image path). Rejected: sparse members | Luke 2026-10-25 |
| P9 | Phone edits | A leader's phone edit saves the number (unique, E.164) and resets `phoneVerified` → red "Unverified" until the member verifies at next sign-in. Rejected: read-only for leaders | Luke 2026-10-25 |
| P10 | Birthday edit | A new shared-edit-field `date` arrangement (native date wheel), built from this proposal and routed to `/ui2-resolve` for the design to draw. Rejected: text with a date mask | Luke 2026-10-25 |
| P11 | Edit-page states | Back with unsaved changes discards silently; saving = Save disabled + spinner; save-failed = inline error above Save, value kept (OQ-shared-edit-field-3 proposals) | Luke 2026-10-25 (back) · (assumed at brainstorm) (saving, failed) |
| P12 | Members list data | `GET /api/organizations/:id/members` gains per-member `groupCount` and `joinedAt` and `groupId` / `leaderId` filters (additive). Rejected: N+1 assembly on the phone | Luke 2026-10-25 |
| P13 | Engagement | New `GET /api/members/:id/engagement`: per enrolled program — title, cover, completed count, hours, % progress. Rejected: header-only "0 programs" for now | Luke 2026-10-25 |
| P14 | Member activity rail | The day rail reuses `/api/home/days` with an added `memberId` filter (additive) | (assumed at brainstorm) |

## Out of scope

- Email verification; the member-side phone re-verification flow (existing SMS flow, unchanged).
- Membership "add to group", Engagement "enroll", group-row tap (OQ-members-profile-2 — frames pending).
- Group / program / age-range field edits (EditOptionsCustomFieldScreen is wired with group fields).
- AI suggestions on any field (OQ-shared-edit-field-5; the endpoint is an API-GAP).
- The web client — UI 2.0 leader screens are iPhone-only.
