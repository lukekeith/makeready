/**
 * Adapter: InlineFontSizePicker (component comparison, two-sided twin).
 *
 * Projects one canonical font-size-picker description into:
 *   - toClient → inline-font-size-picker.vue via the ComponentCapture island
 *   - toIphone → InlineFontSizePicker.swift via the component.InlineFontSizePicker
 *               ViewRegistry case (a 5-tile "Aa" HStack wrapped in .padding(16) —
 *               unchanged from today)
 *
 * The fixture's `shared` block is already in the shape both sides expect
 * (`selectedSize: 'xs'|'s'|'m'|'lg'|'xl'`), so the projection is a straight
 * passthrough; no semantic icons to map.
 */
export default {
  toClient(shared = {}) {
    const { selectedSize } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (picker + 16px gutters), matching the
      // iPhone snapshot (ViewRegistry wraps the picker in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'InlineFontSizePicker',
        componentProps: {
          // Omit when absent so the Vue default ('m') keeps the iOS fallback.
          ...(selectedSize ? { selectedSize } : {}),
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.InlineFontSizePicker',
      state: { component: shared },
    };
  },
};
