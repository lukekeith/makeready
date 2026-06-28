/**
 * Adapter: RichTextInput (component comparison, two-sided twin).
 *
 * Projects one canonical rich-text-input description into:
 *   - toClient → rich-text-input.vue via the ComponentCapture island
 *   - toIphone → RichTextInput.swift via the component.RichTextInput case
 *               (RichTextInput(placeholder:, html: .constant(html), minHeight: 200,
 *                autoGrow: false, outputFormat:) wrapped in .padding(16) — unchanged
 *                from the iPhone-first scaffold).
 *
 * The fixture's `shared` block carries `{ placeholder, html, outputFormat }`.
 * The toolbar is constant chrome baked into the Vue twin (its icons are inline
 * SVG / SF-Pro letter glyphs), so this adapter only forwards the text props.
 * `outputFormat` only affects how the iOS side decodes the body (html vs
 * markdown); the Vue twin parses the `html` block tags directly, so it forwards
 * `placeholder` + `html` only.
 */

export default {
  toClient(shared = {}) {
    const { placeholder = '', html = '' } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (the editor card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'RichTextInput',
        componentProps: { placeholder, html },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (the ViewRegistry derives the
    // AttributedString from `html`/`outputFormat` and the size from `autoGrow`).
    return {
      platform: 'iphone',
      view: 'component.RichTextInput',
      state: { component: shared },
    };
  },
};
