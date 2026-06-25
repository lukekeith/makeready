<script lang="ts">
import { cva } from '../../../util/cva'

// LoadingOverlay — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/loading-overlay.scss exactly. Styles are
// global via app.scss, so this component only emits classes. Composes the
// Spinner primitive at size Lg.
export const LoadingOverlayCva = cva('LoadingOverlay', {
  variants: {
    variant: {
      Cover: 'LoadingOverlay--cover',
      Inline: 'LoadingOverlay--inline',
    },
  },
  defaultVariants: {
    variant: 'Cover',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Spinner from '../spinner/spinner.vue'

interface Props {
  open?: boolean
  label?: string
  variant?: keyof typeof LoadingOverlayCva.variant
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  open: true,
  variant: () => LoadingOverlayCva.defaults?.variant as keyof typeof LoadingOverlayCva.variant,
})

const isCover = computed(() => props.variant === 'Cover')

const classes = computed(() =>
  classnames(
    LoadingOverlayCva.variants({ variant: props.variant }),
    // The Cover variant fades; toggle open/closed modifiers drive it. The
    // Inline variant is rendered/removed via v-if instead.
    isCover.value && (props.open ? 'LoadingOverlay--open' : 'LoadingOverlay--closed'),
    props.class
  )
)
</script>

<template>
  <!-- Cover stays mounted so it can fade; Inline mounts only when open. -->
  <div
    v-if="isCover || open"
    :class="classes"
    role="status"
    :aria-busy="open || undefined"
    :aria-hidden="isCover && !open ? 'true' : undefined"
    :aria-label="label || 'Loading'"
  >
    <Spinner size="Lg" />
    <p v-if="label" class="LoadingOverlay__label">{{ label }}</p>
  </div>
</template>
