/**
 * Adapter: edit-read-activity (page comparison).
 * EditReadActivityPage — the READ-activity block editor (ViewRegistry
 * pages.edit-read-activity ↔ web EditReadActivity twin). The web side mirrors
 * the iOS Screen 1 mapping: readBlocks sorted by orderNumber; locked blocks
 * mount COLLAPSED (no expandedIds passed); title seeds the field.
 */
export default {
  toClient(shared) {
    const { activity = {}, editor = {} } = shared ?? {};
    const blocks = [...(activity.readBlocks ?? [])]
      .sort((a, b) => (a.orderNumber ?? 0) - (b.orderNumber ?? 0))
      .map((b) => ({
        id: b.id,
        title: b.title ?? '',
        content: b.content ?? '',
        isLocked: Boolean(b.isLocked),
        sourceReferenceId: b.sourceReferenceId ?? null,
        selections: b.selections ?? [],
      }));
    const componentProps = {
      // iOS seeds the field with activity.title ?? type displayName ("Read").
      title: activity.title ?? 'Read',
      blocks,
      statusBar: true,
    };
    // Highlight-mode variant (web-forward — internal @State on iPhone):
    // expanded locked blocks + the active highlighting block.
    if (editor.expandedIds) componentProps.expandedIds = editor.expandedIds;
    if (editor.highlightingId) componentProps.highlightingId = editor.highlightingId;
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditReadActivity',
        componentProps,
      },
    };
  },

  toIphone(shared) {
    const { user = {}, activity = {} } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.edit-read-activity',
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
