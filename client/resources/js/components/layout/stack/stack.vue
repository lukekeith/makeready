<script lang="ts">
import { cva } from '../../../util/cva'

// Stack — layout primitive. Flex container. CVA variant names mirror the SCSS
// modifiers in resources/css/components/layout/stack.scss exactly. Styles are
// global via app.scss, so this component only emits classes.
//
// VStack / HStack are not separate components — use:
//   <Stack direction="Vertical"> … </Stack>
//   <Stack direction="Horizontal"> … </Stack>
export const StackCva = cva('Stack', {
  variants: {
    direction: {
      Vertical: 'Stack--vertical',
      Horizontal: 'Stack--horizontal',
    },
    gap: {
      None: 'Stack--gap-none',
      Xs: 'Stack--gap-xs',
      Sm: 'Stack--gap-sm',
      Md: 'Stack--gap-md',
      Lg: 'Stack--gap-lg',
      Xl: 'Stack--gap-xl',
    },
    align: {
      Start: 'Stack--align-start',
      Center: 'Stack--align-center',
      End: 'Stack--align-end',
      Stretch: 'Stack--align-stretch',
    },
    justify: {
      Start: 'Stack--justify-start',
      Center: 'Stack--justify-center',
      End: 'Stack--justify-end',
      Between: 'Stack--justify-between',
      Around: 'Stack--justify-around',
    },
  },
  defaultVariants: {
    direction: 'Vertical',
    gap: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  direction?: keyof typeof StackCva.direction
  gap?: keyof typeof StackCva.gap
  align?: keyof typeof StackCva.align
  justify?: keyof typeof StackCva.justify
  wrap?: boolean
  as?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  direction: () => StackCva.defaults?.direction as keyof typeof StackCva.direction,
  gap: () => StackCva.defaults?.gap as keyof typeof StackCva.gap,
  wrap: false,
  as: 'div',
})

const classes = computed(() =>
  classnames(
    StackCva.variants({
      direction: props.direction,
      gap: props.gap,
      align: props.align,
      justify: props.justify,
    }),
    props.wrap && 'Stack--wrap',
    props.class
  )
)
</script>

<template>
  <component :is="as" :class="classes">
    <slot />
  </component>
</template>
