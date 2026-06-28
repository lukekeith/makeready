/**
 * Adapter: CalendarDayCell (component comparison).
 *
 * Projects one canonical day-cell description into:
 *   - toClient → calendar-day-cell.vue via the ComponentCapture island
 *   - toIphone → CalendarDayCell.swift via the component.CalendarDayCell
 *               ViewRegistry case (unchanged from the iPhone-first passthrough)
 *
 * The cell is pure geometry + state (day number, today/selected/outside flags,
 * a list of event-dot colors) — there are no semantic icons to map, so both
 * platforms receive the same fields. The "dots flip to white on a today/
 * selected purple background" rule lives in each renderer, not here.
 */
export default {
  toClient(shared) {
    const {
      dayNumber,
      isCurrentMonth = true,
      isToday = false,
      isSelected = false,
      eventColors = [],
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = cell + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CalendarDayCell',
        componentProps: {
          dayNumber,
          isCurrentMonth: isCurrentMonth === true,
          isToday: isToday === true,
          isSelected: isSelected === true,
          eventColors,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CalendarDayCell',
      state: { component: shared ?? {} },
    };
  },
};
