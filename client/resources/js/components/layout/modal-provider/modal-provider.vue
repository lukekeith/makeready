<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue'
import { useModalStore } from '../../../stores/modal.store'
import { modalRegistry } from '../../../modal-registry'
import './modal-provider.scss'

const modalStore = useModalStore()

function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape' && modalStore.hasOpenModals) {
    e.preventDefault()
    modalStore.closeTopmost()
  }
}

// Prevent body scroll when modals are open
function updateBodyScroll() {
  document.body.style.overflow = modalStore.hasOpenModals ? 'hidden' : ''
}

onMounted(() => {
  document.addEventListener('keydown', handleKeyDown)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown)
  document.body.style.overflow = ''
})
</script>

<template>
  <slot />

  <Teleport to="body">
    <template v-for="modal in modalStore.activeModals" :key="modal.id">
      <!-- Backdrop overlay -->
      <div
        class="ModalProvider__overlay"
        :style="{ zIndex: modal.zIndex - 1 }"
        @click="modalStore.close(modal.id)"
        aria-hidden="true"
      />

      <!-- Modal container -->
      <div
        :class="[
          'ModalProvider__modal',
          modal.type === 'fullscreen' && 'ModalProvider__modal--fullscreen',
          modal.type === 'menu' && 'ModalProvider__modal--menu',
          modal.isTransitioning && 'ModalProvider__modal--transitioning',
        ]"
        :style="{ zIndex: modal.zIndex }"
        role="dialog"
        aria-modal="true"
      >
        <!-- Loading bar during content transitions -->
        <div v-if="modal.isTransitioning" class="ModalProvider__loading-bar" />

        <!-- Close button for fullscreen modals -->
        <div
          v-if="modal.type === 'fullscreen' && !modal.hideCloseButton"
          class="ModalProvider__close-container"
        >
          <button
            class="ModalProvider__close"
            @click="modalStore.close(modal.id)"
            aria-label="Close"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        <!-- Close button for menu modals -->
        <div
          v-if="modal.type === 'menu' && !modal.hideCloseButton"
          class="ModalProvider__menu-close-container"
        >
          <button
            class="ModalProvider__close"
            @click="modalStore.close(modal.id)"
            aria-label="Close"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        <!-- Modal content resolved from registry -->
        <div
          :class="[
            'ModalProvider__content',
            modal.isTransitioning && 'ModalProvider__content--transitioning',
          ]"
        >
          <component
            :is="modalRegistry[modal.contentId]"
            v-if="modalRegistry[modal.contentId]"
          />
          <div v-else style="padding: 16px; color: rgba(255,255,255,0.5); font-size: 12px;">
            No content registered for "{{ modal.contentId }}"
          </div>
        </div>
      </div>
    </template>
  </Teleport>
</template>
