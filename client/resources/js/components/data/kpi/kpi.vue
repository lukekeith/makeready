<script lang="ts">
import { cva } from '../../../util/cva'

// KPI — data. A tappable stat card (iOS Kpi). CVA variant keys mirror the SCSS
// modifiers in resources/css/components/data/kpi.scss exactly. The single
// `trend` variant maps a trend direction to a colored delta. Styles are global
// via app.scss, so this component only emits classes.
export const KpiCva = cva('KPI', {
  variants: {
    trend: {
      Up: 'KPI--trend-up',
      Down: 'KPI--trend-down',
      Flat: 'KPI--trend-flat',
    },
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Trend {
  dir: 'up' | 'down' | 'flat'
  value: string
}

interface Props {
  value: string | number
  label: string
  trend?: Trend
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ click: [MouseEvent] }>()

const trendKey = computed<keyof typeof KpiCva.trend | null>(() => {
  if (!props.trend) return null
  if (props.trend.dir === 'up') return 'Up'
  if (props.trend.dir === 'down') return 'Down'
  return 'Flat'
})

const classes = computed(() =>
  classnames(KpiCva.variants({ trend: trendKey.value }), props.class)
)

const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <button type="button" :class="classes" @click="onClick">
    <span class="KPI__header">
      <span v-if="$slots.icon" class="KPI__icon"><slot name="icon" /></span>
      <span class="KPI__value">{{ value }}</span>
    </span>
    <span class="KPI__footer">
      <span class="KPI__label">{{ label }}</span>
      <span v-if="trend" class="KPI__trend">
        <span class="KPI__trend-arrow" aria-hidden="true">
          <svg v-if="trend.dir === 'up'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 14l5-5 5 5" /></svg>
          <svg v-else-if="trend.dir === 'down'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 10l5 5 5-5" /></svg>
          <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14" /></svg>
        </span>
        {{ trend.value }}
      </span>
    </span>
  </button>
</template>
