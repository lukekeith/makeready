/**
 * Adapter: edit-user-input-activity (page comparison).
 * EditUserInputActivityPage — the Write-activity editor, a nested SlideStack
 * detail inside EditDay (ViewRegistry pages.edit-user-input-activity).
 *
 * Variants carry the seeded activity in `shared.activity`. iOS seeds the
 * title field with activity.title ?? type.displayName ("Study" for
 * USER_INPUT) — replicated here so the web twin renders the same resolved
 * text. programId/lessonId default to the capture seeds; the seeded program
 * makes the auth user the creator, so canEdit chrome (Cancel / Edit Activity
 * / Done) and the Preview button render on both platforms.
 */
export default {
  toClient(shared) {
    const a = shared?.activity ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditUserInputActivity',
        componentProps: {
          statusBar: true,
          title: a.title ?? 'Study',
          placeholder: a.placeholder ?? '',
          helpEnabled: a.isHelpEnabled ?? false,
          helpTitle: a.helpTitle ?? '',
          helpDescription: a.helpDescription ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, activity = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.edit-user-input-activity',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name ?? 'Alex Rivera',
          email: user.email ?? 'alex@example.com',
          picture: user.picture ?? null,
        },
      },
      state: {
        programId: 'capture-prog-0',
        lessonId: 'capture-lesson-0',
        activity,
      },
    };
  },
};
