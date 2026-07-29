<script setup lang="ts">
// ManagedPage — web twin of iPhone ManagedPageView (OverlayManager.swift:381).
//
// Horizontal push chrome, used only by `.page` routes (iOS: .memberRequests
// alone). Full-bleed page slides in from the right; a black scrim UNDER the
// page dims proportionally to slide progress (max 0.30) and NEVER receives
// taps (iOS .allowsHitTesting(false) — dismissOnTapOutside is dead metadata
// for page chrome). Entrance Motion.pagePush = easeOut 300ms; exit
// Motion.pageDismiss = easeIn 250ms; removal tied to transitionend via the
// store's finalize(). Edge-swipe back: arms within 40px of the page's left
// edge, right-only, horizontal-dominant (vertical scrolls win), commits past
// 80px with the drag carried into the exit; sub-threshold releases snap back
// (~Motion.settle — iOS uses the un-tokenized @GestureState default spring).
// No grabber, no PageTitle top inset — those belong to modal chrome.
import { computed, nextTick, onMounted, provide, ref } from 'vue'
import { OVERLAY_CONTEXT, useOverlayManager } from './overlay.store'

const props = defineProps<{
  overlayId: string
}>()

const store = useOverlayManager()

const shown = ref(false)
const dismissing = ref(false)
const dragOffset = ref(0)
const dragging = ref(false)
const snapping = ref(false)

const pageEl = ref<HTMLElement | null>(null)

function animatedDismiss(): void {
  if (dismissing.value) return
  dismissing.value = true
  // iOS: offset += translation BEFORE dismissing so the gesture reset doesn't
  // jump — the CSS transition starts from the dragged position automatically.
  dragging.value = false
  dragOffset.value = 0
  shown.value = false
}

onMounted(() => {
  store.registerAnimatedDismiss(props.overlayId, animatedDismiss)
  // One-runloop defer so content lays out before the slide (iOS
  // DispatchQueue.main.async — text must ride the slide, not pop in place).
  nextTick(() => {
    requestAnimationFrame(() => {
      shown.value = true
    })
  })
})

function onTransitionEnd(e: TransitionEvent): void {
  if (e.propertyName !== 'transform') return
  if (dismissing.value) store.finalize(props.overlayId)
  snapping.value = false
}

// Scrim opacity derived from slide progress (iOS dimOpacity): 0.3 at rest,
// lightens live while dragging. CSS transitions handle enter/exit; during a
// drag we bind the computed value directly.
const dragScrimOpacity = computed(() => {
  const w = pageEl.value?.offsetWidth || 480
  return 0.3 * (1 - Math.min(1, dragOffset.value / w))
})

// ── Edge-swipe back (iOS DragGesture(minimumDistance: 15) + startLocation
//    x < 40 + commit > 80; ScrollView wins vertical drags) ──
const EDGE_ZONE = 40
const MIN_DISTANCE = 15
const COMMIT = 80

let armed = false
let startX = 0
let startY = 0
let activePointerId = 0

function onPointerDown(e: PointerEvent): void {
  const rect = pageEl.value?.getBoundingClientRect()
  if (!rect) return
  if (e.clientX - rect.left >= EDGE_ZONE) return
  armed = true
  startX = e.clientX
  startY = e.clientY
  activePointerId = e.pointerId
}

function onPointerMove(e: PointerEvent): void {
  if (!armed || e.pointerId !== activePointerId) return
  const dx = e.clientX - startX
  const dy = e.clientY - startY
  if (!dragging.value) {
    if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > MIN_DISTANCE) {
      // Vertical-dominant: the inner scroll wins (iOS child-gesture precedence).
      armed = false
      return
    }
    if (dx > MIN_DISTANCE) {
      dragging.value = true
      pageEl.value?.setPointerCapture(activePointerId)
    }
  }
  if (dragging.value) dragOffset.value = Math.max(0, dx)
}

function onPointerUp(e: PointerEvent): void {
  if (!armed || e.pointerId !== activePointerId) return
  armed = false
  if (!dragging.value) return
  const passed = dragOffset.value > COMMIT
  dragging.value = false
  if (passed) {
    // Keep the dragged position as the exit's starting frame.
    if (dismissing.value) return
    dismissing.value = true
    shown.value = false
    dragOffset.value = 0
  } else {
    snapping.value = true
    dragOffset.value = 0
  }
}

provide(OVERLAY_CONTEXT, {
  dismiss: animatedDismiss,
  dismissThen: (completion: () => void) => store.dismissThen(props.overlayId, completion),
})
</script>

<template>
  <div class="ManagedPage" :class="{ 'ManagedPage--shown': shown, 'ManagedPage--dragging': dragging, 'ManagedPage--snapping': snapping }">
    <div
      class="ManagedPage__scrim"
      :style="dragging ? { opacity: dragScrimOpacity, transition: 'none' } : undefined"
    ></div>
    <div
      ref="pageEl"
      class="ManagedPage__page"
      :style="dragging ? { transform: `translateX(${dragOffset}px)` } : undefined"
      @transitionend="onTransitionEnd"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
    >
      <slot />
    </div>
  </div>
</template>

<style scoped>
/* Fills the viewport, clipped to the 480px phone column. */
.ManagedPage {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  overflow: hidden;
}

/* Scrim BELOW the page; never interactive (iOS .allowsHitTesting(false)). */
.ManagedPage__scrim {
  position: absolute;
  inset: 0;
  background: #000;
  opacity: 0;
  pointer-events: none;
  /* Exit phase: same curve/duration as the page (single-curve rule). */
  transition: opacity 250ms cubic-bezier(0.42, 0, 1, 1);
}

.ManagedPage--shown .ManagedPage__scrim {
  opacity: 0.3;
  /* Entrance ≈ iOS Motion.pagePush easeOut 300ms. */
  transition: opacity 300ms cubic-bezier(0, 0, 0.58, 1);
}

.ManagedPage__page {
  position: absolute;
  inset: 0;
  background: var(--color-canvas);
  transform: translateX(100%);
  /* Exit ≈ iOS Motion.pageDismiss easeIn 250ms. */
  transition: transform 250ms cubic-bezier(0.42, 0, 1, 1);
  will-change: transform;
  /* Vertical pans belong to the inner scroll; the swipe-back arms itself. */
  touch-action: pan-y;
}

.ManagedPage--shown .ManagedPage__page {
  transform: translateX(0);
  /* Entrance ≈ iOS Motion.pagePush easeOut 300ms. */
  transition: transform 300ms cubic-bezier(0, 0, 0.58, 1);
}

/* During drag: no transition, transform follows the pointer (iOS
   transaction.animation = nil). */
.ManagedPage--dragging .ManagedPage__page {
  transition: none;
}

/* Cancelled swipe snap-back ≈ Motion.settle (iOS: un-tokenized default
   spring on @GestureState reset — approximated). */
.ManagedPage--snapping .ManagedPage__page {
  transition: transform 200ms cubic-bezier(0, 0, 0.58, 1);
}
</style>
