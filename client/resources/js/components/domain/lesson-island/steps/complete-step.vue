<script setup lang="ts">
import { onMounted } from 'vue'
import axios from 'axios'
import { useLessonState } from '../use-lesson-state'

// Props are still declared so the parent's bindings don't fall through as DOM
// attributes, but the complete step no longer renders its own action — the user
// exits via the header's next chevron or hamburger (both call handleExit).
interface Props {
  groupId: string
  lessonScheduleId?: string
  studyEnrollmentId?: string
  isPreview?: boolean
  previewToken?: string
}

const props = withDefaults(defineProps<Props>(), {
  lessonScheduleId: '',
  isPreview: false,
  studyEnrollmentId: '',
  previewToken: '',
})

const lessonState = useLessonState()

onMounted(() => {
  lessonState.reportProgress('', true)

  // In the synthetic preview walkthrough (pvw- routes), record a lesson-level
  // completion so the study overview reflects it. Preview has no member
  // progress and READ steps persist nothing, so this is the only reliable
  // whole-lesson signal. Real member completion is already tracked per-activity.
  if (props.groupId.startsWith('pvw-') && props.lessonScheduleId) {
    axios
      .post(`/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/complete`, {})
      .catch((err) => console.error('[CompleteStep] failed to save preview completion:', err))
  }
})
</script>

<template>
  <div class="LessonActivity__complete-step">
    <div class="LessonActivity__complete-content">
      <div style="display: flex; flex-direction: column; align-items: center; gap: 24px; text-align: center;">
        <div style="width: 64px; height: 64px; background: rgba(255,255,255,0.08); border-radius: 50%; display: flex; align-items: center; justify-content: center;">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>

        <h2 style="font-size: 24px; font-weight: 700; color: #fff; margin: 0;">
          Lesson Complete!
        </h2>

        <p style="font-size: 15px; color: rgba(255,255,255,0.6); line-height: 1.5; margin: 0; max-width: 280px;">
          Great work! You've finished this lesson.
        </p>
      </div>
    </div>
  </div>
</template>
