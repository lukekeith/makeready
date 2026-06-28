<script lang="ts">
import { cva } from '../../../util/cva'

// Kpi — KPI card twin (iOS Components/Display/Kpi.swift). Data-driven.
// Four layout variants of a "key performance indicator" cell, each on the same
// white@5% rounded card (radius 4pt, 16pt padding):
//   standard  : label row (icon + label) / big value / optional description
//   compact   : icon + value on the left, label pushed to the right
//   sparkline : standard text column on the left, inline trend chart on the right
//   iconValue : value top-left + icon top-right / label / optional description
//
// Value formatting (currency/percent/number/custom) mirrors the Swift
// NumberFormatter pass (thousands separators, percent fraction rules) so the
// rendered string matches the iPhone exactly.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/kpi.scss exactly.
export const KpiCva = cva('Kpi', {
  variants: {
    variant: {
      standard: 'Kpi--variant-standard',
      compact: 'Kpi--variant-compact',
      sparkline: 'Kpi--variant-sparkline',
      iconValue: 'Kpi--variant-icon-value',
    },
  },
  defaultVariants: {
    variant: 'standard',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

type ValueType = 'number' | 'currency' | 'percent' | 'custom' | 'decimal'

interface Props {
  variant?: keyof typeof KpiCva.variant
  kpiValue: number
  valueType?: ValueType
  prefix?: string
  suffix?: string
  symbol?: string
  decimalPlaces?: number
  label: string
  description?: string
  icon?: string // inline SVG markup
  iconColor?: string // CSS color; default = white@50%
  trend?: { points: number[] } | null
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => KpiCva.defaults?.variant as keyof typeof KpiCva.variant,
  valueType: 'number',
  prefix: '',
  suffix: '',
  symbol: '$',
  decimalPlaces: 2,
})

const classes = computed(() =>
  classnames(KpiCva.variants({ variant: props.variant }), props.class)
)

// Mirror Kpi.swift's format(): NumberFormatter(.decimal) with US grouping.
const grouped = (n: number, minFrac: number, maxFrac: number) =>
  n.toLocaleString('en-US', {
    minimumFractionDigits: minFrac,
    maximumFractionDigits: maxFrac,
  })

const formattedValue = computed(() => {
  const v = props.kpiValue
  switch (props.valueType) {
    case 'currency':
      return `${props.symbol}${grouped(v, 0, 0)}`
    case 'percent': {
      const minFrac = v % 1 === 0 ? 0 : 1
      return `${grouped(v, minFrac, 1)}%`
    }
    case 'decimal':
      return grouped(v, props.decimalPlaces, props.decimalPlaces)
    case 'custom':
      return `${props.prefix}${grouped(v, 0, 0)}${props.suffix}`
    case 'number':
    default:
      return grouped(v, 0, 0)
  }
})

const iconStyle = computed(() =>
  props.iconColor ? { color: props.iconColor } : undefined
)

// ── Sparkline geometry (mirrors Kpi.swift SparklineView) ───────────────────
// Swift Charts: LineMark(.monotone) + AreaMark(.monotone) in an 80×48 frame.
// The AreaMark fills between the curve and its y=0 baseline, so Charts extends
// the y-domain down to 0 → value v maps to (1 - v/max) of the plot height.
// We reproduce the monotone (Fritsch–Carlson) cubic that d3/Swift Charts use.
const SPARK_W = 80
const SPARK_H = 48
const SPARK_TOP = 4 // small top inset so the peak doesn't clip the frame

const sparkGeometry = computed(() => {
  const pts = props.trend?.points ?? []
  if (pts.length < 2) return null
  const n = pts.length
  const max = Math.max(...pts, 0) || 1
  const xs = pts.map((_, i) => (i / (n - 1)) * SPARK_W)
  const ys = pts.map((v) => SPARK_TOP + (1 - v / max) * (SPARK_H - SPARK_TOP))

  // Secant slopes
  const dx: number[] = []
  const slope: number[] = []
  for (let i = 0; i < n - 1; i++) {
    dx[i] = xs[i + 1] - xs[i]
    slope[i] = (ys[i + 1] - ys[i]) / dx[i]
  }
  // Tangents (Fritsch–Carlson)
  const m: number[] = new Array(n)
  m[0] = slope[0]
  m[n - 1] = slope[n - 2]
  for (let i = 1; i < n - 1; i++) {
    if (slope[i - 1] * slope[i] <= 0) m[i] = 0
    else m[i] = (slope[i - 1] + slope[i]) / 2
  }
  for (let i = 0; i < n - 1; i++) {
    if (slope[i] === 0) {
      m[i] = 0
      m[i + 1] = 0
    } else {
      const a = m[i] / slope[i]
      const b = m[i + 1] / slope[i]
      const h = a * a + b * b
      if (h > 9) {
        const t = 3 / Math.sqrt(h)
        m[i] = t * a * slope[i]
        m[i + 1] = t * b * slope[i]
      }
    }
  }
  // Hermite → cubic Bézier segments
  let line = `M ${xs[0].toFixed(2)} ${ys[0].toFixed(2)}`
  for (let i = 0; i < n - 1; i++) {
    const c1x = xs[i] + dx[i] / 3
    const c1y = ys[i] + (m[i] * dx[i]) / 3
    const c2x = xs[i + 1] - dx[i] / 3
    const c2y = ys[i + 1] - (m[i + 1] * dx[i]) / 3
    line += ` C ${c1x.toFixed(2)} ${c1y.toFixed(2)}, ${c2x.toFixed(2)} ${c2y.toFixed(2)}, ${xs[i + 1].toFixed(2)} ${ys[i + 1].toFixed(2)}`
  }
  const area = `${line} L ${SPARK_W} ${SPARK_H} L 0 ${SPARK_H} Z`
  return { line, area }
})
</script>

<template>
  <div :class="classes">
    <!-- standard -->
    <template v-if="variant === 'standard'">
      <div class="Kpi__labelRow">
        <span
          v-if="icon"
          class="Kpi__icon"
          :style="iconStyle"
          aria-hidden="true"
          v-html="icon"
        ></span>
        <span class="Kpi__label">{{ label }}</span>
      </div>
      <div class="Kpi__value">{{ formattedValue }}</div>
      <div v-if="description" class="Kpi__description">{{ description }}</div>
    </template>

    <!-- compact -->
    <template v-else-if="variant === 'compact'">
      <span
        v-if="icon"
        class="Kpi__icon"
        :style="iconStyle"
        aria-hidden="true"
        v-html="icon"
      ></span>
      <div class="Kpi__value">{{ formattedValue }}</div>
      <div class="Kpi__spacer"></div>
      <span class="Kpi__label">{{ label }}</span>
    </template>

    <!-- sparkline -->
    <template v-else-if="variant === 'sparkline'">
      <div class="Kpi__textColumn">
        <span class="Kpi__label">{{ label }}</span>
        <div class="Kpi__value">{{ formattedValue }}</div>
        <div v-if="description" class="Kpi__description">{{ description }}</div>
      </div>
      <div class="Kpi__spacer"></div>
      <svg
        v-if="sparkGeometry"
        class="Kpi__sparkline"
        :viewBox="`0 0 ${SPARK_W} ${SPARK_H}`"
        :width="SPARK_W"
        :height="SPARK_H"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <defs>
          <linearGradient id="kpiSparkGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="var(--color-brand-500)" stop-opacity="0.3" />
            <stop offset="100%" stop-color="var(--color-brand-500)" stop-opacity="0" />
          </linearGradient>
        </defs>
        <path :d="sparkGeometry.area" fill="url(#kpiSparkGradient)" stroke="none" />
        <path
          :d="sparkGeometry.line"
          fill="none"
          stroke="var(--color-brand-500)"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </template>

    <!-- iconValue -->
    <template v-else>
      <div class="Kpi__valueRow">
        <div class="Kpi__value">{{ formattedValue }}</div>
        <div class="Kpi__spacer"></div>
        <span
          v-if="icon"
          class="Kpi__icon"
          :style="iconStyle"
          aria-hidden="true"
          v-html="icon"
        ></span>
      </div>
      <span class="Kpi__label">{{ label }}</span>
      <div v-if="description" class="Kpi__description">{{ description }}</div>
    </template>
  </div>
</template>
