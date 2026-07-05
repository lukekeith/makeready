/**
 * Adapter: media (page comparison).
 * MainLibrary 'Media' tab — media library grid (ViewRegistry pages.media).
 *
 * Web side: a capture-only twin (LibraryMedia.vue) composing PageHeader +
 * SearchField, rendered full-bleed via pages/leader-twin.blade.php. Thumbnails
 * never resolve in the isolated snapshot, so the grid cells render the iOS
 * placeholder glyphs (photo / play). iOS `orderedMedia` sorts by createdAt desc
 * but all seeds share a timestamp, so the rendered order is the (capture-defined)
 * order the iPhone shot captured: IMAGE, VIDEO, VIDEO.
 */
const IPHONE_RENDER_ORDER = ['med-2', 'med-1', 'med-3'];

export default {
  toClient(shared) {
    const { media = [], filters = {} } = shared ?? {};
    const byId = new Map(media.map((m) => [m.id, m]));
    const ordered = [
      ...IPHONE_RENDER_ORDER.map((id) => byId.get(id)).filter(Boolean),
      ...media.filter((m) => !IPHONE_RENDER_ORDER.includes(m.id)),
    ];
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'LibraryMedia',
        componentProps: {
          ...(filters.chips ? { chips: filters.chips } : {}),
          media: ordered.map((m) => ({ type: m.type ?? 'VIDEO' })),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.media',
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
