/**
 * Adapter: FieldGroup (component comparison, two-sided twin).
 *
 * Projects one canonical field-group description into:
 *   - toClient → field-group.vue via the ComponentCapture island
 *   - toIphone → FieldGroup.swift via the component.FieldGroup ViewRegistry case
 *               (a FieldGroup of Text rows + dividers + optional description,
 *                wrapped in .padding(16) — unchanged from today)
 *
 * The fixture's `shared` block is already in the shape both sides expect
 * (`fieldRows: string[]`, optional `description: string`), so the projection is a
 * straight passthrough; no semantic icons to map.
 */
export default {
  toClient(shared = {}) {
    const { fieldRows = [], description } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup + 16px gutters), matching
      // the iPhone snapshot (ViewRegistry wraps the field in FieldGroup.padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'FieldGroup',
        componentProps: {
          fieldRows,
          // Omit when absent so the Vue default ('') keeps the description row out.
          ...(description ? { description } : {}),
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.FieldGroup',
      state: { component: shared },
    };
  },
};
