/**
 * Adapter: ToggleControl (component comparison, two-sided twin).
 *
 * Projects one canonical toggle-control description into:
 *   - toClient → toggle-control.vue via the ComponentCapture island
 *   - toIphone → ToggleControl.swift via the component.ToggleControl case
 *               (ToggleControl wrapped in a ToggleGroup, .padding(16) — unchanged
 *                from today)
 *
 * The fixture's `shared` block carries `{ title, description, isOn }`. There are no
 * semantic icons to map; both platforms render the same custom pill toggle from
 * `isOn`, so the canonical shape forwards unchanged to each side.
 */
export default {
  toClient(shared = {}) {
    const { title = '', description = '', isOn = false } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (ToggleGroup card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'ToggleControl',
        componentProps: { title, description, isOn },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (iOS renders the toggle from it).
    return {
      platform: 'iphone',
      view: 'component.ToggleControl',
      state: { component: shared },
    };
  },
};
