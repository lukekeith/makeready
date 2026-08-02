<script setup lang="ts">
// EnrollmentFlowModal (production host) — web twin of iPhone
// EnrollmentFlowModal.swift presented as `.enrollmentFlow` (group entry) /
// `.programEnrollmentFlow` (program entry); dismissOnTapOutside FALSE.
//
// Owns the wizard state the iOS modal keeps as @State: the step index, the
// panel-0 selection, the EnrollmentDateState mirror (start date, enabled
// weekdays, per-day overrides, walked end date) and the confirm-page fields.
// The shared EnrollmentFlow twin renders everything; dialogs present through
// the confirm-dialog service with iOS-exact strings.
import { computed, inject, onMounted, reactive, ref } from 'vue'
import EnrollmentFlow, {
  type EnrollmentFlowGroupRow,
  type EnrollmentFlowProgramRow,
} from '../../../components/card/enrollment-flow/enrollment-flow.vue'
import ConfirmationOverlayModal from './confirmation-overlay-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import {
  useLeaderEnrollmentFlow,
  type FlowGroup,
  type FlowProgram,
} from '../stores/leader-enrollment-flow.store'

const props = defineProps<{
  /** 'group' = preselected group → Select Program panel first;
   *  'program' = preselected program → Select Group panel first. */
  entry: 'group' | 'program'
  seedGroup?: {
    id: string
    name: string
    description?: string
    isPrivate?: boolean
    memberCount: number
    imageUrl?: string
  }
  seedProgram?: {
    id: string
    name: string
    description?: string
    days: number
    imageUrl?: string
  }
  /** Program entry: group ids with an active enrollment (rows dim). */
  enrolledGroupIds?: string[]
  /** Called after a successful enrollment (presenter refreshes its data). */
  onComplete?: () => void
}>()

const store = useLeaderEnrollmentFlow()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

// ── Wizard state (iOS @State) ──
const step = ref(0)
const searchText = ref('')
const groups = ref<FlowGroup[]>([])
const programs = ref<FlowProgram[]>([])
const listLoading = ref(true)
const listError = ref('')
const selectedGroupId = ref<string | null>(null)
const selectedProgramId = ref<string | null>(null)

// Group entry: the group's existing-enrollment context (iOS
// loadEnrollmentsIfNeeded) — programs stay dimmed until it loads.
const contextLoaded = ref(props.entry === 'program')
const activeByProgramId = ref<Map<string, string | null>>(new Map())
const existingLessonDates = ref<string[]>([])

// ── EnrollmentDateState mirror ──
const startDate = ref<string | null>(null)
const enabledDays = ref<number[]>([1, 2, 3, 4, 5])
const overriddenDates = ref<string[]>([])

// ── Confirm state (iOS ConfirmEnrollmentPage defaults) ──
const requireResponse = ref(true)
const syncToStudy = ref(false)
const syncMode = ref<'Automatic' | 'Approval'>('Automatic')
const smsTime = ref('07:30')

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`
}

function todayKey(): string {
  const now = new Date()
  return `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`
}

function keyToDate(key: string): Date {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function dateToKey(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

// ── Data loads (cache-light: fresh per open, like the iOS pages refresh) ──
async function loadList(): Promise<void> {
  listLoading.value = true
  try {
    if (props.entry === 'program') {
      groups.value = await store.loadGroups()
    } else {
      programs.value = await store.loadPrograms()
    }
    listError.value = ''
  } catch {
    listError.value = 'Failed to load'
  } finally {
    listLoading.value = false
  }
}

onMounted(async () => {
  await loadList()
  if (props.entry === 'group' && props.seedGroup) {
    try {
      const ctx = await store.loadGroupContext(props.seedGroup.id)
      activeByProgramId.value = ctx.activeByProgramId
      existingLessonDates.value = ctx.existingLessonDates
    } catch {
      // iOS: failure degrades to an empty context; the wizard proceeds.
    } finally {
      contextLoaded.value = true
    }
  }
})

// ── Twin rows ──
const enrolledSet = computed(() => new Set(props.enrolledGroupIds ?? []))

const groupRows = computed<EnrollmentFlowGroupRow[]>(() =>
  groups.value.map((g) => ({
    id: g.id,
    name: g.name,
    description: g.description,
    memberCount: g.memberCount,
    enrollmentCount: g.enrollmentCount,
    imageUrl: g.imageUrl,
    enrolled: enrolledSet.value.has(g.id),
  }))
)

function enrolledUntilLabel(programId: string): string | undefined {
  if (!activeByProgramId.value.has(programId)) return undefined
  const end = activeByProgramId.value.get(programId)
  if (!end) return 'enrolled'
  const d = new Date(end)
  const label = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  return `enrolled until ${label}`
}

const programRows = computed<EnrollmentFlowProgramRow[]>(() =>
  programs.value.map((p) => ({
    id: p.id,
    name: p.name,
    description: p.description,
    days: p.days,
    imageUrl: p.imageUrl,
    isPublished: p.isPublished,
    enrolledUntil: enrolledUntilLabel(p.id),
    // iOS isDisabled = !isEnrollmentDataLoaded || isCurrentlyEnrolled.
    disabled: !contextLoaded.value || activeByProgramId.value.has(p.id),
  }))
)

const selectedGroup = computed(() =>
  props.entry === 'group'
    ? props.seedGroup ?? null
    : (() => {
        const g = groups.value.find((x) => x.id === selectedGroupId.value)
        return g
          ? {
              id: g.id,
              name: g.name,
              description: g.description,
              isPrivate: g.isPrivate,
              memberCount: g.memberCount,
              imageUrl: g.imageUrl,
            }
          : null
      })()
)

const selectedProgram = computed(() =>
  props.entry === 'program'
    ? props.seedProgram ?? null
    : (() => {
        const p = programs.value.find((x) => x.id === selectedProgramId.value)
        return p
          ? {
              id: p.id,
              name: p.name,
              description: p.description,
              days: p.days,
              imageUrl: p.imageUrl,
            }
          : null
      })()
)

const lessonCount = computed(() => selectedProgram.value?.days ?? 0)

// ── Date logic (iOS EnrollmentDateState) ──
const enabledSet = computed(() => new Set(enabledDays.value))
const overriddenSet = computed(() => new Set(overriddenDates.value))

function isIncluded(key: string): boolean {
  const weekday = keyToDate(key).getDay()
  const enabled = enabledSet.value.has(weekday)
  return overriddenSet.value.has(key) ? !enabled : enabled
}

// calculatedEndDate: walk forward counting included days (maxIter = count*10).
const endDate = computed<string | null>(() => {
  if (!startDate.value || lessonCount.value <= 0) return null
  const maxIterations = lessonCount.value * 10
  let cursor = keyToDate(startDate.value)
  let scheduled = 0
  let last: string | null = null
  for (let i = 0; i < maxIterations; i++) {
    const key = dateToKey(cursor)
    if (isIncluded(key)) {
      scheduled += 1
      last = key
      if (scheduled >= lessonCount.value) break
    }
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1)
  }
  return last
})

// calculatePotentialDates — the would-be schedule from a candidate start.
function potentialDates(fromKey: string): Set<string> {
  const out = new Set<string>()
  const maxIterations = lessonCount.value * 10
  let cursor = keyToDate(fromKey)
  let scheduled = 0
  for (let i = 0; i < maxIterations; i++) {
    const key = dateToKey(cursor)
    if (isIncluded(key)) {
      out.add(key)
      scheduled += 1
      if (scheduled >= lessonCount.value) break
    }
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1)
  }
  return out
}

function selectStartDate(key: string, force = false): void {
  if (key < todayKey()) return
  if (!force && !isIncluded(key)) return
  startDate.value = key
  overriddenDates.value = [] // iOS: new start clears all overrides
}

function toggleWeekday(weekday: number): void {
  const set = new Set(enabledDays.value)
  if (set.has(weekday) && set.size > 1) set.delete(weekday)
  else set.add(weekday)
  enabledDays.value = [...set]
}

function toggleOverride(key: string): void {
  const set = new Set(overriddenDates.value)
  if (set.has(key)) set.delete(key)
  else set.add(key)
  overriddenDates.value = [...set]
}

function isInRange(key: string): boolean {
  return !!startDate.value && !!endDate.value && key >= startDate.value && key <= endDate.value
}

const existingSet = computed(() => new Set(existingLessonDates.value))

// iOS "EEEE, MMMM d" (CalendarFormatters.fullDateHeader).
function fullDateHeader(key: string): string {
  return keyToDate(key).toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  })
}

async function onSelectDate(key: string): Promise<void> {
  // Tapping an overridden day opens the override dialog (iOS
  // onOverrideDayTapped), other days run the overlap-checked selection.
  if (overriddenSet.value.has(key)) {
    const weekdayEnabled = enabledSet.value.has(keyToDate(key).getDay())
    const choice = await confirmDialog.confirm({
      title: fullDateHeader(key),
      message: weekdayEnabled
        ? 'This day has been manually removed from the schedule.'
        : 'This day has been manually added to the schedule.',
      buttons: [
        { label: 'Remove Override', style: 'destructive' },
        { label: 'Set as Start Date', style: 'secondary' },
        { label: 'Cancel', style: 'secondary' },
      ],
    })
    if (choice === 0) toggleOverride(key)
    else if (choice === 1) selectStartDate(key, true)
    return
  }
  if (key < todayKey() || !isIncluded(key)) return
  const overlapping = [...potentialDates(key)].some((d) => existingSet.value.has(d))
  if (!overlapping) {
    selectStartDate(key)
    return
  }
  const choice = await confirmDialog.confirm({
    title: 'Lesson already scheduled',
    message:
      'This member already has a lesson on the selected date. MakeReady recommends one lesson per day per member. Choose another date or schedule anyway if this overlap is intentional.',
    buttons: [
      { label: 'Schedule anyway', style: 'primary' },
      { label: 'Choose another date', style: 'secondary' },
    ],
  })
  if (choice === 0) selectStartDate(key)
}

function onLongpressDate(key: string): void {
  // iOS blackout long-press: only in-range, non-start days toggle.
  if (!isInRange(key) || key === startDate.value) return
  toggleOverride(key)
}

// ── Panel-0 selection (tap toggles; iOS deselects on re-tap) ──
function onSelectGroup(id: string): void {
  selectedGroupId.value = selectedGroupId.value === id ? null : id
}

function onSelectProgram(id: string): void {
  selectedProgramId.value = selectedProgramId.value === id ? null : id
}

function onTapDraftProgram(): void {
  void confirmDialog.confirm({
    title: 'Draft Program',
    message:
      'This study program must be published before it can be used for enrollment. Open the program and publish it first.',
    buttons: [{ label: 'Ok', style: 'secondary' }],
  })
}

// ── Step navigation ──
function onNext(): void {
  if (step.value === 0) {
    if (props.entry === 'program' ? !selectedGroupId.value : !selectedProgramId.value) return
    step.value = 1
  } else if (step.value === 1 && startDate.value) {
    step.value = 2
  }
}

function onBack(): void {
  if (step.value > 0) step.value -= 1
}

function close(): void {
  overlay?.dismiss()
}

// ── Confirm (POST /api/enrollments) ──
const submitting = ref(false)

const confirmation = reactive({ isProcessing: true, message: '' })
const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'

function successMessage(groupName: string, programName: string, startKey: string): string {
  const started = keyToDate(startKey).toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  })
  return `**${groupName}** has been successfully enrolled in **${programName}** starting on **${started}**.`
}

async function onConfirm(): Promise<void> {
  const group = selectedGroup.value
  const program = selectedProgram.value
  const startKey = startDate.value
  if (!group || !program || !startKey || submitting.value) return
  submitting.value = true

  const isGroupEntry = props.entry === 'group'
  // iOS: the wizard dismisses and (group entry only) the processing
  // ConfirmationOverlay presents, flipping to success when the POST lands.
  overlay?.dismiss()
  if (isGroupEntry) {
    confirmation.isProcessing = true
    confirmation.message = successMessage(group.name, program.name, startKey)
    overlayManager.present(ROUTES.confirmationOverlay, ConfirmationOverlayModal, {
      tone: 'success',
      icon: CHECKMARK,
      buttonLabel: 'Done',
      processingMessage: 'Processing enrollment',
      get isProcessing() {
        return confirmation.isProcessing
      },
      get message() {
        return confirmation.message
      },
      onSelect: () => overlayManager.dismiss(ROUTES.confirmationOverlay.id),
    })
  }

  try {
    await store.createEnrollment({
      groupId: group.id,
      studyProgramId: program.id,
      startDateKey: startKey,
      enabledDays: enabledDays.value,
      requireResponse: requireResponse.value,
      syncMode: syncToStudy.value
        ? syncMode.value === 'Approval'
          ? 'APPROVAL'
          : 'AUTO'
        : 'OFF',
      smsTime: smsTime.value,
    })
    if (isGroupEntry) confirmation.isProcessing = false
    props.onComplete?.()
  } catch (err) {
    if (isGroupEntry) overlayManager.dismiss(ROUTES.confirmationOverlay.id)
    void confirmDialog.confirm({
      title: 'Something went wrong',
      message:
        err instanceof Error && err.message
          ? err.message
          : "Couldn't create the enrollment",
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="EnrollmentFlowModal">
    <EnrollmentFlow
      :entry="props.entry"
      :step="step"
      :groups="groupRows"
      :programs="programRows"
      :list-loading="listLoading"
      :list-error="listError"
      :selected-group-id="selectedGroupId"
      :selected-program-id="selectedProgramId"
      :search-text="searchText"
      :start-date="startDate"
      :end-date="endDate"
      :enabled-days="enabledDays"
      :overridden-dates="overriddenDates"
      :existing-lesson-dates="existingLessonDates"
      :confirm-group="selectedGroup"
      :confirm-program="selectedProgram"
      :sms-time="smsTime"
      :require-response="requireResponse"
      :sync-to-study="syncToStudy"
      :sync-mode="syncMode"
      interactive
      @close="close"
      @back="onBack"
      @next="onNext"
      @confirm="onConfirm"
      @retry="loadList"
      @select-group="onSelectGroup"
      @select-program="onSelectProgram"
      @tap-draft-program="onTapDraftProgram"
      @update:search-text="searchText = $event"
      @select-date="onSelectDate"
      @longpress-date="onLongpressDate"
      @toggle-weekday="toggleWeekday"
      @update:require-response="requireResponse = $event"
      @update:sync-to-study="syncToStudy = $event"
      @update:sync-mode="syncMode = $event"
      @update:sms-time="smsTime = $event"
    />
  </div>
</template>

<style scoped>
/* The twin is absolute-inset; give it a full-height positioned box inside the
   managed-modal sheet. */
.EnrollmentFlowModal {
  position: relative;
  height: 100%;
}
</style>
