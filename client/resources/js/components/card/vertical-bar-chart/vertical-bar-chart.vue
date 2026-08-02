<script setup lang="ts">
// VerticalBarChartTwin — web twin of the iOS `VerticalBarChart`
// (SwiftUI Swift Charts vertical `BarMark`).
//
// Renders time-series / category comparisons as vertical bars so it can be
// compared apples-to-apples against the iPhone build in the Compare tool. Fully
// prop driven; renders every comparison variant from the same canonical data.
//
// Layout mirrors the iPhone snapshot exactly. The iOS chart is `.frame(height:
// chartHeight)` then `.padding(16)` then a rounded `white@0.05` card; the
// ViewRegistry wraps that in another `.padding(16)` and the capture harness
// adds the 16px `.capture-wrap` gutter. So this component owns the card (16px
// pad + radius-8 white@0.05 fill) and the chart plot at `chartHeight`, and the
// harness/gutter supply the outer 16px margin — total = chartHeight + 64pt,
// matching the iPhone snapshot height.
//
// Inside the `chartHeight` frame Swift Charts reserves the bottom band for the
// x-axis category labels and the leading column for the y-axis value labels,
// then plots vertical bars across the remaining region (value 0 → domainMax maps
// to baseline → plot top).
//
// The y-scale is reverse-engineered from the iOS snapshots: Swift auto-picks a
// "nice" tick step targeting ~3 intervals across the data max, pads the data max
// ~10% and rounds up to the next step for the domain max, and labels every step
// inclusive of BOTH ends (0 … domainMax).
//
// Colours arrive already resolved by the adapter (the iOS ViewRegistry remaps
// each fixture hex to a brand token and renders any rgba/unknown shade as a
// muted `white@0.3` grey), so this component renders the colours verbatim.
import { computed } from 'vue'

export interface VerticalBarChartDataPoint {
  label: string
  value: number
  color: string
}

interface Props {
  dataPoints: VerticalBarChartDataPoint[]
  showValues?: boolean
  chartHeight?: number
  // Additive (iOS VerticalBarChart xAxisValues 2026-07-30): when supplied, only
  // these category labels get an x-axis mark — dense series (e.g. a 30-bar
  // month) thin their marks to ~weekly while every band keeps its slot.
  // Omitted (the default, matching every existing capture) labels every bar.
  xAxisValues?: string[] | null
  // Additive: iOS's leading axis column HUGS its widest label (+8pt spacing).
  // 'auto' reproduces that; the numeric default 32 keeps every existing
  // capture identical (it was measured off wider 2-3 char tick labels).
  yAxisWidth?: number | 'auto'
}

const props = withDefaults(defineProps<Props>(), {
  showValues: true,
  chartHeight: 200,
  xAxisValues: null,
  yAxisWidth: 32,
})

// Bottom band reserved for x-axis category labels (iOS AxisValueLabel
// verticalSpacing 8 + ~16pt label line for Typography.s12).
const X_AXIS_H = 24
// iOS BarMark default thickness ≈ 0.72 of each category band (measured off the
// iPhone snapshots across the 4-, 6- and 7-bar variants).
const BAR_RATIO = 0.72

// Plot region height (bars + grid), above the x-axis band.
const plotH = computed(() => Math.max(props.chartHeight - X_AXIS_H, 0))

const maxValue = computed(() =>
  props.dataPoints.reduce((m, p) => Math.max(m, p.value || 0), 0)
)

// Swift Charts auto y-axis: a "nice" step targeting ~3 intervals across the
// data max (the vertical axis is coarser than the horizontal one — see the
// HorizontalBarChart twin, which targets ~4).
function niceStep(max: number): number {
  if (max <= 0) return 1
  const raw = max / 3
  const mag = Math.pow(10, Math.floor(Math.log10(raw)))
  const norm = raw / mag
  let mult: number
  if (norm <= 1) mult = 1
  else if (norm <= 2) mult = 2
  else if (norm <= 2.5) mult = 2.5
  else if (norm <= 5) mult = 5
  else mult = 10
  return mult * mag
}

const step = computed(() => niceStep(maxValue.value))

// Domain max: pad the data max ~10% and round up to the next nice step.
const domainMax = computed(() => {
  if (maxValue.value <= 0) return step.value
  return Math.ceil((maxValue.value * 1.1) / step.value) * step.value
})

// iOS formatAxisValue: ≥1000 → "%.0fk"; else "%.0f".
function formatAxis(v: number): string {
  if (v >= 1000) return `${Math.round(v / 1000)}k`
  return `${Math.round(v)}`
}

// iOS formatValue: ≥1000 → "%.1fk"; integer → "%.0f"; else "%.1f".
function formatValue(v: number): string {
  if (v >= 1000) return `${(v / 1000).toFixed(1)}k`
  if (Number.isInteger(v)) return `${v}`
  return v.toFixed(1)
}

// y ticks 0 … domainMax inclusive (both ends labeled, matching iOS), each
// positioned by its value up the plot.
const yTicks = computed(() => {
  const out: { label: string; bottom: number }[] = []
  if (domainMax.value <= 0) return out
  for (let v = 0; v <= domainMax.value + 1e-6; v += step.value) {
    out.push({ label: formatAxis(v), bottom: (v / domainMax.value) * plotH.value })
  }
  return out
})

// 'auto' y-axis column: widest tick label (~7px/char at Typography.s11) + the
// 8px horizontalSpacing, mirroring iOS's hugging axis column.
const yAxisWidthPx = computed(() => {
  if (props.yAxisWidth !== 'auto') return props.yAxisWidth
  const maxLen = yTicks.value.reduce((m, t) => Math.max(m, t.label.length), 1)
  return maxLen * 7 + 8
})

const bars = computed(() =>
  props.dataPoints.map((p) => ({
    label: p.label,
    color: p.color,
    valueLabel: formatValue(p.value || 0),
    heightPx:
      domainMax.value > 0
        ? (Math.max(p.value || 0, 0) / domainMax.value) * plotH.value
        : 0,
  }))
)
</script>

<template>
  <div class="VBarChartTwin">
    <div class="VBarChartTwin__chart" :style="{ height: `${chartHeight}px` }">
      <div
        class="VBarChartTwin__plot"
        :style="{
          gridTemplateColumns: `${yAxisWidthPx}px 1fr`,
          gridTemplateRows: `1fr ${X_AXIS_H}px`,
        }"
      >
        <!-- Leading y-axis value ticks. -->
        <div class="VBarChartTwin__yaxis">
          <span
            v-for="(t, i) in yTicks"
            :key="i"
            class="VBarChartTwin__ytick"
            :style="{ bottom: `${t.bottom}px` }"
            >{{ t.label }}</span
          >
        </div>

        <!-- Bars, anchored to the baseline. -->
        <div class="VBarChartTwin__bars">
          <div v-for="(b, i) in bars" :key="i" class="VBarChartTwin__band">
            <span
              v-if="showValues"
              class="VBarChartTwin__value"
              :style="{ bottom: `${b.heightPx + 4}px` }"
              >{{ b.valueLabel }}</span
            >
            <div
              class="VBarChartTwin__bar"
              :style="{
                height: `${b.heightPx}px`,
                width: `${BAR_RATIO * 100}%`,
                background: b.color,
              }"
            ></div>
          </div>
        </div>

        <!-- Bottom x-axis category labels, aligned under each band. When
             xAxisValues thins the marks, unlisted bands keep an empty slot so
             band alignment is preserved (iOS AxisMarks(values:)). -->
        <div class="VBarChartTwin__xaxis">
          <span
            v-for="(b, i) in bars"
            :key="i"
            class="VBarChartTwin__xlabel"
            :class="{ 'VBarChartTwin__xlabel--thinned': !!xAxisValues }"
            >{{ !xAxisValues || xAxisValues.includes(b.label) ? b.label : '' }}</span
          >
        </div>
      </div>
    </div>
  </div>
</template>
