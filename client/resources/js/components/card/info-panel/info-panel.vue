<script lang="ts">
import { cva } from '../../../util/cva'

// InfoPanel — info panel (iOS Components/Display/InfoPanel.swift). Data-driven.
// Renders a rounded panel of label/value rows in one of two modes:
//   keyValue : label left, value right on the same row (16px padding)
//   data     : label above value, stacked (16px padding, 4px gap)
// Rows are separated by a 1px white@10% divider (no divider after the last).
//
// NB: the iOS panel background is `.ultraThinMaterial`, which renders INVISIBLE
// in the isolated /compare snapshot (it blurs over the app background, which is
// the same dark color as the surrounding crop). So this twin keeps the panel
// background transparent to match — only the dividers and text render.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/info-panel.scss exactly.
export const InfoPanelCva = cva('InfoPanel', {
  variants: {
    mode: {
      keyValue: 'InfoPanel--mode-key-value',
      data: 'InfoPanel--mode-data',
    },
  },
  defaultVariants: {
    mode: 'keyValue',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

export interface InfoPanelItem {
  label: string
  value: string
}

interface Props {
  mode?: keyof typeof InfoPanelCva.mode
  items?: InfoPanelItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  mode: () => InfoPanelCva.defaults?.mode as keyof typeof InfoPanelCva.mode,
  items: () => [],
})

const classes = computed(() =>
  classnames(InfoPanelCva.variants({ mode: props.mode }), props.class)
)
</script>

<template>
  <div :class="classes">
    <template v-for="(item, i) in items" :key="i">
      <div class="InfoPanel__row">
        <span class="InfoPanel__label">{{ item.label }}</span>
        <span class="InfoPanel__value">{{ item.value }}</span>
      </div>
      <div v-if="i < items.length - 1" class="InfoPanel__divider" aria-hidden="true"></div>
    </template>
  </div>
</template>
