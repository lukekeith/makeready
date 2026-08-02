/**
 * Adapter: enrollment-schedule (page comparison).
 * EnrollmentSchedulePage — the .enrollmentSchedule modal's primary pane.
 * WEB-ONLY until the pages.enrollment-schedule ViewRegistry case + its
 * enrollmentDetailsById seeding plumbing land (see fixture note).
 */
export default {
  toClient(shared) {
    const { title = 'Schedule', rows = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EnrollmentSchedule',
        componentProps: { title, rows },
      },
    };
  },

  toIphone(shared) {
    const { title = 'Schedule' } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.enrollment-schedule',
      auth: {
        isAuthenticated: true,
        currentUser: { id: 'user-1', name: 'Alex Rivera', email: 'alex@example.com', picture: null },
      },
      state: { titleOverride: title },
    };
  },
};
