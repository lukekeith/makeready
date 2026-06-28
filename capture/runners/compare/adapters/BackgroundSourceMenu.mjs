/**
 * Adapter: BackgroundSourceMenu (component comparison).
 *
 * Projects into:
 *   - toClient → background-source-menu.vue via the ComponentCapture island
 *   - toIphone → BackgroundSourceMenu.swift via the component.BackgroundSourceMenu
 *     ViewRegistry case
 *
 * The menu's three rows + their SF Symbols are fixed in the iOS component (the
 * `shared` block is empty `{}`), so the Vue twin owns the same fixed content +
 * inline SVG icons. Nothing to map.
 */
export default {
  toClient() {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'BackgroundSourceMenu',
        componentProps: {},
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.BackgroundSourceMenu',
      state: { component: shared ?? {} },
    };
  },
};
