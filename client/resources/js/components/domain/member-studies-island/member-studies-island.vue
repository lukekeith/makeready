<script setup lang="ts">
import { computed } from 'vue'
import LessonCard from '../study-home-island/lesson-card.vue'
import { startOfDay, daysBetween, type LessonState, type StudyLesson } from '../study-home-island/use-study-home-state'

// One enrolled study on the member group-home "Your studies" list. Lessons carry
// completedAt (server-derived) rather than per-activity progress, so completion
// is lesson-level here.
interface StudyLessonInput {
  id: string
  dayNumber?: number | null
  title?: string | null
  scheduledDate?: string | null
  completedAt?: string | null
  estimatedMinutes?: number | null
  // Server-reported count of scheduled activities. A lesson with 0 activities has
  // nothing to complete, so it's treated as vacuously done (monday#12268464531).
  activityCount?: number | null
  href?: string | null
}
interface Study {
  id: string | null
  title: string
  description?: string | null
  coverImageUrl?: string | null
  studyHref?: string | null
  lessons: StudyLessonInput[]
}

const props = withDefaults(defineProps<{ studies: Study[] }>(), {
  studies: () => [],
})

const today = startOfDay(new Date())

function isAvailable(l: StudyLessonInput): boolean {
  if (!l.scheduledDate) return true
  return startOfDay(new Date(l.scheduledDate)) <= today
}

function daysUntil(l: StudyLessonInput): number {
  if (!l.scheduledDate) return 0
  return Math.max(0, daysBetween(today, new Date(l.scheduledDate)))
}

/** Days since a lesson unlocked (positive when scheduled in the past). */
function daysAgo(l: StudyLessonInput): number {
  if (!l.scheduledDate) return 0
  return Math.max(0, daysBetween(new Date(l.scheduledDate), today))
}

/** A lesson counts as done if it has a completion timestamp OR has no activities
 *  at all — a zero-activity lesson has nothing to complete, so it's vacuously
 *  done rather than stranding the member on a perpetual INCOMPLETE
 *  (monday#12268464531). activityCount is null when unreported (fixtures) — only
 *  an explicit 0 triggers the vacuous-complete path. */
function isComplete(l: StudyLessonInput): boolean {
  return !!l.completedAt || l.activityCount === 0
}

/** First not-yet-completed lesson in schedule order; falls back to the last
 *  lesson when every lesson is complete. */
function nextLesson(lessons: StudyLessonInput[]): StudyLessonInput | null {
  if (!lessons.length) return null
  return lessons.find((l) => !isComplete(l)) ?? lessons[lessons.length - 1]
}

/** Adapt a group-home lesson into the StudyLesson shape LessonCard expects
 *  (no per-activity data on this surface). */
function toCardLesson(l: StudyLessonInput): StudyLesson {
  return {
    id: l.id,
    dayNumber: l.dayNumber ?? 0,
    title: l.title ?? '',
    scheduledDate: l.scheduledDate ?? null,
    estimatedMinutes: l.estimatedMinutes ?? null,
    activities: [],
    href: l.href ?? null,
  }
}

interface Badge { label: string | null; variant: string }

// The card always shows the member's next-uncompleted lesson, so it's the
// "up next" card — matching the study-home badge (COMPLETE when done, else
// UP NEXT). A lesson that unlocked in the past and still isn't done is overdue,
// so it reads INCOMPLETE instead. Upcoming/locked lessons still show their
// native "Available in N days".
function badgeFor(complete: boolean, overdue: boolean): Badge {
  if (complete) return { label: 'COMPLETE', variant: 'complete' }
  if (overdue) return { label: 'INCOMPLETE', variant: 'overdue' }
  return { label: 'UP NEXT', variant: 'next' }
}

// Lesson-level completion across the whole study, driving the card's progress
// bar. Lessons carry server-derived completedAt, so a lesson counts as done once
// it has a completion timestamp.
function completionOf(lessons: StudyLessonInput[]): { completed: number; total: number; fraction: number } {
  const total = lessons.length
  const completed = lessons.filter(isComplete).length
  return { completed, total, fraction: total ? completed / total : 0 }
}

const cards = computed(() =>
  props.studies.map((study) => {
    const { completed, total, fraction } = completionOf(study.lessons)
    const raw = nextLesson(study.lessons)
    if (!raw) return { study, lesson: null as StudyLesson | null, state: 'incomplete' as LessonState, daysUntil: 0, badge: { label: null, variant: 'next' } as Badge, href: null as string | null, completed, total, fraction }
    const available = isAvailable(raw)
    const complete = isComplete(raw)
    const ago = daysAgo(raw)
    // Available, unlocked in the past, and still not done → overdue.
    const overdue = available && !complete && ago > 0
    const state: LessonState = complete ? 'complete' : available ? 'incomplete' : 'unavailable'
    return {
      study,
      lesson: toCardLesson(raw),
      state,
      daysUntil: daysUntil(raw),
      badge: badgeFor(complete, overdue),
      // Open lessons (available/complete) link straight to the lesson. Upcoming
      // (locked) lessons can't be opened yet, so the whole card goes to the
      // study home page (calendar + lesson list) instead.
      href: state === 'unavailable' ? study.studyHref ?? null : raw.href ?? null,
      completed,
      total,
      fraction,
    }
  })
)
</script>

<template>
  <div
    v-for="card in cards"
    :key="card.study.id ?? card.study.title"
    class="EnrolledStudyCard"
  >
    <img
      v-if="card.study.coverImageUrl"
      :src="card.study.coverImageUrl"
      :alt="card.study.title"
      class="EnrolledStudyCard__cover"
    />

    <div class="EnrolledStudyCard__body">
      <component
        :is="card.study.studyHref ? 'a' : 'div'"
        :href="card.study.studyHref || undefined"
        class="EnrolledStudyCard__main"
      >
        <div class="EnrolledStudyCard__details">
          <p class="EnrolledStudyCard__title">{{ card.study.title }}</p>
          <p v-if="card.study.description" class="EnrolledStudyCard__description">{{ card.study.description }}</p>
          <div v-if="card.total > 0" class="EnrolledStudyCard__progress">
            <div class="EnrolledStudyCard__progress-track">
              <div class="EnrolledStudyCard__progress-fill" :style="{ width: card.fraction * 100 + '%' }" />
            </div>
            <span class="EnrolledStudyCard__progress-label">{{ card.completed }} of {{ card.total }} lessons complete</span>
          </div>
        </div>
      </component>

      <component
        v-if="card.lesson"
        :is="card.href ? 'a' : 'div'"
        :href="card.href || undefined"
        class="EnrolledStudyCard__lesson-link"
      >
        <LessonCard
          :lesson="card.lesson"
          :state="card.state"
          :is-preview="false"
          :days-until="card.daysUntil"
          :badge="card.badge.label"
          :badge-variant="card.badge.variant"
          :up-next="card.badge.label === 'UP NEXT'"
        />
      </component>
    </div>
  </div>
</template>
