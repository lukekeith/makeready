/**
 * Adapter: HeatMapChart (component comparison).
 *
 * Projects one canonical heat-map description into:
 *   - toClient → heat-map-chart.vue via the ComponentCapture island
 *   - toIphone → HeatMapChart.swift via the component.HeatMapChart ViewRegistry case
 *
 * `toIphone` forwards the shared block unchanged (the Swift side owns decoding).
 * `toClient` maps the shared block straight onto the Vue twin's props — the field
 * names already line up (dataPoints / showDayLabels / chartHeight / colorScale).
 *
 * Parity note: the iOS chart body colors every cell with `Color.brandPrimary` at
 * a continuous opacity (`colorForValue`), ignoring `colorScale` entirely — so the
 * Vue twin does the same. `colorScale` is forwarded only for fidelity / future use.
 */
export default {
  toClient(shared) {
    const {
      dataPoints = [],
      showDayLabels = true,
      chartHeight = 120,
      colorScale,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper so the web shot matches the iPhone
      // snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'HeatMapChart',
        componentProps: {
          showDayLabels,
          chartHeight,
          ...(colorScale ? { colorScale } : {}),
          dataPoints: dataPoints.map((p) => ({
            week: p.week ?? 0,
            day: p.day ?? 0,
            value: p.value ?? 0,
            dayLabel: p.dayLabel ?? '',
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.HeatMapChart',
      state: { component: shared },
    };
  },
};
