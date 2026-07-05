/**
 * Adapter: edit-youtube-activity (page comparison).
 * EditYouTubeActivityPage — the YouTube-activity editor, a nested SlideStack
 * detail inside EditDay (ViewRegistry pages.edit-youtube-activity).
 *
 * Variants carry the seeded activity in `shared.activity`. Unlike the Write
 * editor, iOS seeds the title field with activity.title ?? "" (no
 * displayName fallback). The preview thumbnail is a remote image
 * (img.youtube.com) that never resolves in iPhone snapshots, so the web side
 * omits it — both platforms render the white@5% well + play glyph.
 */
export default {
  toClient(shared) {
    const a = shared?.activity ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditYouTubeActivity',
        componentProps: {
          statusBar: true,
          title: a.title ?? '',
          youtubeUrl: a.youtubeUrl ?? '',
          // iPhone snapshots freeze the (stubbed) metadata fetch mid-flight,
          // so the reference always shows "Loading video info..." under the
          // preview — mirror it whenever a URL is seeded.
          fetchingMetadata: Boolean(a.youtubeUrl),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, activity = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.edit-youtube-activity',
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
