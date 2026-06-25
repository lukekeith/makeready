<script lang="ts">
import { cva } from '../../../util/cva'

// Popover — overlay. CVA exposes the reka-ui placement enums as type-safe
// values; positioning/a11y is delegated to reka-ui's Popover primitives.
// Styles are global via app.scss (overlay/popover.scss); this component only
// emits classes + wires the primitive.
export const PopoverCva = cva('Popover', {
  variants: {
    side: {
      Top: 'top',
      Right: 'right',
      Bottom: 'bottom',
      Left: 'left',
    },
    align: {
      Start: 'start',
      Center: 'center',
      End: 'end',
    },
  },
  defaultVariants: {
    side: 'Bottom',
    align: 'Center',
  },
})
</script>

<script setup lang="ts">
import {
  PopoverRoot,
  PopoverTrigger,
  PopoverPortal,
  PopoverContent,
  PopoverArrow,
} from 'reka-ui'
import { classnames } from '../../../util/classnames'

type Side = 'top' | 'right' | 'bottom' | 'left'
type Align = 'start' | 'center' | 'end'

interface Props {
  side?: keyof typeof PopoverCva.side
  align?: keyof typeof PopoverCva.align
  sideOffset?: number
  showArrow?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  side: () => PopoverCva.defaults?.side as keyof typeof PopoverCva.side,
  align: () => PopoverCva.defaults?.align as keyof typeof PopoverCva.align,
  sideOffset: 8,
  showArrow: false,
})

const sideValue = (): Side => PopoverCva.side[props.side] as Side
const alignValue = (): Align => PopoverCva.align[props.align] as Align
</script>

<template>
  <PopoverRoot class="Popover">
    <PopoverTrigger as-child>
      <slot name="trigger" />
    </PopoverTrigger>
    <PopoverPortal>
      <PopoverContent
        :class="classnames('Popover__content', props.class)"
        :side="sideValue()"
        :align="alignValue()"
        :side-offset="sideOffset"
      >
        <slot />
        <PopoverArrow v-if="showArrow" class="Popover__arrow" :width="12" :height="6" />
      </PopoverContent>
    </PopoverPortal>
  </PopoverRoot>
</template>
