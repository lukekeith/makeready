<script setup lang="ts">
import { ref, computed } from 'vue'

// SwipeableCard — swipe the content left to reveal the trailing #actions
// (SlideButtons). Pointer-driven; snaps open/closed past half the reveal width.
// Reduced-motion users still get the reveal (it just snaps without easing via
// the --animating class, which is gated by the SCSS motion tokens).
interface Props {
  /** Width revealed when fully open; defaults to ~one 72px action lane. */
  revealWidth?: number
  disabled?: boolean
  class?: string
}
const props = withDefaults(defineProps<Props>(), {
  revealWidth: 76,
  disabled: false,
})
const emit = defineEmits<{ open: []; close: [] }>()

const tx = ref(0) // current translateX (0 = closed, -revealWidth = open)
const animating = ref(false)
const dragging = ref(false)
let startX = 0
let startTx = 0

function onPointerDown(e: PointerEvent) {
  if (props.disabled) return
  dragging.value = true
  animating.value = false
  startX = e.clientX
  startTx = tx.value
  ;(e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId)
}
function onPointerMove(e: PointerEvent) {
  if (!dragging.value) return
  const dx = e.clientX - startX
  // Clamp between fully open (-revealWidth) and closed (0); allow a little
  // rubber-band past closed.
  tx.value = Math.min(8, Math.max(-props.revealWidth, startTx + dx))
}
function settle() {
  if (!dragging.value) return
  dragging.value = false
  animating.value = true
  const open = tx.value < -props.revealWidth / 2
  tx.value = open ? -props.revealWidth : 0
  emit(open ? 'open' : 'close')
}
function close() {
  animating.value = true
  if (tx.value !== 0) emit('close')
  tx.value = 0
}

const contentStyle = computed(() => ({
  transform: `translateX(${tx.value}px)`,
  ...(dragging.value ? { transition: 'none' } : {}),
}))
defineExpose({ close })
</script>

<template>
  <div :class="['SwipeableCard', animating && 'SwipeableCard--animating', props.class]">
    <div class="SwipeableCard__actions" :style="{ width: `${revealWidth}px` }">
      <slot name="actions" :close="close" />
    </div>
    <div
      class="SwipeableCard__content"
      :style="contentStyle"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="settle"
      @pointercancel="settle"
      @transitionend="animating = false"
    >
      <slot />
    </div>
  </div>
</template>
