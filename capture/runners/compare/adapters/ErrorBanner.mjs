/**
 * Adapter: ErrorBanner (component comparison).
 *
 * Projects one canonical error-banner description into:
 *   - toClient → card/error-banner/error-banner.vue via the ComponentCapture island
 *   - toIphone → component.ErrorBanner ViewRegistry case
 *               (Components/Feedback/ErrorBanner.swift, the pure `ErrorBanner` struct)
 *
 * The `shared` block is the banner's prop bag: { message, hasRetry }. The iPhone
 * side receives it unchanged (the ViewRegistry maps `hasRetry` → a non-nil
 * `onRetry` closure). The two fixed glyphs (exclamationmark.triangle.fill and the
 * retry arrow.clockwise) are intrinsic chrome — they never vary by data — so they
 * live inline in each platform's component rather than travelling through here.
 */
export default {
  toClient(shared) {
    const { message = '', hasRetry = false } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot framing (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'ErrorBanner',
        componentProps: {
          message,
          hasRetry: hasRetry === true,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ErrorBanner',
      state: { component: shared },
    };
  },
};
