<script setup lang="ts">
import { ref, computed, useSlots } from 'vue'
import CardGroupMini from '../card-group-mini/card-group-mini.vue'
import CardSlideButton from '../card-slide-button/card-slide-button.vue'

// SwipeableCard — swipe the content left to reveal the trailing #actions
// (CardSlideButtons). Web twin of iOS Components/Card/SwipeableCard.swift.
//
// iOS mechanics reproduced:
//   • Buttons sit UNDER the content (ZStack .trailing); the content translates
//     left over them. Total reveal width = 48·n + 8·(n−1) + 8 leading +
//     16 trailing padding (single button = 72px).
//   • Progressive reveal: as the drag opens, each button interpolates
//     size 24→48, icon 12→20 and opacity 0→1 with
//     progress = min(|offset| / totalButtonWidth, 1) — so at rest the lane is
//     invisible, exactly like iOS (which only renders it past |offset| > 5).
//   • Release: snap open when velocityX < -100 px/s (fast flick) OR
//     |offset| > totalButtonWidth/2; else snap closed. Motion.springSnappy
//     (spring 0.3/0.8) ≈ 300ms cubic-bezier(0.32,0.72,0,1).
//   • Tap on a revealed card closes it; `tap` only fires when closed.
//   • Tapping an action fires it, then closes (iOS runs action + closeButtons).
//
// Two ways to drive it:
//   1. Slots (production) — pass default content and either #actions or the
//      `slideButtons` prop (the fallback #actions renders CardSlideButtons and
//      emits `action` with the button index).
//   2. Data-driven (Compare capture island) — pass `card` + `slideButtons`.
//      The default slot falls back to an embedded CardGroupMini.
//
// At rest (tx = 0) the content fully covers the action lane, so an isolated
// capture shows ONLY the content card — exactly what the iOS SwipeableCard
// renders before it is swiped.
interface MetaItem {
  number: string | number
  label?: string
}
interface SlideButtonSpec {
  /** Inline SVG string (semantic SF Symbols are mapped to SVG in the adapter). */
  icon: string
  variant?: 'reschedule' | 'delete' | 'skip' | 'edit'
}
interface CardSpec {
  title: string
  metadata?: MetaItem[]
  imageUrl?: string
}

// iOS SwipeableCard constants (SwipeableCard.swift:47-51, :199-205).
const MIN_BUTTON = 24
const MAX_BUTTON = 48
const MIN_ICON = 12
const MAX_ICON = 20
const BUTTON_GAP = 8
const LANE_LEADING = 8
const LANE_TRAILING = 16

interface Props {
  /** Explicit reveal width override; defaults to the iOS-computed lane width. */
  revealWidth?: number
  disabled?: boolean
  /** Chrome-less production wrap: the slotted card twin brings its own
   *  surface/radius (iOS SwipeableCard adds none) and the content may slide
   *  over the page gutter unclipped, like iOS. */
  bare?: boolean
  // ── Data-driven (capture) props ──────────────────────────────────────────
  isSwipeEnabled?: boolean
  slideButtons?: SlideButtonSpec[]
  /** Resting content card (mirrors the iOS ViewRegistry CardGroupMini). */
  card?: CardSpec
  class?: string
}
const props = withDefaults(defineProps<Props>(), {
  revealWidth: undefined,
  disabled: false,
  bare: false,
  isSwipeEnabled: true,
  slideButtons: () => [],
  // Defaults mirror the iOS `component.SwipeableCard` ViewRegistry content.
  card: () => ({ title: 'Swipeable Card', metadata: [{ number: '12', label: 'Members' }] }),
})
const emit = defineEmits<{ open: []; close: []; tap: []; action: [index: number] }>()

// Capture (data-driven) mode = no default slot supplied; the embedded
// CardGroupMini provides the chrome, so the wrapper drops its own surface/radius.
const slots = useSlots()
const isCapture = computed(() => !slots.default)

const swipeEnabled = computed(() => props.isSwipeEnabled && !props.disabled)

// iOS totalButtonWidth (SwipeableCard.swift:199-202). With a slotted #actions
// and no slideButtons the caller must pass revealWidth (legacy behavior: 76).
const reveal = computed(() => {
  if (props.revealWidth != null) return props.revealWidth
  const n = props.slideButtons.length
  if (!n) return 76
  return MAX_BUTTON * n + BUTTON_GAP * (n - 1) + LANE_LEADING + LANE_TRAILING
})

const tx = ref(0) // current translateX (0 = closed, -reveal = open)
const animating = ref(false)
const dragging = ref(false)
const revealed = ref(false)
let startX = 0
let startY = 0
let startTx = 0
let engaged = false // horizontal intent confirmed (direction lock)
let moved = false // suppress the click that follows a drag
let lastX = 0
let lastT = 0
let velocity = 0 // px/s, signed

// Progressive reveal (iOS revealProgress, :208-223).
const progress = computed(() => Math.min(Math.abs(tx.value) / reveal.value, 1))
const buttonStyle = computed(() => {
  const p = progress.value
  const size = MIN_BUTTON + (MAX_BUTTON - MIN_BUTTON) * p
  const icon = MIN_ICON + (MAX_ICON - MIN_ICON) * p
  return {
    width: `${size}px`,
    height: `${size}px`,
    opacity: `${p}`,
    '--csb-icon': `${icon}px`,
  }
})

function onPointerDown(e: PointerEvent) {
  if (!swipeEnabled.value) return
  dragging.value = true
  animating.value = false
  engaged = false
  moved = false
  startX = e.clientX
  startY = e.clientY
  startTx = tx.value
  lastX = e.clientX
  lastT = e.timeStamp
  velocity = 0
  ;(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId)
}
function onPointerMove(e: PointerEvent) {
  if (!dragging.value) return
  const dx = e.clientX - startX
  const dy = e.clientY - startY
  // Direction lock (iOS CardGestureCoordinator): vertical intent yields to
  // the scroll view; only a horizontal pan engages the swipe.
  if (!engaged) {
    if (Math.abs(dx) < 5 && Math.abs(dy) < 5) return
    if (Math.abs(dy) > Math.abs(dx)) {
      dragging.value = false
      return
    }
    engaged = true
  }
  moved = true
  // Track release velocity (px/s) from the last move segment.
  const dt = e.timeStamp - lastT
  if (dt > 0) velocity = ((e.clientX - lastX) / dt) * 1000
  lastX = e.clientX
  lastT = e.timeStamp
  // iOS handleSwipeChanged: negative offsets apply 1:1 (no rubber-band);
  // swiping right is clamped at 0.
  tx.value = Math.min(0, startTx + dx)
}
function settle() {
  if (!dragging.value) return
  dragging.value = false
  if (!engaged) return
  animating.value = true
  // iOS handleSwipeEnded: fast left flick OR past half the lane width.
  const open = velocity < -100 || Math.abs(tx.value) > reveal.value / 2
  tx.value = open ? -reveal.value : 0
  if (open !== revealed.value) {
    revealed.value = open
    emit(open ? 'open' : 'close')
  }
}
function close() {
  animating.value = true
  tx.value = 0
  if (revealed.value) {
    revealed.value = false
    emit('close')
  }
}
function onContentClick() {
  if (moved) {
    moved = false
    return
  }
  // iOS: tap closes a revealed card; otherwise it's the card's own tap.
  if (revealed.value) close()
  else emit('tap')
}
function onAction(index: number) {
  emit('action', index)
  close()
}

const contentStyle = computed(() => ({
  transform: `translateX(${swipeEnabled.value ? tx.value : 0}px)`,
  ...(dragging.value ? { transition: 'none' } : {}),
}))
defineExpose({ close })
</script>

<template>
  <div :class="['SwipeableCard', isCapture && 'SwipeableCard--capture', props.bare && 'SwipeableCard--bare', animating && 'SwipeableCard--animating', props.class]">
    <div class="SwipeableCard__actions" :style="{ width: `${reveal}px` }">
      <slot name="actions" :close="close" :progress="progress">
        <CardSlideButton
          v-for="(btn, i) in slideButtons"
          :key="i"
          :icon="btn.icon"
          :variant="btn.variant"
          :style="buttonStyle"
          @click="onAction(i)"
        />
      </slot>
    </div>
    <div
      class="SwipeableCard__content"
      :style="contentStyle"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="settle"
      @pointercancel="settle"
      @click="onContentClick"
      @transitionend="animating = false"
    >
      <slot>
        <CardGroupMini :title="card.title" :metadata="card.metadata" :image-url="card.imageUrl" />
      </slot>
    </div>
  </div>
</template>
