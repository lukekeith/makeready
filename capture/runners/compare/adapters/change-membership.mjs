/**
 * Adapter: change-membership (page comparison).
 * ChangeMembershipModal — topLevel RAW modal with an internal panel state
 * machine. The web twin exposes capture-only initialPanel/initialConfirmKind
 * props; the iOS modal's panel is private @State, so only the MAIN panel
 * variants (default/removed) are two-sided — confirm/transfer variants are
 * web-only (see fixture note).
 */

export default {
  toClient(shared) {
    const {
      memberName = '',
      groupName = '',
      mode = 'joined',
      candidates = [],
      initialPanel = 'main',
      initialConfirmKind = 'remove',
      initialTransferName = '',
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'ChangeMembership',
        componentProps: {
          memberName,
          groupName,
          mode,
          candidates,
          initialPanel,
          initialConfirmKind,
          initialTransferName,
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { memberName = '', groupName = '', mode = 'joined', candidates = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.change-membership',
      auth: {
        isAuthenticated: true,
        currentUser: { id: 'user-1', name: 'Alex Rivera', email: 'alex@example.com', picture: null },
      },
      state: { changeMembership: { memberName, groupName, mode, candidates } },
    };
  },
};
