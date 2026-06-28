/**
 * Adapter: CalendarWeekdayHeader (component comparison).
 *
 * Projects one canonical weekday-header description into:
 *   - toClient → calendar-weekday-header.vue via the ComponentCapture island
 *   - toIphone → CalendarWeekdayHeader (CalendarHeaderView.swift) via the
 *               component.CalendarWeekdayHeader ViewRegistry case (unchanged
 *               from the iPhone-first passthrough)
 *
 * The header is a fixed "S M T W T F S" row — no semantic icons, no per-instance
 * data — so both platforms receive the same (empty) shared block. The seven
 * Sunday-first letters are defaulted by each renderer.
 */
export default {
  toClient(shared) {
    const { days } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = the full-width weekday row).
      clip: '.capture-wrap',
      data: {
        component: 'CalendarWeekdayHeader',
        componentProps: {
          ...(days ? { days } : {}),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CalendarWeekdayHeader',
      state: { component: shared ?? {} },
    };
  },
};
