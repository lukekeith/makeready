<script setup lang="ts">
import { ref } from 'vue'
import { DialogRoot, DialogPortal, DialogContent, DialogClose } from 'reka-ui'

// BottomSheet — standalone controlled, draggable bottom sheet. Self-teleports
// to body via reka-ui's DialogPortal (focus trap + ESC + scroll lock). Frosted
// backdrop + slide-up transition match the ModalProvider sheet (mp-sheet-*).
// Drag-to-dismiss replicates modal-provider.vue's pointer logic.

interface Props {
  open: boolean
  title?: string
  dismissOnBackdrop?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  dismissOnBackdrop: true,
})

const emit = defineEmits<{ 'update:open': [boolean] }>()

function close() {
  emit('update:open', false)
}

// reka-ui drives open=false on ESC; backdrop tap is handled separately so we
// can honor dismissOnBackdrop.
function onOpenChange(next: boolean) {
  if (!next) close()
}

function onBackdrop() {
  if (props.dismissOnBackdrop) close()
}

// ─── Drag-to-dismiss (replicated from modal-provider.vue) ─────────────────────
const dragY = ref(0)
const dragging = ref(false)
let dragStartY = 0

function onPointerDown(e: PointerEvent) {
  dragging.value = true
  dragStartY = e.clientY
  dragY.value = 0
  ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
}
function onPointerMove(e: PointerEvent) {
  if (!dragging.value) return
  dragY.value = Math.max(0, e.clientY - dragStartY) // only downward
}
function onPointerUp() {
  if (!dragging.value) return
  const dismissed = dragY.value > 96
  dragging.value = false
  dragY.value = 0
  if (dismissed) close()
}
</script>

<template>
  <DialogRoot :open="open" @update:open="onOpenChange">
    <DialogPortal>
      <Transition name="mp-backdrop">
        <div
          v-if="open"
          class="BottomSheet__backdrop"
          aria-hidden="true"
          @click="onBackdrop"
        />
      </Transition>

      <Transition name="mp-sheet">
        <DialogContent
          v-if="open"
          class="BottomSheet"
          :aria-label="title || 'Sheet'"
          :style="dragging ? { transform: `translateY(${dragY}px)`, transition: 'none' } : undefined"
        >
          <div
            class="BottomSheet__grabber-area"
            @pointerdown="onPointerDown"
            @pointermove="onPointerMove"
            @pointerup="onPointerUp"
            @pointercancel="onPointerUp"
          >
            <span class="BottomSheet__grabber" />
          </div>

          <h2 v-if="title" class="BottomSheet__title">{{ title }}</h2>

          <div class="BottomSheet__content">
            <slot />
          </div>

          <DialogClose class="BottomSheet__sr-close" aria-label="Close">Close</DialogClose>
        </DialogContent>
      </Transition>
    </DialogPortal>
  </DialogRoot>
</template>
