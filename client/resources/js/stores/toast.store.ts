// Toast / Banner store — the ephemeral feedback channel (PRD §8.6).
// Deliberately SEPARATE from the modal stack: toasts and the banner do not
// participate in z-stacking, priority, or focus trapping. They auto-dismiss.
//
//   banner — a single top slide-down message (iOS ErrorBanner parity):
//            auto-dismiss after `duration`, swipe/tap to dismiss, optional retry.
//   toast  — a short bottom message; a small queue (max 3) that auto-dismisses.
import { defineStore } from 'pinia'
import { ref } from 'vue'

export type FeedbackTone = 'neutral' | 'error' | 'success' | 'warning'

export interface IToast {
  id: string
  message: string
  tone: FeedbackTone
  /** Optional inline action (label + handler). */
  action?: { label: string; onPress: () => void }
}

export interface IBanner {
  id: string
  message: string
  tone: FeedbackTone
  /** Retry affordance — shows a button that runs this then dismisses. */
  retry?: () => void
}

const DEFAULT_DURATION = 4000 // matches iOS ErrorBanner (4s)
const MAX_TOASTS = 3

// Monotonic id source — avoids Date.now()/Math.random() (forbidden in some
// harness contexts and unnecessary here).
let _seq = 0
const nextId = () => `fb-${++_seq}`

export const useToastStore = defineStore('toast', () => {
  const toasts = ref<IToast[]>([])
  const banner = ref<IBanner | null>(null)
  const _timers = new Map<string, ReturnType<typeof setTimeout>>()

  function _arm(id: string, duration: number, onExpire: () => void) {
    if (duration <= 0) return
    _timers.set(id, setTimeout(() => {
      _timers.delete(id)
      onExpire()
    }, duration))
  }

  function _disarm(id: string) {
    const t = _timers.get(id)
    if (t) {
      clearTimeout(t)
      _timers.delete(id)
    }
  }

  // ─── Toasts ────────────────────────────────────────────────────────────────
  function showToast(opts: {
    message: string
    tone?: FeedbackTone
    duration?: number
    action?: IToast['action']
  }): string {
    const id = nextId()
    const toast: IToast = { id, message: opts.message, tone: opts.tone ?? 'neutral', action: opts.action }
    toasts.value.push(toast)
    // Cap the queue — drop the oldest.
    while (toasts.value.length > MAX_TOASTS) {
      const dropped = toasts.value.shift()
      if (dropped) _disarm(dropped.id)
    }
    _arm(id, opts.duration ?? DEFAULT_DURATION, () => dismissToast(id))
    return id
  }

  function dismissToast(id: string) {
    _disarm(id)
    toasts.value = toasts.value.filter(t => t.id !== id)
  }

  // ─── Banner (single, top) ────────────────────────────────────────────────────
  function showBanner(opts: {
    message: string
    tone?: FeedbackTone
    duration?: number
    retry?: () => void
  }): string {
    // Replace any existing banner (non-stacking).
    if (banner.value) _disarm(banner.value.id)
    const id = nextId()
    banner.value = { id, message: opts.message, tone: opts.tone ?? 'error', retry: opts.retry }
    _arm(id, opts.duration ?? DEFAULT_DURATION, () => dismissBanner())
    return id
  }

  function dismissBanner() {
    if (banner.value) _disarm(banner.value.id)
    banner.value = null
  }

  // Convenience: surface an error the way iOS recordError(surface:true) does.
  function error(message: string, retry?: () => void): string {
    return showBanner({ message, tone: 'error', retry })
  }

  return {
    toasts,
    banner,
    showToast,
    dismissToast,
    showBanner,
    dismissBanner,
    error,
  }
})
