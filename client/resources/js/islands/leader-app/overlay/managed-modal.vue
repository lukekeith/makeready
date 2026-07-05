<script setup lang="ts">
// ManagedModal — web twin of iPhone ManagedModalView (OverlayManager.swift).
//
// Full-screen bottom sheet: dark scrim fading to black@0.5, sheet sliding up
// from below with top corners rounded 16px and a 34×5 white@50 drag capsule
// overlaid at the top. Present ≈ iOS spring(response 0.4, damping 0.85) —
// approximated as 400ms ease-out-quint; dismiss ≈ spring(0.3/0.85) → 300ms
// ease-in. Offset + scrim animate in the SAME phase (never mixed curves).
// Drag down on the indicator > 80px dismisses, carrying the drag offset into
// the exit so there's no jump-back. Removal is tied to transitionend, not a
// timer; the store's dismiss completions fire from finalize().
import { nextTick, onMounted, provide, ref } from 'vue'
import { OVERLAY_CONTEXT, useOverlayManager } from './overlay.store'

const props = defineProps<{
  overlayId: string
  dismissOnTapOutside: boolean
}>()

const store = useOverlayManager()

const shown = ref(false)
const dismissing = ref(false)
const dragOffset = ref(0)
const dragging = ref(false)

function animatedDismiss(): void {
  if (dismissing.value) return
  dismissing.value = true
  // Carry any in-flight drag into the exit (iOS offset += translation trick).
  dragging.value = false
  shown.value = false
}

onMounted(() => {
  store.registerAnimatedDismiss(props.overlayId, animatedDismiss)
  // Deferred one tick so content lays out before the slide (iOS
  // DispatchQueue.main.async before animateAppear).
  nextTick(() => {
    requestAnimationFrame(() => {
      shown.value = true
    })
  })
})

function onTransitionEnd(e: TransitionEvent): void {
  if (e.propertyName !== 'transform') return
  if (dismissing.value) store.finalize(props.overlayId)
}

function onScrimClick(): void {
  if (props.dismissOnTapOutside) animatedDismiss()
}

// ── Drag-to-dismiss (drag indicator + any PageTitleBar inside the sheet) ──
//
// A pointer-down on a draggable region only ARMS the gesture; the sheet starts
// dragging (and captures the pointer) once the pointer moves past a small
// threshold. A stationary tap therefore never becomes a drag — buttons inside
// the title bar receive their click untouched. After a real drag, the capture-
// phase click handler swallows the stray click that follows pointerup.
const sheetEl = ref<HTMLElement | null>(null)
const DRAG_REGIONS = '.ManagedModal__dragArea, .PageTitleBar'
const DRAG_START_THRESHOLD = 6

let armed = false
let dragStartY = 0
let activePointerId = 0
let didDrag = false

function onSheetPointerDown(e: PointerEvent): void {
  if (!(e.target as HTMLElement).closest?.(DRAG_REGIONS)) return
  armed = true
  didDrag = false
  dragStartY = e.clientY
  activePointerId = e.pointerId
}

function onSheetPointerMove(e: PointerEvent): void {
  if (!armed || e.pointerId !== activePointerId) return
  const dy = e.clientY - dragStartY
  if (!dragging.value && dy > DRAG_START_THRESHOLD) {
    dragging.value = true
    didDrag = true
    sheetEl.value?.setPointerCapture(activePointerId)
  }
  if (dragging.value) dragOffset.value = Math.max(0, dy)
}

function onSheetPointerUp(e: PointerEvent): void {
  if (!armed || e.pointerId !== activePointerId) return
  armed = false
  if (!dragging.value) return
  const passed = dragOffset.value > 80
  dragging.value = false
  if (passed) {
    animatedDismiss()
  } else {
    dragOffset.value = 0
  }
}

// Swallow the click that follows a real drag so buttons under the pointer
// don't activate on release.
function onSheetClickCapture(e: MouseEvent): void {
  if (!didDrag) return
  didDrag = false
  e.stopPropagation()
  e.preventDefault()
}

provide(OVERLAY_CONTEXT, {
  dismiss: animatedDismiss,
  dismissThen: (completion: () => void) => store.dismissThen(props.overlayId, completion),
})
</script>

<template>
  <div
    class="ManagedModal"
    :class="{ 'ManagedModal--shown': shown, 'ManagedModal--dragging': dragging }"
  >
    <div class="ManagedModal__scrim" @click="onScrimClick"></div>
    <div
      ref="sheetEl"
      class="ManagedModal__sheet"
      :style="dragging ? { transform: `translateY(${dragOffset}px)` } : undefined"
      @transitionend="onTransitionEnd"
      @pointerdown="onSheetPointerDown"
      @pointermove="onSheetPointerMove"
      @pointerup="onSheetPointerUp"
      @pointercancel="onSheetPointerUp"
      @click.capture="onSheetClickCapture"
    >
      <slot />
      <div class="ManagedModal__dragArea">
        <span class="ManagedModal__dragIndicator"></span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Fills the viewport, clipped to the 480px phone column. */
.ManagedModal {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  overflow: hidden;
}

.ManagedModal__scrim {
  position: absolute;
  inset: 0;
  background: #000;
  opacity: 0;
  /* Same phase timing as the sheet (single-curve rule). */
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

.ManagedModal--shown .ManagedModal__scrim {
  opacity: 0.5;
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

.ManagedModal:not(.ManagedModal--shown) .ManagedModal__scrim {
  transition: opacity 300ms cubic-bezier(0.42, 0, 1, 1);
}

.ManagedModal__sheet {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  border-radius: 16px 16px 0 0;
  overflow: hidden;
  transform: translateY(100%);
  transition: transform 300ms cubic-bezier(0.42, 0, 1, 1);
  will-change: transform;
}

.ManagedModal--shown .ManagedModal__sheet {
  transform: translateY(0);
  /* Present ≈ iOS ModalAnimations.appear spring (0.4s, damping 0.85). */
  transition: transform 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

/* During drag: no transition, offset follows the pointer (iOS transaction
   animation = nil). */
.ManagedModal--dragging .ManagedModal__sheet {
  transition: none;
}

.ManagedModal__dragArea {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  touch-action: none;
}

/* Any PageTitleBar inside the sheet is a drag surface: touch-action none stops
   native panning from eating the gesture; taps on its buttons still click
   (drag only starts past the movement threshold). The 16px top inset is iOS
   PageTitle's modalProvidesDragIndicator spacer pushing the title row below
   the overlaid drag capsule — it belongs to PageTitle-in-modal, never the
   sheet (full-bleed content must still reach the top edge). */
.ManagedModal__sheet :deep(.PageTitleBar) {
  touch-action: none;
  padding-top: 16px;
}

.ManagedModal__dragIndicator {
  width: 34px;
  height: 5px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.5);
}
</style>
