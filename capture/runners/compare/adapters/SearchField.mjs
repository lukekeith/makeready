/**
 * Adapter: SearchField (component comparison, two-sided twin).
 *
 * Projects one canonical search-field description into:
 *   - toClient → search-field.vue via the ComponentCapture island
 *   - toIphone → SearchField.swift via the component.SearchField ViewRegistry case
 *               (unchanged from today's iPhone-first passthrough).
 *
 * The fixture's `shared` block carries the canonical iPhone shape
 * (`{ isActive, searchText, placeholder }`). Both platforms consume the same three
 * fields, so the projection is a straight forward of the resting-state props; the
 * magnifyingglass / xmark glyphs are SF symbols on iOS and inline SVG in the twin
 * (drawn by the component), so there are no icons to map here.
 */
export default {
  toClient(shared = {}) {
    const { isActive = false, searchText = '', placeholder = 'Search' } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (field + close button + 16px gutters),
      // matching the iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'SearchField',
        componentProps: {
          isActive,
          searchText,
          placeholder,
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.SearchField',
      state: { component: shared },
    };
  },
};
