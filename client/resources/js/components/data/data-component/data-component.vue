<script lang="ts">
import { cva } from '../../../util/cva'

// DataComponent — shared metadata unit (PRD §4 / inventory §7). CVA variant
// keys mirror the SCSS modifiers in resources/css/components/data/data-component.scss.
export const DataComponentCva = cva('DataComponent', {
  variants: {
    variant: {
      IconValue: 'DataComponent--icon-value',
      NumberLabel: 'DataComponent--number-label',
    },
  },
  defaultVariants: {
    variant: 'IconValue',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof DataComponentCva.variant
  /** icon-value form: the value string (icon goes in the #icon slot). */
  value?: string | number
  /** number-label form */
  number?: string | number
  label?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => DataComponentCva.defaults?.variant as keyof typeof DataComponentCva.variant,
})

const classes = computed(() =>
  classnames(DataComponentCva.variants({ variant: props.variant }), props.class)
)
</script>

<template>
  <div :class="classes">
    <template v-if="variant === 'IconValue'">
      <span v-if="$slots.icon" class="DataComponent__icon"><slot name="icon" /></span>
      <span class="DataComponent__value"><slot>{{ value }}</slot></span>
    </template>
    <template v-else>
      <span class="DataComponent__number">{{ number }}</span>
      <span class="DataComponent__label">{{ label }}</span>
    </template>
  </div>
</template>
