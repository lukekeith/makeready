/**
 * Adapter: UserMenu (component comparison).
 *
 * Projects one canonical user-menu description into:
 *   - toClient → user-menu.vue via the ComponentCapture island
 *   - toIphone → UserMenu.swift via the component.UserMenu ViewRegistry case
 *
 * UserMenu is a *connected* component on iOS: it renders the signed-in user
 * (from `authManager.currentUser`) and one row per
 * `AppState.shared.userOrganizations`. So the iPhone side projects the variant
 * into a `fixture.auth` (which the capture harness turns into a mock AuthManager)
 * plus a `component` bag carrying the org list + avatar URL (seeded into AppState
 * / the image cache by the registry case) — unchanged from when this was an
 * iPhone-only adapter.
 *
 * The web twin is genuinely data-driven: it forwards the user's name + avatar URL
 * and a flat `items` list. Each item's `icon` is an iOS SF Symbol name that maps
 * here to the matching inline SVG (viewBox sized per glyph, fill/stroke
 * currentColor so the Vue SCSS tints it white). The fixture already carries the
 * resolved `items` (My profile / <org name> / Logout); the web side just maps
 * their icons to SVG.
 */

// iOS person.fill — head circle + rounded shoulders (filled, currentColor).
const PERSON_FILL =
  '<svg viewBox="0 0 28 28" fill="currentColor" aria-hidden="true">' +
  '<circle cx="14" cy="9" r="5"/>' +
  '<path d="M14 16c-5 0-9 3-9 6.5 0 .85 .65 1.5 1.5 1.5h15c.85 0 1.5-.65 1.5-1.5 0-3.5-4-6.5-9-6.5z"/>' +
  '</svg>';

// iOS building.2.fill — a main windowed building on the LEFT (2×3 window grid +
// a bottom-center doorway) with a narrower building behind it on the RIGHT (a
// column of edge windows). One path, fill-rule evenodd so the windows/door are
// true holes (the button background shows through, exactly like the SF symbol).
const BUILDING_2_FILL =
  '<svg viewBox="0 0 20 20" fill="currentColor" fill-rule="evenodd" aria-hidden="true">' +
  '<path d="' +
  // front/main building (rounded rect)
  'M3.7 2H9.3A1.2 1.2 0 0 1 10.5 3.2V16.8A1.2 1.2 0 0 1 9.3 18H3.7A1.2 1.2 0 0 1 2.5 16.8V3.2A1.2 1.2 0 0 1 3.7 2Z' +
  // back building (rounded rect, behind/right)
  'M12 5.5H15.3A1.2 1.2 0 0 1 16.5 6.7V16.8A1.2 1.2 0 0 1 15.3 18H10.8V6.7A1.2 1.2 0 0 1 12 5.5Z' +
  // front windows (2 cols × 3 rows)
  'M4 4h1.6v1.6h-1.6z M6.6 4h1.6v1.6h-1.6z' +
  'M4 6.6h1.6v1.6h-1.6z M6.6 6.6h1.6v1.6h-1.6z' +
  'M4 9.2h1.6v1.6h-1.6z M6.6 9.2h1.6v1.6h-1.6z' +
  // front doorway (bottom center)
  'M4.9 13h3v5h-3z' +
  // back-building windows (left-edge column)
  'M11.6 8h1.5v1.5h-1.5z M11.6 10.4h1.5v1.5h-1.5z M11.6 12.8h1.5v1.5h-1.5z' +
  '" /></svg>';

// iOS rectangle.portrait.and.arrow.right — an outlined portrait panel (open on
// the right) with an arrow exiting to the right (the logout glyph).
const LOGOUT =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.4" ' +
  'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M11 4H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h5"/>' +
  '<path d="M9 10h8"/>' +
  '<path d="M14 7l3 3-3 3"/>' +
  '</svg>';

const WEB_ICONS = {
  'person.fill': PERSON_FILL,
  'building.2.fill': BUILDING_2_FILL,
  'rectangle.portrait.and.arrow.right': LOGOUT,
};

function mapItem(item) {
  return {
    icon: WEB_ICONS[item.icon] ?? '',
    title: item.title,
  };
}

export default {
  toClient(shared = {}) {
    const { userName, avatarURL, items = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'UserMenu',
        componentProps: {
          userName: userName ?? '',
          avatarURL: avatarURL ?? '',
          items: items.map(mapItem),
        },
      },
    };
  },

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
};
