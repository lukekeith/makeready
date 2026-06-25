<script lang="ts">
import { cva } from '../../../util/cva'

// Panel — layout. A surface container. CVA variant/padding names mirror the SCSS
// modifiers in resources/css/components/layout/panel.scss exactly. Styles are
// global via app.scss, so this component only emits classes.
export const PanelCva = cva('Panel', {
  variants: {
    variant: {
      Surface: 'Panel--surface',
      Frosted: 'Panel--frosted',
      Section: 'Panel--section',
    },
    padding: {
      None: 'Panel--padding-none',
      Sm: 'Panel--padding-sm',
      Md: 'Panel--padding-md',
      Lg: 'Panel--padding-lg',
    },
  },
  defaultVariants: {
    variant: 'Surface',
    padding: 'Lg',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof PanelCva.variant
  padding?: keyof typeof PanelCva.padding
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => PanelCva.defaults?.variant as keyof typeof PanelCva.variant,
  padding: () => PanelCva.defaults?.padding as keyof typeof PanelCva.padding,
})

const classes = computed(() =>
  classnames(
    PanelCva.variants({ variant: props.variant, padding: props.padding }),
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <slot />
  </div>
</template>
