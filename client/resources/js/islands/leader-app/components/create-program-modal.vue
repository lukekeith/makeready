<script setup lang="ts">
// CreateProgramModal — production content of the .createProgram overlay (iOS
// CreateProgramPage). The iOS page is ONE modal holding an internal SlideStack:
// create form → Program Home (→ EditDay). On success it slides IN-PLACE to the
// new program's home; the X there dismisses the whole overlay — there is never
// a back-slide to the form. The web mirrors that: SlideStack(main = the
// CreateProgram twin, detail = ProgramHomeModal with `preloaded` since the
// create response already seeded the store).
import { inject, onMounted, reactive, ref, watch } from 'vue'
import CreateProgram from '../../../components/card/create-program/create-program.vue'
import SlideStack from '../overlay/slide-stack.vue'
import ProgramHomeModal from './program-home-modal.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderProgram } from '../stores/leader-program.store'
import { useLeaderLibrary } from '../stores/leader-library.store'

const store = useLeaderProgram()
const library = useLeaderLibrary()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

// iOS: the form's xmark dismisses the whole .createProgram overlay.
function close(): void {
  overlay?.dismiss()
}

const form = reactive({
  name: '',
  description: '',
  templateName: 'Select a template',
  templateId: null as string | null,
  days: '30',
  published: false,
  tags: [] as string[],
})

const templates = ref<Array<{ id: string; name: string }>>([])
const showValidationErrors = ref(false)
const creating = ref(false)
const createdProgramId = ref<string | null>(null)
const confirmDialog = useConfirmDialog()

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

onMounted(async () => {
  try {
    templates.value = await store.loadTemplates()
  } catch {
    // Empty template list — Create stays blocked on the Required badge.
  }
})

function onSelectTemplate(name: string): void {
  form.templateName = name
  form.templateId = templates.value.find((t) => t.name === name)?.id ?? null
}

// iOS auto-clears the validation chrome once both required fields are
// satisfied (Motion.micro; the twin's badge transition handles the fade).
watch(
  () => [form.name, form.templateId],
  () => {
    if (form.name.trim() && form.templateId) showValidationErrors.value = false
  },
)

// ── Cover: picked pre-create, held locally, uploaded AFTER create (iOS). ──
const fileInput = ref<HTMLInputElement | null>(null)
const coverFile = ref<File | null>(null)
const coverPreviewUrl = ref('')

function onCoverTap(): void {
  fileInput.value?.click()
}

function onFileChange(e: Event): void {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (file) {
    coverFile.value = file
    if (coverPreviewUrl.value) URL.revokeObjectURL(coverPreviewUrl.value)
    coverPreviewUrl.value = URL.createObjectURL(file)
  }
  ;(e.target as HTMLInputElement).value = ''
}

function readAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}

// ── Create (iOS createProgram: validate on tap, full-screen creating overlay,
//    then cover upload + best-effort tags, then slide to Program Home). ──
async function onCreate(): Promise<void> {
  if (creating.value) return
  if (!form.name.trim() || !form.templateId) {
    showValidationErrors.value = true
    return
  }
  creating.value = true
  try {
    const id = await store.createProgram({
      name: form.name.trim(),
      templateId: form.templateId,
      days: Number(form.days) || 30,
      isPublished: form.published,
      description: form.description.trim() || undefined,
    })
    if (coverFile.value) {
      try {
        const dataUrl = await readAsDataUrl(coverFile.value)
        await store.uploadCover(id, dataUrl, coverFile.value.type || 'image/jpeg')
      } catch {
        // iOS: program stands; surface the cover failure separately.
        showError("Couldn't upload the cover image")
      }
    }
    await store.addTags(id, form.tags)
    createdProgramId.value = id
    // The Library list caches; refresh so the new program shows behind the
    // modal and after dismiss (iOS upserts into AppState automatically).
    void library.loadPrograms(true)
  } catch {
    showError("Couldn't create the program")
  } finally {
    creating.value = false
  }
}
</script>

<template>
  <div class="CreateProgramModal">
    <SlideStack :item="createdProgramId">
      <CreateProgram
        interactive
        :program-name="form.name"
        :description="form.description"
        :template-value="form.templateName"
        :template-options="templates.map((t) => t.name)"
        :template-selected="!!form.templateId"
        :days-value="form.days"
        :published="form.published"
        :tags="form.tags"
        :cover-url="coverPreviewUrl"
        :show-validation-errors="showValidationErrors"
        :creating="creating"
        @close="close"
        @create="onCreate"
        @update:program-name="form.name = $event"
        @update:description="form.description = $event"
        @select-template="onSelectTemplate"
        @update:days-value="form.days = $event"
        @toggle-publish="form.published = !form.published"
        @add-tag="form.tags = [...form.tags, $event]"
        @remove-tag="form.tags = form.tags.filter((t) => t !== $event)"
        @cover-tap="onCoverTap"
      />
      <template #detail="{ item }">
        <ProgramHomeModal :program-id="String(item)" preloaded />
      </template>
    </SlideStack>

    <input
      ref="fileInput"
      class="CreateProgramModal__file"
      type="file"
      accept="image/*"
      @change="onFileChange"
    />

  </div>
</template>

<style scoped>
.CreateProgramModal {
  position: relative;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.CreateProgramModal :deep(.SlideStack) {
  flex: 1 1 auto;
}

.CreateProgramModal :deep(.CreateProgram),
.CreateProgramModal :deep(.ProgramHomeModal) {
  height: 100%;
}

.CreateProgramModal__file {
  display: none;
}

</style>
