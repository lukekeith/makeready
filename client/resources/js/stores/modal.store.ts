// Pinia modal store — port of archive/react-spa:src/store/ui/modal.service.ts
// Replicates the MobX ModalService API exactly:
//   openMenu / openFullscreen / close / closeTopmost / transitionContent
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// Overlay taxonomy (PRD §8). All overlays flow through this one manager:
//   menu       — bottom sheet of actions (non-draggable)
//   sheet      — draggable bottom sheet
//   dialog     — centered, scale + fade
//   fullscreen — full-screen flow (wizards)
//   popover    — anchored floating panel
// Toasts and banners are NOT here — they are an ephemeral channel in
// toast.store.ts, deliberately separate from this stack.
export type ModalType = 'menu' | 'fullscreen' | 'dialog' | 'sheet' | 'popover'
export type ModalPriority = 'low' | 'high'

export interface IModalConfig {
  id: string
  contentId: string
  type: ModalType
  priority: ModalPriority
  hideCloseButton?: boolean
  /** Tap-on-backdrop dismiss. Defaults true for menu/sheet/dialog/popover,
   *  false for fullscreen (flows dismiss via their own controls). */
  dismissOnBackdrop?: boolean
  /** Optional anchor element id/ref for popover positioning (provider reads it). */
  anchorId?: string
  onClose?: () => void
}

export interface IModalInstance extends IModalConfig {
  zIndex: number
  depth: number
  isTransitioning: boolean
  transitioningTo: string | null
}

const BASE_Z_INDEX = 1000
const Z_INDEX_INCREMENT = 10

export const useModalStore = defineStore('modal', () => {
  const _modalStack = ref<IModalConfig[]>([])
  const _transitions = ref<Map<string, { fromContentId: string; toContentId: string; duration: number }>>(new Map())
  const _currentContentIds = ref<Map<string, string>>(new Map())

  const activeModals = computed<IModalInstance[]>(() =>
    _modalStack.value.map((modal, index) => ({
      ...modal,
      contentId: _currentContentIds.value.get(modal.id) ?? modal.contentId,
      depth: index,
      zIndex: BASE_Z_INDEX + index * Z_INDEX_INCREMENT,
      isTransitioning: _transitions.value.has(modal.id),
      transitioningTo: _transitions.value.get(modal.id)?.toContentId ?? null,
    }))
  )

  const topmostModal = computed(() =>
    activeModals.value.length > 0 ? activeModals.value[activeModals.value.length - 1] : null
  )

  const hasOpenModals = computed(() => _modalStack.value.length > 0)

  function open(config: IModalConfig): string {
    if (config.priority === 'high') {
      closeAllByPriority('low')
    }
    const existingIndex = _modalStack.value.findIndex(m => m.id === config.id)
    if (existingIndex >= 0) {
      _modalStack.value.splice(existingIndex, 1)
    }
    _modalStack.value.push(config)
    _currentContentIds.value.set(config.id, config.contentId)
    return config.id
  }

  function openMenu(id: string, contentId: string, options?: { onClose?: () => void }): string {
    return open({ id, contentId, type: 'menu', priority: 'low', onClose: options?.onClose })
  }

  function openFullscreen(
    id: string,
    contentId: string,
    options?: { onClose?: () => void; hideCloseButton?: boolean }
  ): string {
    return open({ id, contentId, type: 'fullscreen', priority: 'high', ...options })
  }

  // Centered dialog (scale + fade). High priority — closes low menus/sheets.
  function openDialog(
    id: string,
    contentId: string,
    options?: { onClose?: () => void; hideCloseButton?: boolean; dismissOnBackdrop?: boolean }
  ): string {
    return open({ id, contentId, type: 'dialog', priority: 'high', hideCloseButton: true, ...options })
  }

  // Draggable bottom sheet. Low priority (a high dialog can sit over it).
  function openSheet(
    id: string,
    contentId: string,
    options?: { onClose?: () => void; hideCloseButton?: boolean; dismissOnBackdrop?: boolean }
  ): string {
    return open({ id, contentId, type: 'sheet', priority: 'low', ...options })
  }

  // Anchored popover. Low priority, dismiss on backdrop/outside.
  function openPopover(
    id: string,
    contentId: string,
    options?: { onClose?: () => void; anchorId?: string; dismissOnBackdrop?: boolean }
  ): string {
    return open({ id, contentId, type: 'popover', priority: 'low', hideCloseButton: true, ...options })
  }

  function close(id: string): void {
    const modal = _modalStack.value.find(m => m.id === id)
    modal?.onClose?.()
    _modalStack.value = _modalStack.value.filter(m => m.id !== id)
    _transitions.value.delete(id)
    _currentContentIds.value.delete(id)
  }

  function closeTopmost(): void {
    const top = topmostModal.value
    if (top) close(top.id)
  }

  function closeAllByPriority(priority: ModalPriority): void {
    _modalStack.value
      .filter(m => m.priority === priority)
      .forEach(m => {
        m.onClose?.()
        _transitions.value.delete(m.id)
        _currentContentIds.value.delete(m.id)
      })
    _modalStack.value = _modalStack.value.filter(m => m.priority !== priority)
  }

  function transitionContent(modalId: string, toContentId: string, duration = 300): void {
    const modal = _modalStack.value.find(m => m.id === modalId)
    if (!modal) return
    const from = _currentContentIds.value.get(modalId) ?? modal.contentId
    _transitions.value.set(modalId, { fromContentId: from, toContentId, duration })
    setTimeout(() => {
      _currentContentIds.value.set(modalId, toContentId)
      _transitions.value.delete(modalId)
    }, duration)
  }

  function isOpen(id: string): boolean {
    return _modalStack.value.some(m => m.id === id)
  }

  return {
    activeModals,
    topmostModal,
    hasOpenModals,
    open,
    openMenu,
    openFullscreen,
    openDialog,
    openSheet,
    openPopover,
    close,
    closeTopmost,
    closeAllByPriority,
    transitionContent,
    isOpen,
  }
})
