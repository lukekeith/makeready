/**
 * Adapter: CalendarBottomBar (component comparison).
 *
 * Projects one canonical bottom-bar description into:
 *   - toClient → calendar-bottom-bar.vue via the ComponentCapture island
 *   - toIphone → CalendarBottomBar.swift via the component.CalendarBottomBar
 *               ViewRegistry case (unchanged from the iPhone-first passthrough)
 *
 * The two variants are driven entirely by whether the view-mode toggles show
 * (`showViewModes`) and which mode reads as active (`selectedMode`), so both
 * fields travel in `shared` and each adapter forwards them to its platform.
 * The Today button's calendar icon is intrinsic to the component (not data),
 * so the Vue twin inlines its own SVG — nothing icon-shaped needs mapping here.
 */
export default {
  toClient(shared) {
    const { showViewModes = false, selectedMode = 'month' } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CalendarBottomBar',
        componentProps: {
          showViewModes: showViewModes === true,
          selectedMode,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CalendarBottomBar',
      state: { component: shared ?? {} },
    };
  },
};
