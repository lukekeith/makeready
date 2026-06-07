<script setup lang="ts">
import { computed, withDefaults } from 'vue'
import type { StudyLesson } from './use-study-home-state'
import './study-calendar.scss'

const props = withDefaults(
  defineProps<{
    lessons: StudyLesson[]
    selectedId?: string
    upNextId?: string | null
    completedIds?: string[]
    firstDate?: string | null
    lastDate?: string | null
  }>(),
  { completedIds: () => [] }
)

const emit = defineEmits<{ (e: 'select', id: string): void }>()

const WEEKDAYS = ['Sun', 'Mon', 'Tues', 'Wed', 'Thu', 'Fri', 'Sat']

function dateKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
}

function isCompleted(id: string): boolean {
  return props.completedIds.includes(id)
}

// Fraction of the lesson's activities completed (0–1) — drives the cell bar.
function progress(lesson: StudyLesson): number {
  const acts = lesson.activities ?? []
  if (!acts.length) return 0
  return acts.filter((a) => a.completed).length / acts.length
}

// Map calendar day → lesson (by local date).
const lessonsByDate = computed(() => {
  const map = new Map<string, StudyLesson>()
  for (const l of props.lessons) {
    if (l.scheduledDate) map.set(dateKey(new Date(l.scheduledDate)), l)
  }
  return map
})

interface Cell {
  key: string
  day: number | null
  lesson?: StudyLesson
}
interface Month {
  label: string
  cells: Cell[]
}

const months = computed<Month[]>(() => {
  const lessonDates = props.lessons
    .map((l) => (l.scheduledDate ? new Date(l.scheduledDate) : null))
    .filter((d): d is Date => d != null)
  if (lessonDates.length === 0) return []

  const start = props.firstDate ? new Date(props.firstDate) : lessonDates[0]
  const end = props.lastDate ? new Date(props.lastDate) : lessonDates[lessonDates.length - 1]

  const result: Month[] = []
  let cursor = new Date(start.getFullYear(), start.getMonth(), 1)
  const last = new Date(end.getFullYear(), end.getMonth(), 1)

  while (cursor <= last) {
    const year = cursor.getFullYear()
    const month = cursor.getMonth()
    const firstWeekday = new Date(year, month, 1).getDay()
    const daysInMonth = new Date(year, month + 1, 0).getDate()

    const cells: Cell[] = []
    for (let i = 0; i < firstWeekday; i++) cells.push({ key: `pad-${year}-${month}-${i}`, day: null })
    for (let day = 1; day <= daysInMonth; day++) {
      const d = new Date(year, month, day)
      cells.push({ key: dateKey(d), day, lesson: lessonsByDate.value.get(dateKey(d)) })
    }

    result.push({
      label: cursor.toLocaleString('en-US', { month: 'long', year: 'numeric' }),
      cells,
    })
    cursor = new Date(year, month + 1, 1)
  }
  return result
})
</script>

<template>
  <div class="StudyCalendar">
    <div v-for="m in months" :key="m.label" class="StudyCalendar__month">
      <div class="StudyCalendar__month-label">{{ m.label }}</div>
      <div class="StudyCalendar__weekdays">
        <span v-for="w in WEEKDAYS" :key="w" class="StudyCalendar__weekday">{{ w }}</span>
      </div>
      <div class="StudyCalendar__grid">
        <button
          v-for="c in m.cells"
          :key="c.key"
          class="StudyCalendar__cell"
          :class="{
            'StudyCalendar__cell--empty': c.day === null,
            'StudyCalendar__cell--lesson': !!c.lesson,
            'StudyCalendar__cell--selected': c.lesson && c.lesson.id === selectedId,
            'StudyCalendar__cell--up-next': c.lesson && c.lesson.id === upNextId,
            'StudyCalendar__cell--completed': c.lesson && isCompleted(c.lesson.id),
          }"
          :disabled="!c.lesson"
          @click="c.lesson && emit('select', c.lesson.id)"
        >
          <span v-if="c.day !== null" class="StudyCalendar__day-num">{{ c.day }}</span>
          <div v-if="c.lesson" class="StudyCalendar__progress">
            <div class="StudyCalendar__progress-fill" :style="{ width: progress(c.lesson) * 100 + '%' }" />
          </div>
        </button>
      </div>
    </div>
  </div>
</template>
