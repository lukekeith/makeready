<script lang="ts">
import { cva } from '../../../util/cva'

// Avatar — primitive. CVA size names mirror the SCSS modifiers in
// resources/css/components/primitive/avatar.scss exactly. Styles are global via
// app.scss, so this component only emits classes.
export const AvatarCva = cva('Avatar', {
  variants: {
    size: {
      Sm: 'Avatar--sm',
      Md: 'Avatar--md',
      Lg: 'Avatar--lg',
      Xl: 'Avatar--xl',
    },
  },
  defaultVariants: {
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof AvatarCva.size
  src?: string
  initials?: string
  alt?: string
  loading?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => AvatarCva.defaults?.size as keyof typeof AvatarCva.size,
  loading: false,
})

const imageFailed = ref(false)

// Reset the failure state if the source changes.
watch(
  () => props.src,
  () => {
    imageFailed.value = false
  }
)

const showImage = computed(() => Boolean(props.src) && !imageFailed.value)

const classes = computed(() =>
  classnames(
    AvatarCva.variants({ size: props.size }),
    props.loading && 'Avatar--loading',
    props.class
  )
)

const onError = () => {
  imageFailed.value = true
}
</script>

<template>
  <div :class="classes">
    <img
      v-if="showImage"
      class="Avatar__image"
      :src="src"
      :alt="alt"
      @error="onError"
    />
    <span v-else class="Avatar__fallback">{{ initials }}</span>
    <span v-if="loading" class="Avatar__spinner" aria-hidden="true"></span>
  </div>
</template>
