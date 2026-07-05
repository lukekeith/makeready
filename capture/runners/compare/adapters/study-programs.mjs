/**
 * Adapter: study-programs (page comparison).
 * MainLibrary 'Programs' tab — study program cards (ViewRegistry pages.study-programs).
 *
 * Web side: a capture-only twin (LibraryPrograms.vue) composing the existing
 * PageHeader / SearchField / CardProgramFull twins, rendered full-bleed via
 * pages/leader-twin.blade.php. The iPhone seeds each program with creator =
 * "Alex Rivera", isPublished = true, createdAt = now, and NO description (the
 * seeding reads only id/name/days) — so the web twin mirrors that (published
 * badge, author footer, ~"now" date, no description line). iOS sorts "Newest
 * first" but all seeds share a timestamp, so the rendered order is the
 * capture-defined order: The Gospel of John, Psalms of Ascent, Romans.
 */
const IPHONE_RENDER_ORDER = ['prog-2', 'prog-3', 'prog-1'];

export default {
  toClient(shared) {
    const { user = {}, programs = [], filters = {} } = shared ?? {};
    const author = user.name ?? 'Alex Rivera';
    const byId = new Map(programs.map((p) => [p.id, p]));
    const ordered = [
      ...IPHONE_RENDER_ORDER.map((id) => byId.get(id)).filter(Boolean),
      ...programs.filter((p) => !IPHONE_RENDER_ORDER.includes(p.id)),
    ];
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'LibraryPrograms',
        componentProps: {
          programs: ordered.map((p) => ({
            title: p.name ?? '',
            days: p.days ?? 0,
            authorName: author,
            // iOS RelativeDateTimeFormatter on createdAt==capture-now → "in 0 seconds".
            relativeDate: 'in 0 seconds',
            published: true,
          })),
          // Web-forward filter-state variants (compare-visibility policy).
          ...(filters.chips ? { chips: filters.chips } : {}),
          ...(filters.sortLabel ? { sortLabel: filters.sortLabel } : {}),
          ...(filters.openPanel ? { openPanel: filters.openPanel } : {}),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.study-programs',
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
