<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardStudyMini — fixed-width (120×188) study tile (iOS CardStudyMini parity).
//
// Layout (mirrors CardStudyMini.swift exactly):
//   • 120×188 surface tile, 4px corner radius, no border.
//   • Top: a full-bleed 120×114 image region — either a cover photo (or its
//     gray loading placeholder) or a colored icon well (8px radius) with a
//     centered 32×32 white glyph.
//   • Bottom: 8px-padded column (8px gap) — a 2-line title (12px bold, 0.1px
//     tracking, clamped to a 32px box) over a single metadata row (icon+value).
//
// `status: 'pending'`: the card background switches to the dark-purple pending
// well and a full-width "PENDING" badge (brand fill) overlays the top of the
// image region — matching the iOS ZStack(alignment: .top) badge.
//
// Metadata renders the iOS `.icon` DataItem inline: a 14px icon + 13px value.
// Only the first metadata item is shown (the iOS card renders `metadata.first`).

interface ImageStyle {
  kind: 'photo' | 'icon'
  url?: string
  icon?: string // inline SVG markup (icon-well glyph)
  iconBackground?: string // CSS color for the icon well (no DS token for system orange)
}

interface MetaItem {
  icon?: string // inline SVG markup
  value: string
}

interface Props {
  title: string
  status?: 'confirmed' | 'pending'
  imageStyle: ImageStyle
  metadata?: MetaItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  status: 'confirmed',
  metadata: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const isPending = computed(() => props.status === 'pending')

const classes = computed(() =>
  classnames('CardStudyMini', isPending.value && 'CardStudyMini--is-pending', props.class)
)

const firstMeta = computed(() => props.metadata[0] ?? null)

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
    <div class="CardStudyMini__media">
      <img
        v-if="imageStyle.kind === 'photo' && imageStyle.url"
        class="CardStudyMini__image"
        :src="imageStyle.url"
        :alt="title"
      />
      <span
        v-else-if="imageStyle.kind === 'photo'"
        class="CardStudyMini__placeholder"
        aria-hidden="true"
      />
      <span
        v-else
        class="CardStudyMini__iconWell"
        :style="imageStyle.iconBackground ? { background: imageStyle.iconBackground } : undefined"
        aria-hidden="true"
      >
        <span class="CardStudyMini__icon" v-html="imageStyle.icon" />
      </span>

      <span v-if="isPending" class="CardStudyMini__badge">PENDING</span>
    </div>

    <div class="CardStudyMini__body">
      <span class="CardStudyMini__title">{{ title }}</span>
      <div v-if="firstMeta" class="CardStudyMini__data">
        <span v-if="firstMeta.icon" class="CardStudyMini__dataIcon" v-html="firstMeta.icon" />
        <span class="CardStudyMini__dataValue">{{ firstMeta.value }}</span>
      </div>
    </div>
  </div>
</template>
