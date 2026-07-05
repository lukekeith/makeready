/**
 * Adapter: create-program (page comparison).
 * CreateProgramPage — the .createProgram modal opened from the Library "+" menu
 * (ViewRegistry pages.create-program).
 *
 * The iPhone case seeds NOTHING (fresh OverlayManager, no fixture state), so it
 * renders the empty create form: "Select a template" with an empty options
 * list, Days "30", publish off, no tags, no validation chrome. The web side is
 * the shared CreateProgram twin at its defaults — which reproduce exactly that
 * empty state — plus the capture-only status bar (the iPhone reference includes
 * the simulator's).
 */
export default {
  toClient() {
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'CreateProgram',
        componentProps: {
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.create-program',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name ?? 'Alex Rivera',
          email: user.email ?? 'alex@example.com',
          picture: user.picture ?? null,
        },
      },
      state: {},
    };
  },
};
