/**
 * Adapter: groups (page comparison).
 * MemberHomePage 'Groups' tab — leader's group cards (ViewRegistry pages.groups,
 * pendingSubTab 0). Both platforms read the SAME `shared` block.
 *
 * Web side: a capture-only LEADER twin (GroupsLeader.vue) composing the existing
 * PageHeader + CardGroup twins, rendered full-bleed via pages/leader-twin.blade.php
 * (the same generic harness home-dashboard uses). This does NOT touch the
 * production member groups page (resources/views/pages/groups.blade.php).
 *
 * iOS `orderedGroups` sorts by `updatedAt` desc, but the capture seeds every
 * group with the same timestamp, so the rendered order is the (stable) order the
 * shot captured: Young Professionals, Wednesday Study, Sunday Morning Group. The
 * web list is emitted in that same order so the two screenshots line up.
 */
const IPHONE_RENDER_ORDER = ['g-002', 'g-003', 'g-001'];

export default {
  toClient(shared) {
    const { groups = [] } = shared ?? {};
    const byId = new Map(groups.map((g) => [g.id, g]));
    const ordered = [
      ...IPHONE_RENDER_ORDER.map((id) => byId.get(id)).filter(Boolean),
      ...groups.filter((g) => !IPHONE_RENDER_ORDER.includes(g.id)),
    ];
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'GroupsLeader',
        componentProps: {
          groups: ordered.map((g) => ({
            id: g.id,
            name: g.name,
            memberCount: g.memberCount ?? 0,
          })),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.groups',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name ?? 'Alex Rivera',
          email: user.email ?? 'alex@example.com',
          picture: user.picture ?? null,
        },
      },
      state,
    };
  },
};
