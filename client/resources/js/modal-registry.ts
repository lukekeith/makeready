import type { Component } from 'vue'

// Registry mapping contentId strings to Vue components.
// Add entries here as modal content components are created in subsequent plans.
// e.g. import AccountModalContent from './components/domain/account-modal-content/account-modal-content.vue'

export const modalRegistry: Record<string, Component> = {
  // 'account-modal-content': AccountModalContent,
}
