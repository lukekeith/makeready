<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import BulletTextInput from '../../../primitive/bullet-text-input/bullet-text-input.vue'
import { useLessonState } from '../use-lesson-state'

interface Note {
  content?: string
}

interface Activity {
  id: string
  type: string
  title?: string
  isHelpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  helpAlwaysVisible?: boolean
  helpIcon?: string
  helpText?: string
  noteType?: string
  placeholder?: string
  note?: Note
}

interface Props {
  activity: Activity
  isPreview?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  isPreview: false,
})

// Pre-populate with existing note content if available
const noteContent = ref(props.activity.note?.content ?? '')

// Derive noteType from activity.noteType or from helpTitle
const noteType = computed(() => {
  if (props.activity.noteType) return props.activity.noteType
  if (props.activity.helpTitle) {
    return props.activity.helpTitle.toUpperCase().replace(/\s+/g, '_')
  }
  return 'NOTE'
})

const lessonState = useLessonState()

const hasHelp = computed<boolean>(() => {
  return Boolean(
    props.activity.isHelpEnabled &&
    (props.activity.helpTitle || props.activity.helpDescription)
  )
})

/** True once the user has typed meaningful content (whitespace-only doesn't count). */
const hasContent = computed(() => noteContent.value.trim().length > 0)

// Track what has been saved to avoid redundant saves
const lastSavedContent = ref(props.activity.note?.content ?? '')
const isDirty = computed(() => noteContent.value !== lastSavedContent.value && hasContent.value)

// ─── Debounced auto-save ──────────────────────────────────────────────────────

let debounceTimer: ReturnType<typeof setTimeout> | null = null

async function flushSave() {
  if (debounceTimer) {
    clearTimeout(debounceTimer)
    debounceTimer = null
  }
  if (!isDirty.value || !lessonState.saveNote) return
  try {
    await lessonState.saveNote(props.activity.id, noteType.value, noteContent.value)
    lastSavedContent.value = noteContent.value
  } catch (err) {
    console.error('[InputStep] auto-save failed:', err)
  }
}

function scheduleSave() {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(flushSave, 1000)
}

watch(noteContent, () => {
  if (props.isPreview || !lessonState.saveNote) return
  scheduleSave()
})

onUnmounted(() => {
  if (debounceTimer) clearTimeout(debounceTimer)
})

// ─── Progress + before-navigate hook ──────────────────────────────────────────

onMounted(() => {
  lessonState.reportProgress(
    hasContent.value ? 'Continue' : 'Write your response',
    hasContent.value
  )
  lessonState.registerBeforeNavigate(flushSave)
})

watch(hasContent, (has) => {
  lessonState.reportProgress(
    has ? 'Continue' : 'Write your response',
    has
  )
})

function toggleContext() {
  lessonState.contextCollapsed.value = !lessonState.contextCollapsed.value
}
</script>

<template>
  <div class="LessonActivity__input-step">
    <!-- Activity title -->
    <h3 v-if="activity.title" class="LessonActivity__input-step-title">
      {{ activity.title }}
    </h3>

    <!-- Collapsible context help -->
    <div v-if="hasHelp" class="LessonActivity__context" :class="{ 'LessonActivity__context--collapsed': lessonState.contextCollapsed.value }" @click="toggleContext">
      <div class="LessonActivity__context-header">
        <span class="LessonActivity__context-title">
          {{ activity.helpTitle || 'Help' }}
        </span>
        <button type="button" class="LessonActivity__context-toggle" :class="{ 'LessonActivity__context-toggle--collapsed': lessonState.contextCollapsed.value }">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <polyline
              points="6 15 12 9 18 15"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
      <div class="LessonActivity__context-body" :class="{ 'LessonActivity__context-body--collapsed': lessonState.contextCollapsed.value }">
        <p v-if="activity.helpDescription" class="LessonActivity__context-description">
          {{ activity.helpDescription }}
        </p>
      </div>
    </div>

    <div class="LessonActivity__input-wrap">
      <BulletTextInput
        v-model="noteContent"
        :placeholder="activity.placeholder || 'Add your thoughts...'"
        :fill="true"
        :autoFocus="false"
        class="LessonActivity__input-field"
      />
      <!-- Animated pointer arrow — below placeholder, hidden once the user starts typing -->
      <div v-if="!hasContent" class="LessonActivity__input-pointer">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
          <polyline points="6 15 12 9 18 15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </div>
    </div>
  </div>
</template>

<style scoped>
.LessonActivity__input-step-title {
  margin: 0;
  font-family: "SF Pro Text", -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 17px;
  font-weight: 600;
  line-height: 22px;
  color: white;
  text-align: center;
}

/* ─── Collapsible context ────────────────────────────────────────────────── */

.LessonActivity__context {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.1);
  user-select: none;
  cursor: pointer;
  transition: gap 300ms ease;
}

.LessonActivity__context--collapsed {
  gap: 0;
}

.LessonActivity__context-header {
  display: flex;
  align-items: center;
  gap: 8px;
}

.LessonActivity__context-title {
  flex: 1;
  font-family: "SF Pro Text", -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 13px;
  font-weight: 700;
  line-height: 18px;
  color: white;
}

.LessonActivity__context-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  border: none;
  border-radius: 32px;
  background: transparent;
  color: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  padding: 0;
  transition: transform 300ms ease;
}

.LessonActivity__context-toggle--collapsed {
  transform: rotate(180deg);
}

.LessonActivity__context-body {
  display: grid;
  grid-template-rows: 1fr;
  transition: grid-template-rows 300ms ease, opacity 300ms ease;
  opacity: 1;
  overflow: hidden;
}

.LessonActivity__context-body--collapsed {
  grid-template-rows: 0fr;
  opacity: 0;
}

.LessonActivity__context-body > p {
  min-height: 0;
  overflow: hidden;
}

.LessonActivity__context-description {
  margin: 0;
  font-family: "SF Pro Text", -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 13px;
  font-weight: 400;
  line-height: 18px;
  color: rgba(255, 255, 255, 0.7);
  white-space: pre-wrap;
}

/* ─── Input wrap ─────────────────────────────────────────────────────────── */

.LessonActivity__input-wrap {
  position: relative;
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.LessonActivity__input-field {
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 8px;
}

.LessonActivity__input-pointer {
  position: absolute;
  top: 46px;
  left: 16px;
  color: #6c47ff;
  animation: input-pointer-bounce 4s ease-in-out infinite;
  pointer-events: none;
  z-index: 1;
}

@keyframes input-pointer-bounce {
  0%, 100% {
    transform: translateY(8px);
  }
  50% {
    transform: translateY(0);
  }
}
</style>
