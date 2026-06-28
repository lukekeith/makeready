/**
 * Adapter: HorizontalBarChart (component comparison).
 *
 * Projects one canonical horizontal-bar-chart description into:
 *   - toClient → horizontal-bar-chart.vue via the ComponentCapture island
 *   - toIphone → HorizontalBarChart.swift via the component.HorizontalBarChart
 *     ViewRegistry case (forwards the shared block unchanged)
 *
 * Colours are the important detail. The iPhone ViewRegistry does NOT render the
 * raw fixture hex — it remaps each known palette hex to a design-system token
 * (`#6c47ff` → brandPrimary, `#47d4ff` → accentBlue, `#ff6b9d` → pink, …) and
 * renders any rgba / unknown shade as `brandPrimary.opacity(0.5)`. So `toClient`
 * performs the SAME remap to the web equivalents of those tokens, giving both
 * platforms identical pixels. `toIphone` forwards the raw shared block unchanged
 * (the Swift side owns the remap).
 *
 * The remapped web hex values are the iOS tokens' actual colours:
 *   brandPrimary #6C47FF · accentBlue #5680FF · Color.pink #FF375F ·
 *   Color.yellow #FFD60A · Color.green #30D158 · (else) brandPrimary@0.5.
 */
const COLOR_TO_WEB = {
  '#6c47ff': '#6C47FF', // brandPrimary
  '#47d4ff': '#5680FF', // accentBlue
  '#ff6b9d': '#FF375F', // Color.pink
  '#ffd93d': '#FFD60A', // Color.yellow
  '#4ade80': '#30D158', // Color.green
};

function webColor(raw) {
  // rgba shades / unknown → brandPrimary.opacity(0.5) (iOS ViewRegistry default).
  return COLOR_TO_WEB[(raw ?? '').toLowerCase()] ?? 'rgba(108,71,255,0.5)';
}

export default {
  toClient(shared) {
    const { showValues = true, barHeight = 32, dataPoints = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'HorizontalBarChart',
        componentProps: {
          showValues,
          barHeight,
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
      view: 'component.HorizontalBarChart',
      state: { component: shared },
    };
  },
};
