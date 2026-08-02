/**
 * Adapter: unenroll-options (page comparison, WEB-ONLY — see fixture note).
 * UnenrollOptionsModal — the .unenrollOptions modal's 4-phase machine.
 */
export default {
  toClient(shared) {
    const {
      phase = 'options',
      programName = 'Study Program',
      totalLessons = 0,
      lessonsWithData = 0,
      cleanLessons = 0,
      canFullyUnenroll = true,
      confirmMode = 'fullRemoval',
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'UnenrollOptions',
        componentProps: {
          phase,
          programName,
          totalLessons,
          lessonsWithData,
          cleanLessons,
          canFullyUnenroll,
          confirmMode,
        },
      },
    };
  },

  toIphone(shared) {
    const { programName = 'Study Program' } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.unenroll-options',
      auth: {
        isAuthenticated: true,
        currentUser: { id: 'user-1', name: 'Alex Rivera', email: 'alex@example.com', picture: null },
      },
      state: { programName },
    };
  },
};
