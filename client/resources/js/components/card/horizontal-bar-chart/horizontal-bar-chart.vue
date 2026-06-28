<script setup lang="ts">
// HorizontalBarChartTwin — web twin of the iOS `HorizontalBarChart`
// (SwiftUI Swift Charts horizontal `BarMark`).
//
// Renders rankings/comparisons as horizontal bars so it can be compared
// apples-to-apples against the iPhone build in the Compare tool. Fully prop
// driven; renders every comparison variant from the same canonical data.
//
// Layout mirrors the iPhone snapshot exactly. The iOS chart is sized
// `.frame(height: count * barHeight + 40)` and padded 16pt all round (the
// capture harness supplies the 16px gutter), so the component's own height is
// `count * barHeight + 40`. Inside that box Swift Charts lays out, per row:
//   • the category label ABOVE the bar (the leading y-axis label), and
//   • the bar centred in its band with the value annotation trailing it,
// then a faint x-axis of value ticks across the bottom.
//
// The x-scale is reverse-engineered from the iOS snapshots: Swift auto-picks a
// "nice" tick step (~4 intervals), pads the data max by ~10% and rounds up to
// the next step for the domain max, then labels every step strictly below the
// domain max. Bars and ticks span the full content width (domain 0 → max maps
// to 0 → 100%), with value labels overflowing into the trailing slack.
//
// Colours arrive already resolved by the adapter (the iOS ViewRegistry remaps
// each fixture hex to a brand token and renders any rgba/unknown shade as
// brandPrimary@0.5), so this component renders the colours verbatim.
import { computed } from 'vue'

export interface HorizontalBarChartDataPoint {
  label: string
  value: number
  color: string
}

interface Props {
  dataPoints: HorizontalBarChartDataPoint[]
  showValues?: boolean
  barHeight?: number
}

const props = withDefaults(defineProps<Props>(), {
  showValues: true,
  barHeight: 32,
})

// iOS: HorizontalBarChart .frame(height: count * barHeight + 40)
const chartHeight = computed(
  () => props.dataPoints.length * props.barHeight + 40
)

// Category band pitch. The iOS plot reserves ~10pt above the first band and
// ~8pt for the axis below, leaving a band region of (count*barHeight + 22).
const TOP_INSET = 10
const AXIS_AREA = 8
const bandPitch = computed(() => {
  const n = props.dataPoints.length || 1
  return (chartHeight.value - TOP_INSET - AXIS_AREA) / n
})

// iOS BarMark renders a thin bar within each band (~barHeight − 20pt thick).
const barThickness = computed(() => Math.max(props.barHeight - 20, 6))

const maxValue = computed(() =>
  props.dataPoints.reduce((m, p) => Math.max(m, p.value || 0), 0)
)

// Swift Charts "nice" tick step targeting ~4 intervals across the data max.
function niceStep(max: number): number {
  if (max <= 0) return 1
  const raw = max / 4
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

// Tick values: every step strictly below the domain max (the edge tick at the
// plot's right boundary is unlabeled, matching iOS).
const ticks = computed(() => {
  const out: number[] = []
  for (let v = 0; v < domainMax.value - 1e-6; v += step.value) out.push(v)
  return out
})

// iOS formatValue: ≥1000 → "%.1fk"; integer → "%.0f"; else "%.1f".
function formatValue(v: number): string {
  if (v >= 1000) return `${(v / 1000).toFixed(1)}k`
  if (Number.isInteger(v)) return `${v}`
  return v.toFixed(1)
}

// printf %.0f rounds half-to-even (banker's): 2.5 → 2, 7.5 → 8 — unlike JS
// Math.round (half-up). Match iOS so a 2500-step tick reads "2k" not "3k".
function roundHalfEven(x: number): number {
  const f = Math.floor(x)
  const diff = x - f
  if (diff < 0.5) return f
  if (diff > 0.5) return f + 1
  return f % 2 === 0 ? f : f + 1
}

// iOS formatAxisValue: ≥1000 → "%.0fk"; else "%.0f".
function formatAxis(v: number): string {
  if (v >= 1000) return `${roundHalfEven(v / 1000)}k`
  return `${roundHalfEven(v)}`
}

const rows = computed(() =>
  props.dataPoints.map((p) => ({
    label: p.label,
    color: p.color,
    valueLabel: formatValue(p.value || 0),
    widthPct: domainMax.value > 0 ? ((p.value || 0) / domainMax.value) * 100 : 0,
  }))
)

// iOS Swift Charts anchors each x-axis label ~9pt to the right of its raw value
// position (a fixed leading-label offset). Replicate it so the faint tick row
// lines up with the iPhone snapshot rather than with the bars' true value scale.
const AXIS_LABEL_OFFSET = 9
const axisTicks = computed(() =>
  ticks.value.map((v) => ({
    label: formatAxis(v),
    left:
      domainMax.value > 0
        ? `calc(${(v / domainMax.value) * 100}% + ${AXIS_LABEL_OFFSET}px)`
        : `${AXIS_LABEL_OFFSET}px`,
  }))
)
</script>

<template>
  <div
    class="HBarChartTwin"
    :style="{ height: `${chartHeight}px`, paddingTop: `${TOP_INSET}px` }"
  >
    <div class="HBarChartTwin__rows">
      <div
        v-for="(row, i) in rows"
        :key="i"
        class="HBarChartTwin__row"
        :style="{ height: `${bandPitch}px` }"
      >
        <span class="HBarChartTwin__label">{{ row.label }}</span>
        <div class="HBarChartTwin__barline">
          <div
            class="HBarChartTwin__bar"
            :style="{ width: `${row.widthPct}%`, background: row.color, height: `${barThickness}px` }"
          ></div>
          <span v-if="showValues" class="HBarChartTwin__value">{{ row.valueLabel }}</span>
        </div>
      </div>
    </div>

    <div class="HBarChartTwin__axis" :style="{ height: `${AXIS_AREA}px` }">
      <span
        v-for="(t, i) in axisTicks"
        :key="i"
        class="HBarChartTwin__tick"
        :style="{ left: t.left }"
        >{{ t.label }}</span
      >
    </div>
  </div>
</template>
