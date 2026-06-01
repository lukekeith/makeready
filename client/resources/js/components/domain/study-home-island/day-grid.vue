<script setup lang="ts">
import type { StudyLesson } from './use-study-home-state'

const props = withDefaults(
  defineProps<{
    lessons: StudyLesson[]
    selectedId?: string
    completedIds?: string[]
  }>(),
  { completedIds: () => [] }
)

const emit = defineEmits<{ (e: 'select', id: string): void }>()

function isCompleted(id: string): boolean {
  return props.completedIds.includes(id)
}

// Fraction of the lesson's activities the user has completed (0–1).
function progress(lesson: StudyLesson): number {
  const acts = lesson.activities ?? []
  if (!acts.length) return 0
  return acts.filter((a) => a.completed).length / acts.length
}
</script>

<template>
  <div class="DayGrid">
    <button
      v-for="lesson in lessons"
      :key="lesson.id"
      class="DayGrid__cell"
      :class="{
        'DayGrid__cell--selected': lesson.id === selectedId,
        'DayGrid__cell--completed': isCompleted(lesson.id),
      }"
      @click="emit('select', lesson.id)"
    >
      <span class="DayGrid__label">Day</span>
      <span class="DayGrid__number">{{ lesson.dayNumber }}</span>
      <div class="DayGrid__progress">
        <div class="DayGrid__progress-fill" :style="{ width: progress(lesson) * 100 + '%' }" />
      </div>
    </button>
  </div>
</template>
