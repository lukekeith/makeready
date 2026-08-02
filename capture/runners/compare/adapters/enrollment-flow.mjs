/**
 * Adapter: enrollment-flow (page comparison).
 * EnrollmentFlowModal — the 3-panel enrollment wizard presented as the
 * `.enrollmentFlow` (group entry) / `.programEnrollmentFlow` (program entry)
 * modal, dismissOnTapOutside FALSE.
 *
 * Web: the EnrollmentFlow twin, fully prop-seeded (entry/step/lists/calendar/
 * confirm data). iPhone: `pages.enrollment-flow` seeds groups/programs into
 * CaptureState and presents EnrollmentFlowModal with preselectedGroup or
 * preselectedProgram — panel 0 only (the step index, calendar selection and
 * confirm state are private @State the harness can't reach), so the
 * select-dates / confirm variants are WEB-ONLY (see fixture note).
 */

export default {
  toClient(shared) {
    const {
      entry = 'group',
      step = 0,
      groups = [],
      programs = [],
      selectedGroupId = null,
      selectedProgramId = null,
      calendarStartMonth = '',
      calendarMonthCount = 12,
      calendarToday = '',
      startDate = null,
      endDate = null,
      enabledDays = [1, 2, 3, 4, 5],
      overriddenDates = [],
      existingLessonDates = [],
      confirmGroup = null,
      confirmProgram = null,
      smsTime = '07:30',
      requireResponse = true,
      syncToStudy = false,
      syncMode = 'Automatic',
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EnrollmentFlow',
        componentProps: {
          entry,
          step,
          groups,
          programs,
          selectedGroupId,
          selectedProgramId,
          calendarStartMonth,
          calendarMonthCount,
          calendarToday,
          startDate,
          endDate,
          enabledDays,
          overriddenDates,
          existingLessonDates,
          confirmGroup,
          confirmProgram,
          smsTime,
          requireResponse,
          syncToStudy,
          syncMode,
        },
      },
    };
  },

  toIphone(shared) {
    const { entry = 'group', groups = [], programs = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.enrollment-flow',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: 'user-1',
          name: 'Alex Rivera',
          email: 'alex@example.com',
          picture: null,
        },
      },
      state: {
        enrollmentFlowEntry: entry,
        // CaptureGroup / program-bag shapes (CaptureEnvironment seeds these
        // into AppState; the picker lists read the seeded stores). Seed-shape
        // limits: programs always seed isPublished=true and no description.
        groups: groups.map((g) => ({
          id: g.id,
          name: g.name,
          description: g.description ?? null,
          memberCount: g.memberCount ?? 0,
        })),
        programs: programs.map((p) => ({
          id: p.id,
          name: p.name,
          days: p.days ?? 0,
        })),
      },
    };
  },
};
