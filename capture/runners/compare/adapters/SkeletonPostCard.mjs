/**
 * Adapter: SkeletonPostCard (component comparison).
 *
 * Projects one canonical skeleton-post description into:
 *   - toClient → skeleton-post-card.vue via the ComponentCapture island
 *   - toIphone → SkeletonPostCard.swift via the component.SkeletonPostCard
 *     ViewRegistry case
 *
 * The `shared` block is the component's prop bag verbatim
 * (programName / programImageUrl). The iPhone side forwards it unchanged; the
 * web side maps it onto the Vue props. The chrome glyphs (eye / share spinner)
 * are intrinsic to the skeleton and live inside the Vue component, so nothing
 * semantic needs mapping here. The program image URL is forwarded only when
 * present — in the isolated snapshot iOS's AsyncImage never resolves it anyway,
 * and the default variant has none, so both sides render the shimmer cover.
 */
export default {
  toClient(shared) {
    const { programName, programImageUrl } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'SkeletonPostCard',
        componentProps: {
          programName: programName ?? null,
          programImageUrl: programImageUrl ?? null,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.SkeletonPostCard',
      state: { component: shared ?? {} },
    };
  },
};
