/**
 * Adapter: ShimmerView (component comparison).
 *
 * Projects the canonical `shared` block into:
 *   - toIphone → the `component.ShimmerView` ViewRegistry case, which builds the
 *     skeleton shape the fixture describes (a gray@0.3 rounded block, or a
 *     leading-aligned column of text-row bars) and applies the `.shimmer()`
 *     modifier. Unchanged from the iphone-card passthrough it replaces.
 *   - toClient → shimmer-view.vue via the ComponentCapture island.
 *
 * The shimmer gradient starts off-screen and only sweeps in on appear, so the
 * frozen snapshot shows just the static gray skeleton shapes — which is what the
 * Vue twin renders. The `shared` block is a plain shape descriptor (shape, size,
 * cornerRadius / rows), so it maps straight through to the twin's props.
 */
export default {
  toClient(shared) {
    const s = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = the skeleton shape + the 16px gutter).
      clip: '.capture-wrap',
      data: {
        component: 'ShimmerView',
        componentProps: {
          shape: s.shape ?? 'block',
          width: s.width ?? 320,
          height: s.height ?? 100,
          cornerRadius: s.cornerRadius ?? 8,
          rows: (s.rows ?? []).map((r) => ({
            width: r.width ?? 120,
            height: r.height ?? 20,
            cornerRadius: r.cornerRadius ?? 4,
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ShimmerView',
      state: { component: shared ?? {} },
    };
  },
};
