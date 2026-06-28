/**
 * Adapter: SkeletonCardLesson (component comparison).
 *
 * Projects the canonical (empty) skeleton description into:
 *   - toClient → skeleton-card-lesson.vue via the ComponentCapture island
 *   - toIphone → component.SkeletonCardLesson ViewRegistry case (unchanged)
 *
 * The iOS SkeletonCardLesson takes no parameters (it's a static loading
 * placeholder), so `shared` is `{}` and neither side needs prop mapping.
 */
export default {
  toClient() {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'SkeletonCardLesson',
        componentProps: {},
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.SkeletonCardLesson',
      state: { component: shared ?? {} },
    };
  },
};
