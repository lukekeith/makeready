/**
 * Adapter: video-activity-picker (page comparison, iPhone-only for now).
 * VideoActivityPicker — the VIDEO-activity grid picker (ViewRegistry
 * pages.video-activity-picker; seeds nothing, renders the empty library
 * grid + camera tile). The web picker is a pending queue item, so there is
 * no toClient yet → the compare UI shows "not built" on the web side.
 * RECORDING is hardware capture — excluded from parity entirely.
 */
export default {
  // Web side: the ported LIBRARY panel (album header + 4-col 9:16 grid). The
  // iPhone pane renders the RECORDER (hardware; showingLibrary is internal
  // @State) — panes intentionally differ; see the fixture note.
  toClient(shared) {
    const { videos = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'VideoActivityPicker',
        componentProps: {
          albumLabel: 'Library',
          videos: videos.map((v) => ({ id: v.id, duration: v.duration ?? null })),
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.video-activity-picker',
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
