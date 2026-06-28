<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardStudySelectable — selectable study-program card for the enrollment flow
// (iOS CardStudySelectable parity).
//
// Layout (mirrors CardStudySelectable.swift exactly):
//   • 140px-tall surface row, 4px corner radius, 16px padding, 16px gap.
//   • Left body (vertically centered): a 1-line title (17px bold) over a 2-line
//     description (13px, white@70), then a metadata row — a "N days" count
//     (book glyph + 13px white@50) beside a Published/Draft pill.
//   • Right: a fixed 72×108 portrait cover (8px radius). Photo when an imageUrl
//     is given, otherwise a gray icon well with a centered 24px book glyph.
//
// `selected: true`: the surface switches to the dark-purple well, gains a 2px
// brand border, and the cover is overlaid with an 80% brand fill + a centered
// white checkmark — matching the iOS ZStack selection overlay.
//
// The fixed cover dimensions (72×108) come straight from the iOS layout spec and
// are intrinsic structural sizes — raw px is allowed here per the design-system
// exception. Everything else is tokenized.

interface Props {
  title: string
  description?: string
  count: number
  imageUrl?: string
  selected?: boolean
  isPublished?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  description: '',
  imageUrl: '',
  selected: false,
  isPublished: true,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(
    'CardStudySelectable',
    props.selected && 'CardStudySelectable--is-selected',
    props.class
  )
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
    :aria-pressed="selected || undefined"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="CardStudySelectable__body">
      <h3 class="CardStudySelectable__title">{{ title }}</h3>
      <p v-if="description" class="CardStudySelectable__description">{{ description }}</p>

      <div class="CardStudySelectable__meta">
        <span class="CardStudySelectable__count">
          <svg
            class="CardStudySelectable__countIcon"
            viewBox="0 0 16 16"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-4.013 1.448a.5.5 0 0 0-.274.446v11a.5.5 0 0 0 .727.446c.93-.468 2.34-.948 3.658-1.08 1.323-.133 2.452.063 3.072.638a.5.5 0 0 0 .654 0c.62-.575 1.75-.771 3.072-.638 1.318.132 2.728.612 3.658 1.08A.5.5 0 0 0 16 13.834v-11a.5.5 0 0 0-.274-.446c-.97-.776-2.499-1.295-4.013-1.448C10.413.809 8.985.936 8 1.783" />
          </svg>
          {{ count }} days
        </span>

        <span
          class="CardStudySelectable__badge"
          :class="isPublished ? 'CardStudySelectable__badge--published' : 'CardStudySelectable__badge--draft'"
        >
          {{ isPublished ? 'Published' : 'Draft' }}
        </span>
      </div>
    </div>

    <div class="CardStudySelectable__cover">
      <img
        v-if="imageUrl"
        class="CardStudySelectable__image"
        :src="imageUrl"
        :alt="title"
      />
      <span v-else class="CardStudySelectable__well" aria-hidden="true">
        <svg class="CardStudySelectable__wellIcon" viewBox="0 0 16 16" fill="currentColor">
          <path d="M8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-4.013 1.448a.5.5 0 0 0-.274.446v11a.5.5 0 0 0 .727.446c.93-.468 2.34-.948 3.658-1.08 1.323-.133 2.452.063 3.072.638a.5.5 0 0 0 .654 0c.62-.575 1.75-.771 3.072-.638 1.318.132 2.728.612 3.658 1.08A.5.5 0 0 0 16 13.834v-11a.5.5 0 0 0-.274-.446c-.97-.776-2.499-1.295-4.013-1.448C10.413.809 8.985.936 8 1.783" />
        </svg>
      </span>

      <span v-if="selected" class="CardStudySelectable__overlay" aria-hidden="true">
        <svg
          class="CardStudySelectable__check"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="m5 12 5 5L20 7" />
        </svg>
      </span>
    </div>
  </div>
</template>
