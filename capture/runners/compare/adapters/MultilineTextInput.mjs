/**
 * Adapter: MultilineTextInput (component comparison, two-sided twin).
 *
 * Projects one canonical multiline-text-input description into:
 *   - toClient → multiline-text-input.vue via the ComponentCapture island
 *   - toIphone → MultilineTextInput.swift via the component.MultilineTextInput case
 *               (MultilineTextInput wrapped in a FieldGroup, .padding(16) —
 *                unchanged from today)
 *
 * The fixture's `shared` block carries `{ placeholder, text }`, the exact shape
 * both sides expect, so the projection is a straight passthrough — no semantic
 * icons to map. The floating-label state (resting vs floated) is derived from
 * `text` on each side (iOS: isFloatingUp = isFocused || !text.isEmpty; the
 * isolated snapshot is unfocused, so it floats iff text is present).
 */
export default {
  toClient(shared = {}) {
    const { placeholder = '', text = '' } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'MultilineTextInput',
        componentProps: {
          placeholder,
          text,
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.MultilineTextInput',
      state: { component: shared },
    };
  },
};
