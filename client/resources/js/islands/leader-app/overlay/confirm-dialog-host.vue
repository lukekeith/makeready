<script setup lang="ts">
// ConfirmDialogHost — the single full-screen renderer for useConfirmDialog
// requests. Chrome matches the /library/programs delete confirm (the
// reference implementation): fixed blurred dim wash over EVERYTHING (iOS
// alerts are window-level), DialogOverlay scale-in 0.9→1 @ 200ms ease-out.
// Mounted once in leader-app.vue.
import DialogOverlay from '../../../components/card/dialog-overlay/dialog-overlay.vue'
import { useConfirmDialog } from './confirm-dialog.store'

const dialog = useConfirmDialog()
</script>

<template>
  <Transition name="ConfirmDialogHost">
    <div v-if="dialog.active" class="ConfirmDialogHost__scrim" @click.self="dialog.scrimTap()">
      <DialogOverlay
        class="ConfirmDialogHost__dialog"
        :title="dialog.active.title"
        :message="dialog.active.message ?? ''"
        :buttons="dialog.active.buttons"
        @select="dialog.select($event)"
      />
    </div>
  </Transition>
</template>

<style scoped>
.ConfirmDialogHost__scrim {
  position: fixed;
  inset: 0;
  /* Above the overlay-manager stack (z = 100 + index) and every local pane
     overlay — iOS alerts always sit at the top of the window. */
  z-index: 500;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}

.ConfirmDialogHost__dialog {
  max-width: 480px; /* stay within the phone column on wide viewports */
  transition:
    transform 250ms ease-out,
    opacity 250ms ease-out;
}

.ConfirmDialogHost-enter-active,
.ConfirmDialogHost-leave-active {
  transition: opacity 200ms ease-out;
}

.ConfirmDialogHost-enter-from,
.ConfirmDialogHost-leave-to {
  opacity: 0;
}

.ConfirmDialogHost-enter-from .ConfirmDialogHost__dialog,
.ConfirmDialogHost-leave-to .ConfirmDialogHost__dialog {
  transform: scale(0.9);
}
</style>
