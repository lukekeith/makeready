/**
 * Adapter: groups-enrolled (page comparison, iPhone-first).
 * MemberHomePage 'Enrolled' tab — enrollments per program.
 * iPhone-first: web leader twin is Phase B (compose existing component twins,
 * like group-home-leader). No toClient yet → projectComparison yields client:null.
 */
export default {
  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.groups-enrolled',
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
