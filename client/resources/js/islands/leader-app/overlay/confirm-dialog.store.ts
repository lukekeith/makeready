// Confirmation-dialog service — ONE presentation path for every iOS-style
// alert/confirm in the LeaderApp (web equivalent of SwiftUI .alert / the iOS
// DialogOverlay presentations, which always sit at window level).
//
// A single ConfirmDialogHost (mounted in leader-app.vue) renders the active
// request full-screen — fixed blurred scrim + scale-in DialogOverlay — so
// every screen gets the identical chrome the /library/programs delete confirm
// established. Call sites await the tapped button index:
//
//   const confirmDialog = useConfirmDialog()
//   const choice = await confirmDialog.confirm({
//     title: 'Delete Block',
//     message: 'Are you sure…',
//     buttons: [
//       { label: 'Delete', style: 'destructive' },
//       { label: 'Cancel', style: 'secondary' },
//     ],
//   })
//   if (choice === 0) { …destructive action… }
//
// `choice` resolves with the button index, or null when the scrim dismisses
// the dialog. For in-flight states ("Adding..."), present({ sticky: true })
// returns a handle: the tap resolves `choice` but the dialog STAYS until
// update()/close() — matching the Program Home add-day flow.

import { defineStore } from 'pinia'
import { shallowRef } from 'vue'

export interface ConfirmDialogButton {
  label: string
  style?: 'primary' | 'secondary' | 'destructive' | string
}

export interface ConfirmDialogOptions {
  title: string
  message?: string
  buttons: ConfirmDialogButton[]
  /** Scrim tap dismisses (resolves null). Default true — iOS tap-outside. */
  dismissOnScrimTap?: boolean
  /** Button tap resolves `choice` but keeps the dialog up until close(). */
  sticky?: boolean
}

interface ActiveDialog extends ConfirmDialogOptions {
  dismissOnScrimTap: boolean
  sticky: boolean
}

export interface ConfirmDialogHandle {
  /** Resolves the tapped button index, or null on scrim dismiss. */
  choice: Promise<number | null>
  /** Patch the visible dialog (e.g. flip a button label to "Adding..."). */
  update(patch: Partial<Pick<ConfirmDialogOptions, 'title' | 'message' | 'buttons'>>): void
  close(): void
}

export const useConfirmDialog = defineStore('leader-confirm-dialog', () => {
  const active = shallowRef<ActiveDialog | null>(null)
  let resolver: ((index: number | null) => void) | null = null

  function settle(index: number | null): void {
    const r = resolver
    resolver = null
    r?.(index)
  }

  function present(options: ConfirmDialogOptions): ConfirmDialogHandle {
    // A second present replaces the first (shouldn't happen in practice) —
    // resolve the abandoned request as dismissed.
    settle(null)
    active.value = {
      dismissOnScrimTap: true,
      sticky: false,
      ...options,
    }
    const choice = new Promise<number | null>((resolve) => {
      resolver = resolve
    })
    return {
      choice,
      update(patch) {
        if (active.value) active.value = { ...active.value, ...patch }
      },
      close() {
        settle(null)
        active.value = null
      },
    }
  }

  /** The common case: present and await the tapped button index. */
  function confirm(options: ConfirmDialogOptions): Promise<number | null> {
    return present(options).choice
  }

  // Host callbacks.
  function select(index: number): void {
    if (!active.value) return
    const sticky = active.value.sticky
    settle(index)
    if (!sticky) active.value = null
  }

  function scrimTap(): void {
    if (!active.value?.dismissOnScrimTap) return
    settle(null)
    active.value = null
  }

  return { active, present, confirm, select, scrimTap }
})
