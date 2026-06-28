<script setup lang="ts">
// HeatMapChartTwin — web twin of the iOS `HeatMapChart` (Swift Charts grid of
// RectangleMarks). A GitHub-contribution-style weeks × days grid inside a
// rounded white@0.05 container.
//
// Faithful to the iOS component *body*: every cell is brandPrimary at a
// continuous opacity `0.1 + (value / max)·0.9` (iOS `colorForValue`). The
// `colorScale` prop is accepted for fixture parity but is intentionally unused
// for the cell fills — the iOS chart body ignores it too (`colorForValue` always
// returns `Color.brandPrimary`; `colorScale` only feeds the demo legend), so
// mirroring that keeps both platforms identical.
//
// Layout mirrors iOS exactly:
//   • container  → `.padding(16)` + RoundedRectangle(cornerRadius: 8, white@0.05)
//   • chart area → `.frame(height: chartHeight)` (axis + plot, 120pt default)
//   • y-axis     → all 7 day labels Sun(0)…Sat(6), bottom→top (Swift Charts'
//                  numeric y-axis puts 0 at the bottom), 10pt white@0.5.
import { computed } from 'vue'

export interface HeatMapDataPoint {
  week: number
  day: number
  value: number
  dayLabel?: string
}

interface Props {
  dataPoints: HeatMapDataPoint[]
  showDayLabels?: boolean
  chartHeight?: number
  // Accepted for fixture parity; intentionally unused (see header note).
  colorScale?: string[]
}

const props = withDefaults(defineProps<Props>(), {
  dataPoints: () => [],
  showDayLabels: true,
  chartHeight: 120,
})

// iOS y-axis lists Sun(0)…Sat(6) bottom→top; rendered top→bottom it reverses.
const DAY_LABELS_TOP_TO_BOTTOM = ['Sat', 'Fri', 'Thu', 'Wed', 'Tue', 'Mon', 'Sun']

// Columns span the continuous x-domain [0, maxWeek+1] (Swift Charts auto-domain).
const weekCount = computed(
  () => props.dataPoints.reduce((m, p) => Math.max(m, p.week + 1), 0) || 1
)

const maxValue = computed(
  () => props.dataPoints.reduce((m, p) => Math.max(m, p.value || 0), 0) || 1
)

const cells = computed(() =>
  props.dataPoints
    .filter((p) => (p.value || 0) > 0) // iOS colorForValue returns .clear for <=0
    .map((p) => {
      const t = (p.value || 0) / maxValue.value
      return {
        col: p.week + 1, // grid-column, 1-based
        row: 7 - p.day, // day 6 (Sat) → row 1 (top); day 0 (Sun) → row 7 (bottom)
        opacity: 0.1 + t * 0.9, // iOS colorForValue continuous ramp
      }
    })
)
</script>

<template>
  <div class="HeatMapChartTwin">
    <div class="HeatMapChartTwin__chart" :style="{ height: chartHeight + 'px' }">
      <div v-if="showDayLabels" class="HeatMapChartTwin__labels" aria-hidden="true">
        <span
          v-for="label in DAY_LABELS_TOP_TO_BOTTOM"
          :key="label"
          class="HeatMapChartTwin__label"
          >{{ label }}</span
        >
      </div>

      <div
        class="HeatMapChartTwin__grid"
        :style="{ gridTemplateColumns: `repeat(${weekCount}, 1fr)` }"
      >
        <div
          v-for="(cell, i) in cells"
          :key="i"
          class="HeatMapChartTwin__cell"
          :style="{ gridColumn: cell.col, gridRow: cell.row, opacity: cell.opacity }"
        />
      </div>
    </div>
  </div>
</template>
