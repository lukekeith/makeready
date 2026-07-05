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
  // Optional explicit axis labels (iOS xLabels / yLabels). When `yLabels` is
  // supplied the grid uses one row per y-label (e.g. the home dashboard's 24
  // hour-of-day rows) instead of the default 7 weekday rows; `week` maps to the
  // x-column and `day` maps to the y-row, exactly like the Swift RectangleMark.
  xLabels?: string[]
  yLabels?: string[]
}

const props = withDefaults(defineProps<Props>(), {
  dataPoints: () => [],
  showDayLabels: true,
  chartHeight: 120,
})

// iOS y-axis lists Sun(0)…Sat(6) bottom→top; rendered top→bottom it reverses.
const DAY_LABELS_TOP_TO_BOTTOM = ['Sat', 'Fri', 'Thu', 'Wed', 'Tue', 'Mon', 'Sun']

// Row count = explicit yLabels (hour-of-day mode) else the 7 weekday rows.
const rowCount = computed(() => props.yLabels?.length || 7)

// Columns span the continuous x-domain [0, maxWeek+1] (Swift Charts auto-domain),
// or the explicit xLabels count when provided.
const weekCount = computed(
  () =>
    props.xLabels?.length ||
    props.dataPoints.reduce((m, p) => Math.max(m, p.week + 1), 0) ||
    1
)

// Y-axis labels rendered top→bottom. Swift Charts puts value 0 at the bottom, so
// an explicit yLabels list reverses (last label on top); otherwise the default
// weekday column is used when day labels are shown.
const yAxisLabels = computed<string[]>(() => {
  if (props.yLabels?.length) return [...props.yLabels].reverse()
  return props.showDayLabels ? DAY_LABELS_TOP_TO_BOTTOM : []
})

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
        // value 0 sits at the bottom row; the top day/hour gets row 1.
        row: rowCount.value - p.day,
        opacity: 0.1 + t * 0.9, // iOS colorForValue continuous ramp
      }
    })
)
</script>

<template>
  <div class="HeatMapChartTwin">
    <div class="HeatMapChartTwin__chart" :style="{ height: chartHeight + 'px' }">
      <div
        v-if="yAxisLabels.length"
        class="HeatMapChartTwin__labels"
        :style="{ gridTemplateRows: `repeat(${rowCount}, 1fr)` }"
        aria-hidden="true"
      >
        <span
          v-for="(label, i) in yAxisLabels"
          :key="i"
          class="HeatMapChartTwin__label"
          >{{ label }}</span
        >
      </div>

      <div
        class="HeatMapChartTwin__grid"
        :style="{
          gridTemplateColumns: `repeat(${weekCount}, 1fr)`,
          gridTemplateRows: `repeat(${rowCount}, 1fr)`,
        }"
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
