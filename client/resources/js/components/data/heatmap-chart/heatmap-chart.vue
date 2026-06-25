<script lang="ts">
// HeatMapChart — design-system wrapper over vue3-apexcharts (type 'heatmap').
// Activity heatmap (e.g. day-of-week × hour, or week × day). Intensity ramps
// up to brand.
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
</script>

<script setup lang="ts">
import { computed } from 'vue'
import ApexChart from 'vue3-apexcharts'
import { classnames } from '../../../util/classnames'

interface HeatPoint {
  x: string | number
  y: number
}

interface HeatSeries {
  name: string
  data: HeatPoint[]
}

interface Props {
  /** Rows of the heatmap; each row's data is the cells across the x-axis. */
  series: HeatSeries[]
  /** Chart height in px. */
  height?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  height: 260,
})

const options = computed(() => ({
  chart: {
    type: 'heatmap',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
  },
  theme: { mode: 'dark' },
  // Single brand color; ApexCharts shades it by value for the intensity ramp.
  colors: [CHART_PALETTE.brand],
  dataLabels: { enabled: false },
  stroke: { width: 1, colors: [CHART_PALETTE.grid] },
  plotOptions: {
    heatmap: {
      radius: 4,
      enableShades: true,
      shadeIntensity: 0.6,
    },
  },
  grid: { borderColor: CHART_PALETTE.grid },
  xaxis: {
    type: 'category',
    labels: { style: { colors: CHART_PALETTE.label } },
    axisBorder: { color: CHART_PALETTE.grid },
    axisTicks: { color: CHART_PALETTE.grid },
  },
  yaxis: {
    labels: { style: { colors: CHART_PALETTE.label } },
  },
  legend: { show: false },
  tooltip: { theme: 'dark' },
}))

const classes = computed(() => classnames('Chart', 'HeatMapChart', props.class))
</script>

<template>
  <div :class="classes">
    <ApexChart type="heatmap" :series="series" :options="options" :height="height" />
  </div>
</template>
