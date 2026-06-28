/**
 * Adapter: CalendarEventListContent (component comparison).
 *
 * Projects one canonical day's-event-list description into:
 *   - toClient → calendar-event-list-content.vue via the ComponentCapture island
 *   - toIphone → component.CalendarEventListContent ViewRegistry case (unchanged
 *               from the iPhone-first passthrough)
 *
 * Each scheduled-lesson event carries SF-symbol activity icons (book.fill /
 * play.fill / hands.sparkles.fill) which we map to inline SVG for the web twin.
 * On iPhone these icons render in a NEUTRAL box (the calendar passes no rawType,
 * so ActivityStyle falls back to the default white-10 well + white-50 glyph) —
 * the literal icon shows through, NOT a type-derived colored box. The web twin
 * mirrors that exactly.
 *
 * The date header is pre-formatted here to avoid timezone drift in the browser.
 * The ISO date is parsed as UTC midnight (matching the iPhone's JSON decode) and
 * formatted in the capture host's LOCAL timezone — both platforms run on the
 * same host, so this reproduces the iPhone's "EEEE, MMMM d" header exactly
 * (e.g. 2026-01-30 → "Thursday, January 29" west of UTC).
 *
 * NOTE: the iPhone wraps the list in a ScrollView, so its sizeThatFits snapshot
 * collapses the list to ~0 height and only the header is captured (the Lessons
 * reference shows just the date). The web twin renders the real cards — a
 * documented parity gap for that variant, not a faithful pixel match.
 */

// SF Symbol → inline SVG (single-color glyphs, 14px in a 32px neutral box).
const ACTIVITY_SVG = {
  'book.fill':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
  'play.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M8 5v14l11-7z"/></svg>',
  'hands.sparkles.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M12 2l1.6 4.4L18 8l-4.4 1.6L12 14l-1.6-4.4L6 8l4.4-1.6z"/><path d="M5 14l.9 2.4L8 17l-2.1.8L5 20l-.9-2.2L2 17l2.1-.6z"/><path d="M18 13l.7 1.9 1.8.6-1.8.6-.7 1.9-.7-1.9-1.8-.6 1.8-.6z"/></svg>',
};

function formatHeader(iso) {
  if (!iso) return '';
  const d = new Date(iso); // ISO date-only string parses as UTC midnight
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });
}

function toClientProps(shared) {
  const { selectedDate, events = [] } = shared ?? {};
  return {
    dateHeader: formatHeader(selectedDate),
    events: events.map((e) => ({
      id: e.id,
      title: e.title,
      dayNumber: e.dayNumber,
      coverImageUrl: e.coverImageUrl ?? '',
      estimatedMinutes: e.estimatedMinutes ?? 0,
      activities: (e.activityIcons ?? []).map((a) => ({
        icon: ACTIVITY_SVG[a.icon] ?? '',
        label: a.label,
      })),
    })),
  };
}

export default {
  toClient(shared) {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both inset content 16px from the edge).
      clip: '.capture-wrap',
      data: {
        component: 'CalendarEventListContent',
        componentProps: toClientProps(shared),
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CalendarEventListContent',
      state: { component: shared ?? {} },
    };
  },
};
