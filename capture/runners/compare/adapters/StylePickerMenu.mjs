/**
 * Adapter: StylePickerMenu (component comparison, group Overlays).
 *
 * Projects one canonical style-picker description into:
 *   - toClient → style-picker-menu.vue via the ComponentCapture island
 *   - toIphone → StylePickerMenu.swift via the component.StylePickerMenu
 *     ViewRegistry case
 *
 * Canonical `shared`:
 *   { snippet: string, style: null | 'bold' | 'highlight' }
 *
 * The web twin is genuinely data-driven: it forwards the snippet + the applied
 * style and renders the rows, the conditional "Remove style" button, and the
 * "Cancel" button from those two props.
 *
 * NB: the iPhone side is left untouched (generic passthrough of `shared` into
 * `state.component`). The ViewRegistry case reads `state.component.text` for the
 * snippet, but `shared` carries it under `snippet`, so the iOS Text renders empty
 * quotes (“”) — the same data-key artifact as HeatMapChart / SearchableList. The
 * web twin still renders the real snippet (a surfaced gap on that one preview
 * line); the rows / buttons match pixel-tight.
 */

export default {
  toClient(shared = {}) {
    const { snippet = '', style = null } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the iPhone
      // sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'StylePickerMenu',
        componentProps: {
          snippet: snippet ?? '',
          // NB: prop is `appliedStyle`, not `style` — `style` is a reserved
          // Vue/HTML attribute and would never bind through v-bind.
          appliedStyle: style ?? null,
        },
      },
    };
  },

  toIphone(shared = {}) {
    return {
      platform: 'iphone',
      view: 'component.StylePickerMenu',
      state: { component: shared },
    };
  },
};
