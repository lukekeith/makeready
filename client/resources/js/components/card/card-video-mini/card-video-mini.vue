<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardVideoMini — fixed-width (120×188) video tile (iOS CardVideoMini parity).
//
// Layout (mirrors CardVideoMini.swift exactly):
//   • 120×188 surface tile, 4px corner radius, no border.
//   • Top: a full-bleed 120×114 image region (8px radius) — either a cover photo
//     (or its gray loading placeholder) or a slate icon well — with a 24×24 white
//     play badge centered horizontally, 16px from the bottom of the region.
//   • Bottom: 8px-padded column (8px gap) — an optional description (13px, white
//     70%, single line) over a 2-line title (12px bold, 0.1px tracking, clamped
//     to a 32px box) over a single metadata row (icon+value).
//
// Metadata renders the iOS `.icon` DataItem inline: a 14px icon + 13px value.
// Only the first metadata item is shown (the iOS card renders `metadata.first`).
//
// Data-driven, no store access. Class names are plain BEM and match the modifiers
// in resources/css/components/card/card-video-mini.scss.

interface ImageStyle {
  kind: 'photo' | 'icon'
  /** photo form: cover image URL (omitted in isolated /compare snapshots). */
  url?: string
  /** icon form: inline SVG markup for the centered well glyph. */
  icon?: string
}

interface MetaItem {
  /** inline SVG markup */
  icon?: string
  value: string
}

interface Props {
  title: string
  description?: string
  imageStyle: ImageStyle
  metadata?: MetaItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  description: '',
  metadata: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const firstMeta = computed(() => props.metadata[0] ?? null)

const classes = computed(() => classnames('CardVideoMini', props.class))

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
    <div class="CardVideoMini__media">
      <img
        v-if="imageStyle.kind === 'photo' && imageStyle.url"
        class="CardVideoMini__image"
        :src="imageStyle.url"
        :alt="title"
      />
      <span
        v-else-if="imageStyle.kind === 'photo'"
        class="CardVideoMini__placeholder"
        aria-hidden="true"
      />
      <span v-else class="CardVideoMini__iconWell" aria-hidden="true">
        <span class="CardVideoMini__wellGlyph" v-html="imageStyle.icon" />
      </span>

      <span class="CardVideoMini__playBadge" aria-hidden="true">
        <svg viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="12" fill="#ffffff" />
          <path d="M9.6 7.3 17 12l-7.4 4.7Z" fill="#0d101a" />
        </svg>
      </span>
    </div>

    <div class="CardVideoMini__body">
      <span v-if="description" class="CardVideoMini__description">{{ description }}</span>
      <span class="CardVideoMini__title">{{ title }}</span>
      <div v-if="firstMeta" class="CardVideoMini__data">
        <span v-if="firstMeta.icon" class="CardVideoMini__dataIcon" v-html="firstMeta.icon" />
        <span class="CardVideoMini__dataValue">{{ firstMeta.value }}</span>
      </div>
    </div>
  </div>
</template>
