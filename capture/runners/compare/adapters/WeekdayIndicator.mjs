/**
 * Adapter: WeekdayIndicator (component comparison).
 *
 * Projects the canonical weekday set into:
 *   - toClient → weekday-indicator.vue via the ComponentCapture island
 *   - toIphone → component.WeekdayIndicator ViewRegistry case
 *               (Components/Display/WeekdayIndicator.swift), unchanged from the
 *               original generic iphoneCard passthrough.
 *
 * The shared data is a plain `{ enabledDays: number[] }` (0 = Sunday … 6 =
 * Saturday) — the same Set<Int> the SwiftUI view consumes — so both sides map it
 * straight through. No icons to translate; the dots are pure CSS/SwiftUI shapes.
 */
export default {
  toClient(shared) {
    const { enabledDays = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (component + 16px gutters → 440×64pt).
      clip: '.capture-wrap',
      data: {
        component: 'WeekdayIndicator',
        componentProps: {
          enabledDays,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.WeekdayIndicator',
      state: { component: shared },
    };
  },
};
