<script lang="ts">
// UpcomingLessonCard — "next upcoming lesson" card (iOS UpcomingLessonCard).
// A fixed-height (106px) horizontal card: a left DAY indicator (label + number),
// a center column (program name, formatted date, a row of up to four activity
// icon wells), and a right cover image (or a book placeholder when none).
//
// Fully data-driven via props. The date is pre-formatted by the adapter (to
// mirror the iOS DateFormatter "EEEE, MMM d, yyyy" in the local timezone) and
// each activity's glyph arrives as inline SVG mapped from its type (the iPhone
// derives the icon from `type` via ActivityStyle, ignoring the raw icon field).
//
// Class names mirror the BEM modifiers in
// resources/css/components/card/upcoming-lesson-card.scss.
export interface UpcomingLessonActivity {
  // Inline SVG glyph for the activity (currentColor-tinted). The adapter maps
  // the activity `type` → the matching ActivityStyle asset glyph.
  iconSvg: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  programName: string
  dayNumber: number | string
  // Pre-formatted weekday/month/day/year string (built in the adapter so the
  // web twin matches the iOS local-tz DateFormatter exactly).
  dateText: string
  coverUrl?: string
  activities?: UpcomingLessonActivity[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  coverUrl: '',
  activities: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// iOS shows the first four activities (ForEach … prefix(4)).
const boxes = computed(() => (props.activities ?? []).slice(0, 4))

// SF Symbol "book.fill" stand-in for the empty-cover placeholder (open filled
// book), tinted via currentColor at the placeholder's foreground color.
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M11.25 5.4C9.7 4.45 7.7 4 5.75 4c-1.32 0-2.55.22-3.6.6A1.2 1.2 0 0 0 1.5 5.73v12.2c0 .8.78 1.36 1.55 1.13.86-.26 1.83-.39 2.7-.39 1.7 0 3.7.45 5.5 1.55V5.4Z"/><path d="M12.75 5.4C14.3 4.45 16.3 4 18.25 4c1.32 0 2.55.22 3.6.6.39.14.65.51.65.93v12.2c0 .8-.78 1.36-1.55 1.13-.86-.26-1.83-.39-2.7-.39-1.7 0-3.7.45-5.5 1.55V5.4Z"/></svg>'

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
    :class="['UpcomingLessonCard', props.class]"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <!-- Left: DAY indicator -->
    <div class="UpcomingLessonCard__day">
      <span class="UpcomingLessonCard__day-label">DAY</span>
      <span class="UpcomingLessonCard__day-number">{{ dayNumber }}</span>
    </div>

    <!-- Center: program name, date, activity icons -->
    <div class="UpcomingLessonCard__center">
      <h3 class="UpcomingLessonCard__title">{{ programName }}</h3>
      <p class="UpcomingLessonCard__date">{{ dateText }}</p>
      <div v-if="boxes.length" class="UpcomingLessonCard__activities">
        <span
          v-for="(activity, i) in boxes"
          :key="i"
          class="UpcomingLessonCard__activity"
          v-html="activity.iconSvg"
        />
      </div>
    </div>

    <!-- Right: cover image or placeholder -->
    <div class="UpcomingLessonCard__cover">
      <img
        v-if="coverUrl"
        :src="coverUrl"
        :alt="programName"
        class="UpcomingLessonCard__cover-image"
      />
      <div
        v-else
        class="UpcomingLessonCard__cover-placeholder"
        aria-hidden="true"
        v-html="BOOK_FILL"
      />
    </div>
  </div>
</template>
