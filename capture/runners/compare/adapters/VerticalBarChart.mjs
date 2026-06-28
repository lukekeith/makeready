/**
 * Adapter: VerticalBarChart (component comparison).
 *
 * Projects one canonical vertical-bar-chart description into:
 *   - toClient → vertical-bar-chart.vue via the ComponentCapture island
 *   - toIphone → VerticalBarChart.swift via the component.VerticalBarChart
 *     ViewRegistry case (forwards the shared block unchanged)
 *
 * Colours are the important detail. The iPhone ViewRegistry does NOT render the
 * raw fixture hex — it remaps each known palette hex to a design-system token
 * (`#6c47ff` → brandPrimary, `#47d4ff` → accentBlue, `#ff6b9d` → pink, …) and —
 * UNLIKE HorizontalBarChart — renders any rgba / unknown shade as a muted
 * `Color.white.opacity(0.3)` grey (not brandPrimary@0.5). So `toClient` performs
 * the SAME remap to the web equivalents, giving both platforms identical pixels.
 * `toIphone` forwards the raw shared block unchanged (the Swift side owns the
 * remap).
 *
 * The remapped web hex values are the iOS tokens' actual colours:
 *   brandPrimary #6C47FF · accentBlue #5680FF · Color.pink #FF375F ·
 *   Color.yellow #FFD60A · Color.green #30D158 · (else) white@0.3 grey.
 */
const COLOR_TO_WEB = {
  '#6c47ff': '#6C47FF', // brandPrimary
  '#47d4ff': '#5680FF', // accentBlue
  '#ff6b9d': '#FF375F', // Color.pink
  '#ffd93d': '#FFD60A', // Color.yellow
  '#4ade80': '#30D158', // Color.green
};

function webColor(raw) {
  // rgba shades / unknown → Color.white.opacity(0.3) (iOS VerticalBarChart default).
  return COLOR_TO_WEB[(raw ?? '').toLowerCase()] ?? 'rgba(255,255,255,0.3)';
}

export default {
  toClient(shared) {
    const { showValues = true, chartHeight = 200, dataPoints = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'VerticalBarChart',
        componentProps: {
          showValues,
          chartHeight,
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
      view: 'component.VerticalBarChart',
      state: { component: shared },
    };
  },
};
