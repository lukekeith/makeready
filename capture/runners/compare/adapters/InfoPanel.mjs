/**
 * Adapter: InfoPanel (component comparison).
 *
 * Projects one canonical info-panel description into:
 *   - toClient → info-panel.vue via the ComponentCapture island
 *   - toIphone → InfoPanel.swift via the component.InfoPanel ViewRegistry case
 *
 * The `shared` block is the same data both platforms render: a `mode`
 * ('keyValue' | 'data') and an `items` array of { label, value }. Each adapter
 * forwards it unchanged — there are no semantic icons to map.
 */
export default {
  toClient(shared) {
    const { mode = 'keyValue', items = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'InfoPanel',
        componentProps: {
          mode,
          items: items.map((it) => ({ label: it.label, value: it.value })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.InfoPanel',
      state: { component: shared },
    };
  },
};
