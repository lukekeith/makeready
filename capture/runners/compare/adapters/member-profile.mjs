/**
 * Adapter: member-profile (page comparison, group Group).
 *
 * MemberProfilePage.swift is a .memberProfile modal (priority 100, chrome
 * modal, dismissOnTapOutside true). Its profile loads over the NETWORK
 * (GroupActions → GET /api/members/:id/profile), NOT from AppState, so the
 * iPhone harness can only render the seeded pre-load hero (name + initials +
 * gradient) — the `hero` variant. `default` (full content, incl. the removed
 * card's undimmed #df1439 border) and `error` are WEB-FORWARD.
 *
 * A `pages.member-profile` ViewRegistry case exists (2026-07-28) but requires
 * a user-approved xcodebuild before iPhone captures run; until then toIphone
 * returns null (web-only precedent: group-members-page / edit-group).
 */
export default {
  toClient(shared) {
    const {
      name = '',
      loaded = true,
      joined,
      age,
      phone,
      email,
      groups = [],
      errorMessage,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'MemberProfile',
        componentProps: {
          name,
          loaded,
          joined,
          age,
          phone,
          email,
          groups,
          errorMessage,
          statusBar: true,
        },
      },
    };
  },

  // Flip to `pages.member-profile` (state: { memberId, seedName }) once the
  // capture app is rebuilt with the new ViewRegistry case.
  toIphone() {
    return null;
  },
};
