<script lang="ts">
import { cva } from '../../../util/cva'

// HelpText — form. Small helper text shown beneath a field. CVA tone names
// mirror the `.HelpText--*` SCSS modifiers in
// resources/css/components/form/help-text.scss exactly.
//
// There is no separate ErrorText component: an error message is simply
// `<HelpText tone="Error">…</HelpText>`, which colors via --fg-error and sets
// role="alert" so assistive tech announces it.
export const HelpTextCva = cva('HelpText', {
  variants: {
    tone: {
      Muted: 'HelpText--muted',
      Error: 'HelpText--error',
      Success: 'HelpText--success',
    },
  },
  defaultVariants: {
    tone: 'Muted',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  tone?: keyof typeof HelpTextCva.tone
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tone: () => HelpTextCva.defaults?.tone as keyof typeof HelpTextCva.tone,
})

const classes = computed(() =>
  classnames(HelpTextCva.variants({ tone: props.tone }), props.class)
)
</script>

<template>
  <p :class="classes" :role="tone === 'Error' ? 'alert' : undefined">
    <slot />
  </p>
</template>
