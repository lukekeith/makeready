# Enrollment Flow Modal

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/EnrollmentFlowModal.swift`
**Type:** overlay/modal
**Screen states:** populated (background prefetch of existing enrollments; no per-screen loading/empty chrome of its own)

## Components

This screen is a bidirectional 3-step wizard container. It is a horizontal `HStack` of full-width panels offset by `panelIndex`; it does not render its own UI components — it hosts the step pages as children. Each child is documented in its own screen file.

| Component | Variant(s) used | Notes |
|---|---|---|
| `SelectGroupPage` | default | Panel 0 of the program→group flow (rendered only when `preselectedGroup == nil`). See `select-group.md`. |
| `SelectStudyProgramPage` | default | Panel 0 of the group→program flow (rendered only when `preselectedProgram == nil`). See `select-study-program.md`. |
| `SelectEnrollDatePage` | `config: .enrollmentFlow` | Date/day picker step (panel 1). Sub-page outside the assigned set; passed `existingLessonDates` for overlap highlights. |
| `ConfirmEnrollmentPage` | default | Confirm step (panel 2). See `confirm-enrollment.md`. |

## Notes
- Two entry shapes: from a group (steps Select Program → Dates → Confirm) or from a program (steps Select Group → Dates → Confirm). The unused selection panel is simply not instantiated, so the HStack is always 3 visible panels.
- Slides between panels with `withAnimation(Motion.standard)` via the `.offset(x:)` on the HStack — there is no `SlideStack` here; it is a hand-driven offset container.
- Placeholder `Color.appBackground` panels stand in for steps 2/3 until their data is cached (`dateState`, `confirmedEnrollmentData`), so the confirm view is mounted before navigation.
- No custom component is instantiated directly by this file beyond the child pages.
