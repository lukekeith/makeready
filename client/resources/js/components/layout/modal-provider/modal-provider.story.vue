<script setup lang="ts">
import { createPinia } from 'pinia'
import { createApp, ref } from 'vue'
import ModalProvider from './modal-provider.vue'
import { useModalStore } from '../../../stores/modal.store'

// Histoire stories run inside their own Vue app context.
// The story wrapper below shows the ModalProvider with a test button.
const pinia = createPinia()

function openTestMenu() {
  const store = useModalStore()
  store.openMenu('test-menu', 'test-content')
}

function openTestFullscreen() {
  const store = useModalStore()
  store.openFullscreen('test-fullscreen', 'test-content')
}
</script>

<template>
  <Story title="Layout / ModalProvider" :layout="{ type: 'single' }">
    <Variant title="Default">
      <div style="padding: 24px; background: #0a0a0a; min-height: 200px;">
        <p style="color: rgba(255,255,255,0.6); font-size: 14px; margin-bottom: 16px;">
          ModalProvider renders modals via Teleport to body. Open browser DevTools to see the portal.
        </p>
        <div style="display: flex; gap: 8px;">
          <button
            style="padding: 8px 16px; background: #6C47FF; color: white; border: none; border-radius: 6px; cursor: pointer;"
            @click="openTestMenu()"
          >
            Open Menu (bottom sheet)
          </button>
          <button
            style="padding: 8px 16px; background: rgba(255,255,255,0.1); color: white; border: none; border-radius: 6px; cursor: pointer;"
            @click="openTestFullscreen()"
          >
            Open Fullscreen
          </button>
        </div>
        <p style="color: rgba(255,255,255,0.3); font-size: 12px; margin-top: 12px;">
          Note: Story context uses separate Pinia instance per island. In production, share a single Pinia across all islands.
        </p>
      </div>
    </Variant>
  </Story>
</template>
