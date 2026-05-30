<script setup lang="ts">
import { ref, watch } from 'vue'
import { GripVertical } from 'lucide-vue-next'
import { VueDraggable } from 'vue-draggable-plus'
import { useProgramsDomain, ACTIVITY_TYPE_LABELS } from '../../../islands/admin-island/stores/domain/programs.domain'
import type { Activity, ActivityReadBlock } from '../../../islands/admin-island/stores/domain/programs.domain'
import { useProgramDetailUI } from '../../../islands/admin-island/stores/ui/program-detail.ui'
import { useActivityDetailUI } from '../../../islands/admin-island/stores/ui/activity-detail.ui'
import Accordion from 'primevue/accordion'
import AccordionPanel from 'primevue/accordionpanel'
import AccordionHeader from 'primevue/accordionheader'
import AccordionContent from 'primevue/accordioncontent'
import Tag from 'primevue/tag'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Textarea from 'primevue/textarea'
import Select from 'primevue/select'
import ToggleSwitch from 'primevue/toggleswitch'
import Divider from 'primevue/divider'
import Panel from 'primevue/panel'
import Message from 'primevue/message'

const props = defineProps<{ programId: string; lessonId: string }>()

const domain = useProgramsDomain()
const detailUI = useProgramDetailUI()
const activityUI = useActivityDetailUI()

const localActivities = ref<Activity[]>([])
watch(() => detailUI.activitiesForExpandedLesson, (v) => { localActivities.value = [...v] }, { immediate: true, deep: true })

const isAddFormOpen = ref(false)
const newActivityType = ref('READ')
const newActivityTitle = ref('')
const activityTypes = [
  { value: 'READ', label: 'Read' }, { value: 'VIDEO', label: 'Video' }, { value: 'YOUTUBE', label: 'YouTube Video' }, { value: 'USER_INPUT', label: 'Study' },
  { value: 'SOAP', label: 'SOAP' }, { value: 'OIA', label: 'OIA' }, { value: 'DBS', label: 'DBS' }, { value: 'HEAR', label: 'HEAR' },
]

function getTypeSeverity(t: string): string {
  return ({ READ: 'info', VIDEO: 'secondary', USER_INPUT: 'secondary' } as Record<string, string>)[t] ?? 'warn'
}

function openAddForm() { isAddFormOpen.value = true; newActivityType.value = 'READ'; newActivityTitle.value = '' }
function closeAddForm() { isAddFormOpen.value = false }
async function handleAdd() { if (!newActivityTitle.value.trim()) return; await domain.addActivity(props.programId, props.lessonId, newActivityType.value, newActivityTitle.value.trim()); closeAddForm() }
async function handleReorder() { await domain.reorderActivities(props.programId, props.lessonId, localActivities.value.map(a => a.id)) }

function handleActivityClick(activity: Activity) {
  if (activityUI.editingActivityId === activity.id) activityUI.closeEditor()
  else activityUI.openEditor(activity.id, props.programId, props.lessonId)
}

// Editor state
const editTitle = ref(''); const editReadContent = ref(''); const editVideoUrl = ref(''); const editVideoId = ref('')
const editYoutubeUrl = ref(''); const editYoutubeStartSeconds = ref<number | null>(null); const editYoutubeEndSeconds = ref<number | null>(null)
const editPassageReference = ref(''); const editIsHelpEnabled = ref(false); const editHelpTitle = ref('')
const editHelpDescription = ref(''); const isHelpExpanded = ref(false)
const isAddBlockOpen = ref(false); const newBlockTitle = ref(''); const newBlockContent = ref('')
const editingBlockId = ref<string | null>(null); const editingBlockContent = ref('')
const localReadBlocks = ref<ActivityReadBlock[]>([])
const isAddRefOpen = ref(false); const newRefPassage = ref(''); const newRefBookName = ref('')
const newRefBookNumber = ref(0); const newRefChapterStart = ref(1); const newRefVerseStart = ref(1); const newRefVerseEnd = ref(1)

watch(() => activityUI.currentActivity, (a) => {
  if (a) {
    editTitle.value = a.title ?? ''; editReadContent.value = a.readContent ?? ''; editVideoUrl.value = a.videoUrl ?? ''
    editVideoId.value = a.videoId ?? ''; editPassageReference.value = a.passageReference ?? ''
    editYoutubeUrl.value = (a as any).youtubeUrl ?? ''; editYoutubeStartSeconds.value = (a as any).youtubeStartSeconds ?? null
    editYoutubeEndSeconds.value = (a as any).youtubeEndSeconds ?? null
    editIsHelpEnabled.value = a.isHelpEnabled ?? false; editHelpTitle.value = a.helpTitle ?? ''
    editHelpDescription.value = a.helpDescription ?? ''
    localReadBlocks.value = [...(a.readBlocks ?? [])]; isHelpExpanded.value = false
    editingBlockId.value = null; isAddBlockOpen.value = false; isAddRefOpen.value = false
  }
}, { immediate: true })

watch(() => activityUI.currentActivity?.readBlocks, (b) => { if (b) localReadBlocks.value = [...b] }, { deep: true })

async function handleSaveActivity() {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  activityUI.isSaving = true; activityUI.saveError = null
  try {
    const payload: Record<string, any> = { title: editTitle.value, isHelpEnabled: editIsHelpEnabled.value, helpTitle: editHelpTitle.value || undefined, helpDescription: editHelpDescription.value || undefined }
    if (activityUI.isReadType) payload.readContent = editReadContent.value || undefined
    else if (activityUI.isVideoType) { payload.videoUrl = editVideoUrl.value || undefined; payload.videoId = editVideoId.value || undefined }
    else if (activityUI.isYoutubeType) { payload.youtubeUrl = editYoutubeUrl.value || undefined; payload.youtubeStartSeconds = editYoutubeStartSeconds.value ?? undefined; payload.youtubeEndSeconds = editYoutubeEndSeconds.value ?? undefined }
    else if (activityUI.isStudyMethodType) payload.passageReference = editPassageReference.value || undefined
    await domain.updateActivity(activityUI.currentActivity.id, activityUI.editingProgramId, activityUI.editingLessonId, payload)
  } catch (err: any) { activityUI.saveError = err?.response?.data?.message ?? 'Failed to save' }
  finally { activityUI.isSaving = false }
}

async function handleReset() {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  if (!confirm('Reset this activity? All content will be cleared.')) return
  await domain.resetActivity(activityUI.currentActivity.id, activityUI.editingProgramId, activityUI.editingLessonId)
}

async function handleAddBlock() {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  await domain.addReadBlock(activityUI.currentActivity.id, activityUI.editingProgramId, activityUI.editingLessonId, newBlockTitle.value || '', newBlockContent.value || '', (activityUI.currentActivity.readBlocks?.length ?? 0) + 1, false)
  isAddBlockOpen.value = false; newBlockTitle.value = ''; newBlockContent.value = ''
}
function startEditBlock(b: ActivityReadBlock) { editingBlockId.value = b.id; editingBlockContent.value = b.content ?? '' }
async function saveEditBlock() {
  if (!editingBlockId.value || !activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  await domain.updateReadBlock(activityUI.currentActivity.id, editingBlockId.value, editingBlockContent.value || null, activityUI.editingProgramId, activityUI.editingLessonId)
  editingBlockId.value = null
}
async function handleDeleteBlock(blockId: string) {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  await domain.deleteReadBlock(activityUI.currentActivity.id, blockId, activityUI.editingProgramId, activityUI.editingLessonId)
}
async function handleReorderBlocks() {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  await domain.reorderReadBlocks(activityUI.currentActivity.id, activityUI.editingProgramId, activityUI.editingLessonId, localReadBlocks.value.map(b => b.id))
}

async function handleAddSourceRef() {
  if (!activityUI.currentActivity || !activityUI.editingProgramId || !activityUI.editingLessonId) return
  await domain.addSourceReference(activityUI.currentActivity.id, activityUI.editingProgramId, activityUI.editingLessonId, newRefPassage.value, newRefBookNumber.value, newRefBookName.value, newRefChapterStart.value, newRefVerseStart.value, newRefVerseEnd.value)
  isAddRefOpen.value = false; newRefPassage.value = ''; newRefBookName.value = ''; newRefBookNumber.value = 0; newRefChapterStart.value = 1; newRefVerseStart.value = 1; newRefVerseEnd.value = 1
}
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
    <template v-if="localActivities.length > 0">
      <VueDraggable v-model="localActivities" :animation="200" handle=".activity-drag-handle" ghost-class="opacity-40" @end="handleReorder">
        <Accordion :multiple="false" :value="activityUI.editingActivityId ? [activityUI.editingActivityId] : []">
          <AccordionPanel v-for="activity in localActivities" :key="activity.id" :value="activity.id">
            <AccordionHeader @click.stop="handleActivityClick(activity)">
              <div style="display: flex; align-items: center; gap: 0.5rem; flex: 1; min-width: 0;">
                <span class="activity-drag-handle" style="cursor: grab; color: var(--p-text-muted-color);" @click.stop><GripVertical :size="14" /></span>
                <Tag :severity="getTypeSeverity(activity.activityType)">{{ ACTIVITY_TYPE_LABELS[activity.activityType] || activity.activityType }}</Tag>
                <span style="font-size: 0.875rem; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1;">{{ activity.title || '(untitled)' }}</span>
                <Tag :severity="activity.status === 'COMPLETE' ? 'success' : 'secondary'">{{ activity.status === 'COMPLETE' ? 'Complete' : 'Pending' }}</Tag>
                <div style="display: flex; gap: 0.125rem;" @click.stop>
                  <Button icon="pi pi-pencil" severity="secondary" text rounded size="small" @click.stop="handleActivityClick(activity)" />
                  <Button icon="pi pi-trash" severity="danger" text rounded size="small" @click.stop="detailUI.requestDeleteActivity(activity.id)" />
                </div>
              </div>
            </AccordionHeader>
            <AccordionContent v-if="activityUI.editingActivityId === activity.id && activityUI.currentActivity">
              <div style="display: flex; flex-direction: column; gap: 1rem; padding: 0.5rem 0;">
                <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                  <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Title</label>
                  <InputText v-model="editTitle" placeholder="Activity title" fluid />
                </div>

                <template v-if="activityUI.isReadType">
                  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Content</label>
                    <Textarea v-model="editReadContent" :rows="6" placeholder="Plain text content..." fluid />
                  </div>
                  <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                      <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Read Blocks</label>
                      <Button label="Add Block" icon="pi pi-plus" severity="secondary" outlined size="small" @click="isAddBlockOpen = true" />
                    </div>
                    <template v-if="localReadBlocks.length > 0">
                      <VueDraggable v-model="localReadBlocks" :animation="200" handle=".block-drag-handle" @end="handleReorderBlocks">
                        <div v-for="block in localReadBlocks" :key="block.id" style="display: flex; align-items: flex-start; gap: 0.5rem; padding: 0.5rem; border: 1px solid var(--p-content-border-color); border-radius: var(--p-border-radius); margin-bottom: 0.25rem;">
                          <span class="block-drag-handle" style="cursor: grab; color: var(--p-text-muted-color); margin-top: 0.25rem;"><GripVertical :size="12" /></span>
                          <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.25rem;">
                            <template v-if="editingBlockId === block.id">
                              <Textarea v-model="editingBlockContent" :rows="3" fluid @keydown.escape="editingBlockId = null" />
                              <div style="display: flex; gap: 0.25rem;"><Button label="Save" size="small" @click="saveEditBlock" /><Button label="Cancel" severity="secondary" text size="small" @click="editingBlockId = null" /></div>
                            </template>
                            <template v-else>
                              <small style="font-weight: 500;">{{ block.title || 'Block ' + block.orderNumber }}</small>
                              <small style="color: var(--p-text-muted-color); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">{{ block.content || '(empty)' }}</small>
                              <div style="display: flex; gap: 0.25rem;"><Button icon="pi pi-pencil" severity="secondary" text rounded size="small" @click="startEditBlock(block)" /><Button icon="pi pi-trash" severity="danger" text rounded size="small" @click="handleDeleteBlock(block.id)" /></div>
                            </template>
                          </div>
                        </div>
                      </VueDraggable>
                    </template>
                    <small v-else style="color: var(--p-text-muted-color);">No read blocks yet.</small>
                    <Panel v-if="isAddBlockOpen" header="New Block">
                      <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                        <InputText v-model="newBlockTitle" placeholder="Block title (optional)" fluid />
                        <Textarea v-model="newBlockContent" :rows="3" placeholder="Block content..." fluid />
                        <div style="display: flex; gap: 0.25rem;"><Button label="Add" size="small" @click="handleAddBlock" /><Button label="Cancel" severity="secondary" text size="small" @click="isAddBlockOpen = false" /></div>
                      </div>
                    </Panel>
                  </div>
                </template>

                <template v-if="activityUI.isVideoType">
                  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Video URL</label>
                    <InputText v-model="editVideoUrl" placeholder="https://..." fluid />
                  </div>
                  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Video ID</label>
                    <InputText v-model="editVideoId" placeholder="Video identifier" fluid />
                  </div>
                </template>

                <template v-if="activityUI.isYoutubeType">
                  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">YouTube URL</label>
                    <InputText v-model="editYoutubeUrl" placeholder="https://www.youtube.com/watch?v=..." fluid />
                  </div>
                  <div v-if="editYoutubeUrl" style="margin-top: 0.5rem; border-radius: 8px; overflow: hidden; aspect-ratio: 16/9; max-width: 400px;">
                    <iframe
                      :src="`https://www.youtube-nocookie.com/embed/${editYoutubeUrl.match(/(?:v=|youtu\.be\/|embed\/)([a-zA-Z0-9_-]{11})/)?.[1] || ''}`"
                      style="width: 100%; height: 100%; border: none;"
                      allow="accelerometer; encrypted-media; gyroscope; picture-in-picture"
                      allowfullscreen
                    />
                  </div>
                  <div style="display: flex; gap: 0.5rem;">
                    <div style="display: flex; flex-direction: column; gap: 0.25rem; flex: 1;">
                      <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Start Time (seconds)</label>
                      <InputText v-model.number="editYoutubeStartSeconds" placeholder="0" type="number" fluid />
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem; flex: 1;">
                      <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">End Time (seconds)</label>
                      <InputText v-model.number="editYoutubeEndSeconds" placeholder="(full video)" type="number" fluid />
                    </div>
                  </div>
                </template>

                <template v-if="activityUI.isStudyMethodType">
                  <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Passage Reference</label>
                    <InputText v-model="editPassageReference" placeholder="e.g. Romans 1:1-5" fluid />
                  </div>
                </template>

                <!-- Source References -->
                <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                  <div style="display: flex; justify-content: space-between; align-items: center;">
                    <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; color: var(--p-text-muted-color);">Source References</label>
                    <Button label="Add Reference" icon="pi pi-book" severity="secondary" outlined size="small" @click="isAddRefOpen = true" />
                  </div>
                  <div v-if="activityUI.currentActivity?.sourceReferences?.length" style="display: flex; flex-direction: column; gap: 0.25rem;">
                    <div v-for="sref in activityUI.currentActivity.sourceReferences" :key="sref.id" style="font-size: 0.75rem; padding: 0.5rem; border: 1px solid var(--p-content-border-color); border-radius: var(--p-border-radius);">
                      {{ sref.passageReference || 'Unknown passage' }}
                      <span v-if="sref.bookName" style="color: var(--p-text-muted-color); margin-left: 0.25rem;">({{ sref.bookName }} {{ sref.chapterStart }}:{{ sref.verseStart }}-{{ sref.verseEnd }})</span>
                    </div>
                  </div>
                  <small v-else style="color: var(--p-text-muted-color);">No source references.</small>
                  <Panel v-if="isAddRefOpen" header="New Reference">
                    <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                      <InputText v-model="newRefPassage" placeholder="Passage reference (e.g. Romans 1:1-5)" fluid />
                      <div style="display: flex; gap: 0.5rem;"><InputText v-model="newRefBookName" placeholder="Book name" /><InputText v-model.number="newRefBookNumber" placeholder="Book #" type="number" style="width: 5rem;" /></div>
                      <div style="display: flex; gap: 0.5rem;"><InputText v-model.number="newRefChapterStart" placeholder="Ch" type="number" style="width: 4rem;" /><InputText v-model.number="newRefVerseStart" placeholder="V start" type="number" style="width: 5rem;" /><InputText v-model.number="newRefVerseEnd" placeholder="V end" type="number" style="width: 5rem;" /></div>
                      <div style="display: flex; gap: 0.25rem;"><Button label="Add" size="small" @click="handleAddSourceRef" /><Button label="Cancel" severity="secondary" text size="small" @click="isAddRefOpen = false" /></div>
                    </div>
                  </Panel>
                </div>

                <!-- Help Panel -->
                <Panel header="Help Panel" toggleable collapsed>
                  <div style="display: flex; flex-direction: column; gap: 0.75rem;">
                    <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer; font-size: 0.875rem;">
                      <ToggleSwitch v-model="editIsHelpEnabled" /> Enable help panel
                    </label>
                    <template v-if="editIsHelpEnabled">
                      <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                        <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; color: var(--p-text-muted-color);">Help Title</label>
                        <InputText v-model="editHelpTitle" placeholder="Help title" fluid />
                      </div>
                      <div style="display: flex; flex-direction: column; gap: 0.25rem;">
                        <label style="font-size: 0.75rem; font-weight: 500; text-transform: uppercase; color: var(--p-text-muted-color);">Help Description</label>
                        <Textarea v-model="editHelpDescription" :rows="3" placeholder="Help description..." fluid />
                      </div>
                    </template>
                  </div>
                </Panel>

                <!-- Actions -->
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                  <Button :label="activityUI.isSaving ? 'Saving...' : 'Save Activity'" :disabled="activityUI.isSaving" size="small" @click="handleSaveActivity" />
                  <Button label="Reset" icon="pi pi-refresh" severity="secondary" outlined size="small" @click="handleReset" />
                  <Message v-if="activityUI.saveError" severity="error" :closable="false" style="margin: 0;">{{ activityUI.saveError }}</Message>
                </div>
              </div>
            </AccordionContent>
          </AccordionPanel>
        </Accordion>
      </VueDraggable>
    </template>
    <div v-else style="font-size: 0.875rem; color: var(--p-text-muted-color); padding: 1rem 0; text-align: center;">No activities yet. Add your first activity below.</div>

    <!-- Add activity -->
    <div style="display: flex; align-items: center; gap: 0.5rem; padding-top: 0.5rem;">
      <template v-if="isAddFormOpen">
        <Select v-model="newActivityType" :options="activityTypes" option-label="label" option-value="value" :style="{ width: '8rem' }" />
        <InputText v-model="newActivityTitle" placeholder="Activity title..." fluid @keydown.enter="handleAdd" @keydown.escape="closeAddForm" />
        <Button icon="pi pi-plus" size="small" @click="handleAdd" />
        <Button icon="pi pi-times" severity="secondary" text size="small" @click="closeAddForm" />
      </template>
      <Button v-else label="Add Activity" icon="pi pi-plus" severity="secondary" outlined size="small" @click="openAddForm" />
    </div>
  </div>
</template>
