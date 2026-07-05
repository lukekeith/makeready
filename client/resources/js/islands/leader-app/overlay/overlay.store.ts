import { markRaw, ref, type Component } from 'vue'
import { defineStore } from 'pinia'
import type { OverlayRoute } from './overlay-routes'

// OverlayManager — web twin of iPhone Services/OverlayManager.swift.
//
// Single source of truth is `overlays`, kept sorted ascending by priority;
// render order = paint order (the host assigns z-index by array position), so
// modal-on-modal stacking and topLevel-above-everything fall out of the sort —
// exactly the iOS algorithm. Presenting an id that's already shown replaces it.
//
// Dismissal is two-phase, mirroring iOS:
//   • Chrome wrappers register an *animated* dismiss handler on mount.
//   • dismiss(id) asks the wrapper to run its exit animation; the wrapper calls
//     finalize(id) from its transition-end, which removes the overlay and fires
//     any queued completions.
//   • dismissThen(id, cb) queues cb to run only after the exit animation truly
//     finishes — the sequencing primitive for "menu action opens a modal"
//     (never dismiss + present simultaneously).

export interface OverlayItem {
  id: string
  priority: number
  chrome: OverlayRoute['chrome']
  dismissOnTapOutside: boolean
  component: Component
  props: Record<string, unknown>
  /** Monotonic key so re-presenting the same id remounts fresh. */
  key: number
}

let nextKey = 1

export const useOverlayManager = defineStore('leader-overlay-manager', () => {
  const overlays = ref<OverlayItem[]>([])

  // Non-reactive registries (iOS @ObservationIgnored dictionaries).
  const animatedDismissHandlers = new Map<string, () => void>()
  const dismissCompletions = new Map<string, Array<() => void>>()

  function present(
    route: OverlayRoute,
    component: Component,
    props: Record<string, unknown> = {},
  ): void {
    overlays.value = overlays.value.filter((o) => o.id !== route.id)
    overlays.value.push({
      id: route.id,
      priority: route.priority,
      chrome: route.chrome,
      dismissOnTapOutside: route.dismissOnTapOutside,
      component: markRaw(component),
      props,
      key: nextKey++,
    })
    // Ascending priority; equal priorities keep insertion order (stable sort).
    overlays.value.sort((a, b) => a.priority - b.priority)
  }

  function isPresented(id: string): boolean {
    return overlays.value.some((o) => o.id === id)
  }

  /** Chrome wrappers register their exit animation here (onMounted). */
  function registerAnimatedDismiss(id: string, handler: () => void): void {
    animatedDismissHandlers.set(id, handler)
  }

  /** Instant removal — called by chrome at the END of its exit animation. */
  function finalize(id: string): void {
    overlays.value = overlays.value.filter((o) => o.id !== id)
    animatedDismissHandlers.delete(id)
    const completions = dismissCompletions.get(id) ?? []
    dismissCompletions.delete(id)
    for (const completion of completions) completion()
  }

  /** Animated dismiss (falls back to instant if no chrome registered). */
  function dismiss(id: string): void {
    const animated = animatedDismissHandlers.get(id)
    if (animated) animated()
    else finalize(id)
  }

  /** Animate out, then run the completion once actually removed. */
  function dismissThen(id: string, completion: () => void): void {
    if (!isPresented(id)) {
      completion()
      return
    }
    const queue = dismissCompletions.get(id) ?? []
    queue.push(completion)
    dismissCompletions.set(id, queue)
    dismiss(id)
  }

  return {
    overlays,
    present,
    dismiss,
    dismissThen,
    isPresented,
    registerAnimatedDismiss,
    finalize,
  }
})

/** Injection key for content inside an overlay: { dismiss, dismissThen }. */
export const OVERLAY_CONTEXT = Symbol('leader-overlay-context')

export interface OverlayContext {
  dismiss: () => void
  dismissThen: (completion: () => void) => void
}
