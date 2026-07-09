<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
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

// AI completion summary — generated server-side from the lesson content and
// the member's input. memberSummary is null when the member entered nothing
// substantive; fall back to the lesson recap so the block still has value.
const summaryLoading = ref(false)
const summaryText = ref<string | null>(null)
const summaryTitle = ref('What you learned')

const summaryParagraphs = computed(() =>
  summaryText.value
    ? summaryText.value.split(/\n{2,}/).map((p) => p.trim()).filter(Boolean)
    : []
)

function applySummary(summary: { lessonSummary?: string | null; memberSummary?: string | null }) {
  if (summary.memberSummary) {
    summaryTitle.value = 'What you learned'
    summaryText.value = summary.memberSummary
  } else if (summary.lessonSummary) {
    summaryTitle.value = 'Lesson recap'
    summaryText.value = summary.lessonSummary
  }
}

async function fetchSummary(attempt = 0) {
  summaryLoading.value = true
  try {
    const { data } = await axios.get(
      `/member/groups/${props.groupId}/lessons/${props.lessonScheduleId}/summary`
    )
    if (data?.summary) {
      applySummary(data.summary)
    }
    summaryLoading.value = false
  } catch (err: any) {
    // 409 = the final activity's completion hasn't landed yet — retry once
    if (err?.response?.status === 409 && attempt === 0) {
      setTimeout(() => fetchSummary(1), 2000)
      return
    }
    // Any other failure: hide the block silently — completion must still feel done
    summaryLoading.value = false
  }
}

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

  // Capture/preview fixtures preload the summary through the lesson data;
  // real members fetch it from the summary endpoint.
  const preloaded = lessonState.lesson.value?.aiSummary
  if (preloaded) {
    applySummary(preloaded)
    return
  }

  // Preview lessons have no member input to summarize
  if (!props.isPreview && !props.groupId.startsWith('pvw-') && props.lessonScheduleId) {
    fetchSummary()
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
      </ConfirmationMessage>

      <div v-if="summaryLoading" class="LessonActivity__ai-summary-loading">
        Summarizing your lesson…
      </div>
      <div v-else-if="summaryParagraphs.length" class="LessonActivity__ai-summary">
        <div class="LessonActivity__ai-summary-title">{{ summaryTitle }}</div>
        <div class="LessonActivity__ai-summary-text">
          <p v-for="(paragraph, index) in summaryParagraphs" :key="index">{{ paragraph }}</p>
        </div>
      </div>

      <a v-if="groupHomeHref" class="ConfirmationMessage__action" :href="groupHomeHref">
        Return to Group Home
      </a>
    </div>
  </div>
</template>
