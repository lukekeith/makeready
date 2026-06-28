/**
 * Adapter: ExegesisVerseView (component comparison).
 *
 * Projects one canonical exegesis-verse description into:
 *   - toClient → exegesis-verse-view.vue via the ComponentCapture island
 *   - toIphone → ExegesisVerseView.swift via the component.ExegesisVerseView
 *     ViewRegistry case
 *
 * The shared block is the raw `ExegesisVerseView` prop bag (plainText +
 * highlights + flags), so both sides receive the same scripture text, highlight
 * ranges, and font size and render it with their own text engine.
 */
export default {
  toClient(shared) {
    const {
      plainText = '',
      highlights = [],
      usePreviewHighlightStyle = false,
      fontSize = 16,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'ExegesisVerseView',
        componentProps: {
          plainText,
          highlights: highlights.map((h) => ({ start: h.start, end: h.end, style: h.style })),
          usePreviewHighlightStyle: usePreviewHighlightStyle === true,
          fontSize,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ExegesisVerseView',
      state: { component: shared },
    };
  },
};
