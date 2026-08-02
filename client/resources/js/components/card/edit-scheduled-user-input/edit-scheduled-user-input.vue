<script setup lang="ts">
import { ref } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import MultilineTextInput from '../multiline-text-input/multiline-text-input.vue'
import ToggleControl from '../toggle-control/toggle-control.vue'
import BoxButton from '../box-button/box-button.vue'

// EditScheduledUserInput — web twin of the iPhone SCHEDULED Write-activity
// editor (private EditScheduledUserInputView inside
// Pages/Manage/Group/Enrollment/EditEnrollmentDay.swift:947-1064), the inner
// SlideStack detail for USER_INPUT scheduled activities. It is deliberately
// simpler than the program editor (EditUserInputActivity): no Placeholder
// field, no tri-state header (right link is ALWAYS "Save"), short toggle
// copy, and the help description sits under an uppercase section label.
//
// Layout (iOS ScrollView → VStack spacing 16, top pad 16, sections H16):
//   • PageTitle.iconTitleLink — chevron.left / "Edit Activity" / "Save"
//   • FieldGroup { TextInput floating "Activity title" }
//   • ToggleGroup { ToggleControl "Show help" + short description }
//   • when help enabled: FieldGroup { TextInput "Help title" } then a
//     labeled section — "HELP DESCRIPTION" (s13Semibold white@0.5 uppercase)
//     over MultilineTextInput placeholder "Help description"
//   • BoxButton "Preview" (eye right) — iOS shows it when programId exists
//   • 16px bottom spacer
//
// The iOS view is private @State-gated, so the compare is WEB-ONLY.

interface Props {
  title?: string
  /** iOS seeds this as helpTitle != nil || helpDescription != nil. */
  helpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  /** iOS shows Preview when programId != nil (production passes false —
   *  scheduled activity previews have no working endpoint yet). */
  showPreview?: boolean
  /** Production: inputs become editable. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar. Production never passes it.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  helpEnabled: false,
  helpTitle: '',
  helpDescription: '',
  showPreview: true,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  cancel: []
  save: [fields: {
    title: string
    isHelpEnabled: boolean
    helpTitle: string
    helpDescription: string
  }]
  preview: []
}>()

// Local editable state seeded from props (iOS onAppear snapshot).
const title = ref(props.title)
const helpEnabled = ref(props.helpEnabled)
const helpTitle = ref(props.helpTitle)
const helpDescription = ref(props.helpDescription)

function save(): void {
  emit('save', {
    title: title.value.trim(),
    isHelpEnabled: helpEnabled.value,
    helpTitle: helpTitle.value.trim(),
    helpDescription: helpDescription.value.trim(),
  })
}

const CHEV_LEFT =
  '<svg viewBox="0 0 10 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 1L1 9l8 8"/></svg>'
// SF "eye" — Preview button glyph.
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
</script>

<template>
  <div :class="['EditScheduledUserInput', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditScheduledUserInput__statusbar" aria-hidden="true">
      <span class="EditScheduledUserInput__clock">9:41</span>
      <span class="EditScheduledUserInput__indicators">
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
      :left-icon="CHEV_LEFT"
      right-link="Save"
      @left="emit('cancel')"
      @right="save"
    />

    <div class="EditScheduledUserInput__scroll">
      <div class="EditScheduledUserInput__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive"
            floating-label="Activity title"
            :text="title"
            @update:text="title = $event"
          />
        </div>
      </div>

      <div class="EditScheduledUserInput__section">
        <ToggleControl
          title="Show help"
          description="Display a help section for this activity"
          :is-on="helpEnabled"
          @toggle="helpEnabled = !helpEnabled"
        />
      </div>

      <template v-if="helpEnabled">
        <div class="EditScheduledUserInput__section">
          <div class="FieldGroup">
            <TextInput
              :interactive="props.interactive"
              floating-label="Help title"
              :text="helpTitle"
              @update:text="helpTitle = $event"
            />
          </div>
        </div>

        <div class="EditScheduledUserInput__section">
          <div class="EditScheduledUserInput__labelBlock">
            <div class="EditScheduledUserInput__sectionLabel">Help description</div>
            <MultilineTextInput
              :interactive="props.interactive"
              placeholder="Help description"
              :text="helpDescription"
              @update:text="helpDescription = $event"
            />
          </div>
        </div>
      </template>

      <div v-if="props.showPreview" class="EditScheduledUserInput__section">
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

      <div class="EditScheduledUserInput__bottomSpacer"></div>
    </div>
  </div>
</template>
