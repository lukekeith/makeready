<script setup lang="ts">
// UnenrollOptionsModal (production host) — web twin of iPhone
// UnenrollOptionsModal presented as `.unenrollOptions` (tap-outside
// dismisses). Loads unenroll-info on mount (phase machine: loading → options
// → confirm → error, iOS Motion.micro), runs the chosen action, then hands
// off to the ConfirmationOverlay with the iOS-exact success message.
import { inject, onMounted, reactive, ref } from 'vue'
import UnenrollOptions from '../../../components/card/unenroll-options/unenroll-options.vue'
import ConfirmationOverlayModal from './confirmation-overlay-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import { useLeaderEnrollmentSchedule } from '../stores/leader-enrollment-schedule.store'

const props = defineProps<{
  enrollmentId: string
  programName?: string
  programImageUrl?: string
  onComplete?: () => void
}>()

const store = useLeaderEnrollmentSchedule()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()

const phase = ref<'loading' | 'options' | 'confirm' | 'error'>('loading')
const confirmMode = ref<'fullRemoval' | 'cancelFuture'>('fullRemoval')
const errorMessage = ref('')
const info = ref({
  totalLessons: 0,
  lessonsWithData: 0,
  cleanLessons: 0,
  canFullyUnenroll: true,
})

async function loadInfo(): Promise<void> {
  phase.value = 'loading'
  try {
    info.value = await store.loadUnenrollInfo(props.enrollmentId)
    phase.value = 'options'
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : 'Failed to load enrollment status'
    phase.value = 'error'
  }
}

onMounted(loadInfo)

const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'

const confirmation = reactive({ isProcessing: true, message: '' })
const processing = ref(false)

async function proceed(): Promise<void> {
  if (processing.value) return
  processing.value = true
  const mode = confirmMode.value
  const name = props.programName ?? 'Study Program'
  // iOS UnenrollConfirmation success messages (verbatim).
  confirmation.isProcessing = true
  confirmation.message =
    mode === 'fullRemoval'
      ? `Your group has been successfully unenrolled from **${name}**.`
      : `Future lessons have been cancelled for **${name}**. Existing lesson data has been preserved.`
  overlay?.dismiss()
  overlayManager.present(ROUTES.confirmationOverlay, ConfirmationOverlayModal, {
    tone: 'success',
    icon: CHECKMARK,
    buttonLabel: 'Done',
    processingMessage: 'Processing unenrollment',
    get isProcessing() {
      return confirmation.isProcessing
    },
    get message() {
      return confirmation.message
    },
    onSelect: () => overlayManager.dismiss(ROUTES.confirmationOverlay.id),
  })
  try {
    if (mode === 'fullRemoval') await store.deleteEnrollment(props.enrollmentId)
    else await store.cancelFutureLessons(props.enrollmentId)
    confirmation.isProcessing = false
    props.onComplete?.()
  } catch {
    overlayManager.dismiss(ROUTES.confirmationOverlay.id)
  } finally {
    processing.value = false
  }
}
</script>

<template>
  <div class="UnenrollOptionsModal">
    <UnenrollOptions
      :phase="phase"
      :program-name="props.programName"
      :program-image-url="props.programImageUrl"
      :total-lessons="info.totalLessons"
      :lessons-with-data="info.lessonsWithData"
      :clean-lessons="info.cleanLessons"
      :can-fully-unenroll="info.canFullyUnenroll"
      :confirm-mode="confirmMode"
      :error-message="errorMessage"
      @dismiss="overlay?.dismiss()"
      @back="phase = 'options'"
      @select-full-removal="(confirmMode = 'fullRemoval'), (phase = 'confirm')"
      @select-cancel-future="(confirmMode = 'cancelFuture'), (phase = 'confirm')"
      @proceed="proceed"
      @retry="loadInfo"
    />
  </div>
</template>

<style scoped>
.UnenrollOptionsModal {
  position: relative;
  height: 100%;
}
</style>
