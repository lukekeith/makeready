# QA checklist — Edit enrollment (monday#12270302158)

Manual interaction/E2E script for the iPhone edit-enrollment feature. The
*logic* is unit-covered (`EnrollmentEditModelTests`, 14 tests) and the *server*
is integration-covered (`enrollment-edit.test.ts`, 33 tests, 100% line/func).
This checklist covers the **choreography + end-to-end** that automated tests
don't: slide transitions, staging/cancel, and the real server round-trip.

**Setup:** run against local server (`:3010`) with a signed-in leader who owns a
group with at least one **enrolled** study. Have a second group and a second
published study available (for the group/study swap steps).

## 1 — Tap → action menu
- [ ] From a group's **Enrollments** list, tap an enrollment → a **slide-up menu** appears with exactly two rows: **Edit lessons** and **Edit enrollment** (no Open/Share/Delete; header shows the study name).
- [ ] Repeat from a **study program's Enrollments tab** (`ProgramHomePage`) → same menu.
- [ ] **Edit lessons** → opens the existing schedule editor (unchanged behavior).
- [ ] Swipe the menu down / tap the ✕ → dismisses, nothing else happens.

## 2 — Edit enrollment page + drilldowns (slide from the RIGHT)
- [ ] **Edit enrollment** → opens a screen titled **"Edit enrollment"**, left nav **"Cancel"**, right nav **"Save"**. Group / study / schedule / toggles are **prefilled** from the enrollment.
- [ ] Tap the **schedule** strip → the calendar (**"Select dates"**, right button **"Done"**) slides in **from the right**; back/Done slides it back left.
- [ ] Tap the **group** name → group picker slides in from the right.
- [ ] Tap the **study** name → study picker slides in from the right.
- [ ] Direction check: drilldowns enter from the right (Edit enrollment is the root), the **opposite** of the create flow.

## 3 — Staging & Cancel (nothing persists until Save)
- [ ] Change the schedule (start date and/or weekdays), change the group, toggle Require response.
- [ ] Tap **Cancel** → dismisses. Re-open Edit enrollment → **none** of the changes stuck (all back to original). Confirm on the member calendar too.

## 4 — Warning banner (from the server preview)
- [ ] Change the **study program** → a **warning banner** appears at the top summarizing the impact ("X lessons with no activity will be removed… N new lessons will be scheduled").
- [ ] With a member who has **progress** on a lesson, a study swap should mention lessons being **archived** (kept) vs removed.
- [ ] A pure reschedule with an already-sent lesson notes "already sent will not move".

## 5 — Save + confirmation dialog
- [ ] Tap **Save** → a **DialogOverlay** confirmation appears:
  - non-destructive edit → message "This will update the existing enrollment to match your changes."
  - destructive edit (study swap) → the impact summary.
- [ ] Confirm → the enrollment updates; the list/tab refreshes to reflect it.
- [ ] **Reschedule** result: the member's calendar shows the shifted dates; SMS-locked/past lessons did **not** move.
- [ ] **Group change** result: the enrollment now appears under the new group; its calendar events moved with it.
- [ ] **Study swap** result: the member calendar shows the **new** study's lessons from the start date; zero-activity old lessons gone; progressed old lessons preserved (archived).

## 6 — Error handling
- [ ] Kill the server, tap Save → the top **error banner** shows "Couldn't save the enrollment changes" (not a raw error); the page stays open so you can retry.

## Notes / known follow-ups
- Sync-mode ("Sync to study") editing is out of scope here — the enrollment sync pane still owns it.
- Optional: add `/compare` visual-regression fixtures for the Edit enrollment page + drilldowns (not required for functional sign-off).
