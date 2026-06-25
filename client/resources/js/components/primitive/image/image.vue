<script lang="ts">
import { cva } from '../../../util/cva'

// Image — primitive. CVA variant names mirror the SCSS modifiers in
// resources/css/components/primitive/image.scss exactly. Styles are global via
// app.scss, so this component only emits classes and manages load/error state.
export const ImageCva = cva('Image', {
  variants: {
    fit: {
      Cover: 'Image--cover',
      Contain: 'Image--contain',
    },
    ratio: {
      Square: 'Image--square',
      ThreeTwo: 'Image--three-two',
      Portrait: 'Image--portrait',
      Auto: '',
    },
    rounded: {
      true: 'Image--rounded',
      false: '',
    },
  },
  defaultVariants: {
    fit: 'Cover',
    ratio: 'Auto',
    rounded: 'false',
  },
})
</script>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  src: string
  alt: string
  fit?: keyof typeof ImageCva.fit
  ratio?: keyof typeof ImageCva.ratio
  rounded?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  fit: () => ImageCva.defaults?.fit as keyof typeof ImageCva.fit,
  ratio: () => ImageCva.defaults?.ratio as keyof typeof ImageCva.ratio,
  rounded: false,
})

const loaded = ref(false)
const errored = ref(false)

const onLoad = () => {
  loaded.value = true
}

const onError = () => {
  errored.value = true
}

const classes = computed(() =>
  classnames(
    ImageCva.variants({
      fit: props.fit,
      ratio: props.ratio,
      rounded: props.rounded ? 'true' : 'false',
    }),
    loaded.value && 'Image--loaded',
    errored.value && 'Image--errored',
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <img
      v-show="!errored"
      class="Image__img"
      :src="src"
      :alt="alt"
      @load="onLoad"
      @error="onError"
    />
    <div v-if="errored" class="Image__fallback" role="img" :aria-label="alt">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <circle cx="8.5" cy="8.5" r="1.5" />
        <path d="m21 15-5-5L5 21" />
      </svg>
    </div>
  </div>
</template>
