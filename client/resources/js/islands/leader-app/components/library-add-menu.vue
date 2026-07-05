<script setup lang="ts">
// LibraryAddMenu — content of the .libraryAddMenu overlay route: the iOS
// Library "+" → "Create New" ActionCardMenu presented inside ManagedMenuView
// (MainLibrary.swift:250-263). The chrome (card, scrim, grabber, springs)
// comes from managed-menu.vue; this component is only the ActionCardMenu twin
// plus the iOS action sequencing:
//   • "Study Program" → dismissThen(.createProgram) — the menu's exit
//     animation truly completes before the modal presents (no setTimeout).
//   • "Media" → dismiss-only stub, matching the iPhone TODO.
//   • xmark / scrim → plain dismiss.
import { inject } from 'vue'
import ActionCardMenu from '../../../components/card/action-card-menu/action-card-menu.vue'
import { ROUTES } from '../overlay/overlay-routes'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import CreateProgramModal from './create-program-modal.vue'

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()

// iOS MainLibrary ActionCardMenu items (SF book.fill / photo.on.rectangle).
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/><path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/></svg>'
const PHOTO_ON_RECTANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="7" y="3" width="14" height="11" rx="2"/><circle cx="11" cy="7" r="1.3"/><path d="M8 12.5l3-3.2 2.4 2.4 2.4-2.8L20 13"/><path d="M17 17H5a2 2 0 0 1-2-2V7"/></svg>'

const ITEMS = [
  { icon: BOOK_FILL, title: 'Study Program', description: 'Create a new study program' },
  { icon: PHOTO_ON_RECTANGLE, title: 'Media', description: 'Upload photos or videos' },
]

function onSelect(index: number): void {
  if (ITEMS[index]?.title === 'Study Program') {
    // iOS: overlayManager.dismiss(.libraryAddMenu) { present(.createProgram) }
    overlay?.dismissThen(() => {
      overlayManager.present(ROUTES.createProgram, CreateProgramModal, {})
    })
  } else {
    overlay?.dismiss()
  }
}
</script>

<template>
  <ActionCardMenu
    title="Create New"
    :items="ITEMS"
    @select="onSelect"
    @close="overlay?.dismiss()"
  />
</template>
