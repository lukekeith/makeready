/**
 * Adapter: EnrollmentCard (component comparison).
 *
 * Projects one canonical enrollment description into:
 *   - toClient → enrollment-card.vue via the ComponentCapture island
 *   - toIphone → EnrollmentCard.swift via the component.EnrollmentCard ViewRegistry case
 *
 * The iPhone formats the active-state date range from start/end dates using a
 * "MMM d" formatter in the simulator's local timezone (e.g. "MAY 31 - JUN 30").
 * The web component takes a pre-formatted string, so we format it here the same
 * way (local time, uppercased) so both renders read identically.
 */
function formatDay(iso) {
  const d = new Date(iso);
  const month = d.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
  return `${month} ${d.getDate()}`;
}

function dateRange(startDate, endDate) {
  if (!startDate) return '';
  const start = formatDay(startDate);
  if (!endDate) return start;
  return `${start} - ${formatDay(endDate)}`;
}

export default {
  toClient(shared) {
    const { title, days = 0, coverUrl, startDate, endDate, isCompleted } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'EnrollmentCard',
        componentProps: {
          title,
          days,
          coverUrl: coverUrl ?? '',
          dateRange: isCompleted ? '' : dateRange(startDate, endDate),
          completed: isCompleted === true,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.EnrollmentCard',
      state: { component: shared ?? {} },
    };
  },
};
