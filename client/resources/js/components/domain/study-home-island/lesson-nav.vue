<script setup lang="ts">
defineProps<{
  current: number // 1-based index of selected lesson
  total: number
  canPrev: boolean
  canNext: boolean
  showJump: boolean
}>()

const emit = defineEmits<{
  (e: 'prev'): void
  (e: 'next'): void
  (e: 'jump'): void
}>()
</script>

<template>
  <div class="LessonNav">
    <button class="LessonNav__arrow" :disabled="!canPrev" aria-label="Previous lesson" @click="emit('prev')">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <path d="M15 18L9 12L15 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>

    <div class="LessonNav__center">
      <div class="LessonNav__count">
        <span class="LessonNav__count-current">{{ current }}</span>
        <span class="LessonNav__count-sep">/</span>
        <span class="LessonNav__count-total">{{ total }}</span>
        <span class="LessonNav__count-label">lessons</span>
      </div>

      <button v-if="showJump" class="LessonNav__jump" @click="emit('jump')">
        <span>Jump to next</span>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
          <path d="M5 12H19M19 12L12 5M19 12L12 19" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
    </div>

    <button class="LessonNav__arrow" :disabled="!canNext" aria-label="Next lesson" @click="emit('next')">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <path d="M9 18L15 12L9 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>
  </div>
</template>
