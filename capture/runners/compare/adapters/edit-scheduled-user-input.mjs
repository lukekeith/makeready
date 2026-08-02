/**
 * Adapter: edit-scheduled-user-input (page comparison, WEB-ONLY).
 * The SCHEDULED Write-activity editor — iOS renders the private
 * EditScheduledUserInputView inside EditEnrollmentDay (no ViewRegistry case
 * can construct a private @State-gated view). The web twin mirrors the iOS
 * seeding: title = activity.title ?? "", helpEnabled inferred from
 * helpTitle/helpDescription being present (EditEnrollmentDay.swift:1053-1057).
 */
export default {
  toClient(shared) {
    const { activity = {} } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditScheduledUserInput',
        componentProps: {
          title: activity.title ?? '',
          helpEnabled: activity.helpTitle != null || activity.helpDescription != null,
          helpTitle: activity.helpTitle ?? '',
          helpDescription: activity.helpDescription ?? '',
          showPreview: true,
          statusBar: true,
        },
      },
    };
  },

  // The iOS view is private inside EditEnrollmentDay (see fixture note).
  toIphone() {
    return null;
  },
};
