<script lang="ts">
// LineChart — design-system wrapper over vue3-apexcharts (type 'line').
// Smooth (monotone) stroke in brand; multi-series cycles the palette.
//
// CHART_PALETTE mirrors the design tokens as real hex/rgba strings because
// ApexCharts paints inline SVG and cannot resolve CSS custom properties.
// Keep in sync with _palette.scss / _semantic.scss:
//   brand   #6c47ff (--color-brand-500)   accent  #5680ff (--color-accent)
//   success #57db5d                        warning #f4ff76
//   error   #ff4759                        grid    rgba(255,255,255,0.1)
//   label   rgba(255,255,255,0.5)
const CHART_PALETTE = {
  brand: '#6c47ff',
  accent: '#5680ff',
  success: '#57db5d',
  warning: '#f4ff76',
  error: '#ff4759',
  grid: 'rgba(255,255,255,0.1)',
  label: 'rgba(255,255,255,0.5)',
}

// Brand first so the primary line reads as brand; others follow.
const SERIES_COLORS = [
  CHART_PALETTE.brand,
  CHART_PALETTE.accent,
  CHART_PALETTE.success,
  CHART_PALETTE.warning,
  CHART_PALETTE.error,
]
</script>

<script setup lang="ts">
import { computed } from 'vue'
import ApexChart from 'vue3-apexcharts'
import { classnames } from '../../../util/classnames'

interface LineSeries {
  name: string
  data: number[]
}

interface Props {
  /** X-axis categories. */
  categories: string[]
  /** One or more named data series. */
  series: LineSeries[]
  /** Chart height in px. */
  height?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  height: 260,
})

const options = computed(() => ({
  chart: {
    type: 'line',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
    zoom: { enabled: false },
  },
  theme: { mode: 'dark' },
  colors: SERIES_COLORS,
  stroke: { curve: 'smooth', width: 3 },
  dataLabels: { enabled: false },
  markers: { size: 0, hover: { size: 5 } },
  grid: {
    borderColor: CHART_PALETTE.grid,
    strokeDashArray: 0,
  },
  xaxis: {
    categories: props.categories,
    labels: { style: { colors: CHART_PALETTE.label } },
    axisBorder: { color: CHART_PALETTE.grid },
    axisTicks: { color: CHART_PALETTE.grid },
  },
  yaxis: {
    labels: { style: { colors: CHART_PALETTE.label } },
  },
  legend: {
    show: props.series.length > 1,
    position: 'bottom',
    labels: { colors: CHART_PALETTE.label },
    markers: { width: 10, height: 10, radius: 12 },
  },
  tooltip: { theme: 'dark' },
}))

const classes = computed(() => classnames('Chart', 'LineChart', props.class))
</script>

<template>
  <div :class="classes">
    <ApexChart type="line" :series="series" :options="options" :height="height" />
  </div>
</template>
