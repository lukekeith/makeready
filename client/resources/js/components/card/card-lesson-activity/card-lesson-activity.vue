<script lang="ts">
// CardLessonActivity — unified lesson-activity card (iOS CardLessonActivity).
// Data-driven; renders a study or video activity in a default or small layout.
//
// Props:
//   type        string   — activity type (READ / USER_INPUT / EXEGESIS / VIDEO /
//                           YOUTUBE); drives the icon + accent color and the
//                           study-vs-video text layout.
//   title       string
//   description string?
//   status      string?  — 'confirmed' | 'new' | 'pending'. 'new' shows the
//                          type-label + brand action line and a brand border.
//   size        'default' | 'small'
//   estimatedMinutes number? — shown as "N min" (">99 min" past 99)
//   imageUrl    string?  — video thumbnail (confirmed video only)
import { cva } from '../../../util/cva'

export const CardLessonActivityCva = cva('CardLessonActivity', {
  variants: {
    size: {
      default: 'CardLessonActivity--size-default',
      small: 'CardLessonActivity--size-small',
    },
  },
  defaultVariants: {
    size: 'default',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  type?: string
  title: string
  description?: string
  status?: string
  size?: keyof typeof CardLessonActivityCva.size
  estimatedMinutes?: number
  imageUrl?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardLessonActivityCva.defaults?.size as keyof typeof CardLessonActivityCva.size,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// ─── Activity icon registry (mirrors ActivityStyle.icon) ──────────────────────
const ICONS: Record<string, string> = {
  read:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
  userInput:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>',
  // Exegesis: stacked "A + text lines" (matches the iOS IconActivityExegesis
  // text-analysis glyph — two letter A's each beside a pair of lines).
  exegesis:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10l2.2-5 2.2 5"/><path d="M3.7 8.2h3"/><path d="M11 6h10"/><path d="M11 9h6"/><path d="M3 21l2.2-5 2.2 5"/><path d="M3.7 19.2h3"/><path d="M11 17h10"/><path d="M11 20h6"/></svg>',
  // Record-circle for VIDEO (matches the iOS IconRecordVideo glyph used in the
  // new-video state): an outer ring with a solid center dot.
  video:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.5" fill="currentColor" stroke="none"/></svg>',
  youtube:
    '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M8 5v14l11-7z"/></svg>',
}
const PLAY_ICON =
  '<svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="11" fill="#fff"/><path d="M10 8.5v7l5.5-3.5z" fill="#0d101a"/></svg>'

const TYPE_KEY: Record<string, string> = {
  READ: 'read',
  SCRIPTURE: 'read',
  SOAP: 'read',
  USER_INPUT: 'userInput',
  EXEGESIS: 'exegesis',
  VIDEO: 'video',
  YOUTUBE: 'youtube',
}

const typeKey = computed(() => TYPE_KEY[props.type ?? ''] ?? 'read')
const isNew = computed(() => props.status === 'new' || props.status === 'pending')
const isVideo = computed(() => props.type === 'VIDEO' || props.type === 'YOUTUBE')
const hasPhoto = computed(() => isVideo.value && !isNew.value && !!props.imageUrl)
const iconSvg = computed(() => ICONS[typeKey.value] ?? ICONS.read)

const estimateLabel = computed(() => {
  const m = props.estimatedMinutes ?? 0
  if (m <= 0) return ''
  return m > 99 ? '>99 min' : `${m} min`
})

const rootClasses = computed(() =>
  classnames(
    CardLessonActivityCva.variants({ size: props.size }),
    isNew.value && 'CardLessonActivity--new',
    props.class
  )
)

const boxClasses = computed(() => [
  'CardLessonActivity__image--box',
  `CardLessonActivity__image--type-${typeKey.value}`,
  isNew.value ? 'CardLessonActivity__image--new' : 'CardLessonActivity__image--confirmed',
])

const onClick = (e: MouseEvent) => emit('click', e)
const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <!-- Image/icon box shared by both sizes -->
  <div
    :class="rootClasses"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <!-- Small size: image leads -->
    <template v-if="size === 'small'">
      <div
        class="CardLessonActivity__image"
        :class="hasPhoto ? null : boxClasses"
      >
        <img v-if="hasPhoto" class="CardLessonActivity__photo" :src="imageUrl" :alt="title" />
        <span v-else v-html="iconSvg" />
      </div>
      <div class="CardLessonActivity__text">
        <h3 class="CardLessonActivity__title">{{ title }}</h3>
        <p v-if="description" class="CardLessonActivity__desc">{{ description }}</p>
      </div>
      <span v-if="estimateLabel" class="CardLessonActivity__estimate">{{ estimateLabel }}</span>
    </template>

    <!-- Default size: text leads, media on the right -->
    <template v-else>
      <div class="CardLessonActivity__text">
        <!-- New / unconfigured -->
        <template v-if="isNew">
          <span class="CardLessonActivity__typeLabel">{{ type }}</span>
          <p v-if="description" class="CardLessonActivity__action">{{ description }}</p>
        </template>
        <!-- Video: description over title -->
        <template v-else-if="isVideo">
          <p v-if="description" class="CardLessonActivity__desc CardLessonActivity__desc--lead">{{ description }}</p>
          <h3 class="CardLessonActivity__title CardLessonActivity__title--video">{{ title }}</h3>
        </template>
        <!-- Study: title over description -->
        <template v-else>
          <h3 class="CardLessonActivity__title">{{ title }}</h3>
          <p v-if="description" class="CardLessonActivity__desc">{{ description }}</p>
        </template>
      </div>

      <div class="CardLessonActivity__media">
        <div
          class="CardLessonActivity__image"
          :class="hasPhoto ? null : boxClasses"
        >
          <template v-if="hasPhoto">
            <img class="CardLessonActivity__photo" :src="imageUrl" :alt="title" />
            <span class="CardLessonActivity__play" v-html="PLAY_ICON" />
          </template>
          <span v-else v-html="iconSvg" />
        </div>
        <span v-if="estimateLabel" class="CardLessonActivity__estimate">{{ estimateLabel }}</span>
      </div>
    </template>
  </div>
</template>
