/**
 * Adapter: ScheduledLessonCard (component comparison).
 *
 * Projects one canonical scheduled-lesson description into:
 *   - toClient → scheduled-lesson-card.vue via the ComponentCapture island
 *   - toIphone → ScheduledLessonCard.swift via the component.ScheduledLessonCard
 *               ViewRegistry case (unchanged from the iphone-first scaffold).
 *
 * The fixture carries a semantic `status` (future | today | completed) plus a
 * `dayNumber` and an `activities` list. The iOS ViewRegistry turns `status` into
 * a concrete scheduled date relative to *now* (future = now+7d, today = now,
 * completed = now−7d) and lets ScheduledLessonCard decide the visual state —
 * crucially, a date at/before "now" reads as completed, so BOTH `today` and
 * `completed` render the green/checkmark state; only `future` is active.
 *
 * The web twin has no DateFormatter, so this adapter computes the same dates
 * (mirroring ViewRegistry) and formats the month/day in the LOCAL timezone to
 * match the iPhone's local-tz formatter, handing the Vue component plain strings.
 */
const DAY_MS = 24 * 60 * 60 * 1000;
const MONTHS = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

function scheduledDateFor(status) {
  const now = new Date();
  if (status === 'completed') return new Date(now.getTime() - 7 * DAY_MS);
  if (status === 'today') return now;
  return new Date(now.getTime() + 7 * DAY_MS); // future (default)
}

// iOS treats `today` (date == now, i.e. not strictly in the future) and
// `completed` alike: both land in the completed/green state.
function isCompleted(status) {
  return status === 'completed' || status === 'today';
}

export default {
  toClient(shared) {
    const { status = 'future', activities = [] } = shared ?? {};
    const date = scheduledDateFor(status);
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'ScheduledLessonCard',
        componentProps: {
          monthAbbrev: MONTHS[date.getMonth()],
          dayOfMonth: String(date.getDate()),
          completed: isCompleted(status),
          // Every capture variant has at least one configured activity, so the
          // active state always uses the neutral surface (not the purple well).
          hasConfiguredActivities: activities.length > 0,
          activities: activities.map((a) => ({
            type: a.type,
            title: a.title ?? '',
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ScheduledLessonCard',
      state: { component: shared ?? {} },
    };
  },
};
