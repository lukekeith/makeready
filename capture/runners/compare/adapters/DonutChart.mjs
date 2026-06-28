/**
 * Adapter: DonutChart (component comparison).
 *
 * Projects one canonical donut-chart description into:
 *   - toClient → donut-chart.vue via the ComponentCapture island
 *   - toIphone → DonutChart.swift via the component.DonutChart ViewRegistry case
 *
 * Colors are the important detail. The iPhone ViewRegistry does NOT render the
 * raw fixture hex — it remaps each data color to a design-system token
 * (`#47d4ff` → Color.accentBlue, `#ff6b9d` → Color.pink, …) and renders every
 * sector at `.opacity(0.9)`, with any unrecognized / rgba color falling back to
 * `white.opacity(0.3)`. So `toClient` performs the SAME remap to the web
 * equivalents of those tokens, and the Vue twin composites the chart at 0.9 —
 * giving both platforms identical pixels. `toIphone` forwards the raw shared
 * block unchanged (the Swift side owns the remap).
 *
 * The remapped web hex values are the iOS tokens' actual colors:
 *   brandPrimary #6C47FF · accentBlue #5680FF · Color.pink #FF375F ·
 *   Color.yellow #FFD60A · Color.green #30D158 · (else) white@0.3.
 */
const COLOR_TO_WEB = {
  '#6c47ff': '#6C47FF', // brandPrimary
  '#47d4ff': '#5680FF', // accentBlue
  '#ff6b9d': '#FF375F', // Color.pink
  '#ffd93d': '#FFD60A', // Color.yellow
  '#4ade80': '#30D158', // Color.green
};

function webColor(raw) {
  return COLOR_TO_WEB[(raw ?? '').toLowerCase()] ?? 'rgba(255,255,255,0.3)';
}

export default {
  toClient(shared) {
    const {
      dataPoints = [],
      innerRadiusRatio = 0.75,
      showCenterLabel = true,
      centerLabelText = null,
      centerLabelSubtext = null,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the iPhone
      // sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'DonutChart',
        componentProps: {
          innerRadiusRatio,
          showCenterLabel,
          centerLabelText,
          centerLabelSubtext,
          dataPoints: dataPoints.map((p) => ({
            label: p.label ?? '',
            value: p.value ?? 0,
            color: webColor(p.color),
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.DonutChart',
      state: { component: shared },
    };
  },
};
