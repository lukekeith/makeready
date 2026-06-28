/**
 * Adapter: CardStudySelectable (component comparison).
 *
 * Projects one canonical selectable-study-card description into:
 *   - toClient → card-study-selectable.vue via the ComponentCapture island
 *   - toIphone → CardStudySelectable.swift via the component.CardStudySelectable
 *     ViewRegistry case
 *
 * The shared block carries the same fields the Vue twin's props use (title,
 * description, count, imageUrl, selected, isPublished). The card's only glyphs
 * (the metadata book and the selected-state checkmark) are fixed and baked into
 * the Vue component, so there are no semantic icons to map here.
 */
export default {
  toClient(shared) {
    const {
      title,
      description = '',
      count = 0,
      imageUrl = '',
      selected = false,
      isPublished = true,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardStudySelectable',
        componentProps: {
          title,
          description,
          count,
          imageUrl,
          selected,
          isPublished,
        },
      },
    };
  },

  // Unchanged from the prior iphoneCard('component.CardStudySelectable')
  // passthrough: the canonical `shared` block IS the SwiftUI prop bag, decoded
  // into CardStudySelectableData by the ViewRegistry.
  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardStudySelectable',
      state: { component: shared ?? {} },
    };
  },
};
