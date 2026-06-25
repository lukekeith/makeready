<script lang="ts">
import { cva } from '../../../util/cva'

// List — layout. Vertical list container that holds ListItems (placed by the
// caller in the default slot). CVA modifiers mirror the SCSS modifiers in
// resources/css/components/layout/list.scss exactly. Styles are global via
// app.scss, so this component only emits classes.
export const ListCva = cva('List', {
  variants: {
    dividers: {
      On: 'List--dividers',
      Off: '',
    },
    inset: {
      On: 'List--inset',
      Off: '',
    },
  },
  defaultVariants: {
    dividers: 'On',
    inset: 'Off',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  dividers?: boolean
  inset?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  dividers: true,
  inset: false,
})

const classes = computed(() =>
  classnames(
    ListCva.variants({
      dividers: props.dividers ? 'On' : 'Off',
      inset: props.inset ? 'On' : 'Off',
    }),
    props.class
  )
)
</script>

<template>
  <div :class="classes" role="list">
    <slot />
  </div>
</template>
