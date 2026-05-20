<script setup lang="ts">
import { ref } from 'vue'
import Modal from './modal.vue'

const fullscreenOpen = ref(false)
const menuOpen = ref(false)
const noCloseOpen = ref(false)
</script>

<template>
  <Story title="Primitive/Modal" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Fullscreen">
      <button @click="fullscreenOpen = true" style="padding: 8px 16px; background: #6C47FF; color: white; border: none; border-radius: 6px; cursor: pointer;">
        Open Fullscreen Modal
      </button>
      <Modal :is-open="fullscreenOpen" mode="Fullscreen" aria-title="Example Modal" @close="fullscreenOpen = false">
        <div style="color: white; text-align: center; padding: 24px;">
          <h2>Modal Content</h2>
          <p>This is a fullscreen modal.</p>
        </div>
      </Modal>
    </Variant>
    <Variant title="Menu (Bottom Sheet)">
      <button @click="menuOpen = true" style="padding: 8px 16px; background: #6C47FF; color: white; border: none; border-radius: 6px; cursor: pointer;">
        Open Menu
      </button>
      <Modal :is-open="menuOpen" mode="Menu" aria-title="Menu" @close="menuOpen = false">
        <div style="color: white; padding: 8px 0;">
          <p>Menu option 1</p>
          <p>Menu option 2</p>
          <p>Menu option 3</p>
        </div>
      </Modal>
    </Variant>
    <Variant title="No Close Button">
      <button @click="noCloseOpen = true" style="padding: 8px 16px; background: #6C47FF; color: white; border: none; border-radius: 6px; cursor: pointer;">
        Open (no close btn)
      </button>
      <Modal :is-open="noCloseOpen" :show-close-button="false" aria-title="Modal" @close="noCloseOpen = false">
        <div style="color: white; text-align: center; padding: 24px;">
          <p>Click outside to close</p>
        </div>
      </Modal>
    </Variant>
  </Story>
</template>
