<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import MultilineTextInput from '../multiline-text-input/multiline-text-input.vue'
import ToggleControl from '../toggle-control/toggle-control.vue'
import BoxButton from '../box-button/box-button.vue'

// EditUserInputActivity — web twin of the iPhone Write-activity editor
// (Pages/Manage/Program/EditUserInputActivityPage.swift, a nested SlideStack
// detail inside EditDay). Data-driven and shared by BOTH the capture compare
// harness (inert, props seed the form) and the production pane (interactive
// + emits).
//
// Layout (iOS ScrollView → VStack spacing 20, top pad 16, sections H16,
// scroll clipped radius 16):
//   • PageTitle.linkTitleLink — Cancel / "Edit Activity" /
//     Saving... | Save (has changes) | Done
//   • FieldGroup { TextInput floating "Activity title" ÷
//     TextInput floating "Placeholder text" }
//   • ToggleGroup { ToggleControl "Enable context help" + long description }
//   • when help enabled: FieldGroup { TextInput "Help title" ÷
//     MultilineTextInput "Help description" (minHeight 130) }
//   • BoxButton "Preview" (eye right, secondary solid lg fullWidth)
//   • 16px bottom spacer
//
// iOS seeds the title field with activity.title ?? type.displayName ("Study"
// for USER_INPUT) — adapters/wrappers pass the resolved value; the twin
// renders exactly what it's given.

interface Props {
  title?: string
  placeholder?: string
  helpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  saving?: boolean
  /** iOS shows Preview only when programId is present (always, in captures). */
  showPreview?: boolean
  /** Production: inputs become editable. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar (the iPhone reference
  // includes the simulator's). Production never passes this.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  placeholder: '',
  helpEnabled: false,
  helpTitle: '',
  helpDescription: '',
  saving: false,
  showPreview: true,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  cancel: []
  save: [fields: {
    title: string
    placeholder: string
    isHelpEnabled: boolean
    helpTitle: string
    helpDescription: string
  }]
  preview: []
}>()

// Local editable state seeded from props (iOS onAppear snapshot).
const title = ref(props.title)
const placeholder = ref(props.placeholder)
const helpEnabled = ref(props.helpEnabled)
const helpTitle = ref(props.helpTitle)
const helpDescription = ref(props.helpDescription)
watch(() => props.title, (v) => { title.value = v })

// iOS hasChanges — flips the right link Done → Save.
const hasChanges = computed(() =>
  title.value !== props.title ||
  placeholder.value !== props.placeholder ||
  helpEnabled.value !== props.helpEnabled ||
  helpTitle.value !== props.helpTitle ||
  helpDescription.value !== props.helpDescription,
)

const rightLink = computed(() =>
  props.saving ? 'Saving...' : hasChanges.value ? 'Save' : 'Done',
)

function save(): void {
  if (props.saving) return
  emit('save', {
    title: title.value.trim(),
    placeholder: placeholder.value.trim(),
    isHelpEnabled: helpEnabled.value,
    helpTitle: helpTitle.value.trim(),
    helpDescription: helpDescription.value.trim(),
  })
}

// SF "eye" — Preview button glyph.
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
</script>

<template>
  <div :class="['EditUserInputActivity', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditUserInputActivity__statusbar" aria-hidden="true">
      <span class="EditUserInputActivity__clock">9:41</span>
      <span class="EditUserInputActivity__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <PageTitle
      title="Edit Activity"
      left-link="Cancel"
      :right-link="rightLink"
      @left="emit('cancel')"
      @right="save"
    />

    <div class="EditUserInputActivity__scroll">
      <div class="EditUserInputActivity__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive"
            floating-label="Activity title"
            :text="title"
            @update:text="title = $event"
          />
          <div class="FieldGroup__divider" aria-hidden="true"></div>
          <TextInput
            :interactive="props.interactive"
            floating-label="Placeholder text"
            :text="placeholder"
            @update:text="placeholder = $event"
          />
        </div>
      </div>

      <div class="EditUserInputActivity__section">
        <ToggleControl
          title="Enable context help"
          description="Enabling this feature provides a helpful link on the lesson activity designed to provide additional context or help to the member who is completing the activity."
          :is-on="helpEnabled"
          @toggle="helpEnabled = !helpEnabled"
        />
      </div>

      <div v-if="helpEnabled" class="EditUserInputActivity__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive"
            floating-label="Help title"
            :text="helpTitle"
            @update:text="helpTitle = $event"
          />
          <div class="FieldGroup__divider" aria-hidden="true"></div>
          <MultilineTextInput
            :interactive="props.interactive"
            placeholder="Help description"
            :text="helpDescription"
            @update:text="helpDescription = $event"
          />
        </div>
      </div>

      <div v-if="props.showPreview" class="EditUserInputActivity__section">
        <BoxButton
          label="Preview"
          :icon="EYE"
          icon-position="right"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="emit('preview')"
        />
      </div>

      <div class="EditUserInputActivity__bottomSpacer"></div>
    </div>
  </div>
</template>
