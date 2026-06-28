/**
 * Adapter: SelectableLockedBlockView (component comparison).
 *
 * Projects one canonical selectable-locked-block description into:
 *   - toClient → selectable-locked-block-view.vue via the ComponentCapture island
 *   - toIphone → SelectableLockedBlockView.swift via the
 *     component.SelectableLockedBlockView ViewRegistry case
 *
 * The shared block is the raw `SelectableLockedBlockView` prop bag (plainText +
 * selections + flags), so both sides receive the same scripture text, selection
 * ranges, and font size and render it with their own text engine.
 */
export default {
  toClient(shared) {
    const {
      plainText = '',
      selections = [],
      usePreviewHighlightStyle = false,
      fontSize = 16,
      isScripture = true,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'SelectableLockedBlockView',
        componentProps: {
          plainText,
          selections: selections.map((s) => ({ start: s.start, end: s.end, style: s.style })),
          usePreviewHighlightStyle: usePreviewHighlightStyle === true,
          fontSize,
          isScripture: isScripture !== false,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.SelectableLockedBlockView',
      state: { component: shared },
    };
  },
};
