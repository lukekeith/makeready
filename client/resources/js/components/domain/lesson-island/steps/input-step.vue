<script setup lang="ts">
import { ref, computed } from 'vue'
import BulletTextInput from '../../../primitive/bullet-text-input/bullet-text-input.vue'
import Modal from '../../../primitive/modal/modal.vue'

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

// ─── Context help ─────────────────────────────────────────────────────────────
// iPhone stores SF Symbol names (e.g. "lightbulb.fill"); map the fixed set of
// allowed values to inline SVGs so the web preview renders the same glyph.
const SYMBOL_PATHS: Record<string, string> = {
  'lightbulb.fill': 'M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.2 1 2V17h6v-.3c0-.8.4-1.5 1-2A7 7 0 0 0 12 2z',
  'questionmark.circle.fill': 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 15.5a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm1.7-6.3c-.7.5-1 .8-1 1.5v.3h-1.4v-.4c0-1.1.5-1.7 1.3-2.3.7-.5 1.1-.9 1.1-1.6 0-.8-.6-1.3-1.5-1.3-.9 0-1.6.5-1.7 1.5H9.1c0-1.8 1.3-2.9 3.1-2.9 1.9 0 3 1 3 2.6 0 1.2-.6 1.9-1.5 2.6z',
  'pencil': 'M3 17.25V21h3.75L17.8 9.95l-3.75-3.75L3 17.25zM20.7 7.05a1 1 0 0 0 0-1.4l-2.35-2.35a1 1 0 0 0-1.4 0l-1.84 1.83 3.75 3.75 1.84-1.83z',
  'book.fill': 'M4 4a2 2 0 0 1 2-2h12v18H6a2 2 0 0 0-2 2V4zm2 16h12v2H6a2 2 0 0 1 0-4h12V4H6a2 2 0 0 0 0 0v16z',
  'text.cursor': 'M8 4h3v2H9v12h2v2H8a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zm8 0a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3v-2h2V6h-2V4h3z',
  'hand.raised.fill': 'M7 11V5a1.5 1.5 0 0 1 3 0v5h1V4a1.5 1.5 0 0 1 3 0v7h1V5.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-7 7 7 7 0 0 1-7-7V9a1.5 1.5 0 0 1 3 0v2z',
  'heart.fill': 'M12 21s-7-4.5-9.5-9A5.5 5.5 0 0 1 12 6a5.5 5.5 0 0 1 9.5 6C19 16.5 12 21 12 21z',
  'eye.fill': 'M12 5c-7 0-11 7-11 7s4 7 11 7 11-7 11-7-4-7-11-7zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8z',
  'star.fill': 'M12 2l3 7 7.5.6-5.7 5 1.7 7.4L12 18l-6.5 4 1.7-7.4L1.5 9.6 9 9l3-7z',
  'bolt.fill': 'M13 2L4 14h6l-1 8 9-12h-6l1-8z',
  'flame.fill': 'M12 2s-5 6-5 11a5 5 0 0 0 10 0c0-2-1-3-2-4 0 2-1 3-2 3 0-3 1-6-1-10zm0 16a3 3 0 1 1 0-6 3 3 0 0 1 0 6z',
  'leaf.fill': 'M17 3C9 3 4 9 4 16c0 2 1 4 2 5 6-1 12-7 13-14 0-2 0-3-2-4zM6 20l6-6',
}

const hasHelp = computed<boolean>(() => {
  return Boolean(
    props.activity.isHelpEnabled &&
    (props.activity.helpTitle || props.activity.helpDescription)
  )
})

const helpIconPath = computed<string>(() => {
  const key = props.activity.helpIcon
  if (key && SYMBOL_PATHS[key]) return SYMBOL_PATHS[key]
  return SYMBOL_PATHS['questionmark.circle.fill']
})

const showHelpModal = ref(false)

function openHelp() {
  showHelpModal.value = true
}
function closeHelp() {
  showHelpModal.value = false
}

/** True once the user has typed meaningful content (whitespace-only doesn't
 *  count). Drives the Save button's disabled + visual state. */
const hasContent = computed(() => noteContent.value.trim().length > 0)

/** Style maps for the Save button. Kept inline (rather than hoisted into
 *  the SCSS layer) to match the file's existing inline-style approach for
 *  this one-off step component. */
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
    <!-- Always-visible context: title + description rendered inline -->
    <div v-if="hasHelp && activity.helpAlwaysVisible" class="LessonActivity__help-inline">
      <span class="LessonActivity__help-inline-title">
        {{ activity.helpTitle || 'Help' }}
      </span>
      <p v-if="activity.helpDescription" class="LessonActivity__help-inline-description">
        {{ activity.helpDescription }}
      </p>
    </div>

    <!-- Tap-to-modal context: title row opens fullscreen modal -->
    <button
      v-else-if="hasHelp"
      type="button"
      class="LessonActivity__help-row"
      @click="openHelp"
    >
      <svg
        class="LessonActivity__help-row-icon"
        viewBox="0 0 24 24"
        width="18"
        height="18"
        fill="currentColor"
        aria-hidden="true"
      >
        <path :d="helpIconPath" />
      </svg>
      <span class="LessonActivity__help-row-title">
        {{ activity.helpTitle || 'Help' }}
      </span>
    </button>

    <BulletTextInput
      v-model="noteContent"
      :placeholder="`Add your thoughts...`"
      :fill="true"
      :autoFocus="false"
    />

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

    <Modal
      v-if="!activity.helpAlwaysVisible"
      :isOpen="showHelpModal"
      mode="Fullscreen"
      :ariaTitle="activity.helpTitle || 'Help'"
      @close="closeHelp"
    >
      <div class="LessonActivity__help-modal-body">
        <h2 class="LessonActivity__help-modal-title">
          {{ activity.helpTitle || 'Help' }}
        </h2>
        <p
          v-if="activity.helpDescription"
          class="LessonActivity__help-modal-description"
        >
          {{ activity.helpDescription }}
        </p>
      </div>
    </Modal>
  </div>
</template>

<style scoped>
.LessonActivity__help-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 12px 0;
  background: transparent;
  border: none;
  color: rgba(255, 255, 255, 0.85);
  font-size: 14px;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
}
.LessonActivity__help-row-icon {
  color: #6c47ff;
  flex-shrink: 0;
}
.LessonActivity__help-row-title {
  flex: 1;
}

.LessonActivity__help-inline {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px;
  border-radius: 4px;
  background: rgba(108, 71, 255, 0.2);
}
.LessonActivity__help-inline-title {
  font-size: 14px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.85);
}
.LessonActivity__help-inline-description {
  margin: 0;
  font-size: 15px;
  line-height: 1.5;
  color: rgba(255, 255, 255, 0.7);
  white-space: pre-wrap;
}

.LessonActivity__help-modal-body {
  padding: 24px 8px 0;
  color: #fff;
  text-align: left;
}
.LessonActivity__help-modal-title {
  margin: 0 0 12px;
  font-size: 20px;
  font-weight: 600;
  line-height: 1.3;
}
.LessonActivity__help-modal-description {
  margin: 0;
  font-size: 15px;
  line-height: 1.5;
  color: rgba(255, 255, 255, 0.85);
  white-space: pre-wrap;
}
</style>
