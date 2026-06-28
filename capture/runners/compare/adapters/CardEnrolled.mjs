/**
 * Adapter: CardEnrolled (component comparison).
 *
 * Projects one canonical enrollment description into:
 *   - toClient → card-enrolled.vue via the ComponentCapture island
 *   - toIphone → CardEnrolled.swift via the component.CardEnrolled ViewRegistry case
 *
 * The canonical `shared` block carries raw ISO dates + a lessons-left count.
 * The iPhone formats the date range itself (DateFormatters.monthDay, "MMM d")
 * from the decoded Date, so toIphone forwards `shared` untouched. The web twin
 * takes a pre-formatted `dateRange` string, so we format it here.
 *
 * Date formatting note: the iPhone snapshot renders "MMM d" in the simulator's
 * local timezone, which sits behind UTC — so a UTC-midnight date like
 * 2026-01-01T00:00:00Z displays as "Dec 31". We reproduce that exactly by
 * formatting in a US timezone (America/Los_Angeles), so the web `dateRange`
 * matches the captured iPhone reference rather than the literal UTC day.
 */
const MONTH_DAY = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  timeZone: 'America/Los_Angeles',
});

function monthDay(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '' : MONTH_DAY.format(d);
}

function dateRange(startDate, endDate) {
  const start = monthDay(startDate);
  const end = monthDay(endDate);
  if (!start && !end) return '';
  return `${start} - ${end}`;
}

export default {
  toClient(shared) {
    const {
      studyTitle,
      groupName,
      startDate,
      endDate,
      lessonsLeft = null,
      studyImageURL,
      groupImageURL,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardEnrolled',
        componentProps: {
          studyTitle,
          groupName,
          dateRange: dateRange(startDate, endDate),
          lessonsLeft,
          studyImageURL: studyImageURL ?? '',
          groupImageURL: groupImageURL ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardEnrolled',
      state: { component: shared ?? {} },
    };
  },
};
