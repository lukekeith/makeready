<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'

// DragulaList — web twin of the iPhone drag-to-reorder list
// (Components/Layout/Dragula.swift, vendored Dragula + UIDragInteraction).
//
// iOS mechanics reproduced:
//   • Long-press lifts the row (system drag lift ≈ 0.5s hold): the row floats
//     as a full-size ghost with a 12px-radius clip and a lift shadow, while its
//     slot cross-fades to the drop indicator.
//   • Drop indicator = ReorderDropIndicator (ReorderHelpers.swift): a filled
//     rounded-rect gap — white @ 6%, 48px tall, 12px radius — centered in the
//     lifted row's slot (the slot keeps its frame, like SwiftUI .hidden()).
//   • Siblings move out of the way live as the ghost's center crosses their
//     midpoints (iOS dropEntered + items.move on .spring).
//   • Release fires `reorder` with the new id order (iOS dropCompleted) — the
//     parent persists it (optimistic local update first, like the iPhone).
//
// The list owns its row gap (iOS inherits the parent VStack spacing — lessons
// and activities both use spacing 4). Rendering is slot-driven so any card twin
// can be a row: <DragulaList :items="..." #item="{ item }">…</DragulaList>.
//
// No auto-scroll near edges — iOS Dragula has none either.

interface Props {
  items: Array<{ id: string }>
  /** iOS canEdit gating — when false the list renders inert rows. */
  enabled?: boolean
  /** Row gap in px (iOS parent VStack spacing; lessons/activities use 4). */
  gap?: number
  /** Hold duration before the lift (iOS system drag ≈ 500ms). */
  holdMs?: number
}

const props = withDefaults(defineProps<Props>(), {
  enabled: true,
  gap: 4,
  holdMs: 450,
})

const emit = defineEmits<{ reorder: [ids: string[]] }>()

// Local visual order — reordered live during a drag, re-synced from props when
// not dragging (the parent's optimistic update lands here after the drop).
const order = ref<string[]>(props.items.map((i) => i.id))
const draggingId = ref<string | null>(null)

watch(
  () => props.items.map((i) => i.id),
  (ids) => {
    if (!draggingId.value) order.value = [...ids]
  },
  { deep: false },
)

const orderedItems = computed(() =>
  order.value
    .map((id) => props.items.find((i) => i.id === id))
    .filter((i): i is Props['items'][number] => Boolean(i)),
)

// ── Drag state ──────────────────────────────────────────────────────────────
const listEl = ref<HTMLElement | null>(null)
const ghostStyle = ref<Record<string, string>>({})
const settling = ref(false)

let holdTimer: ReturnType<typeof setTimeout> | null = null
let pendingId: string | null = null
let pointerId = -1
let startX = 0
let startY = 0
let grabDX = 0 // pointer offset inside the row at lift
let grabDY = 0
let ghostW = 0
let ghostH = 0
let startedOrder: string[] = []

const draggingItem = computed(
  () => props.items.find((i) => i.id === draggingId.value) ?? null,
)

function rowEls(): HTMLElement[] {
  return Array.from(listEl.value?.querySelectorAll<HTMLElement>('.DragulaList__row') ?? [])
}

function onPointerDown(e: PointerEvent, id: string) {
  if (!props.enabled || draggingId.value || settling.value) return
  pendingId = id
  pointerId = e.pointerId
  startX = e.clientX
  startY = e.clientY
  const row = (e.currentTarget as HTMLElement)
  const rect = row.getBoundingClientRect()
  grabDX = e.clientX - rect.left
  grabDY = e.clientY - rect.top
  ghostW = rect.width
  ghostH = rect.height
  holdTimer = setTimeout(() => lift(rect), props.holdMs)
  window.addEventListener('pointermove', onWindowMove)
  window.addEventListener('pointerup', onWindowUp)
  window.addEventListener('pointercancel', onWindowUp)
  // While lifted, block native (vertical) scrolling for this touch — the
  // first cancelable touchmove after a still hold can still be prevented.
  window.addEventListener('touchmove', onTouchMove, { passive: false })
}

function lift(rect: DOMRect) {
  holdTimer = null
  if (!pendingId) return
  draggingId.value = pendingId
  startedOrder = [...order.value]
  ghostStyle.value = {
    width: `${ghostW}px`,
    height: `${ghostH}px`,
    left: `${rect.left}px`,
    top: `${rect.top}px`,
    transform: 'translate(0px, 0px)',
  }
}

function onTouchMove(e: TouchEvent) {
  if (draggingId.value && e.cancelable) e.preventDefault()
}

function onWindowMove(e: PointerEvent) {
  if (e.pointerId !== pointerId) return
  if (!draggingId.value) {
    // Movement before the hold elapses = scroll/tap intent — cancel the lift.
    if (holdTimer && Math.hypot(e.clientX - startX, e.clientY - startY) > 6) cleanup()
    return
  }
  ghostStyle.value = {
    ...ghostStyle.value,
    transform: `translate(${e.clientX - startX}px, ${e.clientY - startY}px)`,
  }
  reorderAround(e.clientY)
}

// Live sibling reorder (iOS DragulaDropDelegate.dropEntered): when the ghost's
// vertical center crosses a row's midpoint, move the dragged id there.
function reorderAround(pointerY: number) {
  const centerY = pointerY - grabDY + ghostH / 2
  const id = draggingId.value
  if (!id) return
  const from = order.value.indexOf(id)
  let to = from
  const rows = rowEls()
  for (let i = 0; i < rows.length; i++) {
    const rowId = rows[i].dataset.dragId
    if (!rowId || rowId === id) continue
    const r = rows[i].getBoundingClientRect()
    const mid = r.top + r.height / 2
    const idx = order.value.indexOf(rowId)
    if (idx < from && centerY < mid) {
      to = Math.min(to, idx)
    } else if (idx > from && centerY > mid) {
      to = Math.max(to, idx)
    }
  }
  if (to !== from) {
    const next = [...order.value]
    next.splice(from, 1)
    next.splice(to, 0, id)
    order.value = next
  }
}

async function onWindowUp(e: PointerEvent) {
  if (e.pointerId !== pointerId) return
  const wasDragging = Boolean(draggingId.value)
  if (!wasDragging) {
    cleanup()
    return
  }
  // Fly the ghost home to its slot, then settle (iOS drop cancel-animation).
  await nextTick()
  const slot = rowEls().find((r) => r.dataset.dragId === draggingId.value)
  const rect = slot?.getBoundingClientRect()
  if (rect) {
    settling.value = true
    ghostStyle.value = {
      ...ghostStyle.value,
      transition: 'transform 250ms cubic-bezier(0.32, 0.72, 0, 1)',
      transform: `translate(${rect.left - parseFloat(ghostStyle.value.left)}px, ${
        rect.top - parseFloat(ghostStyle.value.top)
      }px)`,
    }
    setTimeout(finishDrop, 260)
  } else {
    finishDrop()
  }
}

function finishDrop() {
  const changed =
    draggingId.value !== null &&
    order.value.some((id, i) => id !== startedOrder[i])
  const finalOrder = [...order.value]
  cleanup()
  if (changed) emit('reorder', finalOrder)
}

function cleanup() {
  if (holdTimer) clearTimeout(holdTimer)
  holdTimer = null
  pendingId = null
  pointerId = -1
  draggingId.value = null
  settling.value = false
  ghostStyle.value = {}
  window.removeEventListener('pointermove', onWindowMove)
  window.removeEventListener('pointerup', onWindowUp)
  window.removeEventListener('pointercancel', onWindowUp)
  window.removeEventListener('touchmove', onTouchMove)
}
</script>

<template>
  <div ref="listEl" class="DragulaList" :style="{ gap: `${props.gap}px` }">
    <TransitionGroup name="DragulaList">
      <div
        v-for="item in orderedItems"
        :key="item.id"
        class="DragulaList__row"
        :class="{ 'DragulaList__row--dragging': item.id === draggingId }"
        :data-drag-id="item.id"
        @pointerdown="onPointerDown($event, item.id)"
      >
        <div class="DragulaList__rowContent">
          <slot name="item" :item="item" :dragging="item.id === draggingId" />
        </div>
        <!-- iOS ReorderDropIndicator: white@6% · 48px · radius 12, centered in
             the lifted row's preserved frame. -->
        <div v-if="item.id === draggingId" class="DragulaList__indicator"></div>
      </div>
    </TransitionGroup>

    <!-- Full-size floating ghost (iOS UIDragPreview: 12px radius, lift shadow). -->
    <Teleport to="body">
      <div v-if="draggingItem" class="DragulaList__ghost" :style="ghostStyle">
        <slot name="item" :item="draggingItem" :dragging="false" />
      </div>
    </Teleport>
  </div>
</template>
