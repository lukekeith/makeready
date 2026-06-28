<script lang="ts">
// ScheduledLessonCard — enrollment-schedule lesson row (iOS ScheduledLessonCard).
// A horizontal card: a MM/DD date column on the left, a list of up to three
// activity rows in the center, and a chevron on the right. Two visual states:
//   active     — neutral (cardBackground) well, brand-purple month + type-colored
//                activity icons.
//   completed  — green (#103E34) well, green month + white checkmark icons.
// The iOS view treats a lesson whose scheduled date is in the past (or that is
// explicitly marked complete) as completed, so the capture's `today`/`completed`
// statuses both land here; only `future` renders the active state.
//
// Fully data-driven via props — the date strings are pre-formatted by the
// adapter (to mirror the iOS DateFormatter / local timezone), everything else is
// derived here from the activity `type` + `title`, mirroring ActivityStyle and
// ScheduledLessonCard.activityTypeLabel.
export interface ScheduledLessonActivity {
  type: string
  title?: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  monthAbbrev: string
  dayOfMonth: string
  completed?: boolean
  // Drives the active-state background: a lesson with no configured activities
  // shows the purple "needs setup" well instead of the neutral surface.
  hasConfiguredActivities?: boolean
  activities?: ScheduledLessonActivity[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  completed: false,
  hasConfiguredActivities: true,
  activities: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// Completed activities show an SF-Symbol checkmark. The active state's per-type
// icon is an asset-catalog glyph (ActivityStyle.icon → "IconActivityRead", …)
// that does NOT render in the isolated iPhone capture (the reference shows a
// blank icon slot), so the web twin draws no glyph in the active state — it just
// reserves the slot to keep the text indent identical.
const CHECK_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12.5l5 5L20 6.5"/></svg>'

// Short type label when an activity has no title (mirrors activityTypeLabel).
const TYPE_LABELS: Record<string, string> = {
  SCRIPTURE: 'Read',
  SOAP: 'SOAP',
  VIDEO: 'Video',
  PRAYER: 'Pray',
  REFLECTION: 'Review',
}

const rows = computed(() =>
  (props.activities ?? []).slice(0, 3).map((a) => {
    const hasTitle = !!(a.title && a.title.length)
    return {
      // Completed rows show the SF-Symbol checkmark (which renders). The active
      // state's type icon is an asset-catalog glyph (ActivityStyle.icon →
      // "IconActivityRead", etc.) that does NOT render in the isolated iPhone
      // capture, so the reference shows a blank icon slot — match it by reserving
      // the 14px slot (keeps the text indent) but drawing nothing.
      iconSvg: props.completed ? CHECK_ICON : '',
      label: hasTitle ? (a.title as string) : (TYPE_LABELS[a.type] ?? a.type),
      reference: hasTitle ? (a.title as string) : '',
    }
  })
)

const moreCount = computed(() => Math.max(0, (props.activities ?? []).length - 3))
const isEmpty = computed(() => (props.activities ?? []).length === 0)

const classes = computed(() => [
  'ScheduledLessonCard',
  props.completed && 'ScheduledLessonCard--completed',
  !props.completed && !props.hasConfiguredActivities && 'ScheduledLessonCard--unconfigured',
  props.class,
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
  <div :class="classes" role="button" tabindex="0" @click="onClick" @keydown="onKeydown">
    <!-- Date column (MM/DD) -->
    <div class="ScheduledLessonCard__date">
      <span class="ScheduledLessonCard__month">{{ monthAbbrev }}</span>
      <span class="ScheduledLessonCard__day">{{ dayOfMonth }}</span>
    </div>

    <!-- Activities -->
    <div class="ScheduledLessonCard__center">
      <div v-if="isEmpty" class="ScheduledLessonCard__empty">No activities</div>
      <template v-else>
        <div v-for="(row, i) in rows" :key="i" class="ScheduledLessonCard__row">
          <span class="ScheduledLessonCard__icon" v-html="row.iconSvg" />
          <span class="ScheduledLessonCard__type">{{ row.label }}</span>
          <span v-if="row.reference" class="ScheduledLessonCard__ref">{{ row.reference }}</span>
        </div>
        <div v-if="moreCount > 0" class="ScheduledLessonCard__more">+{{ moreCount }} more</div>
      </template>
    </div>

    <!-- Chevron -->
    <div class="ScheduledLessonCard__chevron">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M9 6l6 6-6 6" />
      </svg>
    </div>
  </div>
</template>
