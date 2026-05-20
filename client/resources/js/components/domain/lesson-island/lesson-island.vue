<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import axios from 'axios'
import VideoStep from './steps/video-step.vue'
import YoutubeStep from './steps/youtube-step.vue'
import ReadStep from './steps/read-step.vue'
import ExegesisStep from './steps/exegesis-step.vue'
import InputStep from './steps/input-step.vue'
import CompleteStep from './steps/complete-step.vue'
import './lesson-island.scss'

// ─── Types ────────────────────────────────────────────────────────────────────

interface Activity {
  id: string
  type?: string
  activityType?: string
  title?: string
  description?: string
  helpTitle?: string
  helpDescription?: string
  helpAlwaysVisible?: boolean
  helpIcon?: string
  helpText?: string
  isHelpEnabled?: boolean
  noteType?: string
  videoUrl?: string
  video?: { url?: string }
  note?: { content?: string }
  scripture?: unknown
  scriptures?: unknown[]
  sourceReferences?: Array<{
    id: string
    sourceType: string
    passageReference?: string
    bookNumber?: number
    chapterStart?: number
    verseStart?: number
    verseEnd?: number
  }>
  readBlocks?: Array<{
    id: string
    orderNumber: number
    title?: string
    content?: string
    sourceReferenceId?: string
    selections?: Array<{ start: number; end: number; style: string }> | null
    exegesisHighlights?: Array<{ id: string; orderNumber: number; start: number; end: number; noteMarkdown: string }>
  }>
  readContent?: string
  referenceTitle?: string
  progress?: { completedAt?: string }
}

interface Lesson {
  id?: string
  title?: string
  dayNumber?: number
  activities?: Activity[]
  studyEnrollmentId?: string
  studyProgram?: { name?: string }
  requireResponse?: boolean
  requireResponses?: boolean
}

interface LessonData {
  lesson?: Lesson
  [key: string]: unknown
}

interface Step {
  type: 'video' | 'youtube' | 'read' | 'exegesis' | 'input' | 'complete'
  activity?: Activity
}

// ─── Props ────────────────────────────────────────────────────────────────────

interface Props {
  lessonData: LessonData
  groupId: string
  lessonScheduleId: string
  initialStep?: number
  isPreview?: boolean
  previewToken?: string
  singleActivity?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  initialStep: 1,
  isPreview: false,
  previewToken: '',
  singleActivity: false,
})

// ─── State ────────────────────────────────────────────────────────────────────

const currentStepNumber = ref(props.initialStep)
const lesson = ref<Lesson>(props.lessonData?.lesson ?? (props.lessonData as unknown as Lesson))
const isLoading = ref(false)
const isSaving = ref(false)
const readStepComplete = ref(false)
const exegesisStepComplete = ref(false)
const hideTitle = ref(false)

// Reset step-level state when navigating between steps.
watch(currentStepNumber, () => {
  readStepComplete.value = false
  exegesisStepComplete.value = false
  hideTitle.value = false
})

// ─── Computed ─────────────────────────────────────────────────────────────────

/** Build a flat list of steps from lesson activities */
const steps = computed<Step[]>(() => {
  const activities = lesson.value?.activities ?? []
  const result: Step[] = []

  for (const activity of activities) {
    const type = (activity.type || activity.activityType)?.toUpperCase()
    if (type === 'VIDEO') {
      result.push({ type: 'video', activity })
    } else if (type === 'YOUTUBE') {
      result.push({ type: 'youtube', activity })
    } else if (type === 'READ' || type === 'SCRIPTURE') {
      result.push({ type: 'read', activity })
    } else if (type === 'EXEGESIS') {
      result.push({ type: 'exegesis', activity })
    } else if (type === 'USER_INPUT' || type === 'INPUT' || type === 'SOAP') {
      result.push({ type: 'input', activity })
    }
  }

  if (!props.singleActivity) {
    result.push({ type: 'complete' })
  }
  return result
})

const currentStep = computed<Step | undefined>(() => steps.value[currentStepNumber.value - 1])
const totalSteps = computed(() => steps.value.length)
const activityStepCount = computed(() => totalSteps.value - 1)
const isCompleteStep = computed(() => currentStep.value?.type === 'complete')

/** Whether the active step is a read activity — drives full-screen layout
 *  so theme backgrounds extend behind the sticky header. */
const isReadStep = computed(() => currentStep.value?.type === 'read' || currentStep.value?.type === 'exegesis')

/** Video steps intentionally have no page title — the player itself is the
 *  content and a label would compete with the frame for vertical space. */
const isVideoStep = computed(() => currentStep.value?.type === 'video' || currentStep.value?.type === 'youtube')
const isFirstStep = computed(() => currentStepNumber.value === 1)

const lessonTitle = computed(() => {
  const step = currentStep.value
  if (!step || !step.activity) return 'Complete'
  return step.activity.title ?? getDefaultStepTitle(step.activity.type)
})

const studyEnrollmentId = computed(() => lesson.value?.studyEnrollmentId ?? '')

/** Progress bar percentage (0–100) based on current step position */
const progressPercent = computed(() => {
  const total = activityStepCount.value
  if (total <= 0) return 100
  const current = isCompleteStep.value ? total : currentStepNumber.value
  return Math.round((current / total) * 100)
})

/** Whether next button should be disabled */
const nextDisabled = computed(() => {
  // Read steps: disable Next until all read blocks have been completed.
  if (currentStep.value?.type === 'read') return !readStepComplete.value
  // Exegesis steps: disable Next until all highlights have been visited.
  if (currentStep.value?.type === 'exegesis') return !exegesisStepComplete.value
  return false
})

/** Next button label */
const nextLabel = computed(() => {
  if (currentStepNumber.value === activityStepCount.value) return 'Finish'
  return 'Next'
})

function getDefaultStepTitle(type?: string): string {
  switch (type?.toUpperCase()) {
    case 'READ': return 'Read Scripture'
    case 'VIDEO': return 'Watch Video'
    case 'USER_INPUT': return 'Respond'
    case 'EXEGESIS': return 'Exegesis'
    default: return type ?? 'Step'
  }
}

// ─── Navigation ───────────────────────────────────────────────────────────────

function buildLessonUrl(stepNum: number): string {
  // Three URL shapes, keyed on preview context:
  //   1. Token-based public preview (isPreview + previewToken) —
  //      /public/preview/{token}/lesson/{lessonId}/{step}
  //   2. Authenticated preview (isPreview, no token) —
  //      /preview/lesson/{lessonId}/{step}
  //   3. Normal member flow —
  //      /member/groups/{groupId}/lessons/{lessonScheduleId}/{step}
  //
  // Previously the member URL was used unconditionally; in preview contexts
  // that produces /member/groups//lessons//{step} because groupId and
  // lessonScheduleId are empty strings in the preview Blade props.
  if (props.isPreview) {
    const lessonId = lesson.value?.id ?? ''
    if (props.previewToken) {
      return `/public/preview/${props.previewToken}/lesson/${lessonId}/${stepNum}`
    }
    return `/preview/lesson/${lessonId}/${stepNum}`
  }
  return `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/${stepNum}`
}

function goToStep(n: number) {
  if (n < 1 || n > totalSteps.value) return
  currentStepNumber.value = n
  // Update URL for deep-link support without page reload
  window.history.pushState({ step: n }, '', buildLessonUrl(n))
}

function handleBack() {
  if (isFirstStep.value) {
    if (props.isPreview && props.previewToken) {
      window.location.href = `/public/preview/${props.previewToken}`
      return
    }
    const enrollmentId = studyEnrollmentId.value
    if (enrollmentId) {
      window.location.href = `/member/groups/${props.groupId}/study/${enrollmentId}`
    } else {
      window.location.href = `/member/groups/${props.groupId}`
    }
    return
  }
  goToStep(currentStepNumber.value - 1)
}

function handleNext() {
  goToStep(currentStepNumber.value + 1)
}

// ─── AJAX Actions ─────────────────────────────────────────────────────────────

async function submitNote(activityId: string, noteType: string, content: string) {
  if (isSaving.value) return
  isSaving.value = true
  try {
    const response = await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/submit`,
      {
        lessonScheduleId: props.lessonScheduleId,
        note: { type: noteType, content },
      }
    )
    // API returns updated lesson — replace lesson state with response data
    if (response.data?.lesson) {
      lesson.value = response.data.lesson
    }
    handleNext()
  } catch (err) {
    console.error('[LessonActivity] submitNote failed:', err)
  } finally {
    isSaving.value = false
  }
}

async function saveVideoProgress(activityId: string, progress: number) {
  try {
    await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/video-progress`,
      { progress }
    )
  } catch (err) {
    console.error('[LessonActivity] saveVideoProgress failed:', err)
  }
}

async function visitExegesisHighlight(activityId: string, highlightId: string) {
  try {
    await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/exegesis-visit`,
      {
        lessonScheduleId: props.lessonScheduleId,
        highlightId,
      }
    )
  } catch (err) {
    console.error('[LessonActivity] visitExegesisHighlight failed:', err)
  }
}
</script>

<template>
  <div
    class="LessonActivity"
    :class="{ 'LessonActivity--read-fullscreen': isReadStep }"
  >

    <!-- Fixed Header (hidden in single-activity mode) -->
    <div v-if="!singleActivity" class="LessonActivity__header">
      <!-- Progress Bar -->
      <div class="LessonActivity__step-indicator">
        <div class="LessonActivity__progress-bar">
          <div
            class="LessonActivity__progress-fill"
            :style="{ width: progressPercent + '%' }"
          />
        </div>
      </div>

      <!-- Page Header (Back / Next navigation row) -->
      <div class="LessonActivity__page-header">
        <div class="LessonPageHeader LessonPageHeader--theme-dark">
          <div class="LessonPageHeader__left">
            <button
              v-if="!isCompleteStep"
              class="LessonPageHeader__nav-button LessonPageHeader__nav-button--prev"
              type="button"
              @click="handleBack"
            >
              <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="15 18 9 12 15 6" />
              </svg>
              <span class="LessonPageHeader__nav-label">Prev</span>
            </button>
          </div>

          <div class="LessonPageHeader__right">
            <button
              v-if="!isCompleteStep"
              :class="[
                'LessonPageHeader__nav-button',
                'LessonPageHeader__nav-button--next',
                nextDisabled && 'LessonPageHeader__nav-button--disabled',
              ]"
              :disabled="nextDisabled"
              type="button"
              @click="handleNext"
            >
              <span class="LessonPageHeader__nav-label">{{ nextLabel }}</span>
              <svg v-if="nextLabel === 'Finish' && !nextDisabled" class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12" />
              </svg>
              <svg v-else class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Lesson title — rendered below the back/next row. Hidden on video
           steps where the player itself is the content. -->
      <h1 v-if="!isVideoStep && !hideTitle" class="LessonActivity__title">{{ lessonTitle }}</h1>
    </div>

    <!-- Content Area -->
    <div class="LessonActivity__content">

      <div v-if="isLoading" class="LessonActivity LessonActivity--loading">
        Loading...
      </div>

      <template v-else-if="currentStep">

        <!-- VIDEO step -->
        <VideoStep
          v-if="currentStep.type === 'video' && currentStep.activity"
          :key="currentStepNumber"
          :activity="currentStep.activity"
          @next="handleNext"
          @video-progress="saveVideoProgress"
        />

        <!-- YOUTUBE step -->
        <YoutubeStep
          v-else-if="currentStep.type === 'youtube' && currentStep.activity"
          :key="currentStepNumber"
          :activity="currentStep.activity"
          @next="handleNext"
          @video-progress="saveVideoProgress"
        />

        <!-- READ step — renders full-screen (behind the header) so theme
             backgrounds fill the whole viewport. -->
        <ReadStep
          v-else-if="currentStep.type === 'read' && currentStep.activity"
          :key="currentStepNumber"
          :activity="currentStep.activity"
          :groupId="groupId"
          :lessonScheduleId="lessonScheduleId"
          :fullScreen="!singleActivity"
          @next="handleNext"
          @complete="(val: boolean) => { readStepComplete = val }"
          @hide-title="(val: boolean) => { hideTitle = val }"
        />

        <!-- EXEGESIS step -->
        <ExegesisStep
          v-else-if="currentStep.type === 'exegesis' && currentStep.activity"
          :key="currentStepNumber"
          :activity="currentStep.activity"
          :groupId="groupId"
          :lessonScheduleId="lessonScheduleId"
          :fullScreen="!singleActivity"
          :initialHighlightIndex="currentStep.activity.initialHighlightIndex ?? null"
          @visit="visitExegesisHighlight"
          @complete="(val: boolean) => { exegesisStepComplete = val }"
          @hide-title="(val: boolean) => { hideTitle = val }"
        />

        <!-- INPUT (SOAP journal) step -->
        <InputStep
          v-else-if="currentStep.type === 'input' && currentStep.activity"
          :key="currentStepNumber"
          :activity="currentStep.activity"
          :isPreview="isPreview"
          :isSaving="isSaving"
          @submit="submitNote"
        />

        <!-- COMPLETE step -->
        <CompleteStep
          v-else-if="currentStep.type === 'complete'"
          :key="currentStepNumber"
          :groupId="groupId"
          :studyEnrollmentId="studyEnrollmentId"
          :isPreview="isPreview"
          :previewToken="previewToken"
        />

      </template>
    </div>

  </div>
</template>
