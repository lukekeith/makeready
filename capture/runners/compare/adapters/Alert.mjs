/**
 * Adapter: Alert (component comparison).
 *
 * Projects one canonical alert description into:
 *   - toClient → alert.vue via the ComponentCapture island
 *   - toIphone → Alert.swift via the component.Alert ViewRegistry case
 *
 * The shared block is the raw `Alert` prop bag (message + variant). The leading
 * warning triangle is intrinsic to the component (same glyph on both
 * platforms — SF Symbol exclamationmark.triangle.fill / an inline SVG twin), so
 * it carries no icon field; only `variant` drives the tone on each side.
 */
export default {
  toClient(shared) {
    const { message = '', variant = 'warning' } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'Alert',
        componentProps: {
          message,
          variant: variant === 'critical' ? 'critical' : 'warning',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.Alert',
      state: { component: shared ?? {} },
    };
  },
};
