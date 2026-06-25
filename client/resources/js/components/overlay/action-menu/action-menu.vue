<script setup lang="ts">
import { ref } from 'vue'
import { DialogRoot, DialogPortal, DialogContent, DialogClose } from 'reka-ui'

// ActionMenu — bottom action sheet of choices (iOS AddMenu / contextual menu).
// Reuses the BottomSheet look + drag-to-dismiss. Standalone controlled, self-
// teleports to body via reka-ui (focus trap + ESC + scroll lock). Emits
// select(key) then closes.

export interface ActionMenuAction {
  key: string
  label: string
  icon?: string
  destructive?: boolean
}

interface Props {
  open: boolean
  title?: string
  actions: ActionMenuAction[]
}

const props = defineProps<Props>()

const emit = defineEmits<{
  'update:open': [boolean]
  select: [string]
}>()

function close() {
  emit('update:open', false)
}

function onOpenChange(next: boolean) {
  if (!next) close()
}

function onSelect(action: ActionMenuAction) {
  emit('select', action.key)
  close()
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
          class="ActionMenu__backdrop"
          aria-hidden="true"
          @click="close"
        />
      </Transition>

      <Transition name="mp-sheet">
        <DialogContent
          v-if="open"
          class="ActionMenu"
          :aria-label="title || 'Actions'"
          :style="dragging ? { transform: `translateY(${dragY}px)`, transition: 'none' } : undefined"
        >
          <div
            class="ActionMenu__grabber-area"
            @pointerdown="onPointerDown"
            @pointermove="onPointerMove"
            @pointerup="onPointerUp"
            @pointercancel="onPointerUp"
          >
            <span class="ActionMenu__grabber" />
          </div>

          <h2 v-if="title" class="ActionMenu__title">{{ title }}</h2>

          <ul class="ActionMenu__list">
            <li v-for="action in actions" :key="action.key">
              <button
                class="ActionMenu__item"
                :class="action.destructive && 'ActionMenu__item--destructive'"
                type="button"
                @click="onSelect(action)"
              >
                <span v-if="$slots.icon || action.icon" class="ActionMenu__icon">
                  <slot name="icon" :action="action" />
                </span>
                <span class="ActionMenu__label">{{ action.label }}</span>
              </button>
            </li>
          </ul>

          <DialogClose class="ActionMenu__item ActionMenu__item--cancel" aria-label="Cancel">
            <span class="ActionMenu__label">Cancel</span>
          </DialogClose>
        </DialogContent>
      </Transition>
    </DialogPortal>
  </DialogRoot>
</template>
