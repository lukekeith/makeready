/**
 * Adapter: group-members-page (page comparison, group Group) — WEB-ONLY.
 *
 * GroupMembersPage.swift is a trailing SlideStack pane behind the private
 * `rightScreen` @State inside pages.group-home — unreachable by the iPhone
 * harness (same precedent as edit-group / group-invite). NOT to be confused
 * with the `group-members` comparison (the Groups TAB from MemberHomePage).
 */
export default {
  toClient(shared) {
    const { members = [], requests = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'GroupMembersPage',
        componentProps: { members, requests },
      },
    };
  },

  // No iPhone side — the pane is private @State-gated inside pages.group-home.
  toIphone() {
    return null;
  },
};
