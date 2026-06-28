/**
 * Adapter: CardSpinnerOverlay (component comparison).
 *
 * Projects the canonical `shared` block into:
 *   - toIphone → CardSpinnerOverlay.swift via the component.CardSpinnerOverlay
 *     ViewRegistry case (which hosts the overlay over a 320×140 cardBackground
 *     rounded rectangle so the size-less overlay has bounds to fill).
 *   - toClient → card-spinner-overlay.vue via the ComponentCapture island.
 *
 * The overlay has no props (the only variant is `default`, `shared: {}`), so
 * there is nothing semantic to map — the Vue twin reproduces the same host card
 * + black@40% wash + white spinner intrinsically. The iPhone side is unchanged
 * from the iphone-card passthrough it replaces.
 */
export default {
  toClient() {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = the 320×140 card + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardSpinnerOverlay',
        componentProps: {},
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardSpinnerOverlay',
      state: { component: shared ?? {} },
    };
  },
};
