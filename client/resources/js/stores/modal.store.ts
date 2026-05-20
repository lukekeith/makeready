// Pinia modal store — port of archive/react-spa:src/store/ui/modal.service.ts
// Replicates the MobX ModalService API exactly:
//   openMenu / openFullscreen / close / closeTopmost / transitionContent
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export type ModalType = 'menu' | 'fullscreen'
export type ModalPriority = 'low' | 'high'

export interface IModalConfig {
  id: string
  contentId: string
  type: ModalType
  priority: ModalPriority
  hideCloseButton?: boolean
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
    close,
    closeTopmost,
    closeAllByPriority,
    transitionContent,
    isOpen,
  }
})
