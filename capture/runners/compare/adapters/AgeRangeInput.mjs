/**
 * Adapter: AgeRangeInput (component comparison).
 *
 * Projects one canonical age-range description into:
 *   - toClient → age-range-input.vue via the ComponentCapture island
 *   - toIphone → AgeRangeInput.swift (wrapped in FieldGroup) via the
 *     component.AgeRangeInput ViewRegistry case
 *
 * The canonical `shared` block IS the prop bag ({ label, minAge, maxAge }); the
 * Vue twin reproduces the surrounding FieldGroup surface itself. No icons.
 */
export default {
  toClient(shared) {
    const { label, minAge, maxAge } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'AgeRangeInput',
        componentProps: {
          label: label ?? 'Age range',
          minAge: minAge ?? '0',
          maxAge: maxAge ?? '99',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.AgeRangeInput',
      state: { component: shared ?? {} },
    };
  },
};
