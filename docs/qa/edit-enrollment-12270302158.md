# QA checklist — Edit enrollment (monday#12270302158)

Manual interaction/E2E script for the iPhone edit-enrollment feature. The
*logic* is unit-covered (`EnrollmentEditModelTests`, 14 tests) and the *server*
is integration-covered (`enrollment-edit.test.ts`, 33 tests, 100% line/func).
This checklist covers the **choreography + end-to-end** that automated tests
don't: slide transitions, staging/cancel, and the real server round-trip.

**Setup:** run against local server (`:3010`) with a signed-in leader who owns a
group with at least one **enrolled** study. Have a second group and a second
published study available (for the group/study swap steps).

## 1 — Tap → action menu (all THREE entry points)
- [ ] From a group's **Enrollments** list (`EnrollmentsListPage`), tap an enrollment → a **slide-up menu** with exactly two rows: **Edit lessons** and **Edit enrollment** (no Open/Share/Delete; header shows the study name).
- [ ] From a **study program's Enrollments tab** (`ProgramHomePage`) → same menu.
- [ ] From the **Groups page → Enrolled tab** (`MemberHomePage`) → same menu.
- [ ] **Edit lessons** (each entry point) → opens the existing schedule editor (unchanged behavior).
- [ ] Swipe the menu down / tap the ✕ → dismisses, nothing else happens.

### 1a — Permission: disabled "Edit enrollment" (requires deployed server)
- [ ] For an enrollment **you can edit** (you created it, or you manage the group's org): "Edit enrollment" is fully visible and tappable.
- [ ] For an enrollment **created by another leader that you can't manage**: "Edit enrollment" is **dimmed (~40% opacity) and does nothing when tapped**; "Edit lessons" still works.
- [ ] Sanity: the disabled state matches the server — if the row is enabled, saving an edit succeeds; if it's disabled, you genuinely aren't allowed (no false enable/disable).
- [ ] Note: `canManage` is server-computed, so this only shows after the server deploy. Before deploy (or on stale cached data) the button stays enabled — that's expected (`nil ⇒ allowed`).

## 2 — Edit enrollment page + drilldowns (slide from the RIGHT)
- [ ] **Edit enrollment** → opens a screen titled **"Edit enrollment"**, left nav **"Cancel"**, right nav **"Save"**. Group / study / schedule / toggles are **prefilled** from the enrollment.
- [ ] It **opens promptly** (no endless spinner). If the group/study genuinely can't load, you get a **"Couldn't load this enrollment"** screen with Cancel — not an infinite spin.
- [ ] Tap the **schedule** strip → the calendar (**"Select dates"**, right button **"Done"**) slides in **from the right**; back/Done slides it back left.
- [ ] Tap the **group** name → group picker slides in from the right, with a **back chevron** (not ✕) and the **current group already selected**.
- [ ] Tap the **study** name → study picker slides in from the right, with a **back chevron** and the **current study already selected**.
- [ ] **No skip-over:** jumping from the root straight to group or study must NOT flash the dates screen (or any other panel) on the way — the target slides in cleanly. (You can also swipe from the left edge to go back.)
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

## 7 — Regression: groups list no longer poisoned by a null code
- [ ] With a group whose join `code` is null, the app still loads **all** groups (previously one null code failed the whole `/api/groups` decode). The console no longer spams `Decoding error for /api/groups … groups[N].code`.

## Notes / known follow-ups
- **Deploy dependency:** the server changes (edit endpoints, `canManage`, the enrollment-list stamping) must be **deployed** before this works end-to-end on prod. Until then: the edit Save round-trip won't function against prod, and `canManage` is absent so "Edit enrollment" stays enabled (`nil ⇒ allowed`).
- Sync-mode ("Sync to study") editing is out of scope here — the enrollment sync pane still owns it.
- Optional: add `/compare` visual-regression fixtures for the Edit enrollment page + drilldowns (not required for functional sign-off).
