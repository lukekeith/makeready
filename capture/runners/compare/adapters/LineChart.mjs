/**
 * Adapter: LineChart (component comparison).
 *
 * Projects one canonical line-chart description into:
 *   - toClient → line-chart.vue via the ComponentCapture island
 *   - toIphone → LineChart.swift via the component.LineChart ViewRegistry case
 *     (forwards the shared block unchanged)
 *
 * Colours are the important detail. The iPhone ViewRegistry does NOT render the
 * raw fixture hex — it remaps each known palette hex to a design-system token
 * (`#6c47ff` → brandPrimary, `#47d4ff` → accentBlue, …) and renders any unknown
 * shade as brandPrimary. So `toClient` performs the SAME remap to the web
 * equivalents of those tokens (applied to both solid and gradient colours),
 * giving both platforms identical pixels. `toIphone` forwards the raw shared
 * block unchanged (the Swift side owns the remap).
 *
 * The remapped web hex values are the iOS tokens' actual colours:
 *   brandPrimary #6C47FF · accentBlue #5680FF · Color.pink #FF375F ·
 *   Color.yellow #FFD60A · Color.green #30D158 · (else) brandPrimary.
 */
const COLOR_TO_WEB = {
  '#6c47ff': '#6C47FF', // brandPrimary
  '#47d4ff': '#5680FF', // accentBlue
  '#ff6b9d': '#FF375F', // Color.pink
  '#ffd93d': '#FFD60A', // Color.yellow
  '#4ade80': '#30D158', // Color.green
};

function webColor(raw) {
  // Unknown / rgba shades → brandPrimary (iOS ViewRegistry default).
  return COLOR_TO_WEB[(raw ?? '').toLowerCase()] ?? '#6C47FF';
}

export default {
  toClient(shared) {
    const {
      timeScale = 'days',
      showArea = false,
      interpolationMethod = 'monotone',
      trendLines = [],
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the iPhone
      // snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'LineChart',
        componentProps: {
          timeScale,
          showArea,
          interpolationMethod,
          trendLines: trendLines.map((tl) => ({
            color: tl.color ?? 'solid',
            solidColor: webColor(tl.solidColor),
            gradientColors: (tl.gradientColors ?? []).map(webColor),
            gradientAngle: tl.gradientAngle ?? 90,
            lineWidth: tl.lineWidth ?? 2,
            dataPoints: (tl.dataPoints ?? []).map((p) => ({
              date: p.date ?? '',
              value: p.value ?? 0,
            })),
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.LineChart',
      state: { component: shared },
    };
  },
};
