<script setup lang="ts">
// ManagedMenu — web twin of iPhone ManagedMenuView (OverlayManager.swift:471).
//
// A CONTENT-SIZED bottom card (unlike ManagedModal's full-height sheet):
// fill #111215, top corners 16px with a 1px #242937 stroke, upward shadow,
// and a 34×5 tertiaryLabel grabber centered in a 24px strip rendered as the
// first layout child (the modal overlays its capsule on content instead).
// Scrim tap ALWAYS dismisses — iOS menus have no dismissOnTapOutside flag.
// Same springs as the modal chrome (present ≈ spring 0.4/0.85 → 400ms
// ease-out-quint, dismiss ≈ spring 0.3/0.85 → 300ms ease-in); drag-to-dismiss
// works from the grabber strip only, threshold 80px, drag offset carried into
// the exit. Removal is tied to transitionend via the store's finalize().
import { nextTick, onMounted, provide, ref } from 'vue'
import { OVERLAY_CONTEXT, useOverlayManager } from './overlay.store'

const props = defineProps<{
  overlayId: string
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

// ── Drag-to-dismiss (grabber strip only — iOS gesture lives on the strip) ──
const cardEl = ref<HTMLElement | null>(null)
const DRAG_START_THRESHOLD = 5

let armed = false
let dragStartY = 0
let activePointerId = 0

function onGrabberPointerDown(e: PointerEvent): void {
  armed = true
  dragStartY = e.clientY
  activePointerId = e.pointerId
}

function onGrabberPointerMove(e: PointerEvent): void {
  if (!armed || e.pointerId !== activePointerId) return
  const dy = e.clientY - dragStartY
  if (!dragging.value && dy > DRAG_START_THRESHOLD) {
    dragging.value = true
    ;(e.currentTarget as HTMLElement)?.setPointerCapture(activePointerId)
  }
  if (dragging.value) dragOffset.value = Math.max(0, dy)
}

function onGrabberPointerUp(e: PointerEvent): void {
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

provide(OVERLAY_CONTEXT, {
  dismiss: animatedDismiss,
  dismissThen: (completion: () => void) => store.dismissThen(props.overlayId, completion),
})
</script>

<template>
  <div
    class="ManagedMenu"
    :class="{ 'ManagedMenu--shown': shown, 'ManagedMenu--dragging': dragging }"
  >
    <div class="ManagedMenu__scrim" @click="animatedDismiss"></div>
    <div
      ref="cardEl"
      class="ManagedMenu__card"
      :style="dragging ? { transform: `translateY(${dragOffset}px)` } : undefined"
      @transitionend="onTransitionEnd"
    >
      <div
        class="ManagedMenu__dragArea"
        @pointerdown="onGrabberPointerDown"
        @pointermove="onGrabberPointerMove"
        @pointerup="onGrabberPointerUp"
        @pointercancel="onGrabberPointerUp"
      >
        <span class="ManagedMenu__grabber"></span>
      </div>
      <slot />
    </div>
  </div>
</template>

<style scoped>
/* Fills the viewport, clipped to the 480px phone column. */
.ManagedMenu {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  overflow: hidden;
}

.ManagedMenu__scrim {
  position: absolute;
  inset: 0;
  background: #000;
  opacity: 0;
  /* Same phase timing as the card (single-curve rule). */
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

.ManagedMenu--shown .ManagedMenu__scrim {
  opacity: 0.5;
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

.ManagedMenu:not(.ManagedMenu--shown) .ManagedMenu__scrim {
  transition: opacity 300ms cubic-bezier(0.42, 0, 1, 1);
}

/* Content-sized bottom card. The 1px #242937 stroke rides the top-rounded
   outline; the bottom edge is offscreen on iOS (card extends through the home
   indicator), so no bottom border here. */
.ManagedMenu__card {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  flex-direction: column;
  background: #111215;
  border: 1px solid #242937;
  border-bottom: none;
  border-radius: 16px 16px 0 0;
  box-shadow: 0 -8px 24px rgba(0, 0, 0, 0.45);
  overflow: hidden;
  transform: translateY(100%);
  transition: transform 300ms cubic-bezier(0.42, 0, 1, 1);
  will-change: transform;
}

.ManagedMenu--shown .ManagedMenu__card {
  transform: translateY(0);
  /* Present ≈ iOS ModalAnimations.appear spring (0.4s, damping 0.85). */
  transition: transform 400ms cubic-bezier(0.32, 0.72, 0, 1);
}

/* During drag: no transition, offset follows the pointer (iOS transaction
   animation = nil). */
.ManagedMenu--dragging .ManagedMenu__card {
  transition: none;
}

/* 24px transparent hit strip, first layout child (iOS Rectangle.fill(.clear)
   .frame(height: 24)). */
.ManagedMenu__dragArea {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 24px;
  flex: none;
  cursor: grab;
  touch-action: none;
}

/* 34×5 capsule, iOS tertiaryLabel (dark ≈ rgba(235,235,245,0.3)) — NOT the
   modal's white@0.5. */
.ManagedMenu__grabber {
  width: 34px;
  height: 5px;
  border-radius: 999px;
  background: rgba(235, 235, 245, 0.3);
}
</style>
