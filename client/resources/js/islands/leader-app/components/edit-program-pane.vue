<script setup lang="ts">
// EditProgramPane — production rebuild of the iPhone "Edit Program" settings
// pane (ProgramHomePage.editProgramContent), the SlideStack detail reached via
// the gear icon. Layout mirrors iOS (VStack spacing 20, all sections padded H16):
//   • PageTitle.iconTitleLink — chevron.left / "Edit Program" / Done
//   • CoverImagePicker (editable) — tapping opens a file picker; the image
//     auto-uploads (iOS .onChange(of: coverImage) auto-saves the cover)
//   • FieldGroup { TextInput(floating "Program name") }
//   • FieldGroup { MultilineTextInput("Describe the purpose of this program") }
//   • ToggleControl("Publish program", …)   — renders its own ToggleGroup card
//   • TagInput("Add tag...")
// Back chevron discards (edit state is seeded by the parent when the gear is
// tapped, separate from the loaded program); Done saves then slides back.
import { ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import CoverImagePicker from '../../../components/card/cover-image-picker/cover-image-picker.vue'
import TextInput from '../../../components/card/text-input/text-input.vue'
import MultilineTextInput from '../../../components/card/multiline-text-input/multiline-text-input.vue'
import ToggleControl from '../../../components/card/toggle-control/toggle-control.vue'
import TagInput from '../../../components/card/tag-input/tag-input.vue'

const name = defineModel<string>('name', { default: '' })
const description = defineModel<string>('description', { default: '' })
const published = defineModel<boolean>('published', { default: false })
const tags = defineModel<string[]>('tags', { default: () => [] })

const props = defineProps<{
  coverUrl?: string
  saving?: boolean
  uploadingCover?: boolean
}>()

const emit = defineEmits<{
  back: []
  save: []
  coverPicked: [file: File]
}>()

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'

const fileInput = ref<HTMLInputElement | null>(null)

function onCoverClick(): void {
  fileInput.value?.click()
}

function onFileChange(e: Event): void {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (file) emit('coverPicked', file)
  ;(e.target as HTMLInputElement).value = ''
}

function addTag(tag: string): void {
  tags.value = [...tags.value, tag]
}

function removeTag(tag: string): void {
  tags.value = tags.value.filter((t) => t !== tag)
}
</script>

<template>
  <div class="EditProgramPane">
    <PageTitle
      class="EditProgramPane__title"
      title="Edit Program"
      :left-icon="BACK_CHEVRON"
      :right-link="props.saving ? 'Saving...' : 'Done'"
      @left="emit('back')"
      @right="emit('save')"
    />

    <div class="EditProgramPane__scroll">
      <!-- Cover (editable — tap to pick; auto-uploads like iOS) -->
      <div
        class="EditProgramPane__cover"
        role="button"
        tabindex="0"
        @click="onCoverClick"
        @keydown.enter.prevent="onCoverClick"
      >
        <CoverImagePicker
          mode="editable"
          :program-name="name"
          :program-description="description"
          :cover-url="props.coverUrl || undefined"
          :has-image="!!props.coverUrl"
        />
        <div v-if="props.uploadingCover" class="EditProgramPane__coverBusy">
          <span class="EditProgramPane__spinner" aria-label="Uploading"></span>
        </div>
        <input
          ref="fileInput"
          class="EditProgramPane__file"
          type="file"
          accept="image/*"
          @change="onFileChange"
        />
      </div>

      <!-- Program name -->
      <div class="EditProgramPane__section">
        <div class="FieldGroup">
          <TextInput
            interactive
            floating-label="Program name"
            :text="name"
            @update:text="name = $event"
          />
        </div>
      </div>

      <!-- Description -->
      <div class="EditProgramPane__section">
        <MultilineTextInput
          interactive
          placeholder="Describe the purpose of this program"
          :text="description"
          @update:text="description = $event"
        />
      </div>

      <!-- Publish toggle (ToggleControl renders its own ToggleGroup card) -->
      <div class="EditProgramPane__section">
        <ToggleControl
          title="Publish program"
          description="Published programs can be enrolled by groups. Draft programs are only visible to you."
          :is-on="published"
          @toggle="published = !published"
        />
      </div>

      <!-- Tags -->
      <div class="EditProgramPane__section">
        <TagInput
          interactive
          :tags="tags"
          placeholder="Add tag..."
          @add-tag="addTag"
          @remove-tag="removeTag"
        />
      </div>

      <div class="EditProgramPane__bottomSpacer"></div>
    </div>
  </div>
</template>

<style scoped>
.EditProgramPane {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
}

.EditProgramPane__title {
  flex: 0 0 auto;
}

.EditProgramPane__scroll {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 20px; /* iOS VStack(spacing: 20) */
  overflow-y: auto;
}

.EditProgramPane__cover {
  position: relative;
  cursor: pointer;
}

.EditProgramPane__coverBusy {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.4); /* iOS CardSpinnerOverlay wash */
}

.EditProgramPane__spinner {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 3px solid var(--color-white-10);
  border-top-color: var(--color-white-50);
  animation: EditProgramPane-spin 0.8s linear infinite;
}

@keyframes EditProgramPane-spin {
  to {
    transform: rotate(360deg);
  }
}

.EditProgramPane__file {
  display: none;
}

.EditProgramPane__section {
  padding: 0 16px;
}

.EditProgramPane__bottomSpacer {
  flex: 0 0 40px;
}
</style>
