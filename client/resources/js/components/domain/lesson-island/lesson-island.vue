<script setup lang="ts">
import axios from 'axios'
import VideoStep from './steps/video-step.vue'
import YoutubeStep from './steps/youtube-step.vue'
import ReadStep from './steps/read-step.vue'
import ExegesisStep from './steps/exegesis-step.vue'
import InputStep from './steps/input-step.vue'
import CompleteStep from './steps/complete-step.vue'
import MemberLessonHeader from './member-lesson-header.vue'
import { createLessonState, provideLessonState } from './use-lesson-state'
import type { LessonData } from './use-lesson-state'
import './lesson-island.scss'

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

const state = createLessonState({
  lessonData: props.lessonData,
  groupId: props.groupId,
  lessonScheduleId: props.lessonScheduleId,
  initialStep: props.initialStep,
  isPreview: props.isPreview,
  previewToken: props.previewToken,
  singleActivity: props.singleActivity,
  onSaveNote: props.isPreview ? undefined : async (activityId, noteType, content) => {
    await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/submit`,
      { lessonScheduleId: props.lessonScheduleId, note: { type: noteType, content } }
    )
    state.updateActivityState(activityId, { note: { content } })
  },
  // Synthetic preview walkthrough (pvw- routes): persist per-activity completion
  // so the study overview's LessonCard cubes fill in. Real member completion is
  // tracked server-side per activity already.
  onActivityComplete: props.groupId.startsWith('pvw-')
    ? (activityId) => {
        axios
          .post(`/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/complete`, {})
          .catch((err) => console.error('[LessonActivity] failed to save preview activity completion:', err))
      }
    : undefined,
})

provideLessonState(state)

// ─── AJAX Actions ─────────────────────────────────────────────────────────────

async function saveVideoProgress(activityId: string, progress: number) {
  try {
    await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/video-progress`,
      { progress }
    )
    state.updateActivityState(activityId, {
      progress: { ...(state.lesson.value.activities?.find(a => a.id === activityId)?.progress ?? {}), completedAt: progress >= 0.9 ? new Date().toISOString() : undefined },
    })
  } catch (err) {
    console.error('[LessonActivity] saveVideoProgress failed:', err)
  }
}

// Persist completion of a non-input activity (READ/EXEGESIS) once the member
// finishes its content. USER_INPUT activities complete via note submit instead;
// VIDEO completes via video-progress. No-op in preview (pvw- handles its own).
async function markActivityComplete(activityId: string) {
  if (props.isPreview) return
  try {
    await axios.post(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/activity/${activityId}/submit`,
      { lessonScheduleId: props.lessonScheduleId, action: 'complete' }
    )
  } catch (err) {
    console.error('[LessonActivity] markActivityComplete failed:', err)
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
    const existing = state.lesson.value.activities?.find(a => a.id === activityId)?.progress?.exegesisVisitedHighlightIds ?? []
    const visited = existing.includes(highlightId) ? existing : [...existing, highlightId]
    state.updateActivityState(activityId, {
      progress: { ...(state.lesson.value.activities?.find(a => a.id === activityId)?.progress ?? {}), exegesisVisitedHighlightIds: visited },
    })
  } catch (err) {
    console.error('[LessonActivity] visitExegesisHighlight failed:', err)
  }
}
</script>

<template>
  <div
    class="LessonActivity"
    :class="{ 'LessonActivity--read-fullscreen': state.isReadStep.value }"
  >

    <!-- Fixed Header (hidden in single-activity mode) -->
    <div v-if="!singleActivity" class="LessonActivity__header">
      <MemberLessonHeader />
    </div>

    <!-- Content Area -->
    <div class="LessonActivity__content">

      <div v-if="state.isLoading.value" class="LessonActivity LessonActivity--loading">
        Loading...
      </div>

      <template v-else-if="state.currentStep.value">

        <!-- VIDEO step -->
        <VideoStep
          v-if="state.currentStep.value.type === 'video' && state.currentStep.value.activity"
          :key="state.currentStepNumber.value"
          :activity="state.currentStep.value.activity"
          @next="state.handleNext"
          @video-progress="saveVideoProgress"
        />

        <!-- YOUTUBE step -->
        <YoutubeStep
          v-else-if="state.currentStep.value.type === 'youtube' && state.currentStep.value.activity"
          :key="state.currentStepNumber.value"
          :activity="state.currentStep.value.activity"
          @next="state.handleNext"
          @video-progress="saveVideoProgress"
        />

        <!-- READ step -->
        <ReadStep
          v-else-if="state.currentStep.value.type === 'read' && state.currentStep.value.activity"
          :key="state.currentStepNumber.value"
          :activity="state.currentStep.value.activity"
          :groupId="groupId"
          :lessonScheduleId="lessonScheduleId"
          :fullScreen="!singleActivity"
          @next="state.handleNext"
          @complete="(val: boolean) => {
            if (val) {
              const act = state.currentStep.value!.activity!
              const wasComplete = !!act.progress?.completedAt
              state.updateActivityState(act.id, { progress: { ...(act.progress ?? {}), completedAt: new Date().toISOString() } })
              if (!wasComplete) markActivityComplete(act.id)
            }
            state.reportProgress(val ? 'Reading complete' : 'Continue reading', val)
          }"
          @hide-title="(val: boolean) => { state.hideTitle.value = val }"
        />

        <!-- EXEGESIS step -->
        <ExegesisStep
          v-else-if="state.currentStep.value.type === 'exegesis' && state.currentStep.value.activity"
          :key="state.currentStepNumber.value"
          :activity="state.currentStep.value.activity"
          :groupId="groupId"
          :lessonScheduleId="lessonScheduleId"
          :fullScreen="!singleActivity"
          :initialHighlightIndex="state.currentStep.value.activity.initialHighlightIndex ?? null"
          @visit="visitExegesisHighlight"
          @complete="(val: boolean) => state.reportProgress(val ? 'All highlights reviewed' : 'Tap each highlight to continue', val)"
          @hide-title="(val: boolean) => { state.hideTitle.value = val }"
        />

        <!-- INPUT (SOAP journal) step -->
        <InputStep
          v-else-if="state.currentStep.value.type === 'input' && state.currentStep.value.activity"
          :key="state.currentStepNumber.value"
          :activity="state.currentStep.value.activity"
          :isPreview="isPreview"
        />

        <!-- COMPLETE step -->
        <CompleteStep
          v-else-if="state.currentStep.value.type === 'complete'"
          :key="state.currentStepNumber.value"
          :groupId="groupId"
          :lessonScheduleId="lessonScheduleId"
          :studyEnrollmentId="state.studyEnrollmentId.value"
          :isPreview="isPreview"
          :previewToken="previewToken"
        />

      </template>
    </div>

  </div>
</template>
