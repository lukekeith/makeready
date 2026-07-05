/**
 * Adapter: bible-passage-picker (page comparison, WEB-ONLY).
 * The iPhone Bible reader overlay (Pages/Bible/BibleReaderOverlay.swift) is a
 * pure-UIKit window subview with no ViewRegistry case — the iPhone side
 * cannot be captured. The web twin renders each screen statically from the
 * fixture's `picker` blob (books / reader / search).
 */
export default {
  toClient(shared) {
    const { picker = {} } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'BiblePassagePicker',
        componentProps: { ...picker },
      },
    };
  },

  // No iPhone capture case exists for the UIKit overlay (see fixture note).
  toIphone() {
    return null;
  },
};
