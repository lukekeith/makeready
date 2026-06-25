<script lang="ts">
// DonutChart — design-system wrapper over vue3-apexcharts (type 'donut').
//
// CHART_PALETTE mirrors the design tokens as real hex/rgba strings because
// ApexCharts paints inline SVG and cannot resolve CSS custom properties.
// Keep these in sync with _palette.scss / _semantic.scss:
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

// Slice colors, ordered. Brand leads; accent/success/warning/error follow.
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

interface Props {
  /** Slice values, one per label. */
  series: number[]
  /** Slice labels, one per value. */
  labels: string[]
  /** Optional center total label (donut hole). */
  total?: string | number
  /** Chart height in px. */
  height?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  height: 260,
})

const options = computed(() => ({
  chart: {
    type: 'donut',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
  },
  theme: { mode: 'dark' },
  labels: props.labels,
  colors: SERIES_COLORS,
  stroke: { width: 0 },
  legend: {
    position: 'bottom',
    labels: { colors: CHART_PALETTE.label },
    markers: { width: 10, height: 10, radius: 12 },
    itemMargin: { horizontal: 8, vertical: 4 },
  },
  dataLabels: { enabled: false },
  plotOptions: {
    pie: {
      donut: {
        size: '70%',
        labels: {
          show: true,
          name: { color: CHART_PALETTE.label },
          value: { color: '#ffffff', fontWeight: 700 },
          total: {
            show: props.total !== undefined,
            label: props.total !== undefined ? String(props.total) : 'Total',
            color: CHART_PALETTE.label,
            formatter: () =>
              props.total !== undefined
                ? ''
                : String(props.series.reduce((a, b) => a + b, 0)),
          },
        },
      },
    },
  },
  tooltip: { theme: 'dark' },
}))

const classes = computed(() => classnames('Chart', 'DonutChart', props.class))
</script>

<template>
  <div :class="classes">
    <ApexChart type="donut" :series="series" :options="options" :height="height" />
  </div>
</template>
