<script setup lang="ts">
import { onMounted } from 'vue'
import { useLessonState } from '../use-lesson-state'

interface Props {
  groupId: string
  studyEnrollmentId?: string
  isPreview?: boolean
  previewToken?: string
}

const props = withDefaults(defineProps<Props>(), {
  isPreview: false,
  studyEnrollmentId: '',
  previewToken: '',
})

const lessonState = useLessonState()

onMounted(() => {
  lessonState.reportProgress('', true)
})

const studyHomeHref = props.isPreview && props.previewToken
  ? `/public/preview/${props.previewToken}`
  : props.studyEnrollmentId
    ? `/member/groups/${props.groupId}/study/${props.studyEnrollmentId}`
    : `/member/groups/${props.groupId}`
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

    <div class="LessonActivity__complete-action">
      <a
        :href="studyHomeHref"
        style="
          display: block;
          background: #ffffff;
          color: #0d101a;
          border: none;
          border-radius: 8px;
          padding: 14px 32px;
          font-size: 15px;
          font-weight: 600;
          text-decoration: none;
          text-align: center;
          cursor: pointer;
          width: 100%;
        "
      >
        Back to Study
      </a>
    </div>
  </div>
</template>
