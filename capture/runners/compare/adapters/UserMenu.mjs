/**
 * UserMenu adapter (iPhone-only).
 *
 * UserMenu is a *connected* component: it renders the signed-in user (from
 * `authManager.currentUser`) and one row per `AppState.shared.userOrganizations`.
 * So this adapter projects the variant into a `fixture.auth` (which the capture
 * harness turns into a mock AuthManager) plus a `component` bag carrying the org
 * list + avatar URL (seeded into AppState / the image cache by the registry case).
 */
export default {
  toIphone(shared = {}) {
    return {
      platform: 'iphone',
      view: 'component.UserMenu',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: 'capture-user',
          name: shared.userName ?? 'User',
          email: 'user@example.com',
          picture: shared.avatarURL ?? null,
        },
      },
      state: {
        component: {
          // avatarUrl is pre-seeded into ImageCache by setupCaptureState so the
          // CachedAsyncImage renders within one synchronous snapshot pass.
          avatarUrl: shared.avatarURL ?? null,
          organizations: shared.organizations ?? null,
        },
      },
    };
  },
  toClient() {
    return null;
  },
};
