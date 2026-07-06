# UI/UX Work (Priority 2)

Items that need new or changed interaction design before they can be built. Documented here so nothing is lost; each cites the monday ticket(s) and the code that grounds it. Ordered by how much they block real member/leader usage.

---

## UX-1. "Open Lesson" should give leaders a preview, not the member join funnel
**Tickets:** 12268645785, 12344861586 ("a fancy way to preview")

Tapping *Open Lesson* on an enrollment schedule opens the **member join URL** (`EnrollmentSchedulePage.swift:420-444` → `GET /lesson-schedules/:id/invite` → `enrollments.ts:2382` returns `app.makeready.org/join/study/{id}`), which drops the leader into phone verification. A complete no-auth, token-based leader preview already exists (`server/src/routes/study-preview.ts`, web routes `web.php:78-99`) — it's just not wired to this button.

**Decision needed:** is *Open Lesson* "preview as leader" (route to the existing preview) or "share with members" (rename + copy-link affordance)? Likely both, as two distinct actions. Implementation is small once decided.

## UX-2. Input/note activity: explicit Save/Done affordance above the keyboard
**Tickets:** 12344861586, 12297336134 ("stuck until I accidentally swiped down the keyboard")

The input step auto-saves (debounced, `input-step.vue:71-93`) but renders **no** button; the only forward control is the header chevron (`member-lesson-header.vue:106-115`), which the on-screen keyboard hides. Members feel trapped and get no "saved" signal.

**Design:** a sticky Done/Next control that stays above the keyboard (keyboard accessory or sticky footer) + a subtle saved indicator. Small scope; resolves the most-repeated member complaint.

## UX-3. Video activity: in-content Next + clearer completion message
**Tickets:** 12415667946

The "strange message" is the nav-pill status ("Watch the video" / "Video complete", `video-step.vue:32-50`); the step is non-scrolling (`lesson-island.scss:77-86`) and forward navigation is again only the header chevron, active after 90% watched. Design an explicit Continue button in the step and reword the status copy. (Shares the "single top-only affordance" root cause with UX-2 — one sticky-Continue pattern could resolve both.)

## UX-4. Member notes: a real destination to read/edit past notes
**Tickets:** 12344861586 ("no way to edit my existing note or even read it again")

The Notes tab in the member bottom nav is a dead link (`navigation-island.vue:152`, `href="#"` — Schedule and Search likewise). Notes are only reachable transiently inside a lesson. Needs a designed member notes screen + route. *Related code-only companion:* the highlight note editor bottom-sheet has no keyboard avoidance (`exegesis-highlight-menu.vue:121-148`).

Note: the reported **data loss** ("highlighting over a note deleted my other note") is already guarded on web (`edit-exegesis-activity-pane.vue:173-174` refuses overlaps); if it reproduces, it's the iPhone path — worth a quick check before designing anything.

## UX-5. iPhone read editor: formatting/heading toolbar pinned to the keyboard
**Tickets:** 12297336134 ("can't scroll back up to the H1/H2/H3 selection")

The heading picker is an inline toolbar at the top of each editor block (`RichTextInput.swift:314-369`); keyboard auto-scroll keeps pulling the view back to the caret, so the toolbar is unreachable. Design: move formatting into a keyboard `inputAccessoryView` (persistent bar above the keyboard). Interaction redesign, not a one-liner.

## UX-6. Exegesis highlight selection & editing (iPhone leader)
**Tickets:** 12325580210 ("clunky… impossible to edit the highlight after it's selected"), 12297338039 (tap-hold vs double-tap)

Exegesis uses native long-press/drag selection (`ExegesisVerseView.swift`, `usesNativeTextSelection`); read lessons already use the lighter single-tap-per-verse model (`SelectableLockedBlockView.swift:66-70`). Design decision: adopt tap-per-verse (or double-tap-word) selection for exegesis and add an edit path for an existing highlight. Interacts with the scroll-freeze machinery — treat as an interaction-model change.

## UX-7. Activity-type naming: merge/rename "Read (bible)" and "Exegesis"
**Tickets:** 12297345805, 12268478769

Scott's proposal: *Exegesis* → **"Add bible verse"**, *Read* → **"Custom text"**, and combine the two entry points; also make the + affordance obvious ("start without the custom text field up"). Pure renaming is a copy change, but combining the two activity types and reworking the add-content entry point is a product/UX call that touches both editors.

## UX-8. Study sharing model ("mark for org consumption")
**Tickets:** 12344861586

The proper fix behind the enrollment permission gap (CF-2 in [code-fixes.md](code-fixes.md)): a `sharedWithOrg`-style flag on `StudyProgram` (no such field exists — `schema.prisma:831-859`), a creator-facing toggle, and enrollment rules = own studies + org-consumable ones. Schema + UI feature; the code-only scoping in CF-2 should land first.

## UX-9. Unpublish warning/confirm dialog
**Tickets:** 12268464531

Companion to CF-6: once the server blocks (or cascades) unpublish-while-enrolled, the clients need a confirm dialog explaining consequences ("this will unenroll N groups"). Small design, both iPhone and web admin.

## UX-10. Enrollment schedule management (change days/time/frequency, reschedule, republish)
**Tickets:** 12268648378, 12270302158, feature requests 12270300418/12354285433/12270300519 overlap

Leaders cannot change an enrollment's days/time/frequency after creation, and can't navigate back to the publish/enrollment screen to re-publish or adjust. The server already has a per-lesson schedule-add endpoint (`enrollments.ts:4062`) but no edit-cadence capability or screen to host it. This is the largest UX cluster — schedule editing screen + navigation back to enrollment management — and overlaps heavily with the "living studies" feature requests. Design it once, covering: edit cadence, reschedule/skip a lesson, and re-open the publish screen.

## UX-11. Reading experience polish batch (member)
**Tickets:** 12344966853, 12081607589, 12081585156

Smaller design opinions, grouped for one pass:
- Reading surface should look like paper — white page, black text, serif; highlights yellow/blue/pink; current blue highlight color reads wrong on black (12344966853).
- Reading themes "too much for v1" — consider hiding the theme picker (12344966853).
- Vertical centering nit on one screen (12344966853).
- Post-unenrollment icon reads like an error state (12344966853).
- Join form: birthday → birth year only; minimum-age enforcement should follow the group age range or the age range should be removed (12344966853; enforcement itself is server logic).
- Group page: badge/status bar showing "group is enrolled in study X and it's active" instead of ambiguous activity posts (12081607589).
- 12081585156 (marked fixed Jun 11) has three newer complaints — "too many navigation elements", "can't get to the text as a member" — that likely fold into UX-11/CF-10; re-verify before closing.
