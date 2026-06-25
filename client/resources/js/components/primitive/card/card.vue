<script lang="ts">
import { cva } from '../../../util/cva'

// Card — primitive. CVA variant/padding names mirror the SCSS modifiers in
// resources/css/components/primitive/card.scss exactly. Styles are global via
// app.scss, so this component only emits classes.
export const CardCva = cva('Card', {
  variants: {
    variant: {
      Default: 'Card--default',
      Flat: 'Card--flat',
      Bordered: 'Card--bordered',
      Elevated: 'Card--elevated',
      Frosted: 'Card--frosted',
      Ghost: 'Card--ghost',
      Selectable: 'Card--selectable',
    },
    padding: {
      None: 'Card--padding-none',
      Sm: 'Card--padding-sm',
      Default: 'Card--padding-default',
      Lg: 'Card--padding-lg',
    },
  },
  defaultVariants: {
    variant: 'Default',
    padding: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof CardCva.variant
  padding?: keyof typeof CardCva.padding
  selected?: boolean
  title?: string
  description?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => CardCva.defaults?.variant as keyof typeof CardCva.variant,
  padding: () => CardCva.defaults?.padding as keyof typeof CardCva.padding,
  selected: false,
})

const slots = useSlots()

const classes = computed(() =>
  classnames(
    CardCva.variants({ variant: props.variant, padding: props.padding }),
    props.selected && 'Card--is-selected',
    props.class
  )
)

const hasHeader = computed(
  () => Boolean(slots.header) || Boolean(props.title) || Boolean(props.description)
)
</script>

<template>
  <div :class="classes">
    <div v-if="hasHeader" class="Card__header">
      <slot name="header">
        <h3 v-if="title" class="Card__title">{{ title }}</h3>
        <p v-if="description" class="Card__description">{{ description }}</p>
      </slot>
    </div>

    <div v-if="$slots.default" class="Card__content">
      <slot />
    </div>

    <div v-if="$slots.footer" class="Card__footer">
      <slot name="footer" />
    </div>
  </div>
</template>
