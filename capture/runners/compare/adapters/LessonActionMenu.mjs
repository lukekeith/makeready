/**
 * Adapter: LessonActionMenu (component comparison).
 *
 * Projects one canonical lesson-action-menu description into:
 *   - toClient → lesson-action-menu.vue via the ComponentCapture island
 *   - toIphone → LessonActionMenu.swift via the component.LessonActionMenu
 *     ViewRegistry case
 *
 * The `shared` block is the component's fixture bag (studyName, dayNumber,
 * scheduledDate, enrollmentId, showEditEnrollment, showAddLesson, items). The
 * iPhone side forwards it unchanged — each item's `icon` is an SF Symbol name
 * consumed by SwiftUI's `Image(systemName:)`.
 *
 * For the web twin:
 *   - Each SF Symbol name maps to inline SVG markup (drawn `currentColor` so the
 *     SCSS tints normal rows brandPrimary and destructive rows bright red).
 *   - The "Day N - <date>" subtitle is pre-formatted here. The iPhone decodes
 *     `scheduledDate` ("2026-01-30") as UTC midnight then renders it with a
 *     local-tz DateFormatter ("MMM d, yyyy"), which shifts the displayed day back
 *     one in any negative-offset zone (Jan 30 → "Jan 29, 2026"). Formatting the
 *     same UTC-midnight Date in local tz here reproduces that exactly.
 */

// SF "pencil.line" — diagonal pencil over a short underline.
const PENCIL_LINE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M15 5l4 4L9 19l-4 1 1-4z"/>' +
  '<path d="M14.5 5.5l4 4"/>' +
  '<path d="M4 21.5h9"/>' +
  '</svg>';

// SF "slider.horizontal.3" — three horizontal rails, each with a filled knob at
// a different position (left / right / left).
const SLIDER_HORIZONTAL_3 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">' +
  '<path d="M3 6h18"/><path d="M3 12h18"/><path d="M3 18h18"/>' +
  '<circle cx="9" cy="6" r="2.4" fill="currentColor" stroke="none"/>' +
  '<circle cx="16" cy="12" r="2.4" fill="currentColor" stroke="none"/>' +
  '<circle cx="7" cy="18" r="2.4" fill="currentColor" stroke="none"/>' +
  '</svg>';

// SF "safari" — compass: a ring with a filled needle pointing up-right.
const SAFARI =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<circle cx="12" cy="12" r="9"/>' +
  '<path d="M16 8l-2.2 5.8L8 16l2.2-5.8z" fill="currentColor" stroke="none"/>' +
  '</svg>';

// SF "square.and.arrow.up" — share glyph: a tray with an up arrow rising out.
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M12 15V4M8 8l4-4 4 4"/>' +
  '<path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/>' +
  '</svg>';

// SF "plus" — plus sign.
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">' +
  '<path d="M12 5v14M5 12h14"/>' +
  '</svg>';

// SF "trash" — lid, handle, tapering can with rib lines.
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M4 7h16"/>' +
  '<path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/>' +
  '<path d="M6 7l1 12.5A2 2 0 0 0 9 19.5h6a2 2 0 0 0 2-2L18 7"/>' +
  '<path d="M10 11v6.5M14 11v6.5"/>' +
  '</svg>';

const WEB_ICONS = {
  'pencil.line': PENCIL_LINE,
  'slider.horizontal.3': SLIDER_HORIZONTAL_3,
  safari: SAFARI,
  'square.and.arrow.up': SHARE_UP,
  plus: PLUS,
  trash: TRASH,
};

// Format an ISO date-only string ("2026-01-30", parsed as UTC midnight) to the
// iOS "MMM d, yyyy" rendering in the capture machine's local tz.
function monthDayYear(iso) {
  if (!iso) return '';
  const date = new Date(iso);
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

export default {
  toClient(shared) {
    const { studyName, dayNumber, scheduledDate, items = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'LessonActionMenu',
        componentProps: {
          studyName,
          subtitle: `Day ${dayNumber} - ${monthDayYear(scheduledDate)}`,
          items: items.map((item) => ({
            icon: WEB_ICONS[item.icon] ?? '',
            title: item.title,
            style: item.style ?? 'normal',
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.LessonActionMenu',
      state: { component: shared ?? {} },
    };
  },
};
