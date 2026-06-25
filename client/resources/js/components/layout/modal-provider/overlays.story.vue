<script setup lang="ts">
import ModalProvider from './modal-provider.vue'
import DeviceFrame from '../device-frame/device-frame.vue'
import Button from '../../primitive/button/button.vue'
import { useModalStore } from '../../../stores/modal.store'
import { useToastStore } from '../../../stores/toast.store'

// Store-driven overlay orchestration. Pinia is installed globally in
// histoire.setup.ts, so the stores resolve here. ModalProvider teleports the
// overlays + toast/banner channel to <body>.
const modal = useModalStore()
const toast = useToastStore()

const openMenu = () => modal.openMenu('demo', 'demo-menu')
const openSheet = () => modal.openSheet('demo', 'demo-menu')
const openDialog = () => modal.openDialog('demo', 'demo-menu')
const openFullscreen = () => modal.openFullscreen('demo', 'demo-menu')

const toastIt = () => toast.showToast({ message: 'Saved to library', tone: 'success' })
const toastAction = () =>
  toast.showToast({ message: 'Group archived', tone: 'neutral', action: { label: 'Undo', onPress: () => {} } })
const bannerIt = () =>
  toast.error("Couldn't send invite — check your connection.", () => toast.showToast({ message: 'Retrying…', tone: 'neutral' }))
</script>

<template>
  <Story title="Overlays/Overlay Manager" :layout="{ type: 'single' }">
    <Variant title="Store-driven overlays + toast/banner">
      <DeviceFrame size="Md">
        <ModalProvider>
          <div class="OverlaysDemo">
            <h2>Overlay manager</h2>
            <p>Each opens through the single Pinia modal store; toasts/banner flow through the ephemeral channel.</p>

            <div class="OverlaysDemo__group">
              <span>Modal stack</span>
              <Button mode="Action" variant="Secondary" @click="openMenu">Menu</Button>
              <Button mode="Action" variant="Secondary" @click="openSheet">Sheet (drag)</Button>
              <Button mode="Action" variant="Secondary" @click="openDialog">Dialog</Button>
              <Button mode="Action" variant="Secondary" @click="openFullscreen">Fullscreen</Button>
            </div>

            <div class="OverlaysDemo__group">
              <span>Ephemeral</span>
              <Button mode="Action" variant="Secondary" @click="toastIt">Toast</Button>
              <Button mode="Action" variant="Secondary" @click="toastAction">Toast + Undo</Button>
              <Button mode="Action" variant="Destructive" @click="bannerIt">Error banner</Button>
            </div>
          </div>
        </ModalProvider>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.OverlaysDemo { padding: var(--space-xl) var(--page-pad-x); }
.OverlaysDemo h2 { font-size: var(--text-heading); font-weight: var(--font-weight-bold); margin-bottom: var(--space-sm); }
.OverlaysDemo p { font-size: var(--text-sm); color: var(--fg-secondary); margin-bottom: var(--space-xl); }
.OverlaysDemo__group { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-sm); margin-bottom: var(--space-lg); }
.OverlaysDemo__group > span { width: 100%; font-size: var(--text-xs); text-transform: uppercase; letter-spacing: var(--tracking-wide); color: var(--fg-tertiary); }
</style>
