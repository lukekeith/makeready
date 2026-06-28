/**
 * Adapter: TabSlider (component comparison).
 *
 * Projects one canonical tab-slider description into:
 *   - toClient → tab-slider.vue via the ComponentCapture island
 *   - toIphone → TabSlider.swift via the component.TabSlider ViewRegistry case
 *
 * `shared` is the control's state verbatim ({ tabs, selectedIndex }). Both
 * platforms forward it unchanged — the segmented layout (white@20% track, the
 * brandPrimary pill behind the selected tab) is intrinsic to the component, so
 * the only variant-varying data is the tab labels and which one is selected.
 * There are no semantic icons (the tabs are text only), so nothing needs
 * platform icon mapping.
 */
export default {
  toClient(shared) {
    const { tabs = [], selectedIndex = 0 } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + the harness's 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'TabSlider',
        componentProps: {
          tabs,
          selectedIndex,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.TabSlider',
      state: { component: shared ?? {} },
    };
  },
};
