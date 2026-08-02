/**
 * Adapter: calendar (page comparison).
 * MainCalendar — the split-month calendar screen (ViewRegistry pages.calendar
 * ↔ web SplitMonthCalendar twin).
 *
 * Determinism: iOS builds its month window from `Date()`, so the fixture pins
 * `today` (the iPhone capture date) plus an explicit `windowStart`/`monthCount`
 * and a pre-formatted `title`. The iPhone reference sits at the TOP of the
 * window (the snapshot precedes the controller's scroll-to-current-month), so
 * the `default` variant seeds the window start to match it.
 *
 * The `with-events` and `expanded` variants are WEB-ONLY — the iPhone side
 * cannot be scrolled or expanded from the harness (internal UIKit state).
 */

/** Expand "yyyy-MM" + a count into the [{ year, month }] window the twin takes. */
function monthWindow(startKey, count) {
  const [y, m] = String(startKey ?? '').split('-').map(Number);
  if (!y || !m) return [];
  const out = [];
  for (let i = 0; i < (count ?? 1); i += 1) {
    const idx = m - 1 + i;
    out.push({ year: y + Math.floor(idx / 12), month: (idx % 12) + 1 });
  }
  return out;
}

const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAY_LONG = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday'];

/** iOS CardLesson date line "EEEE, MMM d, yyyy", built in LOCAL terms. */
function dateLine(key) {
  const [y, m, d] = String(key).split('-').map(Number);
  const dt = new Date(y, (m ?? 1) - 1, d ?? 1);
  return `${WEEKDAY_LONG[dt.getDay()]}, ${MONTH_SHORT[dt.getMonth()]} ${dt.getDate()}, ${dt.getFullYear()}`;
}

export default {
  toClient(shared) {
    const {
      today = null,
      title = '',
      windowStart,
      monthCount,
      selectedDate = null,
      expanded = false,
      calendarEvents = [],
    } = shared ?? {};

    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'SplitMonthCalendar',
        componentProps: {
          title,
          months: monthWindow(windowStart, monthCount),
          todayKey: today,
          selectedKey: selectedDate,
          expanded,
          // iOS event title = the STUDY PROGRAM NAME; every dot is #6c47ff.
          events: calendarEvents.map((e) => ({
            id: e.id,
            date: e.date,
            day: e.dayNumber ?? 1,
            title: e.studyName ?? e.title ?? '',
            dateLine: dateLine(e.date),
            estimatedMinutes: e.estimatedMinutes,
            activities: e.activities ?? [],
            color: e.color ?? '#6c47ff',
          })),
          statusBar: true,
          // The iPhone page renders standalone (no NavBar) above the 34pt
          // home indicator, so its Today pill clears the bottom by 16 + 34.
          navBarVisible: false,
          homeIndicator: true,
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, ...state } = shared ?? {};
    // Only the collapsed window start is reachable from the harness — the
    // scrolled/expanded variants have no iPhone counterpart (see fixture note).
    if (shared?.expanded || shared?.selectedDate) return null;
    return {
      platform: 'iphone',
      view: 'pages.calendar',
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
