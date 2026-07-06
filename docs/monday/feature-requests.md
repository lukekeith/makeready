# Feature Requests (Priority 3)

The 12 items on the **Feature requests** board (`18417603408`), analyzed and grouped. These all need product/UX definition before build — except FR-6, which already exists. Duplicates are merged (12 tickets → 9 features).

---

## FR-1. Living studies: add content after publish/enroll
**Tickets:** 12270300418 + 12354285433 (duplicates) · also bug tickets 12268576962, 12268648378

Add lessons/content to a published + enrolled study; new lessons auto-join the calendar; missed dates don't stall the study; frequency preserved; members can join mid-study. **This is the feature-shaped answer to the snapshot-architecture bugs** (CF-3/4/5/6 in [code-fixes.md](code-fixes.md)): today enrollments are frozen copies made at enroll time with no re-sync path. Recommend landing the code-only lifecycle fixes first, then designing the snapshot-sync model here (see also UX-10 in [ui-ux.md](ui-ux.md)).

## FR-2. Schedule control: skip / insert a special lesson
**Tickets:** 12270300519

Insert a one-off lesson (current events, special dates) into an enrolled study; skip or reschedule any lesson. Same enrollment-schedule surface as FR-1/UX-10 — design together.

## FR-3. Lesson library & migration
**Tickets:** 12268474877

Move a lesson between studies, duplicate a lesson, move+copy without breaking study flow, compose a study from a lesson library. Pairs naturally with FR-4/FR-5.

## FR-4. Duplicate study
**Tickets:** 12268427023

Clone a study to re-target for a different audience. Server-heavy (deep copy of lessons/activities/read blocks — copy machinery similar to the enrollment snapshot logic in `enrollments.ts:365-503` already exists to model from); UI is a single action + naming.

## FR-5. Custom lesson templates
**Tickets:** 12268463248

Leader-defined lesson templates, scoped by default to the study they were created in.

## FR-6. Remove people from a group — **already built, close the ticket**
**Tickets:** 12303257933

Fully implemented end-to-end: `DELETE /api/groups/:groupId/members/:memberId` (`server/src/routes/group-members.ts:619`, soft delete + `MembershipEvent` audit trail), iPhone (`GroupActions.swift:459`, surfaced in `MemberProfilePage.swift:408` and `ChangeMembershipModal.swift:157` "Remove from group"), and web (`members.domain.ts:133`, `member-profile-drawer.vue:27`). If Scott can't see it, check his role against the `requireGroupManage('group.update')` gate — a discoverability/permission question, not missing functionality.

## FR-7. Guest lesson contribution ("solicitation of lesson in study")
**Tickets:** 12266593869

Private, non-shareable link lets a guest author lesson activities without the app; creator sets lesson count + direction; guest attribution kept with the lesson; submissions land "for review" with accept/reject (v2: feedback notes to the guest). Largest net-new feature in the list — new auth surface (token links), guest editor UI, and a review queue. The device-locked token pattern in `study-preview.ts` is a starting point for the link mechanics.

## FR-8. MakeReady video library in lessons
**Tickets:** 12303207603 + 12273864192 (duplicates)

Insert one of ~400 existing MakeReady social videos into a lesson; discover via tag search or transcript ("words spoken") search; architecture must generalize to per-org private content libraries. Building blocks exist: Cloudflare Stream for video, the media library, Claude-based tagging, and the semantic-search/embeddings stack (transcript search would follow the Bible-embedding pattern). Needs: video import/backfill of the 400, transcript extraction, and a picker UI.

## FR-9. AI note summaries & lesson chapters
**Tickets:** 12303272591 + 12303188320 (linked pair)

Chapters as structural markers inside a study; reaching a chapter end (or study end) triggers an AI-generated "how you've changed" summary of the member's notes; members can also browse old notes. Depends on the member-notes destination (UX-4) existing first. Claude integration already lives server-side for tagging/alt-text — the summarization call is incremental; the product design (tone, privacy, opt-in) is the real work.

---

### Suggested grouping for roadmap purposes

| Theme | Features | Shared foundation |
|---|---|---|
| Living studies & scheduling | FR-1, FR-2 (+ UX-10) | Enrollment snapshot re-sync model |
| Content reuse | FR-3, FR-4, FR-5 | Deep-copy service for lessons/studies |
| Content library | FR-8 | Media library + embeddings/tagging |
| Member growth | FR-9 (+ UX-4) | Member notes surface + AI pipeline |
| Collaboration | FR-7 | Token-link auth (from study-preview) |
| — | FR-6 | Done — close ticket |
