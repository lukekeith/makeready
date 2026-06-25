<script lang="ts">
import { cva } from '../../../util/cva'

// Tooltip — overlay. CVA exposes the reka-ui side enum as type-safe values;
// positioning + a11y (hover/focus, delay, escape) are delegated to reka-ui's
// Tooltip primitives. Styles are global via app.scss (overlay/tooltip.scss).
export const TooltipCva = cva('Tooltip', {
  variants: {
    side: {
      Top: 'top',
      Right: 'right',
      Bottom: 'bottom',
      Left: 'left',
    },
  },
  defaultVariants: {
    side: 'Top',
  },
})
</script>

<script setup lang="ts">
import {
  TooltipProvider,
  TooltipRoot,
  TooltipTrigger,
  TooltipPortal,
  TooltipContent,
  TooltipArrow,
} from 'reka-ui'
import { classnames } from '../../../util/classnames'

type Side = 'top' | 'right' | 'bottom' | 'left'

interface Props {
  content?: string
  side?: keyof typeof TooltipCva.side
  delay?: number
  showArrow?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  side: () => TooltipCva.defaults?.side as keyof typeof TooltipCva.side,
  delay: 300,
  showArrow: true,
})

const sideValue = (): Side => TooltipCva.side[props.side] as Side
</script>

<template>
  <TooltipProvider :delay-duration="delay">
    <TooltipRoot class="Tooltip">
      <TooltipTrigger as-child>
        <slot name="trigger" />
      </TooltipTrigger>
      <TooltipPortal>
        <TooltipContent
          :class="classnames('Tooltip__content', props.class)"
          :side="sideValue()"
          :side-offset="4"
        >
          <slot>{{ content }}</slot>
          <TooltipArrow v-if="showArrow" class="Tooltip__arrow" :width="10" :height="5" />
        </TooltipContent>
      </TooltipPortal>
    </TooltipRoot>
  </TooltipProvider>
</template>
