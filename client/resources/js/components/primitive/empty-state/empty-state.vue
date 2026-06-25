<script lang="ts">
import { cva } from '../../../util/cva'

// EmptyState — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/empty-state.scss exactly. Styles are
// global via app.scss, so this component only emits classes.
export const EmptyStateCva = cva('EmptyState', {
  variants: {
    size: {
      Sm: 'EmptyState--size-sm',
      Default: 'EmptyState--size-default',
      Lg: 'EmptyState--size-lg',
    },
    align: {
      Center: 'EmptyState--align-center',
      Left: 'EmptyState--align-left',
    },
  },
  defaultVariants: {
    size: 'Default',
    align: 'Center',
  },
})
</script>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof EmptyStateCva.size
  align?: keyof typeof EmptyStateCva.align
  title?: string
  description?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => EmptyStateCva.defaults?.size as keyof typeof EmptyStateCva.size,
  align: () => EmptyStateCva.defaults?.align as keyof typeof EmptyStateCva.align,
})

const slots = useSlots()

const classes = computed(() =>
  classnames(
    EmptyStateCva.variants({ size: props.size, align: props.align }),
    props.class
  )
)

const hasContent = computed(
  () => Boolean(props.title) || Boolean(props.description) || Boolean(slots.default)
)
</script>

<template>
  <div :class="classes">
    <div v-if="$slots.icon" class="EmptyState__icon" aria-hidden="true">
      <slot name="icon" />
    </div>

    <div v-if="hasContent" class="EmptyState__content">
      <p v-if="title" class="EmptyState__title">{{ title }}</p>
      <p v-if="$slots.default || description" class="EmptyState__description">
        <slot>{{ description }}</slot>
      </p>
    </div>

    <div v-if="$slots.action" class="EmptyState__action">
      <slot name="action" />
    </div>
  </div>
</template>
