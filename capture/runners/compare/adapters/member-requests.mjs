/**
 * Adapter: member-requests (page comparison, group Group).
 *
 * MemberRequestsPage.swift — the ONLY `.page` chrome route (ManagedPageView
 * horizontal push; the chrome animates live, snapshots capture the page).
 * Fully seedable on BOTH sides: web renders the MemberRequestsPage twin;
 * iPhone renders the new `pages.member-requests` ViewRegistry case, which
 * seeds AppState.pendingJoinRequestsByGroupId from state.joinRequests and
 * group names from state.groups (requires a user-approved xcodebuild of the
 * capture app before the first iPhone run).
 *
 * A request whose groupId isn't in `groups` renders WITHOUT the "Group" chip
 * (iOS omits it silently) — r-2 exercises that on purpose.
 */
const MONTH_DAY_YEAR = { month: 'short', day: 'numeric', year: 'numeric' };

function requestedLabel(epoch) {
  // Local tz on both platforms (compare-date-range-local-tz precedent).
  return new Date(epoch * 1000).toLocaleDateString('en-US', MONTH_DAY_YEAR);
}

export default {
  toClient(shared) {
    const { groups = [], requests = [] } = shared ?? {};
    const nameById = new Map(groups.map((g) => [g.id, g.name]));
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'MemberRequestsPage',
        componentProps: {
          requests: requests.map((r) => ({
            // iOS GroupJoinRequest.id = "{groupId}-{requestId}".
            id: `${r.groupId}-${r.id}`,
            firstName: r.firstName ?? '',
            lastName: r.lastName ?? '',
            groupName: nameById.get(r.groupId),
            requestedLabel: requestedLabel(r.createdAt ?? 1_700_000_000),
          })),
          statusBar: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { groups = [], requests = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.member-requests',
      auth: { loggedIn: true },
      state: {
        groups,
        joinRequests: requests.map((r) => ({
          id: r.id,
          groupId: r.groupId,
          firstName: r.firstName ?? null,
          lastName: r.lastName ?? null,
          createdAt: r.createdAt ?? 1_700_000_000,
        })),
      },
    };
  },
};
