/**
 * Adapter: SlideButton (component comparison).
 *
 * Projects one canonical slide-button description into:
 *   - toClient → CardSlideButton.vue via the ComponentCapture island
 *   - toIphone → SlideButton.swift via the component.SlideButton ViewRegistry case
 *
 * The iOS SlideButton (SwipeableCard.buttonRow) renders as a 48pt circle filled
 * by `style` with a single white SF Symbol icon. `icon` travels semantically
 * (e.g. "calendar") and each adapter maps it to its platform's icon system —
 * inline SVG for web, the raw SF Symbol name for iPhone.
 */

// Web SVGs chosen to silhouette-match the SF Symbols the iPhone renders.
const WEB_ICONS = {
  // SF "calendar" — rounded frame, two top tabs, a grid of day dots.
  calendar:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<rect x="3" y="5" width="18" height="16" rx="3.5"/>'
    + '<path d="M7 3v3M17 3v3M3 9.5h18"/>'
    + '<g fill="currentColor" stroke="none">'
    + '<circle cx="8" cy="13" r="1"/><circle cx="12" cy="13" r="1"/><circle cx="16" cy="13" r="1"/>'
    + '<circle cx="8" cy="17" r="1"/><circle cx="12" cy="17" r="1"/><circle cx="16" cy="17" r="1"/>'
    + '</g></svg>',
  // SF "trash" — lid, handle, tapering can with rib lines.
  trash:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M4 7h16"/>'
    + '<path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/>'
    + '<path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/>'
    + '<path d="M10 11v6.5M14 11v6.5"/>'
    + '</svg>',
  // SF "forward" — two outlined right-pointing triangles (fast-forward).
  forward:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round">'
    + '<path d="M3 5.5l8 6.5-8 6.5z"/>'
    + '<path d="M13 5.5l8 6.5-8 6.5z"/>'
    + '</svg>',
  // SF "pencil" — diagonal pencil with a small tip.
  pencil:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/>'
    + '<path d="M14.5 5.5l3 3"/>'
    + '</svg>',
};

export default {
  toClient(shared) {
    const { icon, style } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'SlideButton',
        componentProps: {
          icon: WEB_ICONS[icon] ?? '',
          // `style` is a Vue reserved attribute, so the Vue twin takes the fill
          // as `variant` (see card-slide-button.vue).
          variant: style ?? 'skip',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.SlideButton',
      state: { component: shared },
    };
  },
};
