<script lang="ts">
// Page (a.k.a Screen) — layout. The page content wrapper: centers content at
// --page-max-w with horizontal --page-pad-x and a full min-height. Styles are
// global via app.scss, so this component only emits classes.
//
// No CVA variant table: Page's only modifiers (padded, safe-area) are boolean
// state toggles, not enum variants, so they're applied as plain modifier flags.
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  /** Apply horizontal --page-pad-x. Default true. */
  padded?: boolean
  /** Add safe-area top/bottom padding for notch / home indicator. */
  safeArea?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  padded: true,
  safeArea: false,
})

const classes = computed(() =>
  classnames(
    'Page',
    props.padded && 'Page--padded',
    props.safeArea && 'Page--safe-area',
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <slot />
  </div>
</template>
