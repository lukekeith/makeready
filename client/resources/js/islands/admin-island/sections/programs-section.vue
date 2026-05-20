<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { GripVertical } from 'lucide-vue-next'
import { VueDraggable } from 'vue-draggable-plus'
import { useProgramsDomain } from '../stores/domain/programs.domain'
import type { Lesson, ExportPreviewData, ImportResult } from '../stores/domain/programs.domain'
import { useProgramsListUI } from '../stores/ui/programs-list.ui'
import { useProgramDetailUI } from '../stores/ui/program-detail.ui'
import AdminTable from '../../../components/admin/admin-table/admin-table.vue'
import AdminForm from '../../../components/admin/admin-form/admin-form.vue'
import AdminConfirmDialog from '../../../components/admin/admin-confirm-dialog/admin-confirm-dialog.vue'
import AdminImageUpload from '../../../components/admin/admin-image-upload/admin-image-upload.vue'
import AdminActivityList from '../../../components/admin/admin-activity-list/admin-activity-list.vue'
import Button from 'primevue/button'
import Tabs from 'primevue/tabs'
import TabList from 'primevue/tablist'
import Tab from 'primevue/tab'
import TabPanels from 'primevue/tabpanels'
import TabPanel from 'primevue/tabpanel'
import InputText from 'primevue/inputtext'
import Card from 'primevue/card'
import Dialog from 'primevue/dialog'
import Message from 'primevue/message'

const domain = useProgramsDomain()
const listUI = useProgramsListUI()
const detailUI = useProgramDetailUI()
const route = useRoute()
const router = useRouter()
const isSaving = ref(false)
const importFileInput = ref<HTMLInputElement | null>(null)
const localLessons = ref<Lesson[]>([])
watch(() => detailUI.lessons, (v) => { localLessons.value = [...v] }, { immediate: true, deep: true })
const inlineEditId = ref<string | null>(null)
const inlineEditTitle = ref('')

onMounted(async () => { if (route.params.id) await domain.getProgram(route.params.id as string); else await Promise.all([domain.loadPrograms(), domain.loadTemplates()]) })
watch(() => route.params.id, async (id) => { if (id) await domain.getProgram(id as string); else await Promise.all([domain.loadPrograms(), domain.loadTemplates()]) })

const createFields = computed(() => [
  { key: 'name', label: 'Program Name', type: 'text' as const, required: true, placeholder: 'Enter program name' },
  { key: 'description', label: 'Description', type: 'textarea' as const, placeholder: 'Describe this program (optional)' },
  { key: 'templateId', label: 'Template', type: 'select' as const, required: true, options: listUI.templateOptions },
  { key: 'days', label: 'Number of Days', type: 'number' as const, required: true, placeholder: '30' },
])
const editFields = [
  { key: 'name', label: 'Program Name', type: 'text' as const, required: true, placeholder: 'Enter program name' },
  { key: 'description', label: 'Description', type: 'textarea' as const, placeholder: 'Describe this program (optional)' },
]

async function handleCreate(p: Record<string, any>) { isSaving.value = true; listUI.formError = null; try { await domain.createProgram(p); listUI.closeForm() } catch (e: any) { listUI.formError = e?.response?.data?.message ?? 'Failed' } finally { isSaving.value = false } }
async function handleUpdate(p: Record<string, any>) { if (!listUI.editingProgram) return; isSaving.value = true; listUI.formError = null; try { await domain.updateProgram(listUI.editingProgram.id, p); listUI.closeForm() } catch (e: any) { listUI.formError = e?.response?.data?.message ?? 'Failed' } finally { isSaving.value = false } }
async function handleDelete() { if (!listUI.confirmDeleteProgram) return; try { await domain.deleteProgram(listUI.confirmDeleteProgram.id) } finally { listUI.cancelDelete() } }
async function handleTogglePublish() { if (!detailUI.currentProgram) return; await domain.updateProgram(detailUI.currentProgram.id, { isPublished: !detailUI.currentProgram.isPublished }) }
async function handleMetadataSave(p: Record<string, any>) { detailUI.isSavingMetadata = true; detailUI.metadataError = null; try { await domain.updateProgram(route.params.id as string, p) } catch (e: any) { detailUI.metadataError = e?.response?.data?.message ?? 'Failed' } finally { detailUI.isSavingMetadata = false } }
async function handleCoverUpload(file: File) { detailUI.isUploadingCover = true; try { await domain.uploadCoverImage(route.params.id as string, file) } finally { detailUI.isUploadingCover = false } }
async function handleAddLesson() { await domain.addLesson(route.params.id as string) }
function startInlineEdit(l: Lesson) { inlineEditId.value = l.id; inlineEditTitle.value = l.title }
async function saveInlineEdit() { if (!inlineEditId.value) return; await domain.updateLessonTitle(route.params.id as string, inlineEditId.value, inlineEditTitle.value); inlineEditId.value = null }
function cancelInlineEdit() { inlineEditId.value = null }
async function handleDeleteLesson() { const l = detailUI.confirmDeleteLesson; if (!l) return; try { await domain.deleteLesson(route.params.id as string, l.id) } finally { detailUI.cancelDeleteLesson() } }
async function handleReorder() { await domain.reorderLessons(route.params.id as string, localLessons.value.map(l => l.id)) }
async function handleDeleteActivity() { const a = detailUI.confirmDeleteActivity; if (!a || !detailUI.expandedLessonId) return; try { await domain.deleteActivity(a.id, route.params.id as string, detailUI.expandedLessonId) } finally { detailUI.cancelDeleteActivity() } }

// Export preview
const showExportPreview = ref(false)
const exportPreview = ref<ExportPreviewData | null>(null)
const isLoadingExportPreview = ref(false)
const isExporting = ref(false)

async function openExportPreview() {
  isLoadingExportPreview.value = true
  showExportPreview.value = true
  try {
    exportPreview.value = await domain.getExportPreview(route.params.id as string)
  } catch {
    showExportPreview.value = false
  } finally {
    isLoadingExportPreview.value = false
  }
}

async function confirmExport() {
  isExporting.value = true
  try {
    await domain.exportProgram(route.params.id as string)
    showExportPreview.value = false
  } finally {
    isExporting.value = false
  }
}

// Import preview
const showImportPreview = ref(false)
const importPreview = ref<ExportPreviewData | null>(null)
const importFile = ref<File | null>(null)
const importValidationError = ref<string | null>(null)
const showImportSuccess = ref(false)
const importResult = ref<ImportResult | null>(null)

function triggerImport() { importFileInput.value?.click() }

async function handleImportFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = '' // reset so same file can be re-selected
  if (!file) return

  importValidationError.value = null
  importFile.value = file

  try {
    importPreview.value = await domain.parseImportFile(file)
    showImportPreview.value = true
  } catch (err: any) {
    importValidationError.value = err.message
    listUI.importError = err.message
  }
}

async function confirmImport() {
  if (!importFile.value) return
  listUI.isImporting = true
  try {
    importResult.value = await domain.importProgram(importFile.value)
    showImportPreview.value = false
    showImportSuccess.value = true
  } catch (err: any) {
    listUI.importError = err?.response?.data?.message ?? err.message ?? 'Failed to import'
    showImportPreview.value = false
  } finally {
    listUI.isImporting = false
    importFile.value = null
  }
}

function dismissImportSuccess() {
  showImportSuccess.value = false
  importResult.value = null
}
</script>

<template>
  <!-- Detail View -->
  <template v-if="route.params.id">
    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
      <div>
        <Button label="Back to Programs" icon="pi pi-arrow-left" severity="secondary" text @click="router.push('/admin/programs')" />
        <div style="display: flex; align-items: center; gap: 0.75rem; margin-top: 0.5rem;">
          <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0; flex: 1;">{{ detailUI.pageTitle }}</h1>
          <Button label="Export" icon="pi pi-download" severity="secondary" outlined @click="openExportPreview" />
          <Button :label="detailUI.currentProgram?.isPublished ? 'Unpublish' : 'Publish'" :severity="detailUI.currentProgram?.isPublished ? 'secondary' : 'primary'" :outlined="detailUI.currentProgram?.isPublished" @click="handleTogglePublish" />
        </div>
      </div>

      <AdminImageUpload :current-url="detailUI.currentProgram?.coverImageUrl" :uploading="detailUI.isUploadingCover" label="Program Cover Image" @upload="handleCoverUpload" />

      <Tabs :value="detailUI.activeTab" @update:value="(v) => detailUI.activeTab = v">
        <TabList>
          <Tab value="lessons">Lessons</Tab>
          <Tab value="enrollments">Enrollments</Tab>
          <Tab value="metadata">Details</Tab>
        </TabList>
        <TabPanels>
          <TabPanel value="lessons">
            <div style="display: flex; flex-direction: column; gap: 0.5rem; padding-top: 1rem;">
              <div v-if="localLessons.length > 0">
                <VueDraggable v-model="localLessons" :animation="200" handle=".lesson-drag-handle" @end="handleReorder">
                  <Card v-for="lesson in localLessons" :key="lesson.id" style="margin-bottom: 0.25rem;">
                    <template #content>
                      <div style="display: flex; align-items: center; gap: 0.5rem;">
                        <Button :icon="detailUI.expandedLessonId === lesson.id ? 'pi pi-chevron-down' : 'pi pi-chevron-right'" severity="secondary" outlined rounded size="small" @click="detailUI.toggleExpandLesson(lesson.id)" />
                        <span class="lesson-drag-handle" style="cursor: grab; color: var(--p-text-muted-color);"><GripVertical :size="16" /></span>
                        <small style="color: var(--p-text-muted-color); width: 2.5rem; flex-shrink: 0;">Day {{ lesson.dayNumber }}</small>

                        <template v-if="inlineEditId === lesson.id">
                          <InputText v-model="inlineEditTitle" fluid @keydown.enter="saveInlineEdit" @keydown.escape="cancelInlineEdit" />
                          <Button icon="pi pi-check" severity="secondary" text rounded size="small" @click="saveInlineEdit" />
                          <Button icon="pi pi-times" severity="secondary" text rounded size="small" @click="cancelInlineEdit" />
                        </template>
                        <template v-else>
                          <span style="flex: 1; font-size: 0.875rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">{{ lesson.title }}</span>
                          <Button icon="pi pi-pencil" severity="secondary" text rounded size="small" @click="startInlineEdit(lesson)" />
                          <Button icon="pi pi-trash" severity="danger" text rounded size="small" @click="detailUI.requestDeleteLesson(lesson.id)" />
                        </template>
                      </div>
                      <AdminActivityList v-if="detailUI.expandedLessonId === lesson.id" :program-id="(route.params.id as string)" :lesson-id="lesson.id" style="margin-top: 0.75rem;" />
                    </template>
                  </Card>
                </VueDraggable>
              </div>
              <div v-else style="color: var(--p-text-muted-color);">No lessons yet. Add your first lesson below.</div>
              <Button label="Add Lesson" icon="pi pi-plus" severity="secondary" outlined @click="handleAddLesson" />
            </div>
          </TabPanel>

          <TabPanel value="enrollments">
            <div style="padding-top: 1rem; color: var(--p-text-muted-color);">Enrollments management — coming in Phase 9</div>
          </TabPanel>

          <TabPanel value="metadata">
            <div style="padding-top: 1rem;">
              <AdminForm :key="'metadata-' + (detailUI.currentProgram?.id ?? 'none')" :open="true" :inline="true" :hide-cancel-button="true" title="Program Details" :fields="detailUI.metadataFields" :values="detailUI.metadataFormValues" :error="detailUI.metadataError ?? undefined" :saving="detailUI.isSavingMetadata" @save="handleMetadataSave" @cancel="() => {}" />
            </div>
          </TabPanel>
        </TabPanels>
      </Tabs>

      <AdminConfirmDialog :open="!!detailUI.confirmDeleteLesson" title="Delete Lesson" :message="`Are you sure you want to delete &quot;${detailUI.confirmDeleteLesson?.title ?? ''}&quot;? Remaining lessons will be renumbered.`" @confirm="handleDeleteLesson" @cancel="detailUI.cancelDeleteLesson" />
      <AdminConfirmDialog :open="!!detailUI.confirmDeleteActivity" title="Delete Activity" message="Are you sure you want to delete this activity? This cannot be undone." @confirm="handleDeleteActivity" @cancel="detailUI.cancelDeleteActivity" />
    </div>
  </template>

  <!-- List View -->
  <template v-else>
    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
      <div style="display: flex; align-items: center; justify-content: space-between;">
        <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Programs</h1>
        <div style="display: flex; gap: 0.5rem;">
          <Button label="Import" icon="pi pi-upload" severity="secondary" outlined :loading="listUI.isImporting" @click="triggerImport" />
          <Button label="+ Create Program" @click="listUI.openCreateForm" />
        </div>
      </div>
      <input ref="importFileInput" type="file" accept=".makeready,.zip" style="display: none;" @change="handleImportFile" />
      <Message v-if="listUI.importError" severity="error" :closable="true" @close="listUI.importError = null">{{ listUI.importError }}</Message>
      <AdminTable :columns="listUI.tableColumns" :rows="listUI.tableRows" :loading="domain.isLoading" empty-message="No programs yet. Create your first study program." @row-click="listUI.navigateToDetail" @edit="listUI.openEditForm" @delete="listUI.requestDelete" />
      <AdminForm :key="listUI.editingProgramId ?? 'create'" :open="listUI.isCreateFormOpen" :title="listUI.isEditing ? 'Edit Program' : 'Create Program'" :fields="listUI.isEditing ? editFields : createFields" :values="listUI.isEditing ? { name: listUI.editingProgram?.name ?? '', description: listUI.editingProgram?.description ?? '' } : {}" :error="listUI.formError ?? undefined" :saving="isSaving" @save="listUI.isEditing ? handleUpdate($event) : handleCreate($event)" @cancel="listUI.closeForm" />
      <AdminConfirmDialog :open="!!listUI.confirmDeleteProgram" title="Delete Program" :message="`Are you sure you want to delete &quot;${listUI.confirmDeleteProgram?.name ?? ''}&quot;? This will remove all lessons and enrollments.`" @confirm="handleDelete" @cancel="listUI.cancelDelete" />

      <!-- Import Preview Dialog -->
      <Dialog :visible="showImportPreview" header="Import Program" modal :style="{ width: '28rem' }" @update:visible="(v) => { if (!v) showImportPreview = false }">
        <div v-if="importPreview" style="display: flex; flex-direction: column; gap: 1rem;">
          <div style="font-size: 1.125rem; font-weight: 600;">{{ importPreview.name }}</div>
          <div v-if="importPreview.templateName" style="font-size: 0.875rem; color: var(--p-text-muted-color);">Template: {{ importPreview.templateName }}</div>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.days }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Days</div></div>
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.activities }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Activities</div></div>
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.reads }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Reads</div></div>
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.videos }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Videos</div></div>
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.readBlocks }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Read Blocks</div></div>
            <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ importPreview.scriptureRefs }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Scripture Refs</div></div>
          </div>
          <small style="color: var(--p-text-muted-color);">The program will be imported as a draft.</small>
        </div>
        <template #footer>
          <Button label="Cancel" severity="secondary" text @click="showImportPreview = false" />
          <Button label="Confirm Import" :loading="listUI.isImporting" @click="confirmImport" />
        </template>
      </Dialog>

      <!-- Import Success Dialog -->
      <Dialog :visible="showImportSuccess" header="Import Complete" modal :style="{ width: '24rem' }" :closable="false">
        <div style="display: flex; flex-direction: column; gap: 0.75rem;">
          <p><strong>{{ importResult?.program?.name }}</strong> has been imported and is ready to use.</p>
          <Message v-for="(warning, i) in (importResult?.warnings ?? [])" :key="i" severity="warn" :closable="false">{{ warning }}</Message>
        </div>
        <template #footer>
          <Button label="Done" @click="dismissImportSuccess" />
        </template>
      </Dialog>
    </div>
  </template>

  <!-- Export Preview Dialog -->
  <Dialog :visible="showExportPreview" header="Export Program" modal :style="{ width: '28rem' }" @update:visible="(v) => { if (!v) showExportPreview = false }">
    <div v-if="isLoadingExportPreview" style="display: flex; justify-content: center; padding: 2rem; color: var(--p-text-muted-color);">Loading preview...</div>
    <div v-else-if="exportPreview" style="display: flex; flex-direction: column; gap: 1rem;">
      <div style="font-size: 1.125rem; font-weight: 600;">{{ exportPreview.name }}</div>
      <div v-if="exportPreview.templateName" style="font-size: 0.875rem; color: var(--p-text-muted-color);">Template: {{ exportPreview.templateName }}</div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.days }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Days</div></div>
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.activities }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Activities</div></div>
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.reads }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Reads</div></div>
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.videos }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Videos</div></div>
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.readBlocks }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Read Blocks</div></div>
        <div style="padding: 0.75rem; border-radius: var(--p-border-radius); border: 1px solid var(--p-content-border-color);"><div style="font-size: 1.25rem; font-weight: 700;">{{ exportPreview.scriptureRefs }}</div><div style="font-size: 0.75rem; color: var(--p-text-muted-color);">Scripture Refs</div></div>
      </div>
      <small style="color: var(--p-text-muted-color);">The program will be exported as a .makeready file.</small>
    </div>
    <template #footer>
      <Button label="Cancel" severity="secondary" text @click="showExportPreview = false" />
      <Button label="Export" icon="pi pi-download" :loading="isExporting" @click="confirmExport" />
    </template>
  </Dialog>
</template>
