<script setup lang="ts">
import { computed, onMounted } from 'vue'
import axios from 'axios'
import { useLessonState } from '../use-lesson-state'
import ConfirmationMessage from '../../confirmation-message/confirmation-message.vue'

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

// Real members can jump back to their group home; preview has no group home.
const groupHomeHref = computed(() =>
  props.isPreview || props.groupId.startsWith('pvw-')
    ? null
    : `/member/groups/${props.groupId}`
)

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
      <ConfirmationMessage
        title="Lesson Complete!"
        message="Great work! You've finished this lesson."
      >
        <template #icon>
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </template>
        <template #actions>
          <a v-if="groupHomeHref" class="ConfirmationMessage__action" :href="groupHomeHref">
            Return to Group Home
          </a>
        </template>
      </ConfirmationMessage>
    </div>
  </div>
</template>
