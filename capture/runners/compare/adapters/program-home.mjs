/**
 * Adapter: program-home (page comparison).
 * ProgramHomePage — the .programHome modal opened by tapping a study program in
 * MainLibrary (ViewRegistry pages.program-home).
 *
 * Web side: the ProgramHome twin (program-home.vue), shared with the production
 * leader app, rendered full-bleed via pages/leader-twin.blade.php. The iPhone
 * side seeds AppState from `state` (programId/programName/programDays/lessons —
 * same shape as the legacy create-program fixtures) and renders the real
 * ProgramHomePage. No cover image is seeded so both sides show the placeholder
 * well (the iOS AsyncImage wouldn't resolve a remote cover in the snapshot
 * anyway); CaptureEnvironment seeds programs isPublished=true → Published badge.
 *
 * Activity icon-box status: the iPhone derives "configured" per type — seeded
 * activities carry no content, so content types (READ / VIDEO / YOUTUBE /
 * EXEGESIS) render the brand-outlined incomplete box, while USER_INPUT (its
 * title IS the question) renders the filled complete box. The web mapping
 * mirrors that.
 */

function activityStatus(type) {
  return type === 'USER_INPUT' ? 'complete' : 'incomplete';
}

// iOS ModelFormatters.monthDay: "MMM d".uppercased(), LOCAL tz (fixture dates
// are noon-UTC so no tz can shift the day).
function dateRange(startIso, endIso) {
  const fmt = (iso) =>
    new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }).toUpperCase();
  if (!startIso) return '';
  return endIso ? `${fmt(startIso)} - ${fmt(endIso)}` : fmt(startIso);
}

export default {
  toClient(shared) {
    const { programName = '', lessons = [], selectedTab = 0, enrollments = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'ProgramHome',
        componentProps: {
          programName,
          published: true,
          hasCoverImage: false,
          selectedTab,
          enrollments: enrollments.map((e) => ({
            id: e.id,
            name: e.group?.name ?? 'Unknown Group',
            subtitle: e.group?.creator?.name ?? undefined,
            dateRange: dateRange(e.startDate, e.endDate),
          })),
          canEdit: true,
          statusBar: true,
          lessons: lessons.map((l) => ({
            id: l.id,
            day: l.dayNumber,
            title: l.title ?? '',
            estimatedMinutes: l.estimatedMinutes ?? 0,
            activities: (l.activities ?? []).map((a) => ({
              activityType: a.type,
              status: activityStatus(a.type),
            })),
          })),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.program-home',
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
