<script lang="ts">
import { cva } from '../../../util/cva'

// CardSlideButton — the circular icon action revealed behind a SwipeableCard
// (iOS SwipeableCard.buttonRow). Captured standalone in the Compare tool: a
// 48px circle filled per `style`, with a single 20px white icon centered.
//
// `variant` drives the fill: reschedule (blue), delete (red), skip/edit (white
// 20%). `icon` is an inline SVG string (semantic SF Symbols are mapped to SVG
// in the compare adapter). Data-driven via props.
//
// NOTE: the variant is exposed as `variant`, NOT `style` — `style` is a Vue
// reserved attribute (it binds as inline CSS on the root element), so a prop
// named `style` never receives the data. The adapter maps the iOS `style` field
// to this `variant` prop.
//
// This is distinct from the labeled, rectangular `SlideButton` component
// (slide-button/slide-button.vue, used by the swipeable-card twin) — that one
// renders a pill with a text label, whereas the iOS reveal action is an
// icon-only circle. CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-slide-button.scss exactly.
export const CardSlideButtonCva = cva('CardSlideButton', {
  variants: {
    variant: {
      reschedule: 'CardSlideButton--style-reschedule',
      delete: 'CardSlideButton--style-delete',
      skip: 'CardSlideButton--style-skip',
      edit: 'CardSlideButton--style-edit',
    },
  },
  defaultVariants: {
    variant: 'skip',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  icon: string
  variant?: keyof typeof CardSlideButtonCva.variant
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  icon: '',
  variant: () => CardSlideButtonCva.defaults?.variant as keyof typeof CardSlideButtonCva.variant,
})

const classes = computed(() =>
  classnames(CardSlideButtonCva.variants({ variant: props.variant }), props.class)
)
</script>

<template>
  <div :class="classes" role="button" aria-hidden="true">
    <span class="CardSlideButton__icon" v-html="icon" />
  </div>
</template>
