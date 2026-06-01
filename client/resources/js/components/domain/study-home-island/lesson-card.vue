<script setup lang="ts">
import { computed } from 'vue'
import ActivityCube from './activity-cube.vue'
import type { StudyLesson, LessonState } from './use-study-home-state'

const props = defineProps<{
  lesson: StudyLesson
  state: LessonState
  isPreview: boolean
  daysUntil: number
}>()

const emit = defineEmits<{ (e: 'open', lesson: StudyLesson): void }>()

const isComplete = computed(() => props.state === 'complete')
const isUnavailable = computed(() => props.state === 'unavailable')

// Left date box: "May / 4" for enrolled, "Day / N" for preview (no schedule).
const monthLabel = computed(() => {
  if (props.isPreview || !props.lesson.scheduledDate) return 'Day'
  return new Date(props.lesson.scheduledDate).toLocaleString('en-US', { month: 'short' })
})
const dayLabel = computed(() => {
  if (props.isPreview || !props.lesson.scheduledDate) return String(props.lesson.dayNumber)
  return String(new Date(props.lesson.scheduledDate).getDate())
})

// Activity cubes are capped at 5 slots: up to 4 cubes, and a 5th "+N" overflow
// block counting the remainder when there are more than 4. (Matches the iPhone
// lesson card pattern.)
const MAX_VISIBLE = 4
const activities = computed(() => props.lesson.activities ?? [])
const visibleActivities = computed(() =>
  activities.value.length > MAX_VISIBLE ? activities.value.slice(0, MAX_VISIBLE) : activities.value
)
const overflowCount = computed(() =>
  activities.value.length > MAX_VISIBLE ? activities.value.length - MAX_VISIBLE : 0
)

const minutesLabel = computed(() =>
  props.lesson.estimatedMinutes ? `${props.lesson.estimatedMinutes} min` : ''
)

function onClick() {
  if (isUnavailable.value) return
  emit('open', props.lesson)
}
</script>

<template>
  <div
    class="LessonCard"
    :class="`LessonCard--${state}`"
    role="button"
    :tabindex="isUnavailable ? -1 : 0"
    @click="onClick"
    @keydown.enter.prevent="onClick"
    @keydown.space.prevent="onClick"
  >
    <div class="LessonCard__date" :class="{ 'LessonCard__date--complete': isComplete }">
      <span class="LessonCard__month" :class="{ 'LessonCard__month--complete': isComplete }">{{ monthLabel }}</span>
      <span class="LessonCard__day">{{ dayLabel }}</span>
    </div>

    <div class="LessonCard__details">
      <p class="LessonCard__title">{{ lesson.title }}</p>

      <div class="LessonCard__meta">
        <template v-if="isUnavailable">
          <span class="LessonCard__availability">
            Available <span class="LessonCard__availability-in">in {{ daysUntil }} {{ daysUntil === 1 ? 'day' : 'days' }}</span>
          </span>
        </template>
        <template v-else>
          <div class="LessonCard__activities">
            <ActivityCube
              v-for="(a, i) in visibleActivities"
              :key="i"
              :type="a.type"
              :filled="a.completed"
            />
            <div
              v-if="overflowCount > 0"
              class="LessonCard__activity-overflow"
              :class="{ 'LessonCard__activity-overflow--complete': isComplete }"
            >+{{ overflowCount }}</div>
          </div>
          <span v-if="minutesLabel" class="LessonCard__minutes">{{ minutesLabel }}</span>
        </template>
      </div>
    </div>
  </div>
</template>
