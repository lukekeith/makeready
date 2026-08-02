/**
 * Adapter: enrollment-action-menu (page comparison, WEB-ONLY — menus
 * snapshot offscreen on iPhone; managed-menu precedent).
 */
export default {
  toClient(shared) {
    const { studyName = 'Study', canManage = true, creatorName = '' } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EnrollmentActionMenu',
        componentProps: { studyName, canManage, creatorName },
      },
    };
  },

  toIphone(shared) {
    const { studyName = 'Study' } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'component.EnrollmentActionMenu',
      auth: {
        isAuthenticated: true,
        currentUser: { id: 'user-1', name: 'Alex Rivera', email: 'alex@example.com', picture: null },
      },
      state: { component: { studyName } },
    };
  },
};
