/**
 * Adapter: BoxButton (component comparison).
 *
 * Projects one canonical button description into:
 *   - toClient → box-button.vue via the ComponentCapture island
 *   - toIphone → BoxButton.swift via the component.BoxButton ViewRegistry case
 *
 * The canonical `shared` block IS the button's prop bag ({ label?, icon?,
 * iconPosition?, variant, style, size, fullWidth? }). `icon` travels as a
 * semantic SF Symbol name; the iPhone consumes it directly (Image(systemName:))
 * while the web adapter maps it to inline SVG (currentColor).
 */

// SF Symbol → inline SVG (24×24, currentColor, stroked to match SF's regular
// weight at these sizes).
const WEB_ICONS = {
  plus:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',
  'arrow.right':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h15M13 6l6 6-6 6"/></svg>',
  trash:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></svg>',
};

export default {
  toClient(shared) {
    const { label, icon, iconPosition, variant, style, size, fullWidth } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'BoxButton',
        componentProps: {
          label: label ?? '',
          icon: icon ? WEB_ICONS[icon] ?? '' : '',
          iconPosition: iconPosition ?? 'none',
          variant: variant ?? 'primary',
          // Renamed from `style` → `buttonStyle`: Vue reserves `style` as an
          // attribute binding and would swallow the value on the island.
          buttonStyle: style ?? 'solid',
          size: size ?? 'md',
          fullWidth: fullWidth ?? false,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.BoxButton',
      state: { component: shared ?? {} },
    };
  },
};
