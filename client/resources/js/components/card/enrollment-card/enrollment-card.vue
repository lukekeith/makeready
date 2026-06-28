<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// EnrollmentCard — type-specific card for a member's enrollment in a study
// program (iOS EnrollmentCard parity). A horizontal row: square program cover
// on the left, then program name + days count + a status indicator, with a
// trailing chevron.
//
// Status indicator has two states (driven by `completed`):
//   active    → clock glyph + the formatted date range (brand purple)
//   completed → green check glyph + "Completed" (iOS success green)
//
// No layout variants → no CVA. Interactive: emits `click`, role=button.
//
// Fields (props):
//   title      string   — study program name (1 line, semibold)
//   days       number   — program length in days ("N days")
//   coverUrl   string?  — square program cover image; book placeholder when absent
//   dateRange  string?  — pre-formatted range for the active state (e.g. "MAY 31 - JUN 30")
//   completed  boolean  — completed vs active status indicator
interface Props {
  title: string
  days: number
  coverUrl?: string
  dateRange?: string
  completed?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  coverUrl: '',
  dateRange: '',
  completed: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() => classnames('EnrollmentCard', props.class))

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
    :class="classes"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <!-- Program cover (square 64×64) -->
    <div class="EnrollmentCard__cover">
      <img
        v-if="coverUrl"
        :src="coverUrl"
        :alt="title"
        class="EnrollmentCard__image"
      />
      <div v-else class="EnrollmentCard__placeholder" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v15H6.5a2.5 2.5 0 0 0-2.5 2.5V4.5z" opacity="0" />
          <path d="M3 4.75A2.75 2.75 0 0 1 5.75 2H12v17.5H5.75A1.25 1.25 0 0 0 4.5 20.75V22H3V4.75zM13.5 2h4.75A2.75 2.75 0 0 1 21 4.75V22h-1.5v-1.25A1.25 1.25 0 0 0 18.25 19.5H13.5V2z" />
        </svg>
      </div>
    </div>

    <!-- Program info + status -->
    <div class="EnrollmentCard__body">
      <h3 class="EnrollmentCard__title">{{ title }}</h3>
      <p class="EnrollmentCard__days">{{ days }} days</p>

      <div
        class="EnrollmentCard__status"
        :class="completed ? 'EnrollmentCard__status--completed' : 'EnrollmentCard__status--active'"
      >
        <svg
          v-if="completed"
          class="EnrollmentCard__status-icon"
          viewBox="0 0 24 24"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-1.1 14.2-4-4 1.4-1.4 2.6 2.6 5.4-5.4 1.4 1.4-6.8 6.8z" />
        </svg>
        <svg
          v-else
          class="EnrollmentCard__status-icon"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="9" />
          <path d="M12 7v5l3 2" />
        </svg>
        <span class="EnrollmentCard__status-text">{{ completed ? 'Completed' : dateRange }}</span>
      </div>
    </div>

    <!-- Trailing chevron -->
    <span class="EnrollmentCard__chevron" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="m9 6 6 6-6 6" />
      </svg>
    </span>
  </div>
</template>
