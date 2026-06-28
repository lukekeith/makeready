/**
 * Adapter: Kpi (component comparison).
 *
 * Projects one canonical KPI description into:
 *   - toClient → kpi.vue via the ComponentCapture island
 *   - toIphone → Kpi.swift via the component.Kpi ViewRegistry case (unchanged)
 *
 * The `shared` block matches the iPhone fixture exactly (variant, kpiValue,
 * valueType, label, description, icon, iconColor, suffix/prefix, trend). The
 * web side maps the two platform-specific things:
 *   - the SF Symbol `icon` name → an inline SVG twin (currentColor)
 *   - the SwiftUI tint `iconColor` (.blue/.green) → the iOS dark-mode system hex
 * Value formatting stays in the Vue component (it mirrors Kpi.swift's
 * NumberFormatter), so the same numeric `kpiValue` drives both renders.
 */

// SF Symbol → inline SVG (24×24 unless noted). Line icons stroke currentColor;
// filled icons fill currentColor so the iconColor tint flows through.
const WEB_ICONS = {
  // chart.line.uptrend.xyaxis — trending-up line with arrow head
  'chart.line.uptrend.xyaxis':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 17 9 11 13 15 21 6"/><polyline points="15 6 21 6 21 12"/></svg>',
  // checkmark.circle — circle with check
  'checkmark.circle':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8.5 12.5l2.4 2.4 4.6-5.3"/></svg>',
  // person.2 — two people, outline
  'person.2':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 20v-1.5a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4V20"/><circle cx="9" cy="7" r="3.5"/><path d="M22 20v-1.5a4 4 0 0 0-3-3.85"/><path d="M16 3.6a4 4 0 0 1 0 6.8"/></svg>',
  // flame — outline
  flame:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>',
  // person.2.fill — two people, filled (wider-than-tall like the SF symbol)
  'person.2.fill':
    '<svg viewBox="0 0 26 20" fill="currentColor"><circle cx="18.5" cy="6" r="3.1"/><path d="M18.5 10.2c-1.5 0-2.85.45-3.82 1.18 1.27.95 2.07 2.32 2.07 3.92V16H23v-1.3c0-2.4-2.02-4.5-4.5-4.5z"/><circle cx="9.5" cy="6.4" r="4"/><path d="M9.5 11.4c-3.4 0-6 1.85-6 4.5V17h12v-1.1c0-2.65-2.6-4.5-6-4.5z"/></svg>',
  // bolt.fill — lightning bolt, filled
  'bolt.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.5 2 4.5 13.5c-.3.4 0 1 .5 1H10l-1.3 7.2c-.1.6.7 1 1.1.5L19.5 10c.3-.4 0-1-.5-1H14l1-6.5c.1-.6-.7-1-1.1-.5z"/></svg>',
};

// SwiftUI tint colors → iOS dark-mode system hexes (the snapshot renders in the
// app's dark appearance). No DS token exists for the raw iOS system palette.
const ICON_COLORS = {
  blue: '#0A84FF',
  green: '#30D158',
};

export default {
  toClient(shared) {
    const s = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'Kpi',
        componentProps: {
          variant: s.variant ?? 'standard',
          kpiValue: s.kpiValue ?? 0,
          valueType: s.valueType ?? 'number',
          prefix: s.prefix ?? '',
          suffix: s.suffix ?? '',
          symbol: s.symbol ?? '$',
          decimalPlaces: s.decimalPlaces ?? 2,
          label: s.label ?? '',
          description: s.description ?? '',
          icon: s.icon ? WEB_ICONS[s.icon] ?? '' : '',
          iconColor: s.iconColor ? ICON_COLORS[s.iconColor] ?? s.iconColor : '',
          trend: s.trend ?? null,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.Kpi',
      state: { component: shared },
    };
  },
};
