<script setup lang="ts">
import { computed } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import CoverImagePicker from '../cover-image-picker/cover-image-picker.vue'
import TextInput from '../text-input/text-input.vue'
import MultilineTextInput from '../multiline-text-input/multiline-text-input.vue'
import MenuInput from '../menu-input/menu-input.vue'
import ToggleControl from '../toggle-control/toggle-control.vue'
import TagInput from '../tag-input/tag-input.vue'

// CreateProgram — web twin of the iPhone Create Program form
// (Pages/Manage/Program/CreateProgramPage.swift, screen 1 of the .createProgram
// modal's internal SlideStack). Data-driven and shared by BOTH the capture
// compare harness (inert, all defaults → the empty form the iPhone
// `pages.create-program` ViewRegistry case renders) and the production modal
// (interactive + emits).
//
// Layout (iOS VStack spacing 20; fields padded H16; cover full-bleed):
//   • PageTitle.iconTitleLink — xmark / "New Study Program" / "Create"
//     (Create is ALWAYS enabled; validation happens on tap)
//   • CoverImagePicker (editable, 240pt)
//   • FieldGroup{ TextInput floating "Program name" }         — required
//   • FieldGroup{ MultilineTextInput description }            — optional
//   • FieldGroup{ MenuInput "Lesson template" (.menu) }       — required
//   • FieldGroup{ MenuInput "Days" (.wheel, 1–360) + divider + description }
//   • ToggleControl "Publish program"
//   • TagInput "Add tag..."
//   • 40px bottom spacer
// Validation chrome (shown only when showValidationErrors): red 1.5px
// radius-10 border on the invalid group + "Required" badge (s11Semibold
// red@0.9 on red@0.15, offset y -14) — bespoke in-page styling on iOS.
// Creating state: full-screen appBackground overlay, spinner + s17Semibold
// "Creating Program".

interface Props {
  programName?: string
  description?: string
  /** Displayed template value (iOS default "Select a template"). */
  templateValue?: string
  /** Template display names, alphabetical (iOS orderedTemplates). */
  templateOptions?: string[]
  /** True once a real template is chosen — drives the Required validation. */
  templateSelected?: boolean
  daysValue?: string
  published?: boolean
  tags?: string[]
  coverUrl?: string
  showValidationErrors?: boolean
  creating?: boolean
  /** Production: inputs become editable + native pickers. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar (the iPhone reference
  // includes the simulator's). Production never passes this.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  programName: '',
  description: '',
  templateValue: 'Select a template',
  templateOptions: () => [],
  templateSelected: false,
  daysValue: '30',
  published: false,
  tags: () => [],
  coverUrl: '',
  showValidationErrors: false,
  creating: false,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  close: []
  create: []
  'update:programName': [value: string]
  'update:description': [value: string]
  selectTemplate: [name: string]
  'update:daysValue': [value: string]
  togglePublish: []
  addTag: [tag: string]
  removeTag: [tag: string]
  coverTap: []
}>()

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'

// iOS validation: name (trimmed) and template are the only required fields.
const nameInvalid = computed(
  () => props.showValidationErrors && !props.programName.trim(),
)
const templateInvalid = computed(
  () => props.showValidationErrors && !props.templateSelected,
)

const DAY_OPTIONS = Array.from({ length: 360 }, (_, i) => String(i + 1))
</script>

<template>
  <div :class="['CreateProgram', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="CreateProgram__statusbar" aria-hidden="true">
      <span class="CreateProgram__clock">9:41</span>
      <span class="CreateProgram__indicators">
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
      title="New Study Program"
      :left-icon="XMARK"
      right-link="Create"
      @left="emit('close')"
      @right="emit('create')"
    />

    <div class="CreateProgram__scroll">
      <!-- Cover (full-bleed; production opens a file picker on tap) -->
      <div
        class="CreateProgram__cover"
        :role="props.interactive ? 'button' : undefined"
        @click="props.interactive && emit('coverTap')"
      >
        <CoverImagePicker
          mode="editable"
          :program-name="props.programName"
          :program-description="props.description"
          :cover-url="props.coverUrl || undefined"
          :has-image="!!props.coverUrl"
        />
      </div>

      <!-- Program name (required) -->
      <div class="CreateProgram__section">
        <div
          class="FieldGroup CreateProgram__group"
          :class="{ 'CreateProgram__group--invalid': nameInvalid }"
        >
          <TextInput
            :interactive="props.interactive"
            floating-label="Program name"
            :text="props.programName"
            @update:text="emit('update:programName', $event)"
          />
          <Transition name="CreateProgram-badge">
            <span v-if="nameInvalid" class="CreateProgram__required">Required</span>
          </Transition>
        </div>
      </div>

      <!-- Description (optional) -->
      <div class="CreateProgram__section">
        <MultilineTextInput
          :interactive="props.interactive"
          placeholder="Describe the purpose of this program"
          :text="props.description"
          @update:text="emit('update:description', $event)"
        />
      </div>

      <!-- Lesson template (required) -->
      <div class="CreateProgram__section">
        <div
          class="FieldGroup CreateProgram__group"
          :class="{ 'CreateProgram__group--invalid': templateInvalid }"
        >
          <MenuInput
            label="Lesson template"
            :selected-value="props.templateValue"
            :options="props.templateOptions"
            :interactive="props.interactive"
            placeholder-value="Select a template"
            @update:selected-value="emit('selectTemplate', $event)"
          />
          <Transition name="CreateProgram-badge">
            <span v-if="templateInvalid" class="CreateProgram__required">Required</span>
          </Transition>
        </div>
      </div>

      <!-- Days (wheel, default 30) -->
      <div class="CreateProgram__section">
        <div class="FieldGroup">
          <MenuInput
            label="Days"
            picker-style="wheel"
            :selected-value="props.daysValue"
            :options="DAY_OPTIONS"
            :interactive="props.interactive"
            @update:selected-value="emit('update:daysValue', $event)"
          />
          <div class="FieldGroup__divider"></div>
          <div class="FieldGroup__description">
            Select the total number of days you want in your study. This number can be
            updated at any time.
          </div>
        </div>
      </div>

      <!-- Publish toggle (ToggleControl renders its own ToggleGroup card) -->
      <div class="CreateProgram__section">
        <ToggleControl
          title="Publish program"
          description="Published programs can be enrolled by groups. Draft programs are only visible to you."
          :is-on="props.published"
          @toggle="emit('togglePublish')"
        />
      </div>

      <!-- Tags (no FieldGroup wrapper on iOS) -->
      <div class="CreateProgram__section">
        <TagInput
          :interactive="props.interactive"
          :tags="props.tags"
          placeholder="Add tag..."
          @add-tag="emit('addTag', $event)"
          @remove-tag="emit('removeTag', $event)"
        />
      </div>

      <div class="CreateProgram__bottomSpacer"></div>
    </div>

    <!-- Creating overlay (iOS: full-screen appBackground + spinner + label). -->
    <div v-if="props.creating" class="CreateProgram__creating">
      <span class="CreateProgram__creatingSpinner" aria-hidden="true"></span>
      <span class="CreateProgram__creatingLabel">Creating Program</span>
    </div>
  </div>
</template>
