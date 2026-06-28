/**
 * Adapter: PageTitle (component comparison).
 *
 * Projects one canonical page-title description into:
 *   - toClient → page-title.vue via the ComponentCapture island
 *   - toIphone → PageTitle.swift via the component.PageTitle ViewRegistry case
 *
 * `shared` is the header's fixture bag verbatim (factory + title/leftIcon/
 * leftLink/rightIcon/rightLink/rightIcons/showDropdown/backText). The iPhone
 * side forwards it unchanged — each icon name is an SF Symbol consumed by
 * SwiftUI's `Image(systemName:)`.
 *
 * For the web twin, the action-slot SF Symbols (leftIcon / rightIcon /
 * rightIcons[].icon) are transcribed to inline SVG (drawn `currentColor` so the
 * SCSS tints them white). The intrinsic chevrons (dropdown chevron.down, the
 * back-link chevron.left) live in the Vue component itself, so the factory +
 * text fields pass through untouched.
 */

// SF "chevron.left" — back/nav arrow.
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M15 4l-7 8 7 8"/>' +
  '</svg>';

// SF "xmark" — close cross.
const XMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M5 5l14 14M19 5L5 19"/>' +
  '</svg>';

// SF "checkmark" — confirm tick.
const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M4 12.5l5 5L20 5.5"/>' +
  '</svg>';

// SF "paperplane" (outline) — send arrow: a triangle with a center fold + tail
// notch, pointing up-right.
const PAPERPLANE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' +
  '<path d="M21.5 2.5L2.6 9.7a0.5 0.5 0 0 0 0 0.95l7.3 2.55 2.55 7.3a0.5 0.5 0 0 0 0.95 0z"/>' +
  '<path d="M21.5 2.5L9.9 13.2"/>' +
  '</svg>';

// SF "person.2" (outline) — two overlapping people: a front figure + a partial
// back figure to its trailing side.
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' +
  '<circle cx="9" cy="7.5" r="3.3"/>' +
  '<path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/>' +
  '<path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/>' +
  '<path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/>' +
  '</svg>';

// SF "calendar" (outline) — rounded month frame with a header rule + a dot grid.
const CALENDAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' +
  '<rect x="3" y="4.5" width="18" height="16.5" rx="2.6"/>' +
  '<path d="M3 9.2h18"/>' +
  '<g fill="currentColor" stroke="none">' +
  '<circle cx="7.5" cy="13" r="0.95"/><circle cx="12" cy="13" r="0.95"/><circle cx="16.5" cy="13" r="0.95"/>' +
  '<circle cx="7.5" cy="17" r="0.95"/><circle cx="12" cy="17" r="0.95"/><circle cx="16.5" cy="17" r="0.95"/>' +
  '</g>' +
  '</svg>';

// SF "gearshape" (outline) — cog: spoked outer ring + center hub.
const GEARSHAPE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' +
  '<circle cx="12" cy="12" r="3.2"/>' +
  '<path d="M19.4 13a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1.03 1.56V19a2 2 0 1 1-4 0v-.09A1.7 1.7 0 0 0 8.8 17.4a1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.7 1.7 0 0 0 4.6 13a1.7 1.7 0 0 0-1.56-1.03H3a2 2 0 1 1 0-4h.09A1.7 1.7 0 0 0 4.6 6.93a1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34H9a1.7 1.7 0 0 0 1.03-1.56V1a2 2 0 1 1 4 0v.09a1.7 1.7 0 0 0 1.03 1.56 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.7 1.7 0 0 0 19.4 7v.05a1.7 1.7 0 0 0 1.56 1.03H21a2 2 0 1 1 0 4h-.09A1.7 1.7 0 0 0 19.4 13z"/>' +
  '</svg>';

const WEB_ICONS = {
  'chevron.left': CHEVRON_LEFT,
  xmark: XMARK,
  checkmark: CHECKMARK,
  paperplane: PAPERPLANE,
  'person.2': PERSON_2,
  calendar: CALENDAR,
  gearshape: GEARSHAPE,
};

function svgFor(name) {
  if (!name) return '';
  return WEB_ICONS[name] ?? '';
}

export default {
  toClient(shared) {
    const {
      factory = 'iconTitle',
      title = '',
      leftIcon = null,
      leftLink = null,
      rightIcon = null,
      rightLink = null,
      rightIcons = null,
      showDropdown = false,
      backText = null,
    } = shared ?? {};

    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'PageTitle',
        componentProps: {
          factory,
          title: title ?? '',
          leftIcon: svgFor(leftIcon),
          leftLink: leftLink ?? '',
          rightIcon: svgFor(rightIcon),
          rightLink: rightLink ?? '',
          rightIcons: (rightIcons ?? []).map((ic) => ({
            icon: svgFor(ic.icon),
            showBadge: ic.showBadge ?? false,
          })),
          showDropdown: showDropdown ?? false,
          backText: backText ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.PageTitle',
      state: { component: shared ?? {} },
    };
  },
};
