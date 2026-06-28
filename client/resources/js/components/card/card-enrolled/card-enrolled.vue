<script setup lang="ts">
// CardEnrolled — enrollment card (iOS CardEnrolled parity). A full-width row
// showing the study title, a calendar meta line (date range + lessons-left),
// the group name, and a vertically-stacked pair of cover images on the RIGHT
// (study on top, group on bottom). Fully data-driven via props; no store access.
//
// Fields (props):
//   studyTitle     string   — study/program title (1 line, ellipsis)
//   groupName      string   — group name (1 line, ellipsis)
//   dateRange      string   — pre-formatted range, e.g. "Dec 31 - Jan 30"
//   lessonsLeft    number?  — when set, renders "· N lesson(s) left"
//   studyImageURL  string?  — top cover; falls back to a book icon well
//   groupImageURL  string?  — bottom cover; falls back to a people icon well
//
// BEM class names mirror resources/css/components/card/card-enrolled.scss.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Image from '../../primitive/image/image.vue'

interface Props {
  studyTitle: string
  groupName: string
  dateRange: string
  lessonsLeft?: number | null
  studyImageURL?: string
  groupImageURL?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  lessonsLeft: null,
  studyImageURL: '',
  groupImageURL: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() => classnames('CardEnrolled', props.class))

const lessonWord = computed(() =>
  props.lessonsLeft === 1 ? 'lesson' : 'lessons'
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
    <div class="CardEnrolled__body">
      <h3 class="CardEnrolled__title">{{ studyTitle }}</h3>

      <div class="CardEnrolled__meta">
        <span class="CardEnrolled__calendar" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="4" width="18" height="18" rx="2" />
            <path d="M16 2v4M8 2v4M3 10h18" />
          </svg>
        </span>
        <span class="CardEnrolled__dates">{{ dateRange }}</span>
        <template v-if="lessonsLeft != null">
          <span class="CardEnrolled__dot" aria-hidden="true"></span>
          <span class="CardEnrolled__lessons">
            <span class="CardEnrolled__lessonsCount">{{ lessonsLeft }}</span>
            {{ lessonWord }} left
          </span>
        </template>
      </div>

      <span class="CardEnrolled__group">{{ groupName }}</span>
    </div>

    <div class="CardEnrolled__stack" aria-hidden="true">
      <div class="CardEnrolled__tile CardEnrolled__tile--top">
        <Image
          v-if="studyImageURL"
          :src="studyImageURL"
          :alt="studyTitle"
          fit="Cover"
          class="CardEnrolled__image"
        />
        <span v-else class="CardEnrolled__fallback">
          <!-- Open book (matches iOS SF Symbol book.fill). -->
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M11 5.5C9.4 4.4 7.1 3.8 4.7 3.8c-.8 0-1.5.1-2.2.2a1 1 0 0 0-.8 1v11.3a1 1 0 0 0 1.2 1c.6-.1 1.2-.2 1.8-.2 2.3 0 4.3.7 5.8 1.7a.5.5 0 0 0 .5 0V5.5Zm2 14.2a.5.5 0 0 0 .5 0c1.5-1 3.5-1.7 5.8-1.7.6 0 1.2.1 1.8.2a1 1 0 0 0 1.2-1V5.9a1 1 0 0 0-.8-1c-.7-.1-1.4-.2-2.2-.2-2.4 0-4.7.6-6.3 1.7v13.3Z" />
          </svg>
        </span>
      </div>

      <div class="CardEnrolled__tile CardEnrolled__tile--bottom">
        <Image
          v-if="groupImageURL"
          :src="groupImageURL"
          :alt="groupName"
          fit="Cover"
          class="CardEnrolled__image"
        />
        <span v-else class="CardEnrolled__fallback">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-3.33 0-7 1.67-7 4.5V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5C16 14.67 12.33 13 9 13Zm7.5-2a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm.5 2c-.62 0-1.27.07-1.91.21 1.42.95 2.41 2.26 2.41 4.29V20a3 3 0 0 1-.18 1H21a1 1 0 0 0 1-1v-2c0-2.83-3.17-4-6-4Z" />
          </svg>
        </span>
      </div>
    </div>
  </div>
</template>
