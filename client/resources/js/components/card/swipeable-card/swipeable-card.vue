<script setup lang="ts">
import { ref, computed, useSlots } from 'vue'
import CardGroupMini from '../card-group-mini/card-group-mini.vue'
import CardSlideButton from '../card-slide-button/card-slide-button.vue'

// SwipeableCard — swipe the content left to reveal the trailing #actions
// (SlideButtons). Pointer-driven; snaps open/closed past half the reveal width.
//
// Two ways to drive it:
//   1. Slots (interactive demo / story) — pass #actions and default content.
//   2. Data-driven (Compare capture island) — pass `card` + `slideButtons`
//      props. The default slot then falls back to an embedded CardGroupMini and
//      the #actions slot to a row of CardSlideButtons.
//
// At rest (tx = 0) the content fully covers the action lane, so an isolated
// capture shows ONLY the content card — exactly what the iOS SwipeableCard
// renders before it is swiped (abs(offset) > 5). The web twin therefore matches
// the iPhone reference by presenting the resting content card; the buttons sit
// hidden behind it for API fidelity.
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

interface Props {
  /** Width revealed when fully open; defaults to ~one 72px action lane. */
  revealWidth?: number
  disabled?: boolean
  // ── Data-driven (capture) props ──────────────────────────────────────────
  isSwipeEnabled?: boolean
  slideButtons?: SlideButtonSpec[]
  /** Resting content card (mirrors the iOS ViewRegistry CardGroupMini). */
  card?: CardSpec
  class?: string
}
const props = withDefaults(defineProps<Props>(), {
  revealWidth: 76,
  disabled: false,
  isSwipeEnabled: true,
  slideButtons: () => [],
  // Defaults mirror the iOS `component.SwipeableCard` ViewRegistry content.
  card: () => ({ title: 'Swipeable Card', metadata: [{ number: '12', label: 'Members' }] }),
})
const emit = defineEmits<{ open: []; close: [] }>()

// Capture (data-driven) mode = no default slot supplied; the embedded
// CardGroupMini provides the chrome, so the wrapper drops its own surface/radius.
const slots = useSlots()
const isCapture = computed(() => !slots.default)

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
  <div :class="['SwipeableCard', isCapture && 'SwipeableCard--capture', animating && 'SwipeableCard--animating', props.class]">
    <div class="SwipeableCard__actions" :style="{ width: `${revealWidth}px` }">
      <slot name="actions" :close="close">
        <CardSlideButton
          v-for="(btn, i) in slideButtons"
          :key="i"
          :icon="btn.icon"
          :variant="btn.variant"
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
      @transitionend="animating = false"
    >
      <slot>
        <CardGroupMini :title="card.title" :metadata="card.metadata" :image-url="card.imageUrl" />
      </slot>
    </div>
  </div>
</template>
