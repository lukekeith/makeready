/**
 * Adapter: exegesis-highlight-menu (component comparison, WEB-ONLY).
 * iOS HighlightActionMenuContent is private to EditExegesisActivityPage —
 * no ViewRegistry case exists, so only the web twin renders (see fixture
 * note). Presented in production through the managed-menu chrome on the
 * `.exegesisHighlightActionMenu` route.
 */
export default {
  toClient(shared) {
    const { menu = {} } = shared ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'ExegesisHighlightMenu',
        componentProps: { ...menu },
      },
    };
  },

  toIphone() {
    return null;
  },
};
