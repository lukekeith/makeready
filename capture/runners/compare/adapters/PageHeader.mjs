/**
 * Adapter: PageHeader (component comparison).
 *
 * Projects one canonical page-header description into:
 *   - toClient → page-header.vue via the ComponentCapture island
 *   - toIphone → PageHeader.swift via the component.PageHeader ViewRegistry case
 *
 * `shared` is the header's state verbatim ({ tabs, activeTab }). Both platforms
 * forward it unchanged — the tab layout + active underline are intrinsic to the
 * component, so the only variant-varying data is the tab labels and which one is
 * active. There are no semantic icons (the captured variants have no trailing
 * content), so nothing needs platform icon mapping.
 */
export default {
  toClient(shared) {
    const { tabs = [], activeTab = 0 } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'PageHeader',
        componentProps: {
          tabs,
          activeTab,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.PageHeader',
      state: { component: shared ?? {} },
    };
  },
};
