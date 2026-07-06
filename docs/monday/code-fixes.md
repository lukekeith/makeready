# Code-Only Fixes (Priority 1)

Fixes that require no new UI/UX design — server logic, authorization, data lifecycle, CSS/layout, and copy. Ordered by severity. Each entry cites the monday ticket(s) it resolves (see [tickets.md](tickets.md)) and the code it was traced to.

---

## P0 — Authorization gaps (server)

### CF-1. Any org role-holder can delete another leader's study
**Tickets:** 12325580210 (update Jul 5: "I can delete studies that aren't mine")

- `DELETE /api/programs/:id` (`server/src/routes/programs.ts:1184`) guards with `mutationFilter(userId)` (`programs.ts:57-65`), which allows `creatorId == user` **OR** `organizationId IN getManageableOrgIds(user)`. `getManageableOrgIds` (`server/src/services/permission.ts:305-313`) includes any org where the user holds *any* role — including plain Group Leader. So any leader can soft-delete any study in their org. Cross-org deletion is already blocked (404).
- **Fix:** restrict the delete handler to `creatorId: userId` (optionally still allow org Owner / Super Admin). Scope the change to the delete route — `mutationFilter` is shared with PATCH and nested mutations, which may legitimately stay org-scoped.
- Delete is exposed in iPhone (`ProgramActions.swift:280`, `MainLibrary.swift:1198`, `StudyProgramHome.swift:755`) and web admin (`leader-library.store.ts:439`); no UI change needed.

### CF-2. A leader can enroll their group in anyone's study
**Tickets:** 12344861586 ("I can enroll my group in someone else's study")

- `POST /api/enrollments` (`server/src/routes/enrollments.ts:125`) checks the *group* with `groupManageFilter` (`:150`) but looks the *study* up with only `{ id, isActive: true }` (`:161-165`) — the comment even says "Any active program can be used for enrollment." Only gates are `isPublished` (`:193`) and has-lessons (`:201`). No creator, org, or sharing check; even a cross-org study id supplied directly would be accepted.
- There is **no sharing flag** in the schema today (`StudyProgram`, `schema.prisma:831-859`, has only `isPublished` / `organizationId` / `creatorId`).
- **Fix (code-only minimum):** scope the study lookup to the caller's own studies and/or their org (mirror `accessFilter`, `programs.ts:39-46`). The full requested model ("creator marks the study for org consumption") is a schema+UI feature — tracked in [ui-ux.md](ui-ux.md#ux-8).

---

## P1 — Study lifecycle & data integrity (server)

Background that drives four tickets: **enrollment snapshots lessons at enroll time** (`enrollments.ts:246-503` copies lessons into `LessonSchedule`/`ScheduledLessonActivity` rows). Members render the snapshot; nothing re-syncs it when the live study changes, and enrollment lifecycle is not tied to the program's publish/active state.

### CF-3. Perpetual "incomplete" enrollment status
**Tickets:** 12268464531 ("residual 'incomplete' after unpublish/republish")

- The three enrollment read endpoints compute `totalLessons` from the **live** `studyProgram.days` but `completedLessons` from the **snapshot** (`enrollments.ts:951-952`, `:1232-1233`, plus `:1030-1088`). Editing the study after enrollment makes the denominator drift, so a member who finished every scheduled lesson still reads incomplete.
- **Fix:** derive `totalLessons` from `enrollment.lessonSchedules` count in all three endpoints. Pure server change.

### CF-4. Deleted study still renders for member and leader
**Tickets:** 12415690223, contributes to 12344966891

- Study delete is a soft delete (`programs.ts:1197-1200`, sets `isActive: false`) that touches nothing else, and **none** of the enrollment-list endpoints filter on the program's active state (member: `enrollments.ts:855`, `:1030`, `:1147`; leader: `:1323-1340`). The dead giveaway: the web store filters `e.isActive !== false` (`leader-group-home.store.ts:357-359`) but `Enrollment` has no such field — a no-op guard for behavior that was never implemented server-side.
- **Fix:** add `studyProgram: { isActive: true }` to the four list endpoints' `where`, and/or cascade enrollment removal when a program is soft-deleted.

### CF-5. Added days never reach enrolled members
**Tickets:** 12268576962 ("calendar breaks when unpublishing")

- `PATCH /api/programs/:id` day-increase creates new `Lesson` rows (`programs.ts:935-960`) but never back-fills `LessonSchedule`/`ScheduledLessonActivity` for existing enrollments. The only propagation path is a manual, per-lesson `POST /enrollments/:id/schedules` (`enrollments.ts:4062`).
- **Fix:** on days-increase, insert snapshot rows for every active enrollment of the program (reuse the copy logic at `enrollments.ts:365-503` and the calendar walk at `:4141-4169`).

### CF-6. Unpublish is a silent no-op for enrollments
**Tickets:** 12268464531 ("I can unpublish without an error or warning; it should kick all enrolled groups out")

- Unpublish just flips the flag (`programs.ts:907-910`, `:984-992`); there is no cascade, no 409, and read endpoints ignore `isPublished`.
- **Fix (code-only minimum):** reject unpublish with 409 when `_count.enrollments > 0` (count already loaded at `:1013-1015`), or cascade-unenroll per Scott's stated expectation. A confirm/warning dialog on top of the 409 is a small UX addition ([ui-ux.md](ui-ux.md#ux-9)); the enforcement itself is server-only. **Product decision needed: block vs. kick-out.**

### CF-7. Stale enrollments in client caches; error on tapping a dead enrollment
**Tickets:** 12344966891 ("unenrolled group still shows up"; "error selecting the enrollment I previously deleted")

- Server delete cascades cleanly (`enrollments.ts:1831-1858`), but the iPhone persists enrollment lists to disk cache-first (`EnrollmentActions.swift:95-128`) and the web store short-circuits refetch via `loadedGroupIds` (`enrollments.domain.ts:70-83`). A stale card then 404s on `GET /enrollments/:id` (`enrollments.ts:677`) or on `completion-stats`, which *does* filter soft-deleted programs (`:1646-1656`) — the one endpoint that does, producing the visible error.
- **Fix:** iPhone — drop the persisted enrollment on 404 in `getEnrollmentDetails` and force-refresh the list on group-home load; web — clear `loadedGroupIds` / prune `enrollmentsByGroup` after unenroll. Pairs with CF-4.

### CF-8. Swipe-to-unenroll errors for non-creator leaders
**Tickets:** 12297338039 ("groups > enrolled > swipe left > trash → error, doesn't unenroll")

- `GET /enrollments/:id/unenroll-info` has **no** ownership filter (`enrollments.ts:4691-4735`), so the modal opens for anyone; but `DELETE /enrollments/:id` (`:1831-1858`) requires `enrollmentManageFilter` (`permission.ts:337-347`) — enrollment creator, group creator, or manageable org role. A leader who passes the first but fails the second gets a 404 → "Failed to unenroll" (`EnrollmentsListPage.swift:329-361`).
- **Fix:** apply the same filter to both endpoints (either allow the delete or hide the affordance), and surface the real error message.

---

## P1 — Join/validation flow (client + server)

### CF-9. Study-join session stores a null organizationId
**Tickets:** 12268645785 ("still getting an error joining a study with my phone number"; "changes won't save")

- `StudyJoinController::showStep` reads `$lesson['organizationId']` at the top level (`client/app/Http/Controllers/StudyJoinController.php:62`), but the API nests it as `lesson.group.organizationId` (`enrollments.ts:2116-2127`). The null flows into `verify-phone` / `confirm-verification` (`StudyJoinController.php:146-149`, `:184-189`), whose schemas treat it as optional (`members.ts:419-424`, `:636-648`) — so members verify without being attached to the study's org.
- The visible **validation error** is the E.164 regex message (`members.ts:420-422`) surfaced raw by the keypad island (`join-phone-island.vue:104-106`); any non-US/non-10-digit entry hits it.
- **Fix:** read `$lesson['group']['organizationId']` (or return a top-level `organizationId` from the API); humanize the phone-format error. The related "Open Lesson sends leaders into the member join funnel" is a routing/product item — [ui-ux.md](ui-ux.md#ux-1).

---

## P1 — Member web layout/CSS (client)

### CF-10. Exegesis step hides the verse top & bible address under the header
**Tickets:** 12415662995, 12386101354 ("navigation covering the verse")

- `exegesis-step.vue:607` hardcodes `padding: 120px 16px 24px` (and a 120px fade mask at `:611-625`) while the header is dynamic and publishes its real height to `--member-lesson-header` (`member-lesson-header.vue:10-17`). The read step already consumes the variable (`read-step.vue:113`); exegesis was never migrated and ignores `safe-area-inset-top`.
- **Fix:** replace the hardcoded inset/mask with `calc(var(--member-lesson-header, 200px) + 16px)` + safe-area, mirroring `read-step.vue`.

### CF-11. Bottom nav sits under the mobile URL bar / home indicator
**Tickets:** 12297336134 ("URL bar covering the nav text"), 12344966853 ("can't get to the bottom-most story — always half covered")

- `.GroupHome__navigation` is `position: fixed; bottom: 0` (`group-home.scss:69-76`), `.Navigation` has no `env(safe-area-inset-bottom)` padding (`navigation.scss:1-10`), and the page uses `min-height: 100vh` not `dvh` (`group-home.scss:4`). The viewport meta already enables safe-area (`layouts/home.blade.php:7`) — it's just unused.
- **Fix:** add safe-area bottom padding to `.Navigation`, switch the shell to `100dvh` (the lesson player already does this at `lesson-island.scss:8-9`).

### CF-12. Legacy read content overlaps the bottom control band
**Tickets:** 12268578241 ("covering text — old study, holdover error")

- Modern themed blocks reserve footer space via `--member-lesson-footer` (`ActivityPreviewPlayer.vue:690-702`), but legacy `readContent` renders through the synthetic `legacy-read` / `themeSlug: 'none'` path (`read-step.vue:174-186`) which doesn't honor the same bottom inset.
- **Fix:** apply the same footer padding to the legacy/no-theme path. Confirm against one of Scott's old studies.

### CF-13. "Your studies" copy → "lessons"
**Tickets:** 12268465402

- Member group-home heading `Your studies` at `resources/views/pages/group-home.blade.php:174-176` (per-card counts already correctly say "lessons", `member-studies-island.vue:147`). If Scott's screenshot is the leader dashboard instead, the label is `home-dashboard.vue:54`. One-line copy change once the screenshot is checked.

---

## P1 — iPhone leader app (code-only, some need on-device repro)

### CF-14. Long read/exegesis title → generic "Couldn't save changes"
**Tickets:** 12297338039

- Server caps titles at 200 chars (`programs.ts:1827-1828`, also `:2005-2006`, `:3547`); the iPhone title inputs have no max length (`EditReadActivityPage.swift:404-410`, `EditExegesisActivityPage.swift:141-146`) and the 400 surfaces as a generic banner (`EditReadActivityPage.swift:1186-1193`).
- **Fix:** enforce `maxLength: 200` client-side and surface the server's message.

### CF-15. Can't highlight the last verse of an exegesis (error) — needs repro
**Tickets:** 12297338039

- Server rejects overlapping highlights with a 400 (`programs.ts:2816-2819`). A last-verse selection extends to the very end of the block text (`VerseSelectionLogic.parseVersePositions`), so a one-char brush against an adjacent highlight (trailing newline/whitespace) trips the overlap check; client shows "Couldn't save the highlight" (`EditExegesisActivityPage.swift:696-705`).
- **Fix:** verify the failing range on-device; trim trailing whitespace from committed ranges or make the server check exclusive at boundaries.

### CF-16. Phantom text in the exegesis/read editor — needs repro
**Tickets:** 12297338039 ("text I didn't insert, like it's saving every second")

- Prime suspect: the markdown↔attributed round-trip in `RichTextInput.swift:70-104` re-converts on every change with a fragile two-flag guard; if the round-trip isn't idempotent it re-emits drifted content (draft written per keystroke at `EditExegesisActivityPage.swift:1055-1066`). Secondary: the native-selection preview machinery mutating `textStorage` (`ExegesisVerseView.swift:653-676`, `:761-811`).
- **Fix:** make the round-trip idempotent / dedupe emissions. Debug on-device.

### CF-17. Screen stuck after member transfer — needs repro
**Tickets:** 12297338039 ("after successful transfer the screen gets stuck, restart needed")

- `ChangeMembershipModal` uses a two-stage dismiss (`ChangeMembershipModal.swift:188-198`, `:438-447`) → `MemberProfilePage.performTransfer` (`:432-447`) → `GroupActions.transferMember` (`GroupActions.swift:492-532`), which also **omits `state.persist()`** unlike sibling actions. Likely a lingering overlay scrim capturing touches.
- **Fix:** verify which overlay remains mounted; fix the teardown and add the missing persist.

### CF-18. Image optimization — answer the question, close two small gaps
**Tickets:** 12271625826

- **Already optimized:** every active ingest path resizes via sharp — media upload caps the "original" at 1200px JPEG q85 with 400px/150px variants (`media.ts:1208-1218`); program/group/event covers same scheme (`programs.ts:3440`, `groups.ts:1203`, `events.ts:1360`); avatars 512×512 webp (`members.ts:1352`).
- Two closable gaps: legacy `storage.ts uploadMemberAvatar` (`storage.ts:118-169`) stores originals with no resize (likely dead code — confirm and remove), and the URL-register endpoints (`media.ts:601-667`, `:1367-1443`) accept client-supplied URLs with no processing.
- **Action:** reply on the ticket with the answer; delete/guard the legacy paths.

### CF-19. Empty study for members after rearranging lessons then enrolling — needs repro
**Tickets:** 12297336134, 12386101354 ("empty lessons")

- The client renders whatever the enrollment API returns and silently drops lessons with empty ids (`group-home.blade.php:42-55`), with no empty-state (`member-studies-island.vue:51-96`). The snapshot copy at enroll time (`enrollments.ts:282-503`) is where a reorder-then-enroll could produce an empty/broken lesson set — needs a reproduction to pin down.
- **Fix:** repro reorder→enroll against the snapshot logic; add a client empty-state ("No lessons yet") instead of a silent blank as a guardrail.
