/**
 * Adapter: FilterChipDropdown (component comparison, two-sided twin).
 *
 * Projects one canonical filter-dropdown description into:
 *   - toClient → filter-chip-dropdown.vue via the ComponentCapture island
 *   - toIphone → FilterChipDropdown.swift via the component.FilterChipDropdown
 *     ViewRegistry case (unchanged from the iPhone-first passthrough)
 *
 * The fixture's `shared` block carries the PANEL's content:
 *   { label, isActive, showClearAll, items: [{ id, label }], selectedIds: [] }
 * (`label`/`isActive` describe the trigger chip, which isn't part of the isolated
 * snapshot — the captured component is the FilterChipDropdownPanel.) The Vue twin
 * consumes these fields directly; there are no icons to map (the panel's two glyphs
 * are inline SVG inside the twin).
 *
 * `toIphone` forwards `shared` unchanged — the iPhone side owns decoding.
 */
export default {
  toClient(shared = {}) {
    const {
      label = '',
      isActive = false,
      showClearAll = true,
      items = [],
      selectedIds = [],
    } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the iPhone
      // sizeThatFits snapshot (both = panel + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'FilterChipDropdown',
        componentProps: {
          label,
          isActive,
          showClearAll,
          items: (items ?? []).map((it) => ({
            id: it.id ?? '',
            label: it.label ?? '',
          })),
          selectedIds: selectedIds ?? [],
        },
      },
    };
  },

  toIphone(shared = {}) {
    return {
      platform: 'iphone',
      view: 'component.FilterChipDropdown',
      state: { component: shared },
    };
  },
};
