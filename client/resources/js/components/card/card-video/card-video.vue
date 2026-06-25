<script lang="ts">
import { cva } from '../../../util/cva'

// CardVideo — type-specific card for a video lesson / media item (iOS VideoCard
// parity).
//
// Data fields (data-driven, no store access):
//   title    string   — video title (required)
//   category string?  — small overline / category label
//   thumbUrl string   — thumbnail image (required)
//   duration string?  — formatted duration badge (e.g. "12:04")
//   size     Row|Mini — layout: 140px Row (thumb left) or 120×188 Mini
//                       (thumb on top + centered 40×40 play overlay)
//
// Composes the Image primitive (rounded thumbnail with shimmer/error states).
// Interactive: role=button, emits `click`, hover well.
//
// CVA `size` keys mirror the SCSS modifiers in
// resources/css/components/card/card-video.scss exactly.
export const CardVideoCva = cva('CardVideo', {
  variants: {
    size: {
      Row: 'CardVideo--size-row',
      Mini: 'CardVideo--size-mini',
    },
  },
  defaultVariants: {
    size: 'Row',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Image from '../../primitive/image/image.vue'

interface Props {
  title: string
  category?: string
  thumbUrl: string
  duration?: string
  size?: keyof typeof CardVideoCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardVideoCva.defaults?.size as keyof typeof CardVideoCva.size,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(CardVideoCva.variants({ size: props.size }), props.class)
)

const isMini = computed(() => props.size === 'Mini')

const onClick = (e: MouseEvent) => emit('click', e)

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <div
    :class="classes"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="CardVideo__media">
      <Image
        class="CardVideo__thumb"
        :src="thumbUrl"
        :alt="title"
        fit="Cover"
        rounded
      />
      <span v-if="isMini" class="CardVideo__play" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M8 5v14l11-7L8 5Z" />
        </svg>
      </span>
      <span v-if="duration" class="CardVideo__duration">{{ duration }}</span>
    </div>

    <div class="CardVideo__body">
      <span v-if="category" class="CardVideo__category">{{ category }}</span>
      <span class="CardVideo__title">{{ title }}</span>
    </div>
  </div>
</template>
