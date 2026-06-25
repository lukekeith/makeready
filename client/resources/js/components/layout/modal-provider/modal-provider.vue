<script setup lang="ts">
import { onMounted, onUnmounted, ref, watch, nextTick } from 'vue'
import { useModalStore } from '../../../stores/modal.store'
import { useToastStore, type FeedbackTone } from '../../../stores/toast.store'
import { modalRegistry } from '../../../modal-registry'
import './modal-provider.scss'

const modalStore = useModalStore()
const toastStore = useToastStore()

// ─── Backdrop dismiss default (fullscreen flows opt out) ──────────────────────
function backdropDismissable(modal: { type: string; dismissOnBackdrop?: boolean }) {
  return modal.dismissOnBackdrop ?? modal.type !== 'fullscreen'
}
function onBackdrop(modal: { id: string; type: string; dismissOnBackdrop?: boolean }) {
  if (backdropDismissable(modal)) modalStore.close(modal.id)
}

// ─── ESC closes topmost ───────────────────────────────────────────────────────
function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape' && modalStore.hasOpenModals) {
    e.preventDefault()
    modalStore.closeTopmost()
  }
}

// ─── Body-scroll lock + focus restore ─────────────────────────────────────────
let lastFocused: HTMLElement | null = null
const containerRefs = new Map<string, HTMLElement>()
function setContainerRef(id: string, el: unknown) {
  if (el) containerRefs.set(id, el as HTMLElement)
  else containerRefs.delete(id)
}

watch(
  () => modalStore.hasOpenModals,
  (open, wasOpen) => {
    document.body.style.overflow = open ? 'hidden' : ''
    if (open && !wasOpen) {
      lastFocused = (document.activeElement as HTMLElement) ?? null
    } else if (!open && wasOpen) {
      lastFocused?.focus?.()
      lastFocused = null
    }
  }
)

// Move focus into the newest topmost modal when the stack changes.
watch(
  () => modalStore.topmostModal?.id,
  async (id) => {
    if (!id) return
    await nextTick()
    containerRefs.get(id)?.focus?.()
  }
)

// ─── Sheet drag-to-dismiss ────────────────────────────────────────────────────
const dragY = ref(0)
const draggingId = ref<string | null>(null)
let dragStartY = 0
function onSheetPointerDown(e: PointerEvent, id: string) {
  draggingId.value = id
  dragStartY = e.clientY
  dragY.value = 0
  ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
}
function onSheetPointerMove(e: PointerEvent) {
  if (draggingId.value === null) return
  dragY.value = Math.max(0, e.clientY - dragStartY) // only downward
}
function onSheetPointerUp(id: string) {
  if (draggingId.value === null) return
  const dismissed = dragY.value > 96
  draggingId.value = null
  if (dismissed) modalStore.close(id)
  dragY.value = 0
}

onMounted(() => document.addEventListener('keydown', handleKeyDown))
onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown)
  document.body.style.overflow = ''
})

// ─── Toast / Banner tone → class ──────────────────────────────────────────────
const toneClass = (t: FeedbackTone) => `is-${t}`
</script>

<template>
  <slot />

  <Teleport to="body">
    <!-- ═══ Modal stack (menu / sheet / dialog / fullscreen / popover) ═══ -->
    <template v-for="modal in modalStore.activeModals" :key="modal.id">
      <Transition name="mp-backdrop" appear>
        <div
          class="ModalProvider__overlay"
          :class="modal.type === 'dialog' && 'ModalProvider__overlay--dim'"
          :style="{ zIndex: modal.zIndex - 1 }"
          @click="onBackdrop(modal)"
          aria-hidden="true"
        />
      </Transition>

      <Transition :name="`mp-${modal.type}`" appear>
        <div
          :ref="(el) => setContainerRef(modal.id, el)"
          tabindex="-1"
          :class="[
            'ModalProvider__modal',
            `ModalProvider__modal--${modal.type}`,
            modal.isTransitioning && 'ModalProvider__modal--transitioning',
          ]"
          :style="{
            zIndex: modal.zIndex,
            ...(modal.type === 'sheet' && draggingId === modal.id
              ? { transform: `translateY(${dragY}px)`, transition: 'none' }
              : {}),
          }"
          role="dialog"
          aria-modal="true"
        >
          <!-- Content-transition loading bar (wizards) -->
          <div v-if="modal.isTransitioning" class="ModalProvider__loading-bar" />

          <!-- Drag handle (sheet) -->
          <div
            v-if="modal.type === 'sheet'"
            class="ModalProvider__grabber-area"
            @pointerdown="(e) => onSheetPointerDown(e, modal.id)"
            @pointermove="onSheetPointerMove"
            @pointerup="() => onSheetPointerUp(modal.id)"
            @pointercancel="() => onSheetPointerUp(modal.id)"
          >
            <span class="ModalProvider__grabber" />
          </div>

          <!-- Close affordance (fullscreen / menu) -->
          <div
            v-if="(modal.type === 'fullscreen' || modal.type === 'menu') && !modal.hideCloseButton"
            :class="modal.type === 'fullscreen' ? 'ModalProvider__close-container' : 'ModalProvider__menu-close-container'"
          >
            <button class="ModalProvider__close" @click="modalStore.close(modal.id)" aria-label="Close">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          <div :class="['ModalProvider__content', modal.isTransitioning && 'ModalProvider__content--transitioning']">
            <component :is="modalRegistry[modal.contentId]" v-if="modalRegistry[modal.contentId]" />
            <div v-else class="ModalProvider__missing">No content registered for "{{ modal.contentId }}"</div>
          </div>
        </div>
      </Transition>
    </template>

    <!-- ═══ Banner (single, top, slide-down) ═══ -->
    <Transition name="mp-banner">
      <div
        v-if="toastStore.banner"
        class="ModalProvider__banner"
        :class="toneClass(toastStore.banner.tone)"
        role="alert"
        @click="toastStore.dismissBanner()"
      >
        <span class="ModalProvider__banner-msg">{{ toastStore.banner.message }}</span>
        <button
          v-if="toastStore.banner.retry"
          class="ModalProvider__banner-action"
          @click.stop="() => { const r = toastStore.banner?.retry; toastStore.dismissBanner(); r?.() }"
        >Retry</button>
      </div>
    </Transition>

    <!-- ═══ Toast queue (bottom) ═══ -->
    <div class="ModalProvider__toasts" role="status" aria-live="polite">
      <TransitionGroup name="mp-toast">
        <div
          v-for="t in toastStore.toasts"
          :key="t.id"
          class="ModalProvider__toast"
          :class="toneClass(t.tone)"
          @click="toastStore.dismissToast(t.id)"
        >
          <span class="ModalProvider__toast-msg">{{ t.message }}</span>
          <button
            v-if="t.action"
            class="ModalProvider__toast-action"
            @click.stop="() => { t.action?.onPress(); toastStore.dismissToast(t.id) }"
          >{{ t.action.label }}</button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>
