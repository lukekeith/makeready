/**
 * Adapter: CardBibleSearchResult (component comparison).
 *
 * Projects one canonical Bible-search-result description into:
 *   - toClient → card-bible-search-result.vue via the ComponentCapture island
 *   - toIphone → CardBibleSearchResult.swift via the component.CardBibleSearchResult
 *     ViewRegistry case
 *
 * The canonical `shared` block IS the iPhone prop bag (passage / text / title? /
 * description?), so toIphone passes it straight through (unchanged from the prior
 * generic iphoneCard adapter). The Vue twin takes the same field names, so the
 * client mapping is a near-identity — title presence switches Verse ↔ Passage on
 * both platforms. No semantic icons in this component, so nothing to map.
 */
export default {
  toClient(shared) {
    const { passage, text, title, description } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardBibleSearchResult',
        componentProps: {
          passage,
          text,
          title: title ?? '',
          description: description ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardBibleSearchResult',
      state: { component: shared ?? {} },
    };
  },
};
