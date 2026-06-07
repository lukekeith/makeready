import { ref, computed, type Ref } from 'vue'

// ─── Types ──────────────────────────────────────────────────────────────────

export interface StudyActivity {
  type: string
  completed: boolean
}

export interface StudyLesson {
  id: string
  dayNumber: number
  title: string
  scheduledDate?: string | null // ISO — enrolled only
  estimatedMinutes?: number | null
  activities: StudyActivity[]
  href?: string | null
}

export type LessonState = 'unavailable' | 'incomplete' | 'partial' | 'complete'

export interface StudyHomeStateOptions {
  lessons: StudyLesson[]
  isPreview: boolean
  firstDate?: string | null
  lastDate?: string | null
  activeDays?: number[]
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Local-midnight Date for day-only comparisons. */
export function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

/** Whole calendar days from `from` to `to` (positive = future). */
export function daysBetween(from: Date, to: Date): number {
  const ms = startOfDay(to).getTime() - startOfDay(from).getTime()
  return Math.round(ms / 86_400_000)
}

// ─── State factory ──────────────────────────────────────────────────────────

export function createStudyHomeState(opts: StudyHomeStateOptions) {
  const lessons = ref<StudyLesson[]>(opts.lessons) as Ref<StudyLesson[]>
  const isPreview = opts.isPreview
  const today = startOfDay(new Date())

  const totalLessons = computed(() => lessons.value.length)

  function isAvailable(lesson: StudyLesson): boolean {
    if (isPreview || !lesson.scheduledDate) return true
    return startOfDay(new Date(lesson.scheduledDate)) <= today
  }

  function lessonState(lesson: StudyLesson): LessonState {
    if (!isAvailable(lesson)) return 'unavailable'
    const acts = lesson.activities ?? []
    const total = acts.length
    const done = acts.filter((a) => a.completed).length
    if (total > 0 && done === total) return 'complete'
    if (done > 0) return 'partial'
    return 'incomplete'
  }

  /** Days until a lesson unlocks (for the "Available in N days" label). */
  function daysUntilAvailable(lesson: StudyLesson): number {
    if (!lesson.scheduledDate) return 0
    return Math.max(0, daysBetween(today, new Date(lesson.scheduledDate)))
  }

  /** First lesson the member still needs to do (incomplete/partial & available). */
  const nextIndex = computed(() => {
    const list = lessons.value
    const needsWork = list.findIndex((l) => {
      const s = lessonState(l)
      return s === 'incomplete' || s === 'partial'
    })
    if (needsWork !== -1) return needsWork
    // Everything available is done — point at the first upcoming lesson, else the last.
    const upcoming = list.findIndex((l) => lessonState(l) === 'unavailable')
    if (upcoming !== -1) return upcoming
    return Math.max(0, list.length - 1)
  })

  const selectedIndex = ref<number>(nextIndex.value)

  const selected = computed<StudyLesson | undefined>(() => lessons.value[selectedIndex.value])
  const selectedState = computed<LessonState>(() =>
    selected.value ? lessonState(selected.value) : 'incomplete'
  )

  function select(index: number) {
    if (index < 0 || index >= lessons.value.length) return
    selectedIndex.value = index
  }
  function selectById(id: string) {
    const i = lessons.value.findIndex((l) => l.id === id)
    if (i !== -1) selectedIndex.value = i
  }
  function prev() {
    if (selectedIndex.value > 0) selectedIndex.value -= 1
  }
  function next() {
    if (selectedIndex.value < lessons.value.length - 1) selectedIndex.value += 1
  }
  function jumpToNext() {
    selectedIndex.value = nextIndex.value
  }

  const canPrev = computed(() => selectedIndex.value > 0)
  const canNext = computed(() => selectedIndex.value < lessons.value.length - 1)

  return {
    lessons,
    isPreview,
    today,
    totalLessons,
    selectedIndex,
    selected,
    selectedState,
    nextIndex,
    canPrev,
    canNext,
    lessonState,
    isAvailable,
    daysUntilAvailable,
    select,
    selectById,
    prev,
    next,
    jumpToNext,
  }
}

export type StudyHomeState = ReturnType<typeof createStudyHomeState>
