<script setup lang="ts">
// EditDayPane — production rebuild of the iPhone EditDay
// (Pages/Manage/Program/EditDay.swift), the lesson editor reached by tapping a
// lesson card on Program Home. It owns a NESTED SlideStack (iOS
// SlideStack(item: $editingActivityId)) whose detail hosts the per-type
// activity editor panes.
//
// dayContent (mirrors iOS):
//   • Header — PageTitle: title-edited → Cancel / "Day N" / Save;
//     default → chevron.left / "Day N" / Done (both slide back)
//   • FieldGroup { TextInput(floating "Lesson title") }, padded H16 top 8
//   • VStack(spacing 4) of CardLessonActivity(size small) rows
//   • add-activity BoxButton (plus) → AddActivityMenu (raw full-screen)
//   • "Preview" BoxButton (eye) → opens the lesson web preview
// WRITE / YOUTUBE / READ slide to editors; EXEGESIS / VIDEO are a later stage.
import { computed, inject, ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import TextInput from '../../../components/card/text-input/text-input.vue'
import CardLessonActivity from '../../../components/card/card-lesson-activity/card-lesson-activity.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import SwipeableCard from '../../../components/card/swipeable-card/swipeable-card.vue'
import DragulaList from '../../../components/card/dragula-list/dragula-list.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import SlideStack from '../overlay/slide-stack.vue'
import AddActivityMenu from './add-activity-menu.vue'
import EditUserInputActivityPane from './edit-user-input-activity-pane.vue'
import EditYoutubeActivityPane from './edit-youtube-activity-pane.vue'
import EditReadActivityPane from './edit-read-activity-pane.vue'
import EditExegesisActivityPane from './edit-exegesis-activity-pane.vue'
import VideoActivityPickerModal from './video-activity-picker-modal.vue'
import VideoPlaybackModal from './video-playback-modal.vue'
import { OverlayPriority } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import type { LeaderActivity, LeaderLesson } from '../stores/leader-program.store'
import { useLeaderProgram } from '../stores/leader-program.store'

const props = defineProps<{ programId: string; lessonId: string }>()

const emit = defineEmits<{ back: [] }>()

const store = useLeaderProgram()

const lesson = computed<LeaderLesson | null>(
  () => store.program?.lessons.find((l) => l.id === props.lessonId) ?? null,
)

// iOS EditDay.canEdit — creator only; gates swipe + drag (view stays open for
// non-creators, read-only).
const memberId = inject<string | null>('memberId', null)
const canEdit = computed(() =>
  Boolean(memberId && store.program?.creatorId && store.program.creatorId === memberId),
)

// ── Lesson title (Cancel/Save header appears once edited, like iOS) ──
const titleDraft = ref(lesson.value?.title ?? '')
const savingTitle = ref(false)
const hasTitleChanges = computed(
  () => titleDraft.value.trim() !== (lesson.value?.title ?? '').trim(),
)

async function saveTitle(): Promise<void> {
  if (savingTitle.value || !lesson.value) return
  savingTitle.value = true
  try {
    await store.updateLessonTitle(props.programId, props.lessonId, titleDraft.value.trim())
  } finally {
    savingTitle.value = false
  }
}

function cancelTitle(): void {
  titleDraft.value = lesson.value?.title ?? ''
}

// ── Nested slide to activity editors ──
const editingActivityId = ref<string | null>(null)
const savingActivity = ref(false)

// Resolved from the SlideStack's MOUNTED item (which outlives the binding
// during slide-out) so the editor never vanishes mid-animation.
function activityFor(id: unknown): LeaderActivity | null {
  return lesson.value?.activities.find((a) => a.id === id) ?? null
}

const overlayManager = useOverlayManager()
const savingVideoActivityId = ref<string | null>(null)

// iOS EditDay: unconfigured video card → VideoActivityPicker fullScreenCover
// (web: managed-modal); configured → VideoActivityManager preview.
function openVideoPicker(activity: LeaderActivity): void {
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
        // iOS handleVideoSelected — NOT optimistic: card spinner until done.
        savingVideoActivityId.value = activity.id
        try {
          await store.updateActivityVideo(props.lessonId, activity.id, v.id, v.playbackUrl)
        } catch {
          showError("Couldn't update the video")
        } finally {
          savingVideoActivityId.value = null
        }
      },
    },
  )
}

function openVideoPreview(activity: LeaderActivity): void {
  overlayManager.present(
    {
      id: 'videoActivityManager',
      priority: OverlayPriority.modal,
      chrome: 'modal',
      dismissOnTapOutside: true,
    },
    VideoPlaybackModal,
    {
      title: activity.video?.title ?? activity.title ?? 'Video',
      playbackUrl: activity.video?.playbackUrl ?? null,
      thumbnailUrl: activity.video?.thumbnailUrl ?? null,
      onRemove: async () => {
        savingVideoActivityId.value = activity.id
        try {
          await store.removeActivityVideo(props.lessonId, activity.id)
        } catch {
          showError("Couldn't remove the video")
        } finally {
          savingVideoActivityId.value = null
        }
      },
    },
  )
}

function onActivityTap(activity: LeaderActivity): void {
  if (
    activity.activityType === 'USER_INPUT' ||
    activity.activityType === 'YOUTUBE' ||
    activity.activityType === 'READ' ||
    activity.activityType === 'EXEGESIS'
  ) {
    editingActivityId.value = activity.id
  } else if (activity.activityType === 'VIDEO') {
    if (activity.status === 'complete') openVideoPreview(activity)
    else openVideoPicker(activity)
  }
}

// iOS activity editors' Preview → /preview/lesson/{lessonId}/{step}, where
// step is the activity's 1-based position among the lesson's activities.
function activityPreviewUrl(id: unknown): string {
  const ordered = lesson.value?.activities ?? []
  const step = ordered.findIndex((a) => a.id === id) + 1
  return step > 0 ? `/admin/preview/lesson/${props.lessonId}/${step}` : ''
}

async function saveActivity(fields: Record<string, unknown>): Promise<void> {
  if (!editingActivityId.value || savingActivity.value) return
  savingActivity.value = true
  try {
    await store.updateActivity(props.lessonId, editingActivityId.value, fields)
    editingActivityId.value = null
  } finally {
    savingActivity.value = false
  }
}

// ── Add activity ──
const showAddMenu = ref(false)
const addingActivity = ref(false)

async function onAddActivity(type: string): Promise<void> {
  showAddMenu.value = false
  if (addingActivity.value) return
  addingActivity.value = true
  try {
    await store.addActivity(props.programId, props.lessonId, type)
  } finally {
    addingActivity.value = false
  }
}

// ── Swipe actions (iOS EditDay.buildSlideButtons) ──
// Gating ported from EditDay.swift: reset (red ↺) when the activity has
// member data (raw status COMPLETE); clear (blue ⊗) when configured and not
// USER_INPUT; trash always. VIDEO cards get clear-if-configured + trash (the
// iOS eye/preview button lands with the video picker screen).
interface SwipeSpec {
  icon: string
  variant: 'reschedule' | 'delete'
  action: 'reset' | 'clear' | 'delete' | 'preview'
}

function slideButtonsFor(a: LeaderActivity): SwipeSpec[] {
  if (!canEdit.value) return []
  const configured = a.status === 'complete'
  const buttons: SwipeSpec[] = []
  if (a.activityType === 'VIDEO') {
    if (configured) {
      buttons.push({ icon: XMARK_CIRCLE, variant: 'reschedule', action: 'clear' })
      buttons.push({ icon: EYE, variant: 'reschedule', action: 'preview' })
    }
  } else {
    if (a.rawStatus === 'COMPLETE')
      buttons.push({ icon: ARROW_CCW, variant: 'delete', action: 'reset' })
    if (a.activityType !== 'USER_INPUT' && configured)
      buttons.push({ icon: XMARK_CIRCLE, variant: 'reschedule', action: 'clear' })
  }
  buttons.push({ icon: TRASH, variant: 'delete', action: 'delete' })
  return buttons
}

// Confirm dialogs (iOS native .alert — exact strings) via the shared
// confirm-dialog service (ConfirmDialogHost renders them full-screen).
const confirmDialog = useConfirmDialog()
const mutatingActivity = ref(false)

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

const CONFIRMS = {
  delete: {
    title: 'Delete activity?',
    message:
      'This will permanently remove this activity from the day. This action cannot be undone.',
    action: 'Delete',
    fallback: 'Failed to delete activity',
  },
  reset: {
    title: 'Reset activity?',
    message:
      'Resetting this activity is not reversible and will remove all data associated with this activity. Once members have participated in this activity, it can no longer be reset.',
    action: 'Reset',
    fallback: 'Failed to reset activity',
  },
  clear: {
    title: 'Clear activity?',
    message:
      'This will reset the activity to its default state, clearing any content that has been configured.',
    action: 'Clear',
    fallback: 'Failed to clear activity',
  },
} as const

function onSwipeAction(activity: LeaderActivity, index: number): void {
  const action = slideButtonsFor(activity)[index]?.action
  if (action === 'reset') void requestActivityMutation(activity, 'reset')
  else if (action === 'clear') void requestActivityMutation(activity, 'clear')
  else if (action === 'delete') void requestActivityMutation(activity, 'delete')
  else if (action === 'preview') openVideoPreview(activity)
}

async function runMutation(fn: () => Promise<void>, fallback: string): Promise<void> {
  if (mutatingActivity.value) return
  mutatingActivity.value = true
  try {
    await fn()
  } catch (err) {
    showError(err instanceof Error ? err.message : fallback)
  } finally {
    mutatingActivity.value = false
  }
}

// Delete removes; clear/reset share the reset endpoint (iOS EditDay).
async function requestActivityMutation(
  a: LeaderActivity,
  kind: keyof typeof CONFIRMS,
): Promise<void> {
  const spec = CONFIRMS[kind]
  const choice = await confirmDialog.confirm({
    title: spec.title,
    message: spec.message,
    buttons: [
      { label: spec.action, style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0) return
  const run =
    kind === 'delete'
      ? () => store.deleteActivity(props.lessonId, a.id)
      : () => store.resetActivity(props.lessonId, a.id)
  void runMutation(run, spec.fallback)
}

// ── Drag reorder (iOS DragulaView → persistActivityOrder) ──
function onReorderActivities(ids: string[]): void {
  void runMutation(
    () => store.reorderActivities(props.programId, props.lessonId, ids),
    'Failed to reorder activities',
  )
}

// Resolve the full activity from a DragulaList slot item ({ id }-typed).
function asActivity(item: { id: string }): LeaderActivity {
  return item as LeaderActivity
}

// iOS videoActivityCard: title = video?.title ?? activity.title ?? displayName;
// description = video duration (ready) or "Select video" (unconfigured).
function videoCardTitle(a: LeaderActivity): string {
  if (a.activityType === 'VIDEO') return a.video?.title ?? a.title ?? 'Video'
  return a.title || 'New activity'
}

function videoCardDescription(a: LeaderActivity): string | undefined {
  if (a.activityType !== 'VIDEO') return undefined
  if (a.video?.isReady && a.video.duration != null) {
    const sec = Math.max(0, Math.round(a.video.duration))
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`
  }
  return a.status === 'complete' ? undefined : 'Select video'
}

function estimatedMinutesFor(a: LeaderActivity): number {
  return a.estimatedSeconds ? Math.max(1, Math.round(a.estimatedSeconds / 60)) : 0
}

// Lesson web preview (iOS opens /preview/lesson/{id} in a webview).
function openPreview(): void {
  window.open(`/admin/preview/lesson/${props.lessonId}`, '_blank')
}

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
// SF "trash" — lid, handle, tapering can with rib lines.
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
// SF "arrow.counterclockwise" — open circular arrow with a top-left head.
const ARROW_CCW =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 5.5v5h5"/><path d="M5.3 10A8 8 0 1 1 4.6 14"/></svg>'
// SF "xmark.circle" — outlined circle with a centered ×.
const XMARK_CIRCLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
</script>

<template>
  <div class="EditDayPane">
    <SlideStack :item="editingActivityId">
      <div class="EditDayPane__day">
        <!-- Header: title-edited → Cancel/Save; default → chevron/Done -->
        <PageTitle
          v-if="hasTitleChanges"
          class="EditDayPane__title"
          :title="`Day ${lesson?.day ?? ''}`"
          left-link="Cancel"
          :right-link="savingTitle ? 'Saving...' : 'Save'"
          @left="cancelTitle"
          @right="saveTitle"
        />
        <PageTitle
          v-else
          class="EditDayPane__title"
          :title="`Day ${lesson?.day ?? ''}`"
          :left-icon="BACK_CHEVRON"
          right-link="Done"
          @left="emit('back')"
          @right="emit('back')"
        />

        <div class="EditDayPane__titleField">
          <div class="FieldGroup">
            <TextInput
              interactive
              floating-label="Lesson title"
              :text="titleDraft"
              @update:text="titleDraft = $event"
            />
          </div>
        </div>

        <div class="EditDayPane__scroll">
          <div class="EditDayPane__activities">
            <!-- iOS: DragulaView (long-press reorder) of SwipeableCards
                 (swipe-left → reset/clear/delete per gating). -->
            <DragulaList
              :items="lesson?.activities ?? []"
              :enabled="canEdit"
              :gap="4"
              @reorder="onReorderActivities"
            >
              <template #item="{ item }">
                <SwipeableCard
                  bare
                  :slide-buttons="slideButtonsFor(asActivity(item))"
                  :is-swipe-enabled="canEdit"
                  @action="onSwipeAction(asActivity(item), $event)"
                  @tap="onActivityTap(asActivity(item))"
                >
                  <div class="EditDayPane__cardWrap">
                    <CardLessonActivity
                      size="small"
                      :type="asActivity(item).activityType"
                      :title="videoCardTitle(asActivity(item))"
                      :description="videoCardDescription(asActivity(item))"
                      :image-url="asActivity(item).video?.thumbnailUrl ?? undefined"
                      :icon-key="asActivity(item).activityType === 'VIDEO' ? 'play' : undefined"
                      :status="asActivity(item).status === 'incomplete' ? 'new' : 'ready'"
                      :estimated-minutes="estimatedMinutesFor(asActivity(item))"
                    />
                    <!-- iOS CardSpinnerOverlay while the video PATCH is in flight. -->
                    <div
                      v-if="savingVideoActivityId === asActivity(item).id"
                      class="EditDayPane__cardSpinner"
                      aria-hidden="true"
                    >
                      <span class="EditDayPane__cardSpinnerRing"></span>
                    </div>
                  </div>
                </SwipeableCard>
              </template>
            </DragulaList>
          </div>

          <BoxButton
            class="EditDayPane__addBtn"
            variant="secondary"
            size="lg"
            :icon="PLUS"
            icon-position="right"
            full-width
            @click="showAddMenu = true"
          />
          <BoxButton
            class="EditDayPane__previewBtn"
            variant="secondary"
            size="lg"
            label="Preview"
            :icon="EYE"
            icon-position="right"
            full-width
            @click="openPreview"
          />
        </div>
      </div>

      <template #detail="{ item }">
        <EditUserInputActivityPane
          v-if="activityFor(item)?.activityType === 'USER_INPUT'"
          :key="String(item)"
          :activity="activityFor(item)!"
          :saving="savingActivity"
          :preview-url="activityPreviewUrl(item)"
          @cancel="editingActivityId = null"
          @save="saveActivity"
        />
        <EditYoutubeActivityPane
          v-else-if="activityFor(item)?.activityType === 'YOUTUBE'"
          :key="String(item)"
          :activity="activityFor(item)!"
          :saving="savingActivity"
          :fetch-title="store.fetchYoutubeTitle"
          :preview-url="activityPreviewUrl(item)"
          @cancel="editingActivityId = null"
          @save="saveActivity"
        />
        <EditReadActivityPane
          v-else-if="activityFor(item)?.activityType === 'READ'"
          :key="String(item)"
          :program-id="props.programId"
          :lesson-id="props.lessonId"
          :activity="activityFor(item)!"
          :preview-url="activityPreviewUrl(item)"
          @cancel="editingActivityId = null"
        />
        <EditExegesisActivityPane
          v-else-if="activityFor(item)?.activityType === 'EXEGESIS'"
          :key="String(item)"
          :program-id="props.programId"
          :lesson-id="props.lessonId"
          :activity="activityFor(item)!"
          :preview-url="activityPreviewUrl(item)"
          @cancel="editingActivityId = null"
        />
        <div v-else class="EditDayPane__stub"></div>
      </template>
    </SlideStack>

    <!-- Add-activity menu (iOS raw-chrome full-screen overlay) -->
    <AddActivityMenu
      v-if="showAddMenu"
      @select="onAddActivity"
      @close="showAddMenu = false"
    />
  </div>
</template>

<style scoped>
.EditDayPane {
  position: relative;
  height: 100%;
  background: var(--color-canvas);
  color: #fff;
  overflow: hidden;
}

.EditDayPane__day {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.EditDayPane__title {
  flex: 0 0 auto;
}

/* iOS: FieldGroup { TextInput } .padding(.horizontal,16).padding(.top,8) */
.EditDayPane__titleField {
  flex: 0 0 auto;
  padding: 8px 16px 0;
}

.EditDayPane__scroll {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 16px 16px 32px;
}

/* iOS VStack(spacing: 4) of activity cards. */
.EditDayPane__activities {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.EditDayPane__addBtn {
  margin-top: 12px; /* iOS 12px spacer above the add button */
}

.EditDayPane__previewBtn {
  margin-top: 12px;
}

.EditDayPane__stub {
  height: 100%;
  background: var(--color-canvas);
}

/* Video-save spinner (iOS CardSpinnerOverlay: black@0.4 wash + white ring). */
.EditDayPane__cardWrap {
  position: relative;
}

.EditDayPane__cardSpinner {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.4);
  border-radius: 8px;
  z-index: 2;
}

.EditDayPane__cardSpinnerRing {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: 2.4px solid rgba(255, 255, 255, 0.25);
  border-top-color: #fff;
  animation: EditDayPane-spin 0.8s linear infinite;
}

@keyframes EditDayPane-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
