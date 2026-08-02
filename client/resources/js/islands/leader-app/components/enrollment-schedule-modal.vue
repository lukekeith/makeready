<script setup lang="ts">
// EnrollmentScheduleModal — production host of the `.enrollmentSchedule`
// overlay (iOS EnrollmentSchedulePage): the EnrollmentSchedule twin inside a
// SlideStack whose detail panes are the per-day editor (EditEnrollmentDay
// CORE — title + activity add/delete/clear/reorder) and the existing
// EnrollmentSyncPane (the sync icon's target).
//
// iOS mechanics ported: row tap → .lessonActionMenu (Edit Activities / Open
// Lesson / Share Lesson / Add Lesson / Delete); swipe share/calendar/trash
// (calendar = iOS TODO stub, deliberately inert); "Add a new lesson?" sticky
// dialog; "Delete Lesson?" alert with iOS-exact strings.
//
// Per-activity CONTENT editors (iOS EditEnrollmentDay editor branches): the
// day pane owns a NESTED SlideStack (iOS SlideStack(item:$editingActivityId))
// whose detail hosts the shared editors with the `.enrollment` action
// provider (scheduledActivityActions). Activity tap: READ / USER_INPUT /
// YOUTUBE / EXEGESIS slide to their editor; VIDEO opens the picker
// (unconfigured) or playback modal (configured) — iOS fullScreenCovers.
// Preview buttons are OMITTED in scheduled mode: iOS builds
// /preview/activity/{scheduledActivityId}, which the preview endpoint
// cannot resolve (program activities only) — it 404s there too.
import { computed, inject, onMounted, ref, watch } from 'vue'
import EnrollmentSchedule from '../../../components/card/enrollment-schedule/enrollment-schedule.vue'
import LessonActionMenu from '../../../components/card/lesson-action-menu/lesson-action-menu.vue'
import CardLessonActivity from '../../../components/card/card-lesson-activity/card-lesson-activity.vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import TextInput from '../../../components/card/text-input/text-input.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import SwipeableCard from '../../../components/card/swipeable-card/swipeable-card.vue'
import DragulaList from '../../../components/card/dragula-list/dragula-list.vue'
import EditScheduledUserInput from '../../../components/card/edit-scheduled-user-input/edit-scheduled-user-input.vue'
import SlideStack from '../overlay/slide-stack.vue'
import AddActivityMenu from './add-activity-menu.vue'
import EnrollmentSyncPane from './enrollment-sync-pane.vue'
import EditYoutubeActivityPane from './edit-youtube-activity-pane.vue'
import EditReadActivityPane from './edit-read-activity-pane.vue'
import EditExegesisActivityPane from './edit-exegesis-activity-pane.vue'
import VideoActivityPickerModal from './video-activity-picker-modal.vue'
import VideoPlaybackModal from './video-playback-modal.vue'
import { OverlayPriority, ROUTES } from '../overlay/overlay-routes'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderProgram } from '../stores/leader-program.store'
import {
  useLeaderEnrollmentSchedule,
  type ScheduleEntry,
  type ScheduledActivityRow,
} from '../stores/leader-enrollment-schedule.store'

const props = defineProps<{
  enrollmentId: string
  /** iOS titleOverride — most entries pass "Lessons". */
  titleOverride?: string
  /** Open straight into a day's editor once the schedule loads. iOS presents
   *  `.editEnrollmentDay` as its own modal from Calendar/MainHome; on web the
   *  day editor lives inside this modal, so those entries seed it here. */
  initialScheduleId?: string
  /** Called after a mutation the presenter may care about (delete/add). */
  onChanged?: () => void
}>()

const store = useLeaderEnrollmentSchedule()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

onMounted(async () => {
  const details = store.loadDetails(props.enrollmentId)
  void store.loadCompletionStats(props.enrollmentId)
  await details
  // Calendar / MainHome "Edit Activities" opens a specific day directly.
  if (props.initialScheduleId) {
    const schedule = store.data?.schedules.find((s) => s.id === props.initialScheduleId)
    if (schedule) openDayEditor(schedule)
  }
})

const title = computed(
  () => props.titleOverride ?? store.data?.programName ?? 'Schedule'
)

// SlideStack detail: 'day:<scheduleId>' or 'sync'.
const detailScreen = ref<string | null>(null)

const addingLesson = ref(false)

function close(): void {
  overlay?.dismiss()
}

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

// ── Add lesson (iOS DialogOverlay, sticky "Adding...") ──
async function requestAddLesson(): Promise<void> {
  if (addingLesson.value) return
  const dialog = confirmDialog.present({
    title: 'Add a new lesson?',
    message: "This will schedule the study's next lesson at the end of the enrollment.",
    buttons: [
      { label: 'Add lesson', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
    sticky: true,
  })
  const choice = await dialog.choice
  if (choice !== 0) {
    dialog.close()
    return
  }
  addingLesson.value = true
  dialog.update({
    buttons: [
      { label: 'Adding...', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  try {
    const result = await store.addScheduledLesson(props.enrollmentId)
    if (result === 'allScheduled') {
      dialog.close()
      void confirmDialog.confirm({
        title: 'Add a new lesson?',
        message: 'All lessons in this study are already scheduled',
        buttons: [{ label: 'OK', style: 'secondary' }],
      })
      return
    }
    props.onChanged?.()
    dialog.close()
  } catch {
    dialog.close()
    showError("Couldn't add the lesson")
  } finally {
    addingLesson.value = false
  }
}

// ── Delete lesson (iOS native alert, exact strings) ──
async function requestDeleteRow(scheduleId: string): Promise<void> {
  const schedule = store.data?.schedules.find((s) => s.id === scheduleId)
  if (!schedule) return
  const studyName = store.data?.programName ?? 'Study'
  const choice = await confirmDialog.confirm({
    title: 'Delete Lesson?',
    message: `Are you sure you want to permanently delete Day ${schedule.day} of ${studyName} from the enrollment schedule?`,
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0) return
  try {
    await store.deleteSchedule(props.enrollmentId, scheduleId)
    props.onChanged?.()
  } catch {
    showError("Couldn't delete the lesson")
  }
}

// ── Share (swipe + menu row): lesson invite URL → navigator.share / copy ──
async function shareLesson(scheduleId: string): Promise<void> {
  try {
    const url = await store.loadLessonInvite(scheduleId)
    if (!url) throw new Error()
    if (navigator.share) await navigator.share({ url })
    else await navigator.clipboard.writeText(url)
  } catch {
    showError("Couldn't open the lesson")
  }
}

async function openLesson(scheduleId: string): Promise<void> {
  try {
    const url = await store.loadLessonInvite(scheduleId)
    if (!url) throw new Error()
    window.open(url, '_blank', 'noopener')
  } catch {
    showError("Couldn't open the lesson")
  }
}

// ── Row tap → lessonActionMenu (iOS-exact rows for this page) ──
function dismissMenu(): void {
  overlayManager.dismiss(ROUTES.lessonActionMenu.id)
}

// iOS LessonActionMenu rows for this page (onEditEnrollment NOT passed).
const PENCIL_LINE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M13 21h8"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>'
const SAFARI =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2.2 5-5 2.2 2.2-5z"/></svg>'
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14.5V3.5"/><path d="M8.2 7l3.8-3.8L15.8 7"/><path d="M5.5 11.5v7a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-7"/></svg>'

const DAY_MENU_ITEMS = [
  { icon: PENCIL_LINE, title: 'Edit Activities' },
  { icon: SAFARI, title: 'Open Lesson' },
  { icon: SHARE_UP, title: 'Share Lesson' },
  { icon: PLUS, title: 'Add Lesson' },
  { icon: TRASH_SVG, title: 'Delete', style: 'destructive' as const },
]

function openDayEditor(schedule: ScheduleEntry): void {
  editTitle.value = schedule.title ?? schedule.lessonTitle ?? ''
  originalTitle.value = editTitle.value
  editingActivityId.value = null
  detailScreen.value = `day:${schedule.id}`
}

function onRowTap(scheduleId: string): void {
  const schedule = store.data?.schedules.find((s) => s.id === scheduleId)
  if (!schedule) return
  const dateLabel = new Date(schedule.scheduledDate).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
  overlayManager.present(ROUTES.lessonActionMenu, LessonActionMenu, {
    studyName: store.data?.programName ?? 'Study',
    subtitle: `Day ${schedule.day} - ${dateLabel}`,
    items: DAY_MENU_ITEMS,
    onSelect: (i: number) => {
      dismissMenu()
      const label = DAY_MENU_ITEMS[i]?.title
      if (label === 'Edit Activities') openDayEditor(schedule)
      else if (label === 'Open Lesson') void openLesson(scheduleId)
      else if (label === 'Share Lesson') void shareLesson(scheduleId)
      else if (label === 'Add Lesson') void requestAddLesson()
      else if (label === 'Delete') void requestDeleteRow(scheduleId)
    },
    onClose: dismissMenu,
  })
}

// ═══ EditEnrollmentDay CORE (detail pane) ═══

const detailSchedule = computed<ScheduleEntry | null>(() => {
  if (!detailScreen.value?.startsWith('day:')) return null
  const id = detailScreen.value.slice(4)
  return store.data?.schedules.find((s) => s.id === id) ?? null
})

const editTitle = ref('')
const originalTitle = ref('')
const savingTitle = ref(false)
const addingActivity = ref(false)
const busyActivityId = ref<string | null>(null)

function dayFromSlot(item: unknown): ScheduleEntry | null {
  const id = String(item).startsWith('day:') ? String(item).slice(4) : null
  return id ? store.data?.schedules.find((s) => s.id === id) ?? null : null
}

const hasTitleChanges = computed(() => editTitle.value !== originalTitle.value)

async function saveTitle(schedule: ScheduleEntry): Promise<void> {
  if (savingTitle.value) return
  savingTitle.value = true
  try {
    await store.saveScheduleTitle(props.enrollmentId, schedule.id, editTitle.value)
    originalTitle.value = editTitle.value
  } catch {
    showError("Couldn't save the lesson title")
  } finally {
    savingTitle.value = false
  }
}

function cancelTitle(): void {
  editTitle.value = originalTitle.value
}

// iOS pending labels / row text mapping (EditEnrollmentDay.swift:316-366).
function activityDisplayName(type: string): string {
  if (type === 'READ') return 'Read'
  if (type === 'USER_INPUT') return 'Response'
  if (type === 'VIDEO') return 'Video'
  return type
}

function activityRowTitle(a: ScheduledActivityRow): string {
  if (a.type === 'VIDEO') return a.title ?? 'Video'
  return a.passageReference ?? a.title ?? activityDisplayName(a.type)
}

function activityRowDescription(a: ScheduledActivityRow): string {
  if (a.type === 'VIDEO') return a.isConfigured ? 'Video selected' : 'Select video'
  if (!a.isConfigured) {
    if (a.type === 'READ') return 'Provide text to read'
    if (a.type === 'EXEGESIS') return 'Select passage and add highlights'
    return 'Configure activity'
  }
  const block = a.readBlocks.find((b) => b.content)
  if (a.type === 'READ' && block) {
    return block.title ? `${block.title}\n${block.content}` : block.content ?? ''
  }
  return a.passageReference ?? a.title ?? activityDisplayName(a.type)
}

const CLEAR_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M8.5 8.5l7 7M15.5 8.5l-7 7"/></svg>'
const EYE_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const TRASH_SVG =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'

// iOS buildSlideButtons: eye (VIDEO && configured) → preview, xmark.circle
// (configured) → clear, trash → delete.
interface ActivitySwipeSpec {
  icon: string
  variant: 'reschedule' | 'delete'
  action: 'preview' | 'clear' | 'delete'
}

function activityButtons(a: ScheduledActivityRow): ActivitySwipeSpec[] {
  const buttons: ActivitySwipeSpec[] = []
  if (a.type === 'VIDEO' && a.isConfigured) {
    // iOS opens the web activity preview here, but scheduled activity ids
    // 404 on that endpoint — the working substitute is the playback modal.
    buttons.push({ icon: EYE_SVG, variant: 'reschedule', action: 'preview' })
  }
  if (a.isConfigured) buttons.push({ icon: CLEAR_SVG, variant: 'reschedule', action: 'clear' })
  buttons.push({ icon: TRASH_SVG, variant: 'delete', action: 'delete' })
  return buttons
}

async function onActivityAction(a: ScheduledActivityRow, index: number): Promise<void> {
  const action = activityButtons(a)[index]?.action
  if (action === 'preview') {
    openVideoPreview(a)
    return
  }
  const isClear = action === 'clear'
  if (isClear) {
    const choice = await confirmDialog.confirm({
      title: 'Clear activity?',
      message:
        'This will reset the activity to its default state, clearing any content that has been configured.',
      buttons: [
        { label: 'Clear', style: 'destructive' },
        { label: 'Cancel', style: 'secondary' },
      ],
    })
    if (choice !== 0) return
    busyActivityId.value = a.id
    try {
      await store.clearActivity(props.enrollmentId, a.id)
    } catch {
      showError("Couldn't clear the activity")
    } finally {
      busyActivityId.value = null
    }
    return
  }
  const choice = await confirmDialog.confirm({
    title: 'Delete activity?',
    message:
      'This will permanently remove this activity from the day. This action cannot be undone.',
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0) return
  busyActivityId.value = a.id
  try {
    await store.deleteActivity(props.enrollmentId, a.id)
  } catch {
    showError("Couldn't delete the activity")
  } finally {
    busyActivityId.value = null
  }
}

function openAddActivity(schedule: ScheduleEntry): void {
  overlayManager.present(ROUTES.addActivityMenu, AddActivityMenu, {
    onSelect: async (type: string) => {
      overlayManager.dismiss(ROUTES.addActivityMenu.id)
      addingActivity.value = true
      try {
        await store.addActivity(props.enrollmentId, schedule.id, type)
      } catch {
        showError("Couldn't add the activity")
      } finally {
        addingActivity.value = false
      }
    },
    onClose: () => overlayManager.dismiss(ROUTES.addActivityMenu.id),
  })
}

async function onReorder(schedule: ScheduleEntry, ids: string[]): Promise<void> {
  try {
    await store.reorderActivities(props.enrollmentId, schedule.id, ids)
    // Optimistic local order (iOS upserts AppState in place).
    schedule.activities.sort((a, b) => ids.indexOf(a.id) - ids.indexOf(b.id))
  } catch {
    showError("Couldn't reorder the activities")
    void store.loadDetails(props.enrollmentId, false)
  }
}

// ═══ Per-activity CONTENT editors (nested SlideStack, iOS EditEnrollmentDay) ═══

const programStore = useLeaderProgram()
const editingActivityId = ref<string | null>(null)
const savingEditor = ref(false)

// Resolve from the SLOT's mounted item (iOS inlineEditPane re-resolves from
// live state) so the editor survives the slide-out animation.
function activityRowFor(id: unknown): ScheduledActivityRow | null {
  for (const s of store.data?.schedules ?? []) {
    const row = s.activities.find((a) => a.id === id)
    if (row) return row
  }
  return null
}

function scheduleForActivity(id: unknown): ScheduleEntry | null {
  for (const s of store.data?.schedules ?? []) {
    if (s.activities.some((a) => a.id === id)) return s
  }
  return null
}

// iOS onTap (EditEnrollmentDay.swift:342-348 / :388-394).
function onActivityTap(a: ScheduledActivityRow): void {
  if (busyActivityId.value === a.id) return
  if (['READ', 'USER_INPUT', 'YOUTUBE', 'EXEGESIS'].includes(a.type)) {
    editingActivityId.value = a.id
  } else if (a.type === 'VIDEO') {
    if (a.isConfigured) openVideoPreview(a)
    else openVideoPicker(a)
  }
}

// Estimates/titles recalc server-side — refresh silently when an editor
// slides back (iOS reads live AppState the actions already upserted).
watch(editingActivityId, (id, prev) => {
  if (id === null && prev !== null) void store.loadDetails(props.enrollmentId, false)
})

// ── WRITE (iOS saveUserInputContent — the editor stays up while saving,
//    then slides back; failures surface after the optimistic dismiss) ──
async function saveUserInput(
  a: ScheduledActivityRow,
  fields: { title: string; isHelpEnabled: boolean; helpTitle: string; helpDescription: string }
): Promise<void> {
  if (savingEditor.value) return
  savingEditor.value = true
  busyActivityId.value = a.id
  try {
    // iOS sends toggleScheduledActivityHelp then updateScheduledActivity —
    // one PATCH carries the same fields here. Empty help fields are nulled so
    // toggling help OFF actually clears them (iOS omits them, which leaves
    // the toggle re-inferring ON next open).
    await store.updateScheduledActivityFields(a.id, {
      isHelpEnabled: fields.isHelpEnabled,
      ...(fields.title ? { title: fields.title } : {}),
      helpTitle: fields.isHelpEnabled && fields.helpTitle ? fields.helpTitle : null,
      helpDescription:
        fields.isHelpEnabled && fields.helpDescription ? fields.helpDescription : null,
    })
    editingActivityId.value = null
  } catch {
    editingActivityId.value = null
    showError("Couldn't save the activity")
  } finally {
    savingEditor.value = false
    busyActivityId.value = null
  }
}

// ── YOUTUBE (iOS updateScheduledActivityYouTube → PATCH {title, youtubeUrl}) ──
async function saveYoutube(
  a: ScheduledActivityRow,
  fields: { youtubeUrl: string; title: string }
): Promise<void> {
  if (savingEditor.value) return
  savingEditor.value = true
  try {
    await store.updateScheduledActivityFields(a.id, {
      ...(fields.title.trim() ? { title: fields.title.trim() } : {}),
      youtubeUrl: fields.youtubeUrl.trim() || null,
    })
    editingActivityId.value = null
  } catch {
    showError("Couldn't save the activity")
  } finally {
    savingEditor.value = false
  }
}

// ── VIDEO (iOS fullScreenCovers → managed-modal overlays; PATCH is
//    NON-optimistic — row spinner until the round-trip lands) ──
function openVideoPicker(a: ScheduledActivityRow): void {
  overlayManager.present(
    {
      id: 'videoActivityPicker',
      priority: OverlayPriority.modal,
      chrome: 'modal',
      dismissOnTapOutside: true,
    },
    VideoActivityPickerModal,
    {
      onSelect: async (v: { id: string; playbackUrl: string | null }) => {
        busyActivityId.value = a.id
        try {
          await store.updateScheduledActivityVideo(a.id, v.id, v.playbackUrl)
        } catch {
          showError("Couldn't add the video")
        } finally {
          busyActivityId.value = null
        }
      },
    }
  )
}

function openVideoPreview(a: ScheduledActivityRow): void {
  overlayManager.present(
    {
      id: 'videoActivityManager',
      priority: OverlayPriority.modal,
      chrome: 'modal',
      dismissOnTapOutside: true,
    },
    VideoPlaybackModal,
    {
      title: a.detail.video?.title ?? a.title ?? 'Video',
      playbackUrl: a.videoUrl ?? a.detail.video?.playbackUrl ?? null,
      thumbnailUrl: a.detail.video?.thumbnailUrl ?? null,
      onRemove: async () => {
        busyActivityId.value = a.id
        try {
          await store.removeScheduledActivityVideo(a.id)
        } catch {
          showError("Couldn't remove the video")
        } finally {
          busyActivityId.value = null
        }
      },
    }
  )
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
</script>

<template>
  <div class="EnrollmentScheduleModal">
    <SlideStack :item="detailScreen">
      <EnrollmentSchedule
        :title="title"
        left-icon="xmark"
        :rows="store.scheduleRows()"
        :loading="store.loading && !store.data"
        :error-message="!store.data && store.error ? store.error : ''"
        :adding-lesson="addingLesson"
        interactive
        @dismiss="close"
        @sync="detailScreen = 'sync'"
        @retry="store.loadDetails(props.enrollmentId)"
        @row-tap="onRowTap"
        @share="shareLesson"
        @delete-row="requestDeleteRow"
        @add-lesson="requestAddLesson()"
      />
      <template #detail="{ item }">
        <EnrollmentSyncPane
          v-if="item === 'sync'"
          :enrollment-id="props.enrollmentId"
          :group-name="undefined"
          @back="detailScreen = null"
        />
        <div
          v-else-if="dayFromSlot(item)"
          :key="String(item)"
          class="EnrollmentScheduleModal__day"
        >
          <!-- iOS EditEnrollmentDay owns its own SlideStack(item:
               $editingActivityId) — the day list slides to the per-type
               activity editors. -->
          <SlideStack :item="editingActivityId">
            <div v-if="dayFromSlot(item)" class="EnrollmentScheduleModal__dayInner">
              <div class="EnrollmentScheduleModal__dragSpacer"></div>
              <PageTitle
                v-if="hasTitleChanges"
                factory="linkTitleLink"
                :title="`Day ${dayFromSlot(item)!.day}`"
                left-link="Cancel"
                :right-link="savingTitle ? 'Saving...' : 'Save'"
                :right-link-disabled="savingTitle"
                @left="cancelTitle"
                @right="saveTitle(dayFromSlot(item)!)"
              />
              <PageTitle
                v-else
                factory="iconTitleLink"
                :title="`Day ${dayFromSlot(item)!.day}`"
                :left-icon="XMARK"
                right-link="Done"
                @left="detailScreen = null"
                @right="detailScreen = null"
              />
              <div class="EnrollmentScheduleModal__titleField">
                <TextInput
                  floating-label="Lesson title"
                  :text="editTitle"
                  interactive
                  @update:text="editTitle = $event"
                />
              </div>
              <div class="EnrollmentScheduleModal__dayScroll">
                <DragulaList
                  :items="dayFromSlot(item)!.activities"
                  :gap="4"
                  @reorder="onReorder(dayFromSlot(item)!, $event)"
                >
                  <template #item="{ item: act }">
                    <SwipeableCard
                      bare
                      :slide-buttons="activityButtons(act as ScheduledActivityRow)"
                      @action="onActivityAction(act as ScheduledActivityRow, $event)"
                      @tap="onActivityTap(act as ScheduledActivityRow)"
                    >
                      <div
                        class="EnrollmentScheduleModal__activity"
                        :class="{
                          'EnrollmentScheduleModal__activity--busy':
                            busyActivityId === (act as ScheduledActivityRow).id,
                        }"
                      >
                        <CardLessonActivity
                          size="small"
                          :type="(act as ScheduledActivityRow).type"
                          :title="activityRowTitle(act as ScheduledActivityRow)"
                          :description="activityRowDescription(act as ScheduledActivityRow)"
                          :status="(act as ScheduledActivityRow).isConfigured ? 'confirmed' : 'new'"
                          :estimated-minutes="(act as ScheduledActivityRow).estimatedMinutes"
                        />
                      </div>
                    </SwipeableCard>
                  </template>
                </DragulaList>
                <div class="EnrollmentScheduleModal__daySpacer"></div>
                <BoxButton
                  :icon="PLUS"
                  variant="secondary"
                  size="lg"
                  full-width
                  :icon-opacity="0.5"
                  :class="{ 'EnrollmentScheduleModal__add--busy': addingActivity }"
                  @click="!addingActivity && openAddActivity(dayFromSlot(item)!)"
                />
              </div>
            </div>

            <template #detail="{ item: actId }">
              <EditScheduledUserInput
                v-if="activityRowFor(actId)?.type === 'USER_INPUT'"
                :key="String(actId)"
                interactive
                :title="activityRowFor(actId)!.detail.title"
                :help-enabled="
                  !!activityRowFor(actId)!.detail.helpTitle ||
                  !!activityRowFor(actId)!.detail.helpDescription
                "
                :help-title="activityRowFor(actId)!.detail.helpTitle"
                :help-description="activityRowFor(actId)!.detail.helpDescription"
                :show-preview="false"
                @cancel="editingActivityId = null"
                @save="saveUserInput(activityRowFor(actId)!, $event)"
              />
              <EditYoutubeActivityPane
                v-else-if="activityRowFor(actId)?.type === 'YOUTUBE'"
                :key="String(actId)"
                :activity="activityRowFor(actId)!.detail"
                :saving="savingEditor"
                :fetch-title="programStore.fetchYoutubeTitle"
                @cancel="editingActivityId = null"
                @save="saveYoutube(activityRowFor(actId)!, $event)"
              />
              <EditReadActivityPane
                v-else-if="activityRowFor(actId)?.type === 'READ'"
                :key="String(actId)"
                :program-id="store.data?.programId ?? ''"
                :lesson-id="scheduleForActivity(actId)?.lessonId ?? ''"
                :activity="activityRowFor(actId)!.detail"
                :actions="
                  store.scheduledActivityActions(
                    scheduleForActivity(actId)!.id,
                    String(actId),
                  )
                "
                @cancel="editingActivityId = null"
              />
              <EditExegesisActivityPane
                v-else-if="activityRowFor(actId)?.type === 'EXEGESIS'"
                :key="String(actId)"
                :program-id="store.data?.programId ?? ''"
                :lesson-id="scheduleForActivity(actId)?.lessonId ?? ''"
                :activity="activityRowFor(actId)!.detail"
                :actions="
                  store.scheduledActivityActions(
                    scheduleForActivity(actId)!.id,
                    String(actId),
                  )
                "
                @cancel="editingActivityId = null"
              />
              <div v-else class="EnrollmentScheduleModal__editorStub"></div>
            </template>
          </SlideStack>
        </div>
      </template>
    </SlideStack>
  </div>
</template>

<style scoped>
.EnrollmentScheduleModal {
  position: relative;
  height: 100%;
}

.EnrollmentScheduleModal :deep(.SlideStack) {
  height: 100%;
}

.EnrollmentScheduleModal :deep(.EnrollmentSchedule) {
  position: absolute;
  inset: 0;
}

.EnrollmentScheduleModal__day {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--color-canvas);
}

/* Nested editor SlideStack fills the day pane. */
.EnrollmentScheduleModal__day :deep(.SlideStack) {
  height: 100%;
}

.EnrollmentScheduleModal__dayInner {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.EnrollmentScheduleModal__editorStub {
  height: 100%;
  background: var(--color-canvas);
}

.EnrollmentScheduleModal__dragSpacer {
  flex: 0 0 16px;
}

.EnrollmentScheduleModal__titleField {
  padding: 8px 16px 0;
}

.EnrollmentScheduleModal__dayScroll {
  flex: 1 1 auto;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 16px 40px;
}

.EnrollmentScheduleModal__daySpacer {
  height: 12px;
}

.EnrollmentScheduleModal__activity--busy {
  opacity: 0.5;
  pointer-events: none;
}

.EnrollmentScheduleModal__add--busy {
  opacity: 0.5;
  pointer-events: none;
}
</style>
