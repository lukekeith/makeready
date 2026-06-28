<script lang="ts">
import { cva } from '../../../util/cva'

// CardMediaFull — thumbnail-only media-grid tile (iOS CardMediaFull). A square,
// full-bleed thumbnail used in the library browse grid. The image (or a faint
// placeholder + media-type icon) fills the whole tile, with the usage count
// overlaid top-left and the duration bottom-right.
//
// Fields (props):
//   icon      string  — inline SVG for the media-type glyph (centered, white 20%);
//                        empty for photos (no glyph, just the faint placeholder)
//   count     number  — usage count chip, top-left; hidden when 0
//   duration  string  — formatted duration chip (e.g. "30:30"), bottom-right;
//                        hidden when empty
//   imageUrl  string  — optional thumbnail; falls back to the faint placeholder
//   title     string  — alt text only (the tile renders no title text, matching iOS)
//
// There is a single visual variant — the three compare variants (Video / Photo /
// Audio) differ only in icon + count + duration data, not layout.
export const CardMediaFullCva = cva('CardMediaFull', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { classnames } from '../../../util/classnames'

interface Props {
  icon?: string
  count?: number
  duration?: string
  imageUrl?: string
  title?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  icon: '',
  count: 0,
  duration: '',
  imageUrl: '',
  title: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()
const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <div :class="classnames('CardMediaFull', props.class)" @click="onClick">
    <img
      v-if="imageUrl"
      :src="imageUrl"
      :alt="title"
      class="CardMediaFull__image"
    />
    <div v-else class="CardMediaFull__placeholder" aria-hidden="true">
      <span v-if="icon" class="CardMediaFull__icon" v-html="icon" />
    </div>

    <span v-if="count > 0" class="CardMediaFull__count">{{ count }}</span>
    <span v-if="duration" class="CardMediaFull__duration">{{ duration }}</span>
  </div>
</template>
