/**
 * Adapter: MenuInput (component comparison, two-sided twin).
 *
 * Projects one canonical menu-input description into:
 *   - toClient → menu-input.vue via the ComponentCapture island
 *   - toIphone → MenuInput.swift via the component.MenuInput ViewRegistry case
 *               (MenuInput wrapped in a FieldGroup, .padding(16) — unchanged from
 *                today).
 *
 * The fixture's `shared` block carries the canonical iPhone shape
 * (`{ label, options?, optionsWithDescriptions?, selectedOption, style }`). The
 * iPhone consumes it verbatim; the web twin only needs the resting render, so this
 * adapter projects it to the twin's props:
 *   - `selectedValue`  ← selectedOption
 *   - `options`        ← options, or the values of optionsWithDescriptions
 *                        (descriptions only appear in the iOS sheet, which isn't
 *                         shown in the snapshot, so they're dropped for the twin)
 *   - `style`          ← style (menu / wheel / inline all render the same collapsed
 *                        row; segmented renders the segmented control)
 * There are no semantic icons to map — the twin draws its own chevron.down inline.
 */
export default {
  toClient(shared = {}) {
    const {
      label = '',
      options,
      optionsWithDescriptions,
      selectedOption = '',
      style = 'menu',
    } = shared;
    const opts =
      options ?? (optionsWithDescriptions ?? []).map((o) => o.value);
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'MenuInput',
        componentProps: {
          label,
          selectedValue: selectedOption,
          // `pickerStyle`, not `style` — `style` is a reserved attribute in Vue
          // and would never bind as a component prop.
          pickerStyle: style,
          options: opts,
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (style + options/descriptions drive
    // the iOS render).
    return {
      platform: 'iphone',
      view: 'component.MenuInput',
      state: { component: shared },
    };
  },
};
