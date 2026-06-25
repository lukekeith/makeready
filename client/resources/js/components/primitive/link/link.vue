<script lang="ts">
import { cva } from '../../../util/cva'

// Link — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/link.scss exactly (PRD §6). Styles are
// global via app.scss, so this component only emits classes.
export const LinkCva = cva('Link', {
  variants: {
    variant: {
      Default: 'Link--default',
      Muted: 'Link--muted',
      Inline: 'Link--inline',
    },
  },
  defaultVariants: {
    variant: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  variant?: keyof typeof LinkCva.variant
  href?: string
  target?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () => LinkCva.defaults?.variant as keyof typeof LinkCva.variant,
})

const classes = computed(() =>
  classnames(LinkCva.variants({ variant: props.variant }), props.class)
)
</script>

<template>
  <a :class="classes" :href="href" :target="target">
    <slot />
  </a>
</template>
