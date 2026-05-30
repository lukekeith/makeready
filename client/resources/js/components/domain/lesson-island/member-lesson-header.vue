<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useLessonState } from './use-lesson-state'
import './member-lesson-header.scss'

const state = useLessonState()
const rootEl = ref<HTMLElement | null>(null)
let resizeObserver: ResizeObserver | null = null

onMounted(() => {
  if (!rootEl.value) return
  resizeObserver = new ResizeObserver(([entry]) => {
    const h = Math.round(entry.borderBoxSize?.[0]?.blockSize ?? entry.contentRect.height)
    document.body.style.setProperty('--member-lesson-header', `${h}px`)
  })
  resizeObserver.observe(rootEl.value)
})

onUnmounted(() => {
  resizeObserver?.disconnect()
  document.body.style.removeProperty('--member-lesson-header')
})

const hasMessage = computed(() => state.message.value.length > 0)

const isCollapsed = computed(() => {
  // Alert temporarily overrides collapsed state to show the message
  if (state.messageAlert.value) return false
  return state.messageCollapsed.value
})

const studyTitle = computed(() => state.lesson.value?.studyProgram?.name ?? '')
const dayNumber = computed(() => state.lesson.value?.dayNumber ?? null)

function toggleCollapse() {
  state.messageCollapsed.value = !state.messageCollapsed.value
}
</script>

<template>
  <div ref="rootEl" class="MemberLessonHeader">
    <div class="MemberLessonHeader__container">

      <!-- Title bar -->
      <div class="MemberLessonHeader__title-bar">
        <button
          class="MemberLessonHeader__btn MemberLessonHeader__btn--icon"
          type="button"
          @click="state.handleExit"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <path d="M1 3h14M1 8h14M1 13h14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
          </svg>
        </button>

        <div class="MemberLessonHeader__title">
          <span class="MemberLessonHeader__title-study">{{ studyTitle }}</span>
          <span v-if="dayNumber" class="MemberLessonHeader__title-day">Day {{ dayNumber }}</span>
        </div>

        <button
          v-if="hasMessage"
          class="MemberLessonHeader__btn MemberLessonHeader__btn--icon"
          :class="{ 'MemberLessonHeader__btn--icon-dim': !isCollapsed }"
          type="button"
          @click="toggleCollapse"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 15.5a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm1.7-6.3c-.7.5-1 .8-1 1.5v.3h-1.4v-.4c0-1.1.5-1.7 1.3-2.3.7-.5 1.1-.9 1.1-1.6 0-.8-.6-1.3-1.5-1.3-.9 0-1.6.5-1.7 1.5H9.1c0-1.8 1.3-2.9 3.1-2.9 1.9 0 3 1 3 2.6 0 1.2-.6 1.9-1.5 2.6z"/>
          </svg>
        </button>
        <!-- Invisible spacer when no message to keep title centered -->
        <div v-else class="MemberLessonHeader__btn MemberLessonHeader__btn--spacer" />
      </div>

      <!-- Navigation pill -->
      <div
        class="MemberLessonHeader__nav"
        :class="{ 'MemberLessonHeader__nav--ready': state.canProceed.value }"
      >
        <div class="MemberLessonHeader__nav-bg" />

        <button
          class="MemberLessonHeader__btn MemberLessonHeader__btn--nav"
          :class="{ 'MemberLessonHeader__btn--disabled': state.isFirstStep.value }"
          :disabled="state.isFirstStep.value"
          type="button"
          @click="state.handleBack"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <polyline points="15 18 9 12 15 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>

        <!-- Progress bar -->
        <div class="MemberLessonHeader__progress">
          <div class="MemberLessonHeader__progress-track">
            <div
              class="MemberLessonHeader__progress-fill"
              :style="{ width: state.progressPercent.value + '%' }"
            />
          </div>
        </div>

        <!-- Next chevron -->
        <button
          class="MemberLessonHeader__btn MemberLessonHeader__btn--nav MemberLessonHeader__btn--next"
          :class="{ 'MemberLessonHeader__btn--active': state.canProceed.value }"
          type="button"
          @click="state.tryNext"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <polyline points="9 18 15 12 9 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>
      </div>

      <!-- Message row — animated show/hide via grid-template-rows -->
      <div
        v-if="hasMessage"
        class="MemberLessonHeader__message-wrap"
        :class="{ 'MemberLessonHeader__message-wrap--collapsed': isCollapsed }"
      >
        <div
          class="MemberLessonHeader__message"
          :class="{ 'MemberLessonHeader__message--alert': state.messageAlert.value }"
          @click="toggleCollapse"
        >
          <span class="MemberLessonHeader__message-text">
            {{ state.message.value }}
          </span>
        </div>
      </div>

    </div>
  </div>
</template>
