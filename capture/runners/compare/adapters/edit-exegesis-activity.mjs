/**
 * Adapter: edit-exegesis-activity (page comparison).
 * EditExegesisActivityPage — the EXEGESIS highlight editor (ViewRegistry
 * pages.edit-exegesis-activity ↔ web EditExegesisActivity twin). Web mapping
 * mirrors the iOS page: title seeds activity.title ?? "Exegesis" (the type
 * displayName), the passage chip shows the locked block's title, and the
 * preview renders the block content with its selections as highlight runs.
 */
export default {
  toClient(shared) {
    const { activity = {} } = shared ?? {};
    const block = (activity.readBlocks ?? []).find((b) => b.isLocked) ?? null;
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditExegesisActivity',
        componentProps: {
          title: activity.title ?? 'Exegesis',
          passageTitle: block?.title ?? null,
          content: block?.content ?? '',
          highlights: block?.selections ?? [],
          fontSizeKey: block?.fontSize ?? 'm',
          backgroundColor: block?.backgroundColor ?? null,
          backgroundOverlayOpacity: block?.backgroundOverlayOpacity ?? null,
          backgroundImageUrl: block?.backgroundImageUrl ?? null,
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, activity = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.edit-exegesis-activity',
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
        activity,
      },
    };
  },
};
