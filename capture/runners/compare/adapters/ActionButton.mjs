/**
 * Adapter: ActionButton (component comparison).
 *
 * Projects one canonical button description into:
 *   - toClient → action-button.vue via the ComponentCapture island
 *   - toIphone → ActionButton.swift via the component.ActionButton ViewRegistry case
 *
 * The canonical `shared` block IS the button's prop bag ({ label?, icon?,
 * variant }). `icon` travels as a semantic SF Symbol name; the iPhone consumes
 * it directly (Image(systemName:)) while the web adapter maps it to inline SVG
 * (currentColor) so the same logical data drives both renders.
 */

// SF Symbol → inline SVG (24×24, currentColor). Filled symbols use fill;
// arrow.right is a stroked glyph to match SF's thin arrow.
const WEB_ICONS = {
  'chart.bar.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="12" width="4.5" height="9" rx="1"/><rect x="9.75" y="7" width="4.5" height="14" rx="1"/><rect x="16.5" y="3" width="4.5" height="18" rx="1"/></svg>',
  'arrow.right':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h15M13 6l6 6-6 6"/></svg>',
  // Two outline speech bubbles (SF "bubble.left.and.bubble.right" is the
  // non-filled variant): a left bubble up-top with a down-left tail and a
  // lower-right bubble with a down-right tail, overlapping in the middle.
  'bubble.left.and.bubble.right':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"><path d="M4 3.5h6a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H7l-2.5 2.2V10.5H4a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2z"/><path d="M14 9h6a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-.5v2.2L17 16h-3a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2z"/></svg>',
};

export default {
  toClient(shared) {
    const { label, icon, variant } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'ActionButton',
        componentProps: {
          label: label ?? '',
          icon: icon ? WEB_ICONS[icon] ?? '' : '',
          variant: variant ?? 'white',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ActionButton',
      state: { component: shared ?? {} },
    };
  },
};
