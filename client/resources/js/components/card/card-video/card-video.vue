<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardVideo — type-specific video card (iOS CardVideo parity). A 140px-tall Row
// card: text content on the LEFT (vertically centered), a fixed 72×108 media box
// on the RIGHT. Two status-driven layouts:
//
//   • confirmed (default): a single-line description (13px, white 70%) over a
//     single-line title (17px bold, white), then a metadata row (icon + value,
//     both white) 16px below. The media box shows the cover photo (or its gray
//     loading placeholder) with a 24×24 white play badge centered 16px from the
//     bottom.
//   • new: an overline title "VIDEO" (14px bold, white) over a description
//     (16px bold, brand purple). No metadata. The card sits on the dark-purple
//     pending well and the media box becomes a slate icon well with a centered
//     white play glyph (no play badge).
//
// Data-driven, no store access. Mirrors CardVideo.swift exactly (non-compact,
// 4px corner radius). Class names are plain BEM (single layout) and match the
// modifiers in resources/css/components/card/card-video.scss.

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
  status?: 'confirmed' | 'new' | 'pending'
  imageStyle: ImageStyle
  metadata?: MetaItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  description: '',
  status: 'confirmed',
  metadata: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const isNew = computed(() => props.status === 'new')
const isWell = computed(() => props.status === 'new' || props.status === 'pending')

const classes = computed(() =>
  classnames('CardVideo', isWell.value && 'CardVideo--is-well', props.class)
)

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
    <div class="CardVideo__body">
      <template v-if="isNew">
        <span class="CardVideo__overline">{{ title }}</span>
        <span v-if="description" class="CardVideo__select">{{ description }}</span>
      </template>

      <template v-else>
        <span v-if="description" class="CardVideo__description">{{ description }}</span>
        <h3 class="CardVideo__title">{{ title }}</h3>
        <div v-if="metadata.length" class="CardVideo__data">
          <span v-for="(m, i) in metadata" :key="i" class="CardVideo__dataItem">
            <span v-if="m.icon" class="CardVideo__dataIcon" v-html="m.icon" />
            <span class="CardVideo__dataValue">{{ m.value }}</span>
          </span>
        </div>
      </template>
    </div>

    <div class="CardVideo__media">
      <template v-if="imageStyle.kind === 'photo'">
        <img
          v-if="imageStyle.url"
          class="CardVideo__image"
          :src="imageStyle.url"
          :alt="title"
        />
        <span v-else class="CardVideo__placeholder" aria-hidden="true" />
        <span class="CardVideo__playBadge" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="12" fill="#ffffff" />
            <path d="M9.6 7.3 17 12l-7.4 4.7Z" fill="#0d101a" />
          </svg>
        </span>
      </template>

      <span v-else class="CardVideo__iconWell" aria-hidden="true">
        <span class="CardVideo__wellGlyph" v-html="imageStyle.icon" />
      </span>
    </div>
  </div>
</template>
