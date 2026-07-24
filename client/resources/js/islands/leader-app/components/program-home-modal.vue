<script setup lang="ts">
// ProgramHomeModal — production content of the .programHome overlay (web twin
// of iPhone ProgramHomeModalContent in StudyProgramHome.swift). Loads the
// program via the leader-program store and renders the shared ProgramHome twin
// inside a SlideStack whose detail pane hosts the Edit Program settings
// (iOS detailScreen = .editProgram; EditDay lands here in stage 3).
import { computed, inject, onMounted, reactive, ref, watch } from 'vue'
import ProgramHome from '../../../components/card/program-home/program-home.vue'
import ExportConfirmOverlay from '../../../components/card/export-confirm-overlay/export-confirm-overlay.vue'
import SlideStack from '../overlay/slide-stack.vue'
import EditProgramPane from './edit-program-pane.vue'
import EditDayPane from './edit-day-pane.vue'
import EnrollmentSyncPane from './enrollment-sync-pane.vue'
import ConfirmationOverlayModal from './confirmation-overlay-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import {
  useLeaderProgram,
  type ExportPreview,
  type PublishPreview,
  type PublishPreviewLesson,
} from '../stores/leader-program.store'

// `preloaded`: skip the initial fetch when the store already holds this program
// (the create flow seeds it from the POST response — iOS renders Program Home
// straight from createProgram's payload with no re-fetch).
const props = defineProps<{ programId: string; preloaded?: boolean }>()

const store = useLeaderProgram()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

// iOS canEdit = program.isEditable(by: currentUser.id) — creator only. The
// leader's server user id is bootstrapped as an island prop (LeaderController).
const memberId = inject<string | null>('memberId', null)
const canEdit = computed(() =>
  Boolean(memberId && store.program?.creatorId && store.program.creatorId === memberId),
)

onMounted(() => {
  if (props.preloaded && store.program?.id === props.programId) return
  store.loadProgram(props.programId)
})

const selectedTab = ref(0)

// ── Enrollments tab (iOS enrollmentsContent .task → getProgramEnrollments) ──
// Cache-first: loaded once when the tab is first selected.
const enrollments = ref<
  Array<{ id: string; name: string; subtitle?: string; imageUrl?: string; dateRange: string }>
>([])
const enrollmentsLoading = ref(false)
let enrollmentsLoaded = false

watch(selectedTab, async (tab) => {
  if (tab !== 1 || enrollmentsLoaded) return
  enrollmentsLoading.value = true
  try {
    enrollments.value = await store.loadProgramEnrollments(props.programId)
    enrollmentsLoaded = true
  } catch {
    // Silent: iOS records console-only; the empty state stands (no cache).
  } finally {
    enrollmentsLoading.value = false
  }
})

// SlideStack detail state — 'editProgram', 'day:<lessonId>', or
// 'sync:<enrollmentId>' (study-sync settings for an enrolled group).
const detailScreen = ref<string | null>(null)

const detailLessonId = computed(() =>
  detailScreen.value?.startsWith('day:') ? detailScreen.value.slice(4) : null,
)

// Enrollments-tab row tap → the enrollment's Study Sync settings pane.
function openEnrollmentSync(enrollmentId: string): void {
  detailScreen.value = `sync:${enrollmentId}`
}

function enrollmentName(enrollmentId: string): string | undefined {
  return enrollments.value.find((e) => e.id === enrollmentId)?.name
}

// Edit form state — seeded when the gear is tapped (iOS keeps these as
// separate @State so the back chevron discards cleanly).
const editName = ref('')
const editDescription = ref('')
const editPublished = ref(false)
const editTags = ref<string[]>([])
const saving = ref(false)
const uploadingCover = ref(false)

const lessons = computed(() => store.program?.lessons ?? [])

function close(): void {
  overlay?.dismiss()
}

// Gear: seed the edit fields from the loaded program, then slide (iOS
// ProgramHomePage gearshape handler).
function openSettings(): void {
  const p = store.program
  if (!p) return
  editName.value = p.name
  editDescription.value = p.description
  editPublished.value = p.isPublished
  editTags.value = [...p.tags]
  detailScreen.value = 'editProgram'
}

async function saveSettings(): Promise<void> {
  const p = store.program
  if (!p || saving.value) return
  saving.value = true
  try {
    await store.saveProgram(p.id, {
      name: editName.value.trim() || p.name,
      description: editDescription.value.trim(),
      isPublished: editPublished.value,
      tags: editTags.value,
    })
    detailScreen.value = null
  } catch {
    // Save failed and the store reverted — stay on the pane so nothing is lost.
  } finally {
    saving.value = false
  }
}

// All confirms/alerts present through the shared confirm-dialog service
// (ConfirmDialogHost renders them full-screen at the app root).
const confirmDialog = useConfirmDialog()

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

// Add-day confirm (iOS DialogOverlay "Add a new day?") — sticky: the tapped
// button flips to "Adding..." while the request runs, then the dialog closes.
const addingDay = ref(false)

async function requestAddDay(): Promise<void> {
  const p = store.program
  if (!p || addingDay.value) return
  const dialog = confirmDialog.present({
    title: 'Add a new day?',
    message: 'This will add a new day to the end of your study program.',
    buttons: [
      { label: 'Add day', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
    sticky: true,
  })
  const choice = await dialog.choice
  if (choice !== 0) {
    dialog.close()
    return
  }
  addingDay.value = true
  dialog.update({
    buttons: [
      { label: 'Adding...', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  try {
    await store.addLesson(p.id)
  } catch (err) {
    showError(err instanceof Error ? err.message : "Couldn't add the day")
  } finally {
    addingDay.value = false
    dialog.close()
  }
}

// ── Swipe-to-delete + drag-reorder (iOS lessonCard SwipeableCard + Dragula) ──

// iOS native .alert "Permanently delete day {n}?" — exact strings.
const deletingLesson = ref(false)

async function onDeleteLesson(id: string): Promise<void> {
  const lesson = store.program?.lessons.find((l) => l.id === id)
  if (!lesson || deletingLesson.value) return
  const choice = await confirmDialog.confirm({
    title: `Permanently delete day ${lesson.day}?`,
    message: 'This will permanently delete this day and all associated data from the program.',
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0 || !store.program || deletingLesson.value) return
  deletingLesson.value = true
  try {
    await store.deleteLesson(store.program.id, lesson.id)
  } catch (err) {
    showError(err instanceof Error ? err.message : 'Failed to delete lesson')
  } finally {
    deletingLesson.value = false
  }
}

async function onReorderLessons(ids: string[]): Promise<void> {
  if (!store.program) return
  try {
    await store.reorderLessons(store.program.id, ids)
  } catch (err) {
    showError(err instanceof Error ? err.message : 'Failed to reorder lessons')
  }
}

// ── Publish badge (iOS togglePublishStatus + gating) ──

// iOS lessonsWithoutActivities: every lesson with an empty activities array.
const lessonsWithoutActivities = computed(
  () => (store.program?.lessons ?? []).filter((l) => !l.activities.length),
)

// iOS publishBlockedMessage — dynamically pluralized, exact strings.
const publishBlockedMessage = computed(() => {
  const n = lessonsWithoutActivities.value.length
  return n === 1
    ? 'There is 1 lesson without an activity. Every lesson must have at least one activity before this study can be published.'
    : `There are ${n} lessons without an activity. Every lesson must have at least one activity before this study can be published.`
})

const togglingPublish = ref(false)

function showPublishBlockedDialog(): void {
  // iOS native .alert "Cannot Publish".
  void confirmDialog.confirm({
    title: 'Cannot Publish',
    message: publishBlockedMessage.value,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

async function onTogglePublish(): Promise<void> {
  const p = store.program
  if (!p) return
  // iOS badge tap: publishing a draft is blocked while any lesson is empty;
  // unpublishing is never blocked.
  if (!p.isPublished && lessonsWithoutActivities.value.length) {
    showPublishBlockedDialog()
    return
  }
  if (p.isPublished) {
    await onPublishedBadgeTap()
    return
  }
  const choice = await confirmDialog.confirm({
    title: 'Publish this study?',
    message: 'Publishing the study will make it available for group enrollment.',
    buttons: [
      { label: 'Publish', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0 || togglingPublish.value) return
  // iOS re-checks the gate inside togglePublishStatus.
  if (lessonsWithoutActivities.value.length) {
    showPublishBlockedDialog()
    return
  }
  togglingPublish.value = true
  try {
    await store.setPublished(p.id, true)
  } catch (err) {
    showError(err instanceof Error ? err.message : "Couldn't update the study")
  } finally {
    togglingPublish.value = false
  }
}

// ── Published badge (study-sync phase 6): the badge is now the home of the
//    explicit "Publish updates" action — the publish, not the edit, is the
//    unit of enrollment sync. The dialog offers both actions and IS the
//    confirmation for each (no second dialog for unpublish). ──

const publishingUpdates = ref(false)

async function onPublishedBadgeTap(): Promise<void> {
  const p = store.program
  if (!p || publishingUpdates.value || togglingPublish.value) return
  const dialog = confirmDialog.present({
    title: 'Published study',
    message: 'Checking for changes since the last publish…',
    buttons: [
      { label: 'Publish updates', style: 'primary' },
      { label: 'Switch to Draft', style: 'secondary' },
      { label: 'Cancel', style: 'secondary' },
    ],
    sticky: true,
  })

  // The badge tap is the decision moment — the pending-changes summary loads
  // straight into THIS dialog (last published + what changed since). `settled`
  // stops a late response from patching whatever dialog replaced this one.
  let settled = false
  latestPublishPreview = null
  void store
    .loadPublishPreview(p.id)
    .then((preview) => {
      latestPublishPreview = preview
      if (!settled) dialog.update({ message: publishPreviewMessage(preview) })
    })
    .catch(() => {
      // Silent: preview is advisory — fall back to the generic message; the
      // publish itself is still no-op-guarded server-side.
      if (!settled) {
        dialog.update({
          message:
            'Publish your latest edits to enrolled groups as a new version, or switch this study back to draft.',
        })
      }
    })

  const choice = await dialog.choice
  settled = true
  if (choice === 0) {
    await runPublishUpdates(dialog)
    return
  }
  dialog.close()
  if (choice !== 1) return
  // Explain what switching to draft means for enrolled groups before doing it —
  // no cascade, no kick-out (monday#12268464531). The count is lazy-loaded, so
  // fetch on demand; a failed or zero count simply skips the notice.
  let activeEnrolled = 0
  try {
    activeEnrolled = (await store.loadProgramEnrollments(p.id)).filter((e) => e.isActive).length
  } catch {
    activeEnrolled = 0
  }
  if (activeEnrolled > 0) {
    const proceed = await confirmDialog.confirm({
      title: `Switch "${p.name}" to draft?`,
      message: switchToDraftMessage(activeEnrolled),
      buttons: [
        { label: 'Switch to Draft', style: 'primary' },
        { label: 'Cancel', style: 'secondary' },
      ],
    })
    if (proceed !== 0) return
  }
  togglingPublish.value = true
  try {
    await store.setPublished(p.id, false)
  } catch (err) {
    showError(err instanceof Error ? err.message : "Couldn't update the study")
  } finally {
    togglingPublish.value = false
  }
}

// Explain-only copy for the switch-to-draft confirm, pluralized on the active
// enrollment count (monday#12268464531).
function switchToDraftMessage(n: number): string {
  const groups = n === 1 ? '1 group is' : `${n} groups are`
  return `${groups} currently enrolled. Switching to draft removes this study from new enrollments. Groups already enrolled keep their scheduled lessons — they are not removed.`
}

// Condensed preview: last-published line, a count matrix ("2 changed ·
// 1 added"), then capped per-day lines. \n renders via pre-line message CSS.
function publishPreviewMessage(preview: PublishPreview): string {
  const paragraphs: string[] = []

  if (preview.lastPublished) {
    const date = new Date(preview.lastPublished.publishedAt).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    })
    paragraphs.push(`Last published ${date} (version ${preview.lastPublished.versionNumber})`)
  } else {
    paragraphs.push(
      "Changes aren't tracked for this study yet — publishing creates version 1, the baseline enrolled groups sync to.",
    )
  }

  if (preview.upToDate) {
    paragraphs.push('No changes since — enrolled groups have the latest version.')
    return paragraphs.join('\n\n')
  }

  const changes = preview.changes
  if (changes) {
    const matrix: string[] = []
    if (changes.changed.length) matrix.push(`${changes.changed.length} changed`)
    if (changes.added.length) matrix.push(`${changes.added.length} added`)
    if (changes.removed.length) matrix.push(`${changes.removed.length} removed`)
    if (changes.moved.length) matrix.push(`${changes.moved.length} moved`)
    if (matrix.length) paragraphs.push(matrix.join(' · '))

    const shortTitle = (title: string | null) =>
      !title ? '' : title.length > 24 ? ` — ${title.slice(0, 24)}…` : ` — ${title}`
    const line = (l: PublishPreviewLesson, verb: string) =>
      `Day ${l.dayNumber} ${verb}${shortTitle(l.title)}`
    let detail = [
      ...changes.changed.map((l) => line(l, 'changed')),
      ...changes.added.map((l) => line(l, 'added')),
      ...changes.removed.map((l) => line(l, 'removed')),
      ...changes.moved.map((m) => `Day ${m.fromDay} → ${m.toDay} moved${shortTitle(m.title)}`),
    ]
    const cap = 5
    if (detail.length > cap) {
      detail = [...detail.slice(0, cap), `+ ${detail.length - cap} more`]
    }
    paragraphs.push(detail.join('\n'))
  }

  paragraphs.push('Syncing groups receive these on publish.')
  return paragraphs.join('\n\n')
}

// Latest loaded preview — composes the publish success message (version +
// count matrix). Plain var: only read at publish time, never rendered raw.
let latestPublishPreview: PublishPreview | null = null

// Publishing hands off to a processing ConfirmationOverlay — the circle spins
// while the version is cut, then fills green with the checkmark and the
// success message (mirrors iOS and the export flow; reactive getters flip
// isProcessing/message live inside the presented overlay).
const publishConfirmation = reactive({
  isProcessing: true,
  message: '',
})

async function runPublishUpdates(dialog: ReturnType<typeof confirmDialog.present>): Promise<void> {
  const p = store.program
  if (!p || publishingUpdates.value) {
    dialog.close()
    return
  }
  publishingUpdates.value = true
  dialog.close()

  publishConfirmation.isProcessing = true
  publishConfirmation.message = publishSuccessMessage(p.name)
  overlayManager.present(ROUTES.confirmationOverlay, ConfirmationOverlayModal, {
    tone: 'success',
    icon: CHECKMARK,
    buttonLabel: 'Done',
    processingMessage: 'Publishing updates',
    get isProcessing() {
      return publishConfirmation.isProcessing
    },
    get message() {
      return publishConfirmation.message
    },
    onSelect: () => overlayManager.dismiss(ROUTES.confirmationOverlay.id),
  })

  try {
    const result = await store.publishUpdates(p.id)
    if (result.alreadyUpToDate) {
      // Raced with another publish — nothing was cut.
      overlayManager.dismiss(ROUTES.confirmationOverlay.id)
      void confirmDialog.confirm({
        title: 'Already up to date',
        message: 'Enrolled groups already have the latest version of this study.',
        buttons: [{ label: 'OK', style: 'secondary' }],
      })
    } else {
      if (result.version) {
        publishConfirmation.message = publishSuccessMessage(p.name, result.version.versionNumber)
      }
      // Circle fills green + checkmark; message swaps in.
      publishConfirmation.isProcessing = false
    }
  } catch (err) {
    overlayManager.dismiss(ROUTES.confirmationOverlay.id)
    showError(err instanceof Error ? err.message : "Couldn't publish updates")
  } finally {
    publishingUpdates.value = false
  }
}

// "**{name}** version N published." + count matrix from the loaded preview.
function publishSuccessMessage(programName: string, versionNumber?: number): string {
  const version = versionNumber ?? (latestPublishPreview?.lastPublished?.versionNumber ?? 0) + 1
  const lines = [`**${programName}** version ${version} published.`]
  const changes = latestPublishPreview?.changes
  if (changes) {
    const matrix: string[] = []
    if (changes.changed.length) matrix.push(`${changes.changed.length} changed`)
    if (changes.added.length) matrix.push(`${changes.added.length} added`)
    if (changes.removed.length) matrix.push(`${changes.removed.length} removed`)
    if (changes.moved.length) matrix.push(`${changes.moved.length} moved`)
    if (matrix.length) lines.push(matrix.join(' · '))
  }
  lines.push('Syncing groups are receiving these updates.')
  return lines.join('\n')
}

// ── Export flow (iOS loadExportPreview → ExportConfirmOverlay →
//    exportProgram → ConfirmationOverlay Save/Discard) ──

const overlayManager = useOverlayManager()

const exportPreview = ref<ExportPreview | null>(null)
const showExportConfirm = ref(false)
const loadingExportPreview = ref(false)
const exporting = ref(false)
let exportedFile: { blob: Blob; filename: string } | null = null

// SF "checkmark" — the success circle glyph (40pt medium on iOS).
const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'

// Reactive so isProcessing/message flip live inside the presented overlay.
const exportConfirmation = reactive({
  isProcessing: true,
  message: '',
})

// Publish from the Export & Publish card — close the card, then run the
// same flow as the Published/Draft badge (draft confirm or pending-changes
// dialog).
function onExportOverlayPublish(): void {
  showExportConfirm.value = false
  void onTogglePublish()
}

async function onExport(): Promise<void> {
  const p = store.program
  if (!p || loadingExportPreview.value) return
  loadingExportPreview.value = true
  try {
    exportPreview.value = await store.loadExportPreview(p.id)
    showExportConfirm.value = true
  } catch {
    showError("Couldn't load the export preview")
  } finally {
    loadingExportPreview.value = false
  }
}

function dismissExportConfirmation(): void {
  overlayManager.dismiss(ROUTES.confirmationOverlay.id)
}

// iOS "Save" → share sheet; web equivalent: download the .makeready file.
function saveExportedFile(): void {
  dismissExportConfirmation()
  const file = exportedFile
  exportedFile = null
  if (!file) return
  const url = URL.createObjectURL(file.blob)
  const a = document.createElement('a')
  a.href = url
  a.download = file.filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

function discardExportedFile(): void {
  dismissExportConfirmation()
  exportedFile = null
}

async function runExport(): Promise<void> {
  const p = store.program
  if (!p || exporting.value) return
  exporting.value = true
  exportedFile = null
  // iOS: dismiss the confirm card, then present the processing confirmation.
  showExportConfirm.value = false
  exportConfirmation.isProcessing = true
  exportConfirmation.message = `**${p.name}** has been exported successfully.`
  overlayManager.present(ROUTES.confirmationOverlay, ConfirmationOverlayModal, {
    tone: 'success',
    icon: CHECKMARK,
    buttonLabel: 'Save',
    secondaryButtonLabel: 'Discard',
    processingMessage: 'Exporting study program',
    // Reactive getters — overlay-host re-reads these as the export progresses.
    get isProcessing() {
      return exportConfirmation.isProcessing
    },
    get message() {
      return exportConfirmation.message
    },
    onSelect: saveExportedFile,
    onSecondary: discardExportedFile,
  })
  try {
    exportedFile = await store.exportProgram(p.id)
    exportConfirmation.isProcessing = false
  } catch {
    dismissExportConfirmation()
    showError("Couldn't export the study program")
  } finally {
    exporting.value = false
  }
}

// Cover picks auto-upload (iOS .onChange(of: coverImage)).
function onCoverPicked(file: File): void {
  const p = store.program
  if (!p) return
  const reader = new FileReader()
  reader.onload = async () => {
    uploadingCover.value = true
    try {
      await store.uploadCover(p.id, String(reader.result), file.type || 'image/jpeg')
    } catch {
      // Upload failed — the cover simply stays unchanged.
    } finally {
      uploadingCover.value = false
    }
  }
  reader.readAsDataURL(file)
}
</script>

<template>
  <div class="ProgramHomeModal">
    <!-- Loading / error states mirror iOS (PageTitle + centered state). -->
    <div v-if="store.error" class="ProgramHomeModal__state">
      {{ store.error }}
    </div>
    <SlideStack v-else :item="detailScreen">
      <ProgramHome
        :program-name="store.program?.name ?? ''"
        :program-description="store.program?.description ?? ''"
        :cover-url="store.program?.coverImageUrl ?? ''"
        :has-cover-image="!!store.program?.coverImageUrl"
        :published="store.program?.isPublished ?? false"
        :selected-tab="selectedTab"
        :lessons="lessons"
        :loading="store.loading"
        :enrollments="enrollments"
        :enrollments-loading="enrollmentsLoading"
        :can-edit="canEdit"
        :editable="canEdit"
        @close="close"
        @select-tab="selectedTab = $event"
        @settings="openSettings"
        @select-lesson="detailScreen = `day:${$event}`"
        @select-enrollment="openEnrollmentSync"
        @add-day="requestAddDay()"
        @delete-lesson="onDeleteLesson"
        @reorder-lessons="onReorderLessons"
        @toggle-publish="onTogglePublish"
        @export="onExport"
      />
      <template #detail="{ item }">
        <EditDayPane
          v-if="String(item).startsWith('day:') && store.program"
          :key="String(item)"
          :program-id="store.program.id"
          :lesson-id="String(item).slice(4)"
          @back="detailScreen = null"
        />
        <EnrollmentSyncPane
          v-else-if="String(item).startsWith('sync:')"
          :key="String(item)"
          :enrollment-id="String(item).slice(5)"
          :group-name="enrollmentName(String(item).slice(5))"
          @back="detailScreen = null"
        />
        <EditProgramPane
          v-else
          v-model:name="editName"
          v-model:description="editDescription"
          v-model:published="editPublished"
          v-model:tags="editTags"
          :cover-url="store.program?.coverImageUrl ?? ''"
          :saving="saving"
          :uploading-cover="uploadingCover"
          @back="detailScreen = null"
          @save="saveSettings"
          @cover-picked="onCoverPicked"
        />
      </template>
    </SlideStack>




    <!-- Export preview card (iOS ExportConfirmOverlay: ultraThinMaterial +
         black@0.5 scrim, 250ms ease-out in / 200ms ease-in out, tap-outside
         dismisses). -->
    <Transition name="ProgramHomeModal-export">
      <div
        v-if="showExportConfirm"
        class="ProgramHomeModal__exportScrim"
        @click.self="showExportConfirm = false"
      >
        <ExportConfirmOverlay
          v-if="exportPreview"
          class="ProgramHomeModal__exportCard"
          :program-name="exportPreview.name"
          :days="exportPreview.days"
          :activities="exportPreview.activities"
          :reads="exportPreview.reads"
          :videos="exportPreview.videos"
          :user-inputs="exportPreview.userInputs"
          :read-blocks="exportPreview.readBlocks"
          :scripture-refs="exportPreview.scriptureRefs"
          :template-name="exportPreview.templateName"
          :exporting="exporting"
          @export="runExport"
          @publish="onExportOverlayPublish"
          @cancel="showExportConfirm = false"
        />
      </div>
    </Transition>


  </div>
</template>

<style scoped>
.ProgramHomeModal {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.ProgramHomeModal :deep(.SlideStack) {
  flex: 1 1 auto;
}

/* The modal sheet owns the scroll; the panes fill it. */
.ProgramHomeModal :deep(.ProgramHome) {
  height: 100%;
}

.ProgramHomeModal__state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  color: var(--color-white-50);
}

/* Export preview chrome — iOS ExportConfirmOverlay: ultraThinMaterial(dark) +
   black@0.5 scrim; card scales 0.9→1; enter 250ms ease-out (pagePushBrisk),
   exit 200ms ease-in (Motion.exit). Card carries 32px screen margins. */
.ProgramHomeModal__exportScrim {
  position: absolute;
  inset: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 32px;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}

.ProgramHomeModal__exportCard {
  transition: transform 250ms ease-out, opacity 250ms ease-out;
}

.ProgramHomeModal-export-enter-active {
  transition: opacity 250ms ease-out;
}

.ProgramHomeModal-export-leave-active {
  transition: opacity 200ms ease-in;
}

.ProgramHomeModal-export-leave-active .ProgramHomeModal__exportCard {
  transition: transform 200ms ease-in, opacity 200ms ease-in;
}

.ProgramHomeModal-export-enter-from,
.ProgramHomeModal-export-leave-to {
  opacity: 0;
}

.ProgramHomeModal-export-enter-from .ProgramHomeModal__exportCard,
.ProgramHomeModal-export-leave-to .ProgramHomeModal__exportCard {
  transform: scale(0.9);
}
</style>
