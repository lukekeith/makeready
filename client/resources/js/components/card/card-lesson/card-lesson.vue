<script lang="ts">
// CardLesson — lesson card with a DAY indicator and four display modes (iOS
// CardLesson parity). Fully data-driven via props; `mode` selects the layout.
//
// Props:
//   mode        'planning' | 'lesson' | 'progress' | 'lessonList'
//   day         number                    — the DAY indicator number
//   title       string?                   — lesson / progress / list title (1 line)
//   date        string?                   — pre-formatted date line (lesson mode)
//   description string?                   — progress blurb (2-line clamp)
//   progress    number?                   — 0…1 progress fraction (progress mode)
//   estimatedMinutes number?              — time estimate (lesson mode); formatted
//                                           ">99 min" / "0 min" / "N min"
//   activities  CardLessonActivity[]      — planning rows or lesson icon boxes
//   sections    CardLessonSection[]       — progress section list
//   status      'complete'|'next'|'upcoming'  — lessonList status badge
//   upcomingText string?                  — text for the `upcoming` badge
//   released    boolean?                  — lesson released → highlight (pending) well
//
// Planning activities carry { icon (inline svg), type, title, isConfigured }.
// Lesson activities carry { activityType, status } and the colored icon box is
// derived from activityType (mirrors ActivityStyle.swift).
import { cva } from '../../../util/cva'

export const CardLessonCva = cva('CardLesson', {
  variants: {
    mode: {
      planning: 'CardLesson--mode-planning',
      lesson: 'CardLesson--mode-lesson',
      progress: 'CardLesson--mode-progress',
      lessonList: 'CardLesson--mode-lessonList',
    },
  },
  defaultVariants: {
    mode: 'planning',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

export interface CardLessonActivity {
  // Planning row
  icon?: string // inline SVG markup
  type?: string
  title?: string
  isConfigured?: boolean
  // Lesson icon box
  activityType?: string // READ / USER_INPUT / VIDEO / YOUTUBE / EXEGESIS
  status?: 'default' | 'incomplete' | 'complete'
}

export interface CardLessonSection {
  name: string
  completed?: boolean
}

interface Props {
  mode?: keyof typeof CardLessonCva.mode
  day: number
  title?: string
  date?: string
  description?: string
  progress?: number
  estimatedMinutes?: number
  activities?: CardLessonActivity[]
  sections?: CardLessonSection[]
  status?: 'complete' | 'next' | 'upcoming'
  upcomingText?: string
  released?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  mode: () => CardLessonCva.defaults?.mode as keyof typeof CardLessonCva.mode,
  activities: () => [],
  sections: () => [],
  released: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// ─── Lesson activity-box icon registry (mirrors ActivityStyle.icon) ───────────
const READ_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>'
const WRITE_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>'
const RECORD_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 7l-7 5 7 5z"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>'
const PLAY_ICON =
  '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M8 5v14l11-7z"/></svg>'
const EXEGESIS_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.35-4.35"/><path d="M8 11h6M11 8v6"/></svg>'

const ACTIVITY_META: Record<string, { type: string; icon: string }> = {
  READ: { type: 'read', icon: READ_ICON },
  SCRIPTURE: { type: 'read', icon: READ_ICON },
  SOAP: { type: 'read', icon: READ_ICON },
  OIA: { type: 'read', icon: READ_ICON },
  DBS: { type: 'read', icon: READ_ICON },
  HEAR: { type: 'read', icon: READ_ICON },
  USER_INPUT: { type: 'userInput', icon: WRITE_ICON },
  VIDEO: { type: 'video', icon: RECORD_ICON },
  YOUTUBE: { type: 'youtube', icon: PLAY_ICON },
  EXEGESIS: { type: 'exegesis', icon: EXEGESIS_ICON },
}

function activityMeta(t?: string) {
  return ACTIVITY_META[t ?? ''] ?? ACTIVITY_META.READ
}

const CHEVRON_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18l6-6-6-6"/></svg>'
const CHECK_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L20 7"/></svg>'

// ─── Planning ─────────────────────────────────────────────────────────────────
const isReady = computed(
  () =>
    props.activities.length > 0 &&
    props.activities.every((a) => a.isConfigured !== false)
)

// ─── Lesson ───────────────────────────────────────────────────────────────────
const MAX_VISIBLE = 5
const visibleActivities = computed(() => props.activities.slice(0, MAX_VISIBLE))
const overflowCount = computed(() => Math.max(0, props.activities.length - MAX_VISIBLE))

const hasIncomplete = computed(() =>
  props.activities.some((a) => a.status === 'incomplete')
)
const lessonHighlight = computed(() => props.released || hasIncomplete.value)

const estimateLabel = computed(() => {
  const m = props.estimatedMinutes ?? 0
  if (m > 99) return '>99 min'
  if (m <= 0) return '0 min'
  return `${m} min`
})

// ─── Progress ─────────────────────────────────────────────────────────────────
const progressPct = computed(
  () => `${Math.min(Math.max(props.progress ?? 0, 0), 1) * 100}%`
)

// ─── Day-label colour (lessonList only varies it) ─────────────────────────────
const rootClasses = computed(() =>
  classnames(
    CardLessonCva.variants({ mode: props.mode }),
    props.mode === 'planning' && !isReady.value && 'CardLesson--not-ready',
    props.mode === 'lesson' && lessonHighlight.value && 'CardLesson--highlight',
    props.mode === 'lessonList' && props.status && `CardLesson--status-${props.status}`,
    props.class
  )
)

const badgeText = computed(() => {
  if (props.status === 'complete') return 'COMPLETE'
  if (props.status === 'next') return 'NEXT'
  return props.upcomingText ?? ''
})

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
    :class="rootClasses"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <!-- Shared day indicator -->
    <div class="CardLesson__day">
      <span class="CardLesson__dayLabel">DAY</span>
      <span class="CardLesson__dayNumber">{{ day }}</span>
    </div>

    <!-- ─── Planning ─────────────────────────────────────────────────────── -->
    <template v-if="mode === 'planning'">
      <div v-if="!activities.length" class="CardLesson__planningEmpty">
        Select activities
      </div>
      <div v-else class="CardLesson__planningBody">
        <div
          v-for="(a, i) in activities"
          :key="i"
          class="CardLesson__activityRow"
        >
          <span class="CardLesson__activityRowIcon" v-html="a.icon" />
          <span v-if="a.type" class="CardLesson__activityRowType">{{ a.type }}</span>
          <span
            class="CardLesson__activityRowTitle"
            :class="{ 'is-select': a.isConfigured === false }"
          >
            {{ a.title }}
          </span>
        </div>
      </div>
      <div class="CardLesson__chevron" v-html="CHEVRON_ICON" />
    </template>

    <!-- ─── Lesson ───────────────────────────────────────────────────────── -->
    <template v-else-if="mode === 'lesson'">
      <div class="CardLesson__body">
        <h3 v-if="title" class="CardLesson__title">{{ title }}</h3>
        <span v-if="date" class="CardLesson__date">{{ date }}</span>
        <div v-if="activities.length" class="CardLesson__iconRow">
          <span
            v-for="(a, i) in visibleActivities"
            :key="i"
            class="CardLesson__box"
            :class="[
              `CardLesson__box--type-${activityMeta(a.activityType).type}`,
              `CardLesson__box--status-${a.status ?? 'default'}`,
            ]"
            v-html="activityMeta(a.activityType).icon"
          />
          <span v-if="overflowCount" class="CardLesson__overflow">+{{ overflowCount }}</span>
          <span class="CardLesson__estimate">{{ estimateLabel }}</span>
        </div>
      </div>
    </template>

    <!-- ─── Progress ─────────────────────────────────────────────────────── -->
    <template v-else-if="mode === 'progress'">
      <div class="CardLesson__body">
        <div class="CardLesson__heading">
          <h3 v-if="title" class="CardLesson__title">{{ title }}</h3>
          <p v-if="description" class="CardLesson__description">{{ description }}</p>
        </div>
        <div v-if="progress != null" class="CardLesson__progressTrack">
          <div class="CardLesson__progressFill" :style="{ width: progressPct }" />
        </div>
        <div v-if="sections.length" class="CardLesson__sections">
          <div v-for="(s, i) in sections" :key="i" class="CardLesson__section">
            <span
              class="CardLesson__sectionMark"
              :class="{ 'is-complete': s.completed }"
            >
              <span v-if="s.completed" v-html="CHECK_ICON" />
            </span>
            <span class="CardLesson__sectionName">{{ s.name }}</span>
          </div>
        </div>
      </div>
    </template>

    <!-- ─── Lesson list ──────────────────────────────────────────────────── -->
    <template v-else-if="mode === 'lessonList'">
      <div class="CardLesson__body">
        <span
          v-if="status"
          class="CardLesson__badge"
          :class="`CardLesson__badge--${status}`"
        >
          {{ badgeText }}
        </span>
        <h3 v-if="title" class="CardLesson__title">{{ title }}</h3>
      </div>
    </template>
  </div>
</template>
