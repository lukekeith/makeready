/**
 * Adapter: CardActivity (component comparison).
 *
 * Projects one canonical activity-log entry into:
 *   - toClient → card-activity.vue via the ComponentCapture island
 *   - toIphone → CardActivity.swift via the component.CardActivity case
 *
 * The shared block carries the raw log fields (category, status, text,
 * createdAt). Both platforms derive the category icon/color, status dot, and
 * relative timestamp internally from those fields (mirroring the iOS switches),
 * so the adapter is a straight passthrough — no semantic-icon mapping needed.
 */
export default {
  toClient(shared) {
    const { category, status, text, createdAt } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardActivity',
        componentProps: {
          category: category ?? '',
          status: status ?? '',
          text: text ?? '',
          createdAt: createdAt ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardActivity',
      state: { component: shared ?? {} },
    };
  },
};
