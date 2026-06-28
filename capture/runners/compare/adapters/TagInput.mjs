/**
 * Adapter: TagInput (component comparison, two-sided twin).
 *
 * Projects one canonical tag-input description into:
 *   - toClient → tag-input.vue via the ComponentCapture island
 *   - toIphone → TagInput.swift via the component.TagInput ViewRegistry case
 *               (unchanged from today's iPhone-first passthrough).
 *
 * The fixture's `shared` block carries the canonical iPhone shape
 * (`{ tags, placeholder }`). Both platforms consume the same two fields, so the
 * projection is a straight forward; the xmark on each pill is an SF symbol on
 * iOS and inline SVG drawn by the twin, so there are no icons to map here.
 */
export default {
  toClient(shared = {}) {
    const { tags = [], placeholder = 'Add tag...' } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (the card well + 16px gutters),
      // matching the iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'TagInput',
        componentProps: {
          tags,
          placeholder,
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.TagInput',
      state: { component: shared },
    };
  },
};
