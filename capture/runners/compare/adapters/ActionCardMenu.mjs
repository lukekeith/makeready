/**
 * Adapter: ActionCardMenu (component comparison).
 *
 * Projects one canonical action-card-menu description into:
 *   - toClient → action-card-menu.vue via the ComponentCapture island
 *   - toIphone → ActionCardMenu.swift via the component.ActionCardMenu
 *     ViewRegistry case
 *
 * The `shared` block is the component's prop bag verbatim (title + items, each
 * item = { icon, title, description }). The iPhone side forwards it unchanged —
 * `icon` is an SF Symbol name consumed by SwiftUI's `Image(systemName:)`. The
 * web side maps each SF Symbol name to inline SVG markup (the chevron + xmark
 * glyphs are rendered internally by the Vue twin).
 */

// SF Symbol "book.fill" → inline SVG (open filled book). Two symmetric page
// shapes meeting at a center-spine gap so it reads as an open book.
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor">' +
  '<path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/>' +
  '<path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/>' +
  '</svg>';

// SF Symbol "calendar.badge.plus" → inline SVG (line-weight calendar with a
// trailing plus badge), matching the outlined iOS glyph.
const CALENDAR_BADGE_PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' +
  '<rect x="3" y="4.5" width="18" height="16" rx="2.5"/>' +
  '<path d="M3 9.5h18"/>' +
  '<path d="M8 2.5v4M16 2.5v4"/>' +
  '<path d="M15 16.5h6M18 13.5v6"/>' +
  '</svg>';

// SF Symbol "photo.on.rectangle" → inline SVG (line-weight photo frame, with
// sun + mountains, sitting on a back rectangle), matching the outlined iOS glyph.
const PHOTO_ON_RECTANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' +
  '<rect x="7" y="3" width="14" height="11" rx="2"/>' +
  '<circle cx="11" cy="7" r="1.3"/>' +
  '<path d="M8 12.5l3-3.2 2.4 2.4 2.4-2.8L20 13"/>' +
  '<path d="M17 17H5a2 2 0 0 1-2-2V7"/>' +
  '</svg>';

const WEB_ICONS = {
  'book.fill': BOOK_FILL,
  'calendar.badge.plus': CALENDAR_BADGE_PLUS,
  'photo.on.rectangle': PHOTO_ON_RECTANGLE,
};

export default {
  toClient(shared) {
    const { title, items = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'ActionCardMenu',
        componentProps: {
          title,
          items: items.map((item) => ({
            icon: WEB_ICONS[item.icon] ?? '',
            title: item.title,
            description: item.description,
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ActionCardMenu',
      state: { component: shared ?? {} },
    };
  },
};
