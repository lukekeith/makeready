<script lang="ts">
// ChangeMembership — twin of iPhone ChangeMembershipModal.swift
// (Route.changeMembership: topLevel 300, RAW chrome — ships its own opaque
// appBackground wash; enter/exit animation + dismiss-then-act live in the
// production host).
//
// Three-panel state machine owned HERE (like the iOS modal):
//   main     — "Change membership" + mode-gated action rows
//              (.joined → Transfer groups / Remove from group;
//               .removed → Rejoin group)
//   confirm  — kind-specific headline/body + Confirm/Cancel; Confirm is
//              destructive-red ONLY for remove; Cancel returns to
//              `returnPanel` (the LIST when a transfer target was picked)
//   transfer — "Select a group" + CardGroup candidate rows (72px circle,
//              Members / Active Study(ies) metadata) over a 64px top fade
//              mask, chevron pulse affordance, and the iOS drag-back: the
//              main panel rides in as an underlay while dragging; a committed
//              drag swaps panels INSIDE the animation completion so main does
//              NOT replay its panel transition.
//
// Panel transitions mirror iOS `panelTransition`: directional slide+fade
// (forward: in from bottom / out to top; back: reversed) under
// Motion.standard 300ms ease-in-out. Terminal actions only are emitted —
// remove / rejoin / transfer(targetId) / close — the host handles
// dismiss-then-act.
export interface TransferCandidate {
  id: string
  name: string
  coverImageUrl?: string
  memberCount: number
  activeStudies: number
}

export type ChangeMembershipMode = 'joined' | 'removed'
export type ChangeMembershipPanel = 'main' | 'confirm' | 'transfer'
export type ConfirmKind = 'remove' | 'rejoin' | 'transfer'
</script>

<script setup lang="ts">
import { computed, ref } from 'vue'
import CardGroup from '../card-group/card-group.vue'

interface Props {
  memberName: string
  groupName: string
  mode?: ChangeMembershipMode
  candidates?: TransferCandidate[]
  /** Capture-only: open on a specific panel. */
  initialPanel?: ChangeMembershipPanel
  /** Capture-only: the confirm panel's kind when initialPanel is 'confirm'. */
  initialConfirmKind?: ConfirmKind
  /** Capture-only: pre-picked transfer target name for confirm headlines. */
  initialTransferName?: string
  /** Capture-only simulator status bar. Production never passes it. */
  statusBar?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  mode: 'joined',
  candidates: () => [],
  initialPanel: 'main',
  initialConfirmKind: 'remove',
  initialTransferName: '',
  statusBar: false,
})

const emit = defineEmits<{
  remove: []
  rejoin: []
  transfer: [string]
  close: []
}>()

// ─── Panel state machine (iOS: panel / confirmKind / returnPanel / goingForward)
const panel = ref<ChangeMembershipPanel>(props.initialPanel)
const confirmKind = ref<ConfirmKind>(props.initialConfirmKind)
const returnPanel = ref<ChangeMembershipPanel>('main')
const goingForward = ref(true)
const selectedTransfer = ref<TransferCandidate | null>(
  props.initialTransferName
    ? { id: '', name: props.initialTransferName, memberCount: 0, activeStudies: 0 }
    : null,
)

function goToConfirm(kind: ConfirmKind, from: ChangeMembershipPanel): void {
  confirmKind.value = kind
  returnPanel.value = from
  goingForward.value = true
  panel.value = 'confirm'
}

function goToTransfer(): void {
  goingForward.value = true
  panel.value = 'transfer'
}

function back(to: ChangeMembershipPanel): void {
  goingForward.value = false
  panel.value = to
}

function selectCandidate(candidate: TransferCandidate): void {
  selectedTransfer.value = candidate
  goToConfirm('transfer', 'transfer')
}

function confirmAction(): void {
  // iOS captures the id before dismissal; nil selection silently no-ops.
  if (confirmKind.value === 'remove') emit('remove')
  else if (confirmKind.value === 'rejoin') emit('rejoin')
  else if (selectedTransfer.value?.id) emit('transfer', selectedTransfer.value.id)
  else if (confirmKind.value === 'transfer' && !selectedTransfer.value?.id) emit('close')
}

// ─── Confirm copy (verbatim iOS, incl. fallbacks) ───────────────────────────
const confirmHeadline = computed(() => {
  switch (confirmKind.value) {
    case 'remove':
      return 'Remove from group?'
    case 'rejoin':
      return 'Rejoin group?'
    default:
      return `Transfer to ${selectedTransfer.value?.name || 'group'}?`
  }
})

const confirmBody = computed(() => {
  switch (confirmKind.value) {
    case 'remove':
      return `Removing the member from this group will only remove ${props.memberName}'s membership in the group.`
    case 'rejoin':
      return `Rejoining will restore ${props.memberName}'s membership in the group.`
    default:
      return `${props.memberName} will be moved from ${props.groupName} to ${selectedTransfer.value?.name || 'the selected group'}.`
  }
})

// ─── Transfer drag-back (iOS: chevron DragGesture, commit >120 or flick) ────
const dragY = ref(0)
const dragging = ref(false)
const committing = ref(false)
let dragStartY = 0
let lastY = 0
let lastT = 0
let velocity = 0

function onDragStart(e: PointerEvent): void {
  if (panel.value !== 'transfer') return
  dragging.value = true
  dragStartY = e.clientY
  lastY = e.clientY
  lastT = e.timeStamp
  velocity = 0
  ;(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId)
}

function onDragMove(e: PointerEvent): void {
  if (!dragging.value) return
  const dt = e.timeStamp - lastT
  if (dt > 0) velocity = (e.clientY - lastY) / dt
  lastY = e.clientY
  lastT = e.timeStamp
  // iOS clamps to downward-only.
  dragY.value = Math.max(0, e.clientY - dragStartY)
}

function onDragEnd(): void {
  if (!dragging.value) return
  dragging.value = false
  // iOS commit: translation > 120 OR predictedEnd > 280 (≈ velocity flick).
  const predicted = dragY.value + velocity * 250
  if (dragY.value > 120 || predicted > 280) {
    // Committed: animate off, swap INSIDE the completion, no panel transition
    // for main (it's already on-screen as the underlay).
    committing.value = true
    dragY.value = window.innerHeight
    window.setTimeout(() => {
      committing.value = false
      panel.value = 'main'
      dragY.value = 0
    }, 300)
  } else {
    // Snap back (iOS default gesture-state reset).
    committing.value = true
    dragY.value = 0
    window.setTimeout(() => {
      committing.value = false
    }, 300)
  }
}

const transferStyle = computed(() => ({
  transform: `translateY(${dragY.value}px)`,
  transition: committing.value ? 'transform 0.3s ease-in-out' : 'none',
}))

// Underlay main panel rides in from one screen-height above (iOS).
const underlayVisible = computed(() => panel.value === 'transfer' && dragY.value > 0.5)
const underlayStyle = computed(() => ({
  transform: `translateY(calc(${dragY.value}px - 100vh))`,
  transition: committing.value ? 'transform 0.3s ease-in-out' : 'none',
}))

const transitionName = computed(() =>
  goingForward.value ? 'cm-panel-forward' : 'cm-panel-back',
)

function candidateMetadata(candidate: TransferCandidate) {
  const items: { number: string; label: string }[] = [
    { number: String(candidate.memberCount), label: 'Members' },
  ]
  if (candidate.activeStudies > 0) {
    items.push({
      number: String(candidate.activeStudies),
      label: candidate.activeStudies === 1 ? 'Active Study' : 'Active Studies',
    })
  }
  return items
}

const XMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>'
const CHEVRON_DOWN =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>'
const ARROW_LEFT_RIGHT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 8h13M17 4.5L20.5 8 17 11.5"/><path d="M17 16H4M7 12.5L3.5 16 7 19.5"/></svg>'
const PERSON_MINUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="8" r="3.5"/><path d="M3.5 20c.9-3.3 3.7-5.2 6.5-5.2 1.5 0 3 .5 4.2 1.4"/><path d="M15.5 17.5h6"/></svg>'
const ARROW_UTURN =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 5L4 9l4 4"/><path d="M4 9h11a5 5 0 0 1 0 10h-4"/></svg>'
const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'
</script>

<template>
  <div class="ChangeMembership">
    <div v-if="statusBar" class="ChangeMembership__statusbar" aria-hidden="true">
      <span class="ChangeMembership__clock">9:41</span>
    </div>

    <!-- Drag underlay: main panel pulled in from above while dragging back -->
    <div v-if="underlayVisible" class="ChangeMembership__panel" :style="underlayStyle">
      <div class="ChangeMembership__panelBody">
        <div class="ChangeMembership__titleBlock">
          <h2 class="ChangeMembership__headline">Change membership</h2>
          <p class="ChangeMembership__body">{{ memberName }}'s membership in {{ groupName }}</p>
        </div>
        <div class="ChangeMembership__rows" aria-hidden="true">
          <span class="ChangeMembership__row ChangeMembership__row--secondary">
            <span class="ChangeMembership__rowLabel">Transfer groups</span>
            <span class="ChangeMembership__rowIcon" v-html="ARROW_LEFT_RIGHT" />
          </span>
          <span class="ChangeMembership__row ChangeMembership__row--destructive">
            <span class="ChangeMembership__rowLabel">Remove from group</span>
            <span class="ChangeMembership__rowIcon" v-html="PERSON_MINUS" />
          </span>
        </div>
      </div>
    </div>

    <Transition :name="transitionName">
      <!-- ── Main panel ─────────────────────────────────────────────────── -->
      <div v-if="panel === 'main'" key="main" class="ChangeMembership__panel">
        <div class="ChangeMembership__panelBody">
          <div class="ChangeMembership__titleBlock">
            <h2 class="ChangeMembership__headline">Change membership</h2>
            <p class="ChangeMembership__body">{{ memberName }}'s membership in {{ groupName }}</p>
          </div>

          <div class="ChangeMembership__rows">
            <template v-if="mode === 'joined'">
              <button
                type="button"
                class="ChangeMembership__row ChangeMembership__row--secondary"
                @click="goToTransfer()"
              >
                <span class="ChangeMembership__rowLabel">Transfer groups</span>
                <span class="ChangeMembership__rowIcon" v-html="ARROW_LEFT_RIGHT" />
              </button>
              <button
                type="button"
                class="ChangeMembership__row ChangeMembership__row--destructive"
                @click="goToConfirm('remove', 'main')"
              >
                <span class="ChangeMembership__rowLabel">Remove from group</span>
                <span class="ChangeMembership__rowIcon" v-html="PERSON_MINUS" />
              </button>
            </template>
            <template v-else>
              <button
                type="button"
                class="ChangeMembership__row ChangeMembership__row--primary"
                @click="goToConfirm('rejoin', 'main')"
              >
                <span class="ChangeMembership__rowLabel">Rejoin group</span>
                <span class="ChangeMembership__rowIcon" v-html="ARROW_UTURN" />
              </button>
            </template>
          </div>
        </div>
      </div>

      <!-- ── Confirm panel ──────────────────────────────────────────────── -->
      <div v-else-if="panel === 'confirm'" key="confirm" class="ChangeMembership__panel">
        <div class="ChangeMembership__panelBody">
          <div class="ChangeMembership__titleBlock">
            <h2 class="ChangeMembership__headline">{{ confirmHeadline }}</h2>
            <p class="ChangeMembership__body">{{ confirmBody }}</p>
          </div>

          <div class="ChangeMembership__rows">
            <button
              type="button"
              class="ChangeMembership__row"
              :class="confirmKind === 'remove' ? 'ChangeMembership__row--destructive' : 'ChangeMembership__row--primary'"
              @click="confirmAction()"
            >
              <span class="ChangeMembership__rowLabel">Confirm</span>
              <span class="ChangeMembership__rowIcon" v-html="CHECKMARK" />
            </button>
            <button
              type="button"
              class="ChangeMembership__row ChangeMembership__row--muted"
              @click="back(returnPanel)"
            >
              <span class="ChangeMembership__rowLabel">Cancel</span>
              <span class="ChangeMembership__rowIcon" v-html="XMARK" />
            </button>
          </div>
        </div>
      </div>

      <!-- ── Transfer panel ─────────────────────────────────────────────── -->
      <div
        v-else
        key="transfer"
        class="ChangeMembership__panel ChangeMembership__panel--transfer"
        :style="transferStyle"
      >
        <div
          class="ChangeMembership__chevronZone"
          @pointerdown="onDragStart"
          @pointermove="onDragMove"
          @pointerup="onDragEnd"
          @pointercancel="onDragEnd"
        >
          <span class="ChangeMembership__chevron" aria-hidden="true" v-html="CHEVRON_DOWN" />
        </div>

        <h2 class="ChangeMembership__transferTitle">Select a group</h2>

        <div v-if="!candidates.length" class="ChangeMembership__transferEmpty">
          <p class="ChangeMembership__body">
            {{ memberName }} is already a member of every group in the organization.
          </p>
        </div>

        <div v-else class="ChangeMembership__transferScroll">
          <div class="ChangeMembership__transferList">
            <CardGroup
              v-for="candidate in candidates"
              :key="candidate.id"
              :name="candidate.name"
              :image-url="candidate.coverImageUrl || undefined"
              :icon-fallback="true"
              :member-count="candidate.memberCount"
              :metadata="candidateMetadata(candidate)"
              @click="selectCandidate(candidate)"
            />
          </div>
        </div>
      </div>
    </Transition>

    <!-- Fixed close button — never slides with panels, fades with content -->
    <button type="button" class="ChangeMembership__close" aria-label="Close" @click="emit('close')">
      <span v-html="XMARK" />
    </button>
  </div>
</template>
