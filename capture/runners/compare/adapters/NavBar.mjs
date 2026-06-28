/**
 * Adapter: NavBar (component comparison).
 *
 * Projects one canonical nav-bar description into:
 *   - toClient → nav-bar.vue via the ComponentCapture island
 *   - toIphone → NavBar.swift via the component.NavBar ViewRegistry case
 *
 * `shared` is the bar's state verbatim ({ activeTab, avatarURL }). The iPhone
 * side forwards it unchanged. The web twin's six-tab structure + glyphs are
 * intrinsic to the bar, so the only variant-varying data the client needs is the
 * active tab and the avatar's render mode:
 *   • avatarURL present → CachedAsyncImage's photo never resolves in the isolated
 *     snapshot, so iOS shows its ProgressView spinner → avatarMode 'loading'.
 *   • avatarURL null → iOS falls back to the gray circle + person glyph →
 *     avatarMode 'fallback'.
 */
export default {
  toClient(shared) {
    const { activeTab = '', avatarURL = null } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'NavBar',
        componentProps: {
          activeTab: activeTab ?? '',
          avatarMode: avatarURL ? 'loading' : 'fallback',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.NavBar',
      state: { component: shared ?? {} },
    };
  },
};
