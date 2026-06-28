/**
 * Adapter: HamburgerMenu (component comparison).
 *
 * Projects one canonical hamburger-menu description into:
 *   - toClient → hamburger-menu.vue via the ComponentCapture island
 *   - toIphone → HamburgerMenu.swift via the component.HamburgerMenu ViewRegistry case
 *
 * `shared` is the menu's content verbatim ({ items: [{ icon, title }] }). The
 * iPhone side forwards `shared` unchanged. The web side is genuinely data-driven,
 * so each item's `icon` (an SF Symbol name) is mapped here to the matching inline
 * SVG, drawn at currentColor so the Vue twin's SCSS can tint it (#7c7cff). The
 * books (book.closed.fill / text.book.closed.fill) and the calendar
 * (calendar.badge.clock) are FILLED glyphs with knock-out detail (evenodd holes);
 * magnifyingglass is the lone outlined symbol — matching how iOS renders them.
 */

// SF Symbol "book.closed.fill" → filled closed book (chunky, spine slot knocked
// out), sized to fill the icon box like the iOS glyph.
const BOOK_CLOSED_FILL =
  '<svg viewBox="0 0 20 20" fill="currentColor" fill-rule="evenodd">' +
  '<path d="M5 1.5H15.5A1.6 1.6 0 0 1 17.1 3.1V16.9A1.6 1.6 0 0 1 15.5 18.5H5A2.6 2.6 0 0 1 2.4 15.9V4.1A2.6 2.6 0 0 1 5 1.5Z ' +
  'M5.7 3V17H7V3Z"/>' +
  '</svg>';

// SF Symbol "text.book.closed.fill" → filled closed book with text lines (holes).
const TEXT_BOOK_CLOSED_FILL =
  '<svg viewBox="0 0 20 20" fill="currentColor" fill-rule="evenodd">' +
  '<path d="M5 1.5H15.5A1.6 1.6 0 0 1 17.1 3.1V16.9A1.6 1.6 0 0 1 15.5 18.5H5A2.6 2.6 0 0 1 2.4 15.9V4.1A2.6 2.6 0 0 1 5 1.5Z ' +
  'M5.7 3V17H7V3Z ' +
  'M9 5.7H14.4V7H9Z ' +
  'M9 8.9H14.4V10.2H9Z ' +
  'M9 12.1H14.4V13.4H9Z"/>' +
  '</svg>';

// SF Symbol "magnifyingglass" → outlined glass (the lone non-filled symbol).
const MAGNIFYINGGLASS =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round">' +
  '<circle cx="8.3" cy="8.3" r="5.3"/>' +
  '<path d="M12.4 12.4L17 17"/>' +
  '</svg>';

// SF Symbol "calendar.badge.clock" → filled calendar (header line + grid-dot
// holes) with a clock badge bottom-right. The gap ring + clock hands are true
// evenodd holes, so the card pixel shows through (no hardcoded background fill).
const CALENDAR_BADGE_CLOCK =
  '<svg viewBox="0 0 22 20" fill="currentColor" fill-rule="evenodd">' +
  '<path d="M4.5 4H15.5A1.5 1.5 0 0 1 17 5.5V14.5A1.5 1.5 0 0 1 15.5 16H4.5A1.5 1.5 0 0 1 3 14.5V5.5A1.5 1.5 0 0 1 4.5 4Z ' +
  'M3 7.2H17V8.1H3Z ' +
  'M5.2 9.6H6.7V10.9H5.2Z M8.6 9.6H10.1V10.9H8.6Z M12 9.6H13.5V10.9H12Z ' +
  'M5.2 11.9H6.7V13.2H5.2Z M8.6 11.9H10.1V13.2H8.6Z ' +
  'M16.5 10.1A4.7 4.7 0 1 0 16.5 19.5A4.7 4.7 0 0 0 16.5 10.1Z"/>' +
  '<path d="M16.5 11.3A3.5 3.5 0 1 0 16.5 18.3A3.5 3.5 0 0 0 16.5 11.3Z ' +
  'M16.05 12.4H16.95V14.95L18.6 15.9L18.15 16.68L16.05 15.45Z"/>' +
  '</svg>';

const WEB_ICONS = {
  'book.closed.fill': BOOK_CLOSED_FILL,
  'text.book.closed.fill': TEXT_BOOK_CLOSED_FILL,
  magnifyingglass: MAGNIFYINGGLASS,
  'calendar.badge.clock': CALENDAR_BADGE_CLOCK,
};

function mapItem(item) {
  return {
    icon: WEB_ICONS[item.icon] ?? '',
    title: item.title,
  };
}

export default {
  toClient(shared) {
    const { items = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'HamburgerMenu',
        componentProps: {
          items: items.map(mapItem),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.HamburgerMenu',
      state: { component: shared ?? {} },
    };
  },
};
