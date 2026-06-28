<script setup lang="ts">
// DonutChartTwin — web twin of the iOS `DonutChart` (Swift Charts SectorMark).
//
// Renders a data-driven donut/pie chart as an inline SVG so it can be compared
// apples-to-apples against the iPhone build in the Compare tool. Fully prop
// driven; renders every comparison variant (donut with/without a center label,
// and a full pie when innerRadiusRatio === 0).
//
// Geometry mirrors iOS exactly: slices start at 12 o'clock and sweep clockwise
// (SwiftUI SectorMark), and the whole chart composites at opacity 0.9 (the iOS
// `.opacity(0.9)` on every sector) so a translucent white "other" slice lands at
// the same effective alpha on both platforms.
import { computed } from 'vue'

export interface DonutChartDataPoint {
  label?: string
  value: number
  color: string
}

interface Props {
  dataPoints: DonutChartDataPoint[]
  innerRadiusRatio?: number
  showCenterLabel?: boolean
  centerLabelText?: string | null
  centerLabelSubtext?: string | null
}

const props = withDefaults(defineProps<Props>(), {
  innerRadiusRatio: 0.75,
  showCenterLabel: true,
  centerLabelText: null,
  centerLabelSubtext: null,
})

// 188px square is intrinsic: the iOS snapshot is `.frame(height: 220)` minus the
// 2×16 capture gutter, and Swift Charts draws the circle at the limiting (height)
// dimension. See donut-chart.scss for the design-system intrinsic-size note.
const SIZE = 188
const CX = SIZE / 2
const CY = SIZE / 2
const R = SIZE / 2

const total = computed(() =>
  props.dataPoints.reduce((sum, p) => sum + (p.value || 0), 0)
)

// 0° = 12 o'clock, sweeping clockwise (matches SwiftUI SectorMark).
function point(angleDeg: number, radius: number) {
  const rad = (angleDeg * Math.PI) / 180
  return {
    x: CX + radius * Math.sin(rad),
    y: CY - radius * Math.cos(rad),
  }
}

const slices = computed(() => {
  const t = total.value
  if (t <= 0) return []
  const inner = R * Math.min(Math.max(props.innerRadiusRatio, 0), 1)
  let a0 = 0
  return props.dataPoints.map((p) => {
    const a1 = a0 + (p.value / t) * 360
    // A single command can't draw a full 360° arc — clamp so a lone slice still
    // renders as a near-complete ring/pie.
    const a1c = a1 >= a0 + 360 ? a0 + 359.999 : a1
    const large = a1c - a0 > 180 ? 1 : 0
    const o0 = point(a0, R)
    const o1 = point(a1c, R)
    let d: string
    if (inner > 0) {
      const i1 = point(a1c, inner)
      const i0 = point(a0, inner)
      d =
        `M ${o0.x} ${o0.y} ` +
        `A ${R} ${R} 0 ${large} 1 ${o1.x} ${o1.y} ` +
        `L ${i1.x} ${i1.y} ` +
        `A ${inner} ${inner} 0 ${large} 0 ${i0.x} ${i0.y} Z`
    } else {
      d = `M ${CX} ${CY} L ${o0.x} ${o0.y} A ${R} ${R} 0 ${large} 1 ${o1.x} ${o1.y} Z`
    }
    a0 = a1
    return { d, color: p.color }
  })
})

// Mirrors iOS `totalFormatted` (Kit/Other "k" abbreviation above 1000).
const centerValue = computed(() => {
  if (props.centerLabelText) return props.centerLabelText
  const t = total.value
  if (t >= 1000) return `${(t / 1000).toFixed(1)}k`
  if (Number.isInteger(t)) return `${t}`
  return t.toFixed(1)
})

const centerSubtext = computed(() => props.centerLabelSubtext ?? 'Total')
</script>

<template>
  <div class="DonutChartTwin">
    <svg
      class="DonutChartTwin__svg"
      :width="SIZE"
      :height="SIZE"
      :viewBox="`0 0 ${SIZE} ${SIZE}`"
      aria-hidden="true"
    >
      <path
        v-for="(s, i) in slices"
        :key="i"
        :d="s.d"
        :fill="s.color"
        class="DonutChartTwin__slice"
      />
    </svg>

    <div v-if="showCenterLabel" class="DonutChartTwin__center">
      <span class="DonutChartTwin__value">{{ centerValue }}</span>
      <span class="DonutChartTwin__subtext">{{ centerSubtext }}</span>
    </div>
  </div>
</template>
