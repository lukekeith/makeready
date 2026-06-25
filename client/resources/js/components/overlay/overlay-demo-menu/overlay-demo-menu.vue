<script setup lang="ts">
// Demo registry content — shows the store-driven overlay pattern: an overlay
// content component is a plain component that renders inside ModalProvider
// chrome and dismisses itself via the store. Registered as 'demo-menu' in
// modal-registry.ts. See the "How to add an overlay" recipe in
// docs/ui/COMPONENT_INVENTORY.md §6.
import { useModalStore } from '../../../stores/modal.store'
import { useToastStore } from '../../../stores/toast.store'

const modal = useModalStore()
const toast = useToastStore()

const actions = [
  { key: 'edit', label: 'Edit group', tone: 'default' as const },
  { key: 'share', label: 'Share invite', tone: 'default' as const },
  { key: 'leave', label: 'Leave group', tone: 'destructive' as const },
]

function pick(key: string) {
  modal.closeTopmost()
  toast.showToast({ message: `Selected: ${key}`, tone: key === 'leave' ? 'error' : 'neutral' })
}
</script>

<template>
  <div class="OverlayDemoMenu">
    <h3 class="OverlayDemoMenu__title">Group actions</h3>
    <button
      v-for="a in actions"
      :key="a.key"
      type="button"
      class="OverlayDemoMenu__item"
      :class="a.tone === 'destructive' && 'OverlayDemoMenu__item--destructive'"
      @click="pick(a.key)"
    >
      {{ a.label }}
    </button>
  </div>
</template>

<style scoped>
.OverlayDemoMenu__title {
  font-size: var(--text-overline, var(--text-xs));
  text-transform: uppercase;
  letter-spacing: var(--tracking-wide);
  color: var(--fg-tertiary);
  margin-bottom: var(--space-md);
}
.OverlayDemoMenu__item {
  display: block;
  width: 100%;
  text-align: left;
  min-height: var(--touch-min);
  padding: var(--space-md) var(--space-sm);
  background: transparent;
  border: none;
  border-radius: var(--radius-md);
  color: var(--fg-primary);
  font-size: var(--text-md);
  cursor: pointer;
  transition: background var(--motion-micro-fast) var(--ease-standard);
}
.OverlayDemoMenu__item:hover { background: var(--color-white-5); }
.OverlayDemoMenu__item--destructive { color: var(--fg-destructive); }
</style>
