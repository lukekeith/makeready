<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
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
  isSaving?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  isPreview: false,
  isSaving: false,
})

const emit = defineEmits<{
  submit: [activityId: string, noteType: string, content: string]
}>()

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

/** True once the user has typed meaningful content (whitespace-only doesn't
 *  count). Drives the Save button's disabled + visual state. */
const hasContent = computed(() => noteContent.value.trim().length > 0)

// Report progress to lesson state
onMounted(() => {
  lessonState.reportProgress('Write your response', false)
})

watch(hasContent, (has) => {
  lessonState.reportProgress(
    has ? 'Submit your response' : 'Write your response',
    false // canProceed stays false until submitted — submit auto-advances
  )
})

function toggleContext() {
  lessonState.contextCollapsed.value = !lessonState.contextCollapsed.value
}

const baseButtonStyle = `
  border: none;
  border-radius: 8px;
  padding: 14px 24px;
  font-size: 15px;
  font-weight: 600;
  width: 100%;
  transition: background 150ms ease, color 150ms ease;
`
const activeStyle = `${baseButtonStyle} background: #6c47ff; color: #ffffff; cursor: pointer;`
const mutedStyle  = `${baseButtonStyle} background: rgba(255, 255, 255, 0.08); color: rgba(255, 255, 255, 0.35); cursor: not-allowed;`

function handleSave() {
  if (props.isPreview || props.isSaving || !hasContent.value) return
  emit('submit', props.activity.id, noteType.value, noteContent.value)
}
</script>

<template>
  <div class="LessonActivity__input-step">
    <!-- Activity title -->
    <h3 v-if="activity.title" class="LessonActivity__input-step-title">
      {{ activity.title }}
    </h3>

    <!-- Collapsible context help -->
    <div v-if="hasHelp" class="LessonActivity__context" :class="{ 'LessonActivity__context--collapsed': lessonState.contextCollapsed.value }">
      <div class="LessonActivity__context-header" @click="toggleContext">
        <span class="LessonActivity__context-title">
          {{ activity.helpTitle || 'Help' }}
        </span>
        <button type="button" class="LessonActivity__context-toggle">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <polyline
              :points="lessonState.contextCollapsed.value ? '6 9 12 15 18 9' : '6 15 12 9 18 15'"
              stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
      <p v-if="!lessonState.contextCollapsed.value && activity.helpDescription" class="LessonActivity__context-description">
        {{ activity.helpDescription }}
      </p>
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

    <div v-if="isSaving" style="text-align: center; color: rgba(255,255,255,0.4); font-size: 14px; padding: 8px 0;">
      Saving...
    </div>

    <button
      v-else
      :style="hasContent ? activeStyle : mutedStyle"
      :disabled="!hasContent"
      @click="handleSave"
    >
      Save &amp; Continue
    </button>
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
  padding: 8px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.1);
}

.LessonActivity__context--collapsed {
  gap: 0;
}

.LessonActivity__context-header {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
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
