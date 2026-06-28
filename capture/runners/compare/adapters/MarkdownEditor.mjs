/**
 * Adapter: MarkdownEditor (component comparison, two-sided twin).
 *
 * Projects one canonical markdown-editor description into:
 *   - toClient → markdown-editor.vue via the ComponentCapture island
 *   - toIphone → MarkdownEditor.swift via the component.MarkdownEditor case
 *               (MarkdownEditor(placeholder:, attributedText:
 *                .constant(MarkdownEditor.markdownToAttributed(markdown)),
 *                minHeight: 200, autoGrow:) wrapped in .padding(16) — unchanged
 *                from the iPhone-first scaffold).
 *
 * The fixture's `shared` block carries `{ placeholder, markdown, autoGrow }`.
 * The toolbar is constant chrome baked into the Vue twin (its icons are inline
 * SVG / SF-Pro letter glyphs), so this adapter only forwards the text props.
 */

export default {
  toClient(shared = {}) {
    const { placeholder = '', markdown = '', autoGrow = true } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (the editor card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'MarkdownEditor',
        componentProps: { placeholder, markdown, autoGrow },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (the ViewRegistry derives the
    // AttributedString from `markdown` and the size from `autoGrow`).
    return {
      platform: 'iphone',
      view: 'component.MarkdownEditor',
      state: { component: shared },
    };
  },
};
