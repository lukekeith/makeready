import type { Component } from 'vue'
import OverlayDemoMenu from './components/overlay/overlay-demo-menu/overlay-demo-menu.vue'

// Registry mapping contentId strings → Vue components rendered inside the
// ModalProvider chrome. To add a store-driven overlay:
//   1. Build a content component (renders inside the chrome; dismiss via the
//      modal store's closeTopmost()/close(id)).
//   2. Register it here under a stable contentId.
//   3. Open it: useModalStore().openMenu(id, 'your-content-id')  (or
//      openSheet / openDialog / openFullscreen / openPopover).
// Full recipe: docs/ui/COMPONENT_INVENTORY.md §6 "How to add an overlay".
export const modalRegistry: Record<string, Component> = {
  'demo-menu': OverlayDemoMenu,
}
