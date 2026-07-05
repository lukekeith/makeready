/**
 * Adapter: home-dashboard (page comparison, iPhone-first).
 *
 * The iPhone default post-login screen — `MainHome` (the `.home` tab of
 * `MainView`), rendered via the ViewRegistry `pages.home` case. It's a LEADER
 * analytics dashboard: PageHeader tabs + KPI cards (members / groups / studies /
 * enrolled lessons) + a weekly-activity bar chart, all read from AppState. The
 * capture harness seeds those via `state.homeStats` (see CaptureEnvironment
 * setupCaptureState → CaptureHomeStats).
 *
 * Web side: a capture-only LEADER twin (HomeDashboard.vue) that composes the
 * existing PageHeader / Kpi / VerticalBarChart / HeatMapChart / NavBar twins,
 * rendered full-bleed via pages/leader-twin.blade.php. This does NOT touch the
 * production member `/home` landing or the admin-SPA dashboard.
 */
const WEEKDAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
function weekdayLabel(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || '');
  if (!m) return iso || '';
  return WEEKDAY[new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])).getUTCDay()];
}

export default {
  toClient(shared) {
    const { stats = {}, weeklyActivity = [], heatmap = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'HomeDashboard',
        componentProps: {
          totalMembers: stats.totalMembers ?? 0,
          totalGroups: stats.totalGroups ?? 0,
          totalEnrolledLessons: stats.totalEnrolledLessons ?? 0,
          totalStudies: stats.totalStudies ?? 0,
          weeklyActivity: weeklyActivity.map((p) => ({ label: weekdayLabel(p.date), value: p.count ?? 0 })),
          heatmap: heatmap.map((p) => ({ day: p.day, hour: p.hour, value: p.count ?? 0 })),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, stats = {}, weeklyActivity = [], heatmap = [] } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.home',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name,
          email: user.email,
          picture: user.picture ?? null,
        },
      },
      state: {
        homeStats: {
          totalMembers: stats.totalMembers,
          totalGroups: stats.totalGroups,
          totalStudies: stats.totalStudies,
          totalEnrolledLessons: stats.totalEnrolledLessons,
          weeklyActivity,
          heatmap,
        },
      },
    };
  },
};
